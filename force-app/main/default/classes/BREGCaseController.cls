public with sharing class BREGCaseController {
    public class MyCaseWrapper {
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String workItemNumber;
        @AuraEnabled
        public String formType;
        @AuraEnabled
        public String formCode;
        @AuraEnabled
        public String nameOfTheEntity;
        @AuraEnabled
        public Datetime lastUpdated;
        @AuraEnabled
        public Date resubmissionDueDate;
        @AuraEnabled
        public String annualReportFilingYear;
        @AuraEnabled
        public String fileNumber;
        @AuraEnabled
        public String entityId;
        @AuraEnabled
        public String annualId;
        @AuraEnabled
        public String tntmsmId;
        @AuraEnabled
        public String formCategory;
        @AuraEnabled
        public String paymentId;
        @AuraEnabled
        public Boolean allowedForRemoval;
        @AuraEnabled
        public Boolean allowedForContinuation;
        @AuraEnabled
        public Boolean allowedForWithdrawal;
        @AuraEnabled
        public Boolean allowedForExpedition;
        @AuraEnabled
        public Boolean allowedForResubmission;
        @AuraEnabled
        public Boolean allowedForReopening;
        @AuraEnabled
        public Boolean allowedForView;
    }

    @AuraEnabled(cacheable=true)
    public static List<MyCaseWrapper> getMyFilings() {
        Id currentUserContactId = BREGUtils.getCommunityUserContactId();

        List<Case> myCases = getAllFilings(currentUserContactId);

        Map<Id, CaseHistory> caseHistoryMap = getCaseHistoryMap(myCases);

        Map<Id, String> caseIdPaymentId = getCaseIdPaymentId(myCases);

        List<MyCaseWrapper> myFilings = new List<MyCaseWrapper>();
        for (Case currentCase : myCases) {
            MyCaseWrapper wrapper = new MyCaseWrapper();
            wrapper.recordId = currentCase.Id;
            wrapper.name = currentCase.breg_Entity_name__c;
            wrapper.status = currentCase.Status;
            wrapper.workItemNumber = currentCase.breg_Workitem_Number__c;
            wrapper.formType = currentCase.breg_Form_Configuration__r.breg_Form_Name__c;
            wrapper.formCode = currentCase.breg_Form_Code__c;
            wrapper.nameOfTheEntity = currentCase.breg_Name_of_the_Entity__c;
            wrapper.lastUpdated = currentCase.breg_Received_Date_Formula__c;
            wrapper.annualReportFilingYear = currentCase.breg_Annual_Report_Filing_Year__c;
            wrapper.fileNumber = currentCase.breg_Entity__r.breg_File__c ?? currentCase.breg_Portal_User_Entity_Selected__r.breg_File__c;
            wrapper.entityId = currentCase.breg_Entity__c ?? currentCase.breg_Portal_User_Entity_Selected__c;
            wrapper.annualId = currentCase.breg_Annual__c;
            wrapper.tntmsmId = currentCase.breg_TN_TM_SM__c;
            wrapper.formCategory = BREGUtils.checkFormCategory(currentCase.breg_Form_Code__c);
            wrapper.paymentId = caseIdPaymentId.get(currentCase.Id);
            // If the case is rejected, set the resubmission due date
            wrapper.resubmissionDueDate = currentCase.Status == 'Rejected' ? currentCase.breg_Resubmission_Due_Date__c : null;
            wrapper.allowedForRemoval = isAllowedForRemoval(currentCase);
            wrapper.allowedForContinuation = isAllowedForContinuation(currentCase);
            wrapper.allowedForWithdrawal = isAllowedForWithdrawal(caseHistoryMap.get(currentCase.Id), currentCase);
            wrapper.allowedForExpedition = isAllowedForExpedition(currentCase);
            wrapper.allowedForResubmission = isAllowedForResubmission(currentCase);
            wrapper.allowedForReopening = false; // isAllowedForReopening(currentCase);
            wrapper.allowedForView = isAllowedForView(currentCase, wrapper.paymentId);
            myFilings.add(wrapper);
        }

        return myFilings;
    }


    @AuraEnabled
    public static List<breg_Fee__c> getExpediteFee(String filingId) {
        Case filing = getCaseForUpdate(Id.valueOf(filingId));
        return BREGGetFeeForService.getFees(
            new List<String>{ 'breg_Purchase_Type_Fee_type__c', 'breg_Fee_Amount__c' },
            new Map<String, Object>{
                'breg_Form_Configuration__r.breg_Suffix_Code__c' => filing.breg_Form_Configuration__r.breg_Suffix_Code__c,
                'breg_Purchase_Type_Fee_type__c' => 'Expedite Fees'
            },
            null,
            null
        );
    }

    private static Map<Id, CaseHistory> getCaseHistoryMap(List<Case> cases) {
        List<CaseHistory> caseHistories = getCaseHistory(cases);
        Map<Id, CaseHistory> caseHistoryMap = new Map<Id, CaseHistory>();
        for (CaseHistory history : caseHistories) {
            if (!caseHistoryMap.containsKey(history.CaseId) && history.NewValue == 'Received') {
                caseHistoryMap.put(history.CaseId, history);
            }
        }
        return caseHistoryMap;
    }

    private static List<CaseHistory> getCaseHistory(List<Case> cases) {
        return [
            SELECT CaseId, CreatedDate, NewValue
            FROM CaseHistory
            WHERE CaseId IN :cases AND Field = 'Status'
            ORDER BY CreatedDate DESC
        ];
    }

    private static Map<Id, String> getCaseIdPaymentId(List<Case> cases) {
        List<TransactionLine__c> transactionLines = [
            SELECT Id, breg_Case__c, Payment__c
            FROM TransactionLine__c
            WHERE breg_Case__c IN :cases AND PaidStatus__c = 'Paid' AND Payment__c != NULL AND Amount__c > 0
        ];
        Map<Id, String> caseIdPaymentId = new Map<Id, String>();
        for (TransactionLine__c transactionLine : transactionLines) {
            if (!caseIdPaymentId.containsKey(transactionLine.breg_Case__c)) {
                caseIdPaymentId.put(transactionLine.breg_Case__c, String.valueOf(transactionLine.Payment__c));
            }
        }
        return caseIdPaymentId;
    }

    private static List<Case> getAllFilings(Id contactId) {
        return [
            SELECT
                Id,
                ContactId,
                CaseNumber,
                Type,
                Status,
                Subject,
                LastModifiedDate,
                breg_Form_Code__c,
                breg_Received_Date_Formula__c,
                breg_Entity_name__c,
                breg_Annual_Report_Filing_Year__c,
                breg_TN_TM_SM__c,
                breg_Entity__c,
                breg_Entity__r.breg_File__c,
                breg_Portal_User_Entity_Selected__c,
                breg_Portal_User_Entity_Selected__r.breg_File__c,
                breg_Annual__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Entity_Type__c,
                breg_Form_Configuration__r.breg_Withdrawal_Range__c,
                breg_Form_Configuration__r.breg_Suffix_Code__c,
                breg_Form_Configuration__r.breg_Is_Expeditable__c,
                breg_Form_Configuration__r.breg_Form_Code__c,
                breg_Form_Configuration__r.breg_Form_Name__c,
                Owner.Type,
                breg_Processing_Speed__c,
                breg_Name_of_the_Entity__c,
                breg_Resubmission_Due_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_Reopened_Date__c,
                Parent.breg_Resubmission_Received_Date__c,
                Parent.breg_Reopened_Date__c,
                Origin,
                breg_Workitem_Number__c,
                breg_Form_Action__c,
                breg_Payment_Completed__c,
                ( 
                    SELECT Id // Only check for existence of a withdrawal case related to the same parent case (if any)
                    FROM Cases
                    WHERE breg_Form_Code__c = 'WD' and Status != 'Rejected'
                    LIMIT 1
                )
            FROM Case
            WHERE breg_Form_Configuration__c != NULL AND ContactId = :contactId
            ORDER BY LastModifiedDate DESC
        ];
    }

    private static Case getCaseForUpdate(Id recordId) {
        return [
            SELECT
                Id,
                Status,
                breg_Form_Configuration__r.breg_Withdrawal_Range__c,
                breg_Form_Configuration__r.breg_Suffix_Code__c,
                Owner.Type,
                breg_File_Suffix__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Workitem_Number__c,
                breg_Form_Action__c
            FROM Case
            WHERE Id = :recordId
            FOR UPDATE
        ];
    }

    private static Boolean isAllowedForRemoval(Case caseRecord) {
        return (caseRecord.Status == 'New' || caseRecord.Status == 'Pending Submission') && caseRecord.breg_Payment_Completed__c != true;
    }

    private static Boolean isAllowedForContinuation(Case caseRecord) {
        return (caseRecord.Status == 'New' || caseRecord.Status == 'Pending Submission' || caseRecord.Status == 'Pending Payment') && caseRecord.breg_Payment_Completed__c != true;
    }

    private static Boolean isAllowedForWithdrawal(CaseHistory caseHistory, Case currentCase) {
        Integer withdrawalRange = (Integer) currentCase.breg_Form_Configuration__r.breg_Withdrawal_Range__c;
        return (caseHistory != null && 
            caseHistory.CreatedDate > DateTime.now().addHours(withdrawalRange != null ? -withdrawalRange : 0)) &&
            currentCase.breg_Form_Configuration__r.breg_Form_Code__c != 'WD' &&
            !currentCase.breg_Form_Configuration__r.breg_Form_Code__c.contains('ANN') &&
            currentCase.Status == 'Received' && currentCase.Cases.isEmpty();
    }

    private static Boolean isAllowedForExpedition(Case caseRecord) {
        return caseRecord.breg_Form_Configuration__r.breg_Is_Expeditable__c == true &&
            caseRecord.Owner.Type != 'Queue' &&
            caseRecord.breg_Processing_Speed__c != 'Expedited' &&
            !isAllowedForResubmission(caseRecord) &&
            caseRecord.Status != 'Rejected' &&
            caseRecord.Status != 'Approved' &&
            caseRecord.Status != 'Completed' &&
            caseRecord.breg_Form_Action__c != 'Resubmit' &&
            (caseRecord.Status == 'Pending Payment' || caseRecord.breg_Payment_Completed__c != true);
    }

    private static Boolean isAllowedForResubmission(Case caseRecord) {
        return caseRecord.Status == 'Rejected' &&
            caseRecord.Origin == 'Web' &&
            caseRecord.breg_Resubmission_Due_Date__c != null &&
            caseRecord.breg_Resubmission_Due_Date__c >= Date.today();
    }

    // private static Boolean isAllowedForReopening(Case caseRecord) {
    //     return caseRecord.Status == 'Completed' &&
    //         caseRecord.Origin == 'Web' &&
    //         caseRecord.breg_Reopened_Date__c == null &&
    //         caseRecord.breg_Resubmission_Received_Date__c == null;
    // }

    private static Boolean isAllowedForView(Case caseRecord, String paymentId) {
        return caseRecord.Status != 'New' && caseRecord.Status != 'Pending Submission' && String.isNotBlank(paymentId);
    }

    @AuraEnabled
    public static void runGenerateDocWorkflow(Id recordId, String workflowName) {
        if (!Test.isRunningTest()) {
            if (recordId.getSObjectType() == Case.sObjectType) {
                Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(recordId, 'Case Button clicked');
                System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, null, 'Case Button clicked', workflowLogId));
            } else if (recordId.getSObjectType() == Account.sObjectType) {
                Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(recordId, 'Account Button clicked');
                System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, null, 'Account Button clicked', workflowLogId));
            } else {
                throw new AuraHandledException('Unsupported record type: ' + recordId.getSObjectType());
            }
        }
    }

    @AuraEnabled
    public static void runMethodByName(Id recordId, String methodName) {
        if (String.isBlank(methodName)) {
            throw new AuraHandledException('Method name is required.');
        }

        if (methodName == 'refreshStaleDocumentGenerationStatuses') {
            if (recordId == null) {
                throw new AuraHandledException('Record Id is required for method: ' + methodName);
            }
            BREGUtils.refreshStaleDocumentGenerationStatuses(new Set<Id>{ recordId });
            return;
        }

        throw new AuraHandledException('Unsupported method: ' + methodName);
    }

    @AuraEnabled
    public static void runGenerateDocWorkflowWithTemplate(Id recordId, String workflowName, String templateName) {
        String params = '<recordId>' + recordId + '</recordId>';
        params += '<templateName>' + templateName + '</templateName>';
        startWorkflowWithParams(workflowName, params, recordId);
    }

    @AuraEnabled
    public static void runGenerateDocWorkflowWithParams(Id recordId, String workflowName, String customParameters) {
        String params = '<recordId>' + recordId + '</recordId>';
        params += '<customParameters>' + customParameters + '</customParameters>';
        startWorkflowWithParams(workflowName, params, recordId);
    }

    public static void startWorkflowWithParams(String workflowName, String params, Id recordId) {
        if (!Test.isRunningTest()) {
            Id workflowLogId = BREGStartDocusignWorkflow.createWorkflowLogSafely(recordId, 'Case Button clicked');
            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, recordId, params, 'Case Button clicked', workflowLogId));
        }
    }
}