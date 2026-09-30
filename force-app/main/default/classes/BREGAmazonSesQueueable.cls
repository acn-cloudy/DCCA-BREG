public with sharing class BREGAmazonSesQueueable implements Queueable, Database.AllowsCallouts {
    static final Integer MAX_CALLS = 100;
    static final Integer MAX_RECIPIENTS = 50;
    static final Integer MAX_NUM_OF_EMAIL_RETRIES = 3;
    private List<Task> tasks;
    private List<Task> processedTasks;
    private List<BREGAmazonSesLogger.LogWrapper> emailLogs = new List<BREGAmazonSesLogger.LogWrapper>();
    static final String STATUS_SUCCESS = 'Success';
    static final String STATUS_ERROR = 'Error';
    static final String STATUS_RETRY = 'Repeat';
    static final String STATUS_COMPLETED = 'Completed';
    static final List<Integer> STATUS_CODES_TO_RETRY = new List<Integer>{ 429, 500, 502, 503, 504 };
    //Task Subject to Mass Email Settings mapping
    private final Map<String, BREG_MassEmailSettings__mdt> emailSettingsMap;

    private BREGAmazonSesQueueable() {
        this.emailSettingsMap = getEmailSettingsMap();
    }

    public BREGAmazonSesQueueable(List<Task> tasks) {
        this();
        this.tasks = tasks.deepClone(true, false, false);
        processedTasks = new List<Task>();
        emailLogs = new List<BREGAmazonSesLogger.LogWrapper>();
    }

    public BREGAmazonSesQueueable(List<Task> remained, List<Task> processed, List<BREGAmazonSesLogger.LogWrapper> logs) {
        this();
        tasks = remained;
        processedTasks = processed;
        emailLogs = logs;
    }

    public void execute(QueueableContext context) {
        List<BREGAmazonSesEmailService.EmailWrapper> currentBatch = new List<BREGAmazonSesEmailService.EmailWrapper>();
        Integer calloutCount = 0;

        Integer firstTaskIndex = 0;

        Map<String, List<Task>> tasksBySubject = groupTasksBySubject(tasks);

        for (String taskSubject : tasksBySubject.keySet()) {
            List<Task> tasks = tasksBySubject.get(taskSubject);
            String templateName = emailSettingsMap.containsKey(taskSubject)
                ? emailSettingsMap.get(taskSubject).breg_Email_Template_Developer_Name__c
                : System.Label.BREG_Default_Email_Template;

            for (Integer taskIndex = 0; taskIndex < tasks.size(); taskIndex++) {
                Task t = tasks[taskIndex];
                Boolean isLast = taskIndex == tasks.size() - 1;
                BREGAmazonSesEmailService.EmailWrapper w = new BREGAmazonSesEmailService.EmailWrapper();
                parseEmails(t, w);
                // Count recipients for SES batch size
                currentBatch.add(w);
                Integer totalRecipients = extractAllEmailRecipients(currentBatch).size();
                Boolean lastComposedEmailWrapperHandled = true;
                //If recipients limit exceeded of last task
                if (totalRecipients >= MAX_RECIPIENTS || isLast) {
                    //If total recipients amount exceeds the limit, then remove the last email wrapper and handle it later
                    if (totalRecipients > MAX_RECIPIENTS) {
                        lastComposedEmailWrapperHandled = false;
                        currentBatch.remove(currentBatch.size() - 1);
                        taskIndex--;
                    }

                    // Send current batch and analyze response
                    sendEmailAndAnalyzeResponse(taskSubject, templateName, currentBatch, firstTaskIndex, taskIndex);
                    calloutCount++;
                    if (calloutCount >= MAX_CALLS) {
                        processedTasks.addAll(getTasksUpTo(taskIndex));
                        List<Task> remained = getTasksBehindThe(taskIndex);
                        if (!remained.isEmpty()) {
                            System.enqueueJob(new BREGAmazonSesQueueable(remained, processedTasks, emailLogs));
                        } else
                            System.attachFinalizer(new BREGAmazonSesQueueableFinalizer(context.getJobId(), processedTasks, emailLogs));
                        return;
                    }
                    currentBatch = new List<BREGAmazonSesEmailService.EmailWrapper>();
                    if (!lastComposedEmailWrapperHandled) {
                        currentBatch.add(w);
                    }
                    firstTaskIndex = ++taskIndex;
                    if (isLast) {
                        //If last task, reduce taskIndex by 1 to avoid List index out of bounds error
                        if (currentBatch.size() > 0) {
                            sendEmailAndAnalyzeResponse(taskSubject, templateName, currentBatch, firstTaskIndex, taskIndex - 1);
                        }
                        processedTasks.addAll(getTasksUpTo(taskIndex - 1));
                        System.attachFinalizer(new BREGAmazonSesQueueableFinalizer(context.getJobId(), processedTasks, emailLogs));
                        return;
                    }
                }
            }
        }
    }

    private void sendEmailAndAnalyzeResponse(
        String taskSubject,
        String templateName,
        List<BREGAmazonSesEmailService.EmailWrapper> currentBatch,
        Integer firstTaskIndex,
        Integer lastTaskIndex
    ) {
        prepareTemplateData(taskSubject, currentBatch);
        HttpResponse res = BREGAmazonSesEmailService.sendBulkTemplatedEmail(templateName, currentBatch);
        //analyze response
        Integer resStatusCode = res.getStatusCode();
        //If error
        if (resStatusCode >= 300) {
            String errorMsg = res.getBody();
            String emailSendingStatus = STATUS_CODES_TO_RETRY.contains(resStatusCode) ? STATUS_RETRY : STATUS_ERROR;
            for (Integer i = firstTaskIndex; i <= lastTaskIndex; i++) {
                tasks[i].breg_Email_Sending_Status__c = emailSendingStatus;
                emailLogs.add(new BREGAmazonSesLogger.LogWrapper(tasks[i].Id, STATUS_ERROR, errorMsg));
            }
        } else {
            List<BREGAmazonSesEmailService.EmailResponse> results = BREGAmazonSesEmailService.parseResponse(res.getBody());
            // Mark tasks as completed
            Integer idx = 0;
            for (Integer i = firstTaskIndex; i <= lastTaskIndex; i++) {
                if (results[idx].Status == STATUS_SUCCESS) {
                    tasks[i].breg_Email_Sending_Status__c = STATUS_SUCCESS;
                    tasks[i].Status = STATUS_COMPLETED;
                } else {
                    tasks[i].breg_Email_Sending_Status__c = STATUS_ERROR;
                }
                emailLogs.add(new BREGAmazonSesLogger.LogWrapper(tasks[i].Id, results[idx].Status, results[idx].Error));
                idx++;
            }
        }
        System.debug('*** res.getBody(): ' + res.getBody());
    }

    private List<Task> getTasksUpTo(Integer index) {
        List<Task> retrievedTasks = new List<Task>();
        for (Integer i = 0; i <= index; i++) {
            retrievedTasks.add(tasks[i]);
        }
        return retrievedTasks;
    }

    private List<Task> getTasksBehindThe(Integer index) {
        List<Task> retrievedTasks = new List<Task>();
        for (Integer i = index + 1; i <= tasks.size() - 1; i++) {
            retrievedTasks.add(tasks[i]);
        }
        return retrievedTasks;
    }

    private Set<String> extractAllEmailRecipients(List<BREGAmazonSesEmailService.EmailWrapper> wrappers) {
        Integer total = 0;
        Set<String> recipients = new Set<String>();
        for (BREGAmazonSesEmailService.EmailWrapper w : wrappers) {
            recipients.addAll(w.to);
            recipients.addAll(w.cc);
            recipients.addAll(w.bcc);
        }
        return recipients;
    }

    private void parseEmails(Task t, BREGAmazonSesEmailService.EmailWrapper w) {
        w.to = BREGAmazonSesEmailService.parseEmails(t.breg_To__c);
        w.cc = BREGAmazonSesEmailService.parseEmails(t.breg_Cc__c);
        w.bcc = BREGAmazonSesEmailService.parseEmails(t.breg_Bcc__c);
        w.WhoId = t.WhoId;
        w.WhatId = t.WhatId;
    }

    private void prepareTemplateData(String taskSubject, List<BREGAmazonSesEmailService.EmailWrapper> wrappers) {
        try {
            List<Map<String, Id>> recordIdMaps = new List<Map<String, Id>>();
            for (BREGAmazonSesEmailService.EmailWrapper wrapper : wrappers) {
                recordIdMaps.add(new Map<String, Id>{ 'WhoId' => wrapper.WhoId, 'WhatId' => wrapper.WhatId });
            }
            Type dataProviderType = Type.forName(emailSettingsMap.get(taskSubject).breg_Apex_Data_Provider__c);
            BREGAmazonSesDataProvider dataProvider = (BREGAmazonSesDataProvider) dataProviderType.newInstance();
            List<Map<String, Object>> templateData = dataProvider.getTemplateData(recordIdMaps);
            for (Integer i = 0; i < templateData.size(); i++) {
                wrappers[i].replacementData = templateData[i];
            }
        } catch (Exception e) {
            System.debug('Error preparing template data: ' + e.getMessage());
        }
    }

    private Map<String, List<Task>> groupTasksBySubject(List<Task> tasks) {
        Map<String, List<Task>> tasksBySubject = new Map<String, List<Task>>();
        for (Task t : tasks) {
            if (!tasksBySubject.containsKey(t.Subject)) {
                tasksBySubject.put(t.Subject, new List<Task>());
            }
            tasksBySubject.get(t.Subject).add(t);
        }
        return tasksBySubject;
    }

    private Map<String, BREG_MassEmailSettings__mdt> getEmailSettingsMap() {
        Map<String, BREG_MassEmailSettings__mdt> settingsBySubjectMap = new Map<String, BREG_MassEmailSettings__mdt>();
        if (!Test.isRunningTest()) {
            Map<String, BREG_MassEmailSettings__mdt> settingsMap = BREG_MassEmailSettings__mdt.getAll();
            for (BREG_MassEmailSettings__mdt setting : settingsMap.values()) {
                settingsBySubjectMap.put(setting.breg_Task_Subject__c, setting);
            }
        } else {
            BREG_MassEmailSettings__mdt testConfig = new BREG_MassEmailSettings__mdt(
                breg_Task_Subject__c = 'Annual Renewal Upcoming Alert',
                breg_Email_Template_Developer_Name__c = 'Email_Online_Annual_Reminders_Upcoming',
                breg_Apex_Data_Provider__c = 'BREGAmazonSesDataProvider'
            );
            settingsBySubjectMap.put(testConfig.breg_Task_Subject__c, testConfig);
        }
        return settingsBySubjectMap;
    }

    public class BREGAmazonSesQueueableFinalizer implements Finalizer {
        Id queueableJobId;
        List<Task> processedTasks;
        Set<Id> processedTaskIds;
        List<BREGAmazonSesLogger.LogWrapper> logWrappers;

        public BREGAmazonSesQueueableFinalizer(Id jobId, List<Task> tasks, List<BREGAmazonSesLogger.LogWrapper> logWrappers) {
            this.queueableJobId = jobId;
            this.processedTasks = tasks;
            processedTaskIds = new Map<Id, Task>(processedTasks).keySet();
            this.logWrappers = logWrappers;
        }

        public void execute(FinalizerContext ctx) {
            // This method executes after the Queueable job finishes
            System.debug('Finalizer executing for Queueable Job ID: ' + queueableJobId);

            insert BREGAmazonSesLogger.getLogRecords(logWrappers);

            Map<String, Integer> numOfRetriesByTaskId = BREGAmazonSesLogger.getNumOfRetriesByTaskId(processedTaskIds);

            for (Task t : processedTasks) {
                if (
                    t.breg_Email_Sending_Status__c == STATUS_RETRY &&
                    numOfRetriesByTaskId.containsKey(t.Id) &&
                    numOfRetriesByTaskId.get(t.Id) >= MAX_NUM_OF_EMAIL_RETRIES
                ) {
                    t.breg_Email_Sending_Status__c = STATUS_ERROR;
                }
            }

            update processedTasks;
        }
    }
}