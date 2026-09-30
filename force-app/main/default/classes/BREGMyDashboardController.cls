public without sharing class BREGMyDashboardController {
    private static String RESERVATION_VALUE = 'Reservation';
    private static String ENTITY_VALUE = 'Entity';
    private static final String DOCUMENT_DELIVERY_FORM_CODE = 'DOCDLVR';

    @AuraEnabled(cacheable=true)
    public static List<BREGPaymentController.TransactionLineWrapper> getTransactionLineWrappers() {
        try {
            Set<Id> paymentIds = getPaidPaymentIds();
            List<TransactionLine__c> transactionLines = BREGPaymentController.getTransactionLines(paymentIds);
            List<BREGPaymentController.TransactionLineWrapper> transactionLineWrappers = BREGPaymentController.getTransactionLineWrappers(
                transactionLines
            );
            return transactionLineWrappers;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + '|' + e.getStackTraceString());
        }
    }

    // Get all paid transactions for the current user contact
    private static Set<Id> getPaidPaymentIds() {
        Id contactId = BREGUtils.getCommunityUserContactId();
        Map<Id, pymt__PaymentX__c> paymentIdToPaymentMap = new Map<Id, pymt__PaymentX__c>([
            SELECT Id
            FROM pymt__PaymentX__c
            WHERE pymt__Status__c = 'Completed' AND pymt__Contact__c = :contactId
        ]);
        return paymentIdToPaymentMap.keySet();
    }

    @AuraEnabled(cacheable=true)
    public static List<MyBusinessWrapper> getMyBusinesses() {
        try {
            Id contactId = BREGUtils.getCommunityUserContactId();

            List<Case> cases = [
                SELECT
                    Id,
                    breg_Entity__c,
                    breg_Entity__r.Name,
                    breg_Entity__r.breg_Entity_Type__c,
                    breg_Entity__r.breg_Entity_Status__c,
                    breg_Entity__r.breg_File__c,
                    breg_Entity__r.breg_File_Suffix__c,
                    breg_TN_TM_SM__c,
                    breg_TN_TM_SM__r.Name,
                    breg_TN_TM_SM__r.breg_Status__c,
                    breg_TN_TM_SM__r.breg_File__c,
                    breg_TN_TM_SM__r.breg_File_Suffix__c,
                    breg_TN_TM_SM__r.breg_Type__c
                FROM Case
                WHERE ContactId = :contactId 
                    AND (breg_Entity__c != NULL OR breg_TN_TM_SM__c != NULL)
                    AND breg_Form_Code__c != :DOCUMENT_DELIVERY_FORM_CODE
                ORDER BY breg_Received_Date__c DESC
            ];

            List<MyBusinessWrapper> myBusinesses = new List<MyBusinessWrapper>();
            Set<Id> businessIds = new Set<Id>();
            for (Case c : cases) {
                if (businessIds.contains(c.breg_Entity__c) || businessIds.contains(c.breg_TN_TM_SM__c)) {
                    continue;
                }

                if (c.breg_Entity__c != null) {
                    MyBusinessWrapper wrapper = constructMyBusinessWrapperForAccount(c.breg_Entity__r);
                    myBusinesses.add(wrapper);
                    businessIds.add(c.breg_Entity__c);
                } else if (c.breg_TN_TM_SM__c != null) {
                    MyBusinessWrapper wrapper = constructMyBusinessWrapperForTNTMSM(c.breg_TN_TM_SM__r);
                    myBusinesses.add(wrapper);
                    businessIds.add(c.breg_TN_TM_SM__c);
                }
            }

            return myBusinesses;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + '|' + e.getStackTraceString());
        }
    }

    private static MyBusinessWrapper constructMyBusinessWrapperForAccount(Account acc) {
        MyBusinessWrapper wrapper = new MyBusinessWrapper();
        wrapper.recordId = acc.Id;
        wrapper.businessName = acc.Name != null ? acc.Name : '';
        wrapper.recordType = acc.breg_Entity_Type__c == ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE ? RESERVATION_VALUE : ENTITY_VALUE;
        wrapper.fileNumber = getFileNumber(acc.breg_File__c, acc.breg_File_Suffix__c);
        wrapper.status = acc.breg_Entity_Status__c != null ? acc.breg_Entity_Status__c : '';
        return wrapper;
    }

    private static MyBusinessWrapper constructMyBusinessWrapperForTNTMSM(breg_TN_TM_SM__c tnTmSm) {
        MyBusinessWrapper wrapper = new MyBusinessWrapper();
        wrapper.recordId = tnTmSm.Id;
        wrapper.businessName = tnTmSm.Name != null ? tnTmSm.Name : '';
        wrapper.recordType = tnTmSm.breg_Type__c != null ? tnTmSm.breg_Type__c : '';
        wrapper.fileNumber = getFileNumber(tnTmSm.breg_File__c, tnTmSm.breg_File_Suffix__c);
        wrapper.status = tnTmSm.breg_Status__c != null ? tnTmSm.breg_Status__c : '';
        return wrapper;
    }

    private static String getFileNumber(String fileNumber, String fileSuffix) {
        return (String.isBlank(fileNumber) ? '' : fileNumber) + (String.isBlank(fileSuffix) ? '' : ' ' + fileSuffix);
    }

    private static List<Task> getEmailTasks() {
        Id contactId = BREGUtils.getCommunityUserContactId();
        return [
            SELECT Subject, breg_Case__c, breg_Account__c, CreatedDate, Id, TaskSubtype, WhoId, WhatId, AccountId, Description
            FROM Task
            WHERE WhoId = :contactId AND TaskSubtype = 'Email'
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<CommunicationWrapper> getMyCommunications() {
        List<CommunicationWrapper> result = new List<CommunicationWrapper>();
        List<Task> emailTasks = getEmailTasks();

        Map<Id, String> whatIdToNameMap = getMapEntityName(emailTasks);
        Map<Id, List<breg_Document__c>> attachmentsMap = getMapTaskAttachments(emailTasks);
        for (Task currentTask : emailTasks) {
            CommunicationWrapper wrapper = new CommunicationWrapper();
            wrapper.recordId = currentTask.Id;
            wrapper.subject = currentTask.Subject;
            wrapper.body = currentTask.Description;
            wrapper.createdDate = currentTask.CreatedDate.format('yyyy-MM-dd HH:mm:ss');
            wrapper.associatedEntity = whatIdToNameMap.get(currentTask.WhatId);
            List<AttachmentWrapper> attachments = new List<AttachmentWrapper>();
            Id parentId =  attachmentsMap.keySet().contains(currentTask.Id) ? currentTask.Id : currentTask.breg_Case__c;
            if (parentId != null) {
                List<breg_Document__c> docs = attachmentsMap.get(parentId);
                if (docs != null && docs.size() > 0) {
                    for (breg_Document__c doc : docs) {
                        AttachmentWrapper attach = new AttachmentWrapper();
                        attach.recordId = doc.Id;
                        attach.name = doc.Name;
                        attach.docusignId = doc.breg_Docusign_Document_Id__c;
                        attachments.add(attach);
                    }
                }
            }
            wrapper.attachments = attachments;
            result.add(wrapper);
        }
        return result;
    }

    public static Map<Id, List<breg_Document__c>> getMapTaskAttachments(List<Task> emailTasks) {
        Set<Id> caseIds = new Set<Id>();
        Set<Id> taskIds = new Set<Id>();

        for (Task task : emailTasks) {
            if (task.breg_Case__c != null) {
                caseIds.add(task.breg_Case__c);
            } 
            taskIds.add(task.Id);
            
        }

        List<breg_Document__c> relatedDocuments = [
            SELECT Id, Name, breg_Docusign_Document_Id__c, breg_Case__c, breg_TaskId__c
            FROM breg_Document__c
            WHERE (breg_Case__c IN :caseIds OR breg_TaskId__c IN :taskIds)
            AND breg_Docusign_Document_Id__c != null
            AND breg_Is_Irrelevant__c = false
            AND ( 
                breg_Is_Public__c = true
                OR NAME LIKE '%Approval Package%'
            )
        ];

        Map<Id, List<breg_Document__c>> attachmentsMap = new Map<Id, List<breg_Document__c>>();

        for (breg_Document__c doc : relatedDocuments) {
            Id parentId = doc.breg_TaskId__c != null ? doc.breg_TaskId__c : doc.breg_Case__c;
            if (parentId != null) {
                if (!attachmentsMap.containsKey(parentId)) {
                    attachmentsMap.put(parentId, new List<breg_Document__c>());
                }
                attachmentsMap.get(parentId).add(doc);
            }
        }

        return attachmentsMap;
    }

    public static Map<Id, String> getMapEntityName(List<Task> emailTasks) {
        List<Id> accountsIds = new List<Id>();
        List<Id> tnIds = new List<Id>();
        List<Id> annualsIds = new List<Id>();
        List<Id> caseIds = new List<Id>();
        Map<Id, String> whatIdToNameMap = new Map<Id, String>();
        for (Task currentTask : emailTasks) {
            if (currentTask.WhatId != null) {
                String objectName = currentTask.WhatId.getSObjectType().getDescribe().getName();
                if (objectName == 'Account') {
                    accountsIds.add(currentTask.WhatId);
                } else if (objectName == 'breg_TN_TM_SM__c') {
                    tnIds.add(currentTask.WhatId);
                } else if (objectName == 'breg_Annual__c') {
                    annualsIds.add(currentTask.WhatId);
                } else if (objectName == 'Case') {
                    caseIds.add(currentTask.WhatId);
                }
            }
        }
        if (!accountsIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :accountsIds
            ]) {
                whatIdToNameMap.put(acc.Id, acc.Name);
            }
        }

        if (!tnIds.isEmpty()) {
            for (breg_TN_TM_SM__c tn : [
                SELECT Id, Name
                FROM breg_TN_TM_SM__c
                WHERE Id IN :tnIds
            ]) {
                whatIdToNameMap.put(tn.Id, tn.Name);
            }
        }
        if (!annualsIds.isEmpty()) {
            for (breg_Annual__c annual : [
                SELECT Id, breg_Account__r.Name
                FROM breg_Annual__c
                WHERE Id IN :annualsIds
            ]) {
                whatIdToNameMap.put(annual.Id, annual.breg_Account__r.Name);
            }
        }
        if (!caseIds.isEmpty()) {
            for (Case c : [
                SELECT Id, breg_Name_of_the_Entity__c, breg_TNTMSM_Description__c
                FROM Case
                WHERE Id IN :caseIds
            ]) {
                String name = 'Without entity';
                if (c.breg_Name_of_the_Entity__c != null) {
                    name = c.breg_Name_of_the_Entity__c;
                } else if (c.breg_TNTMSM_Description__c != null) {
                    name = c.breg_TNTMSM_Description__c;
                }
                whatIdToNameMap.put(c.Id, name);
            }
        }
        return whatIdToNameMap;
    }

    public class CommunicationWrapper {
        @AuraEnabled
        public String subject { get; set; }
        @AuraEnabled
        public String body { get; set; }
        @AuraEnabled
        public String createdDate { get; set; }
        @AuraEnabled
        public String associatedEntity { get; set; }
        @AuraEnabled
        public Id recordId { get; set; }
        @AuraEnabled
        public List<AttachmentWrapper> attachments { get; set; }
    }

    public class AttachmentWrapper {
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String docusignId { get; set; }
        @AuraEnabled
        public String recordId { get; set; }
    }

    public class MyBusinessWrapper {
        @AuraEnabled
        public String recordId { get; set; }
        @AuraEnabled
        public String businessName { get; set; }
        @AuraEnabled
        public String recordType { get; set; }
        @AuraEnabled
        public String fileNumber { get; set; }
        @AuraEnabled
        public String status { get; set; }
    }
}