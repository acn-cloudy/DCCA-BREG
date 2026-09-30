public with sharing class BREGBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private String sObjectName;
    private List<BREGBatchInterface> processors = new List<BREGBatchInterface>();
    public static List<SObject> involuntaryBatchUpdatedRecords = new List<SObject>();
    private Map<String, BREG_Batch_Setting__mdt> metadataSettings = new Map<String, BREG_Batch_Setting__mdt>();
    private final String COMBINE_DOCS_WORKFLOW = 'BREG Combine Documents';

    public BREGBatch(String sObjectName) {
        this.sObjectName = sObjectName;

        // Load metadata settings
        List<BREG_Batch_Setting__mdt> settings = Test.isRunningTest() ? getTestMetadata() : getMetadata();
        for (BREG_Batch_Setting__mdt setting : settings) {
            // Store metadata setting for later use
            metadataSettings.put(setting.breg_Apex_Class_Name__c, setting);

            try {
                Type cls = Type.forName(setting.breg_Apex_Class_Name__c);
                Object instance = cls.newInstance();
                BREGBatchInterface processor = (BREGBatchInterface) instance;
                processor.cronExp = setting.breg_Cron_Expression__c;
                processor.lastRunDate = setting.breg_Last_Run_Date__c;
                processor.className = setting.breg_Apex_Class_Name__c;
                if (processor.isRunningToday()) {
                    processors.add(processor);
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error loading processor ' + setting.breg_Apex_Class_Name__c + ': ' + e.getMessage());
            }
        }

        System.debug('BREGBatch initialized with ' + processors.size() + ' active processors for sObject: ' + sObjectName);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Get fields from the BREG_Batch_Fields fieldset for this sObject
        Set<String> fields = getBatchFieldsFromFieldSet(sObjectName);
        String soql = 'SELECT Id, ' + String.join(new List<String>(fields), ',') + ' FROM ' + sObjectName;
        String filter;
        switch on sObjectName {
            when 'Account' {
                filter = ' WHERE IsPersonAccount != true and RecordType.Name = \'BREG Account\'';
            }
            when 'breg_Entity_List_Result__c' {
                filter = ' WHERE breg_Docusign_Document_Id__c != null ';
            }
            when else {
                filter = '';
            }
        }
        soql += filter;
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Map<Id, SObject> recordsMap = new Map<Id, SObject>(scope);
        List<SObject> recordsToUpsert = new List<SObject>();
        List<Task> tasksToUpsert = new List<Task>();

        for (BREGBatchInterface proc : processors) {
            try {
                BREGBatchInterface.BatchProcessingResult result = proc.processRecords(recordsMap, sObjectName);
                if (result != null) {
                    if (result.recordsToUpsert != null && !result.recordsToUpsert.isEmpty()) {
                        recordsToUpsert.addAll(result.recordsToUpsert.values());
                    }
                    if (result.tasksToUpsert != null && !result.tasksToUpsert.isEmpty()) {
                        tasksToUpsert.addAll(result.tasksToUpsert);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error processing records with processor ' + proc.className + ': ' + e.getMessage());
            }
        }

        // Perform DML operations with error handling
        try {
            if (!recordsToUpsert.isEmpty()) {
                Database.UpsertResult[] upsertResults = Database.upsert(recordsToUpsert, false);
                Integer successCount = 0;
                for (Database.UpsertResult result : upsertResults) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        for (Database.Error error : result.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'Error upserting record with Id ' + result.getId() + ': ' + error.getMessage());
                        }
                    }
                }
                System.debug('Temporarily upserted ' + successCount + ' records successfully');
            }
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'Error upserting records: ' + e.getMessage());
        }

        try {
            if (!tasksToUpsert.isEmpty()) {
                Database.UpsertResult[] upsertResults = Database.upsert(tasksToUpsert, false);
                Integer successCount = 0;
                for (Database.UpsertResult result : upsertResults) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        for (Database.Error error : result.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'Error upserting task with Id ' + result.getId() + ': ' + error.getMessage());
                        }
                    }
                }
                System.debug('Successfully upserted ' + successCount + ' tasks');
            }
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'Error upserting tasks: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Log completion and processor results
        System.debug('BREGBatch completed for sObject: ' + sObjectName);

        for (BREGBatchInterface proc : processors) {
            if (proc.logs != null && !proc.logs.isEmpty()) {
                System.debug('Processor "' + proc.className + '" logs: ' + String.join(proc.logs, '; '));
            }
        }

        // Update Custom Metadata with last run dates using Metadata API
        updateLastRunDates();
    }

    public static String escapeXml(String input) {
        if (input == null)
            return '';
        return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace('\'', '&apos;');
    }

    //@future(callout=true)
    public static void startWorkflowForCombinedDocs(String workflowName, String params) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, null, params, 'BREGBatch', false));
        }
    }

    public static String getRelatedInvDissolveDocumentsIds() {
        Set<Id> accountsIds = new Set<Id>();
        List<String> certificateName = new List<String>{
            'CERTIFICATE OF REVOCATION',
            'CERTIFICATE OF ADMINISTRATIVE DISSOLUTION',
            'CERTIFICATE OF ADMINISTRATIVE TERMINATION'
        };
        for (SObject acc : involuntaryBatchUpdatedRecords) {
            accountsIds.add(acc.Id);
        }
        List<breg_Document__c> invDissDocs = [
            SELECT Id, Name, breg_Account__c, breg_Docusign_Document_Id__c, breg_Availability__c
            FROM breg_Document__c
            WHERE
                Name IN :certificateName
                AND breg_Account__c IN :accountsIds
                AND breg_Docusign_Document_Id__c != NULL
                AND breg_Availability__c = 'Available Now'
        ];
        List<String> docusignIds = new List<String>();
        for (breg_Document__c doc : invDissDocs) {
            docusignIds.add(doc.breg_Docusign_Document_Id__c);
        }
        return String.join(docusignIds, ',');
    }

    /**
     * Updates the last run date in Custom Metadata using Metadata API
     */
    private void updateLastRunDates() {
        try {
            // Create a deployment container
            Metadata.DeployContainer metadataDeployContainer = new Metadata.DeployContainer();
            Date currentDate = Date.today();

            // Create metadata updates for each processor that ran
            for (BREGBatchInterface proc : processors) {
                String processorClassName = proc.className;
                BREG_Batch_Setting__mdt currentSetting = metadataSettings.get(processorClassName);

                if (currentSetting != null) {
                    // Create Custom Metadata object
                    Metadata.CustomMetadata customMetadataRec = new Metadata.CustomMetadata();
                    customMetadataRec.fullName = 'BREG_Batch_Setting__mdt.' + currentSetting.DeveloperName;
                    customMetadataRec.label = currentSetting.MasterLabel;

                    // Update the last run date to today
                    Metadata.CustomMetadataValue lastRunDate = new Metadata.CustomMetadataValue();
                    lastRunDate.field = 'breg_Last_Run_Date__c';
                    lastRunDate.value = currentDate;
                    customMetadataRec.values.add(lastRunDate);

                    // Add metadata instance to the container
                    metadataDeployContainer.addMetadata(customMetadataRec);
                }
            }

            // Deploy the container if we have updates
            if (!metadataDeployContainer.getMetadata().isEmpty()) {
                Metadata.Operations.enqueueDeployment(metadataDeployContainer, new BREGMetadataDeployCallback());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error updating custom metadata: ' + e.getMessage());
        }
    }

    private List<BREG_Batch_Setting__mdt> getTestMetadata() {
        List<BREG_Batch_Setting__mdt> testMetadataList = new List<BREG_Batch_Setting__mdt>();
        BREG_Batch_Setting__mdt testMetadata = new BREG_Batch_Setting__mdt();
        testMetadata.DeveloperName = 'UnitTestBatch';
        testMetadata.MasterLabel = 'Unit Test Batch';
        testMetadata.breg_Apex_Class_Name__c = 'BREGBatchInterfaceExtTest';
        testMetadata.breg_Cron_Expression__c = '* * * * *';
        testMetadata.breg_Last_Run_Date__c = null;
        testMetadata.breg_Is_Active__c = true;
        testMetadata.breg_Job_sObject__c = 'Account';
        testMetadataList.add(testMetadata);
        return testMetadataList;
    }

    private List<BREG_Batch_Setting__mdt> getMetadata() {
        return [
            SELECT
                DeveloperName,
                MasterLabel,
                breg_Apex_Class_Name__c,
                breg_Cron_Expression__c,
                breg_Last_Run_Date__c,
                breg_Is_Active__c,
                breg_Job_sObject__c
            FROM BREG_Batch_Setting__mdt
            WHERE breg_Job_sObject__c = :sObjectName AND breg_Is_Active__c = TRUE
        ];
    }

    private Set<String> getBatchFieldsFromFieldSet(String sObjectName) {
        Set<String> fields = new Set<String>();

        try {
            // Get the sObject type
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(sObjectName);
            // Get the fieldset
            Schema.DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();
            Map<String, Schema.FieldSet> fieldSets = describeSObjectResult.fieldSets.getMap();

            if (fieldSets.containsKey('BREG_Batch_Fields')) {
                Schema.FieldSet fieldSet = fieldSets.get('BREG_Batch_Fields');

                // Get field API names from the fieldset
                for (Schema.FieldSetMember fieldSetMember : fieldSet.getFields()) {
                    fields.add(fieldSetMember.getFieldPath());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting fields from fieldset for sObject ' + sObjectName + ': ' + e.getMessage());
        }

        return fields;
    }
}