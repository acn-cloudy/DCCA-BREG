public without sharing class BREGAnnualRobotWithoutSharing {

    private static final Set<String> RELEVANT_ROLES = new Set<String>{'Agent', 'Partner', 'Manager', 'Member', 'Director', 'Officer'};

    public static List<Case> queryCases(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<Case>();
        }

        return [
            SELECT
                Id,
                Status,
                ContactId,
                RecordType.DeveloperName,
                breg_No_Changes__c,
                breg_File__c,
                breg_Form_Code__c,
                breg_Is_Manager_Managed__c,
                breg_Workitem_ID__c,
                breg_Workitem_Number__c,
                breg_Override_Payment__c,
                breg_Annual_Robot_Status__c,
                breg_Robot_Processed_DateTime__c,
                breg_Submission_Date__c,
                breg_Effective_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_Annual_Report_Filing_Year__c,
                breg_Name_of_the_Entity__c,
                breg_Entity_Type__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__City__s,
                breg_Company_Address__StateCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__PostalCode__s,
                breg_Number_of_initial_members__c,
                breg_Membership_Fees_Received__c,
                breg_Number_of_Shareholders__c,
                breg_Annual__c,
                breg_Annual__r.breg_Status__c,
                breg_Annual__r.breg_Filing_Date__c,
                breg_Annual__r.breg_Filing_Due_Date__c,
                breg_Annual__r.breg_Filing_Year__c,
                breg_Annual__r.breg_Received_Date__c,
                breg_Entity__c,
                breg_Entity__r.Id,
                breg_Entity__r.Name,
                breg_Entity__r.ParentId,
                breg_Entity__r.Parent.breg_Entity_Type__c,
                breg_Entity__r.breg_Entity_Status__c,
                breg_Entity__r.breg_Entity_Type__c,
                breg_Entity__r.breg_Bounced_Check__c,
                breg_Entity__r.breg_BRIM_CRA_FL__c,
                breg_Entity__r.breg_Purpose__c,
                breg_Entity__r.breg_Mailing_Address__Street__s,
                breg_Entity__r.breg_Mailing_Address_Street_2__c,
                breg_Entity__r.breg_Mailing_Address__City__s,
                breg_Entity__r.breg_Mailing_Address__StateCode__s,
                breg_Entity__r.breg_Mailing_Address__CountryCode__s,
                breg_Entity__r.breg_Mailing_Address__PostalCode__s,
                breg_Entity__r.BillingStreet,
                breg_Entity__r.breg_Billing_Address_Street_2__c,
                breg_Entity__r.BillingCity,
                breg_Entity__r.BillingStateCode,
                breg_Entity__r.BillingCountryCode,
                breg_Entity__r.BillingPostalCode,
                breg_Entity__r.breg_Number_of_initial_members__c,
                breg_Entity__r.breg_Membership_Fees_Received__c,
                breg_Entity__r.breg_Number_of_Shareholders__c,
                breg_Entity__r.breg_Incorporation_Date__c
            FROM Case
            WHERE Id IN :caseIds
                AND Status = 'Received'
                AND Origin = 'Web'
                AND breg_No_Changes__c = true
                AND RecordType.DeveloperName = 'BREG_Case'
        ];
    }

    public static List<Case> expandWithEligibleEntityAnnualCases(List<Case> loadedCases) {
        if (loadedCases == null || loadedCases.isEmpty()) {
            return new List<Case>();
        }

        Set<Id> loadedCaseIds = new Set<Id>();
        Set<Id> entityIds = new Set<Id>();

        for (Case loadedCase : loadedCases) {
            loadedCaseIds.add(loadedCase.Id);
            if (loadedCase.breg_Entity__c != null) {
                entityIds.add(loadedCase.breg_Entity__c);
            }
        }

        if (entityIds.isEmpty()) {
            return loadedCases;
        }

        Set<Id> additionalCaseIds = new Set<Id>();
        for (Case relatedCase : [
            SELECT Id
            FROM Case
            WHERE breg_Entity__c IN :entityIds
                AND Id NOT IN :loadedCaseIds
                AND Status = 'Received'
                AND Origin = 'Web'
                AND breg_No_Changes__c = true
                AND RecordType.DeveloperName = 'BREG_Case'
                AND breg_Form_Code__c LIKE 'ANN-%'
        ]) {
            additionalCaseIds.add(relatedCase.Id);
        }

        if (additionalCaseIds.isEmpty()) {
            return loadedCases;
        }

        List<Case> expandedCases = new List<Case>();
        expandedCases.addAll(loadedCases);
        expandedCases.addAll(queryCases(additionalCaseIds));
        return expandedCases;
    }

    public static void updateCasesSafely(List<Case> casesToUpdate) {
        if (casesToUpdate == null || casesToUpdate.isEmpty()) {
            return;
        }

        Boolean previousDisableTrigger = TriggerUtils.disableTrigger;
        TriggerUtils.disableTrigger = true;
        try {
            update casesToUpdate;
        } finally {
            TriggerUtils.disableTrigger = previousDisableTrigger;
        }
    }

    public static void insertCommentsSafely(List<CaseComment> commentsToInsert) {
        if (commentsToInsert == null || commentsToInsert.isEmpty()) {
            return;
        }

        insert commentsToInsert;
    }

    public static List<Case> getQueuedFollowUpCases(Set<Id> successfulEntityIds) {
        if (successfulEntityIds == null || successfulEntityIds.isEmpty()) {
            return new List<Case>();
        }

        return [
            SELECT Id
            FROM Case
            WHERE breg_Entity__c IN :successfulEntityIds
                AND Status = 'Received'
                AND breg_No_Changes__c = true
                AND breg_Annual_Robot_Status__c = :BREGAnnualRobotRules.ROBOT_STATUS_IN_QUEUE
                AND RecordType.DeveloperName = 'BREG_Case'
                AND breg_Form_Code__c LIKE 'ANN-%'
        ];
    }

    public static List<Case> getAnnualCaseCounts(Set<Id> annualIds) {
        if (annualIds == null || annualIds.isEmpty()) {
            return new List<Case>();
        }

        return [
            SELECT breg_Annual__c
            FROM Case
            WHERE breg_Annual__c IN :annualIds
                AND RecordType.DeveloperName = 'BREG_Case'
                AND breg_Form_Code__c LIKE 'ANN-%'
                AND Status NOT IN ('Pending Submission', 'New', 'Expired')
        ];
    }

    public static List<TransactionLine__c> getPaidTransactionLines(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<TransactionLine__c>();
        }

        return [
            SELECT breg_Case__c
            FROM TransactionLine__c
            WHERE breg_Case__c IN :caseIds AND PaidStatus__c = 'Paid'
        ];
    }

    public static List<Case> getConflictingTransactionCases(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<Case>();
        }

        return [
            SELECT Id, breg_Entity__c, breg_Submission_Date__c
            FROM Case
            WHERE breg_Entity__c IN :entityIds
                AND breg_Form_Configuration__r.breg_Form_Code__c IN ('ADD', 'X-8', 'X-7', 'DC-2', 'DNP-2', 'LLC-2', 'ODC')
                AND Status NOT IN ('Approved', 'Rejected', 'Completed', 'Expired', 'Purged', 'Pending Submission')
        ];
    }

    public static List<breg_Document__c> getPublicCaseDocuments(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<breg_Document__c>();
        }

        return [
            SELECT breg_Case__c, Name, breg_Is_Initial_Filing__c
            FROM breg_Document__c
            WHERE breg_Case__c IN :caseIds
                AND breg_Is_Public__c = true
                AND breg_Is_Irrelevant__c = false
                AND breg_Docusign_Document_Id__c != null
        ];
    }

    public static List<Account> getBouncedGpAccounts(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<Account>();
        }

        return [
            SELECT ParentId
            FROM Account
            WHERE ParentId IN :entityIds AND breg_Entity_Type__c IN :BREGAnnualRobotRules.GP_ENTITY_TYPES AND breg_Bounced_Check__c = true
        ];
    }

    public static List<breg_Account_Affiliation__c> getEntityAffiliations(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<breg_Account_Affiliation__c>();
        }

        return [
            SELECT
                breg_Entity__c, breg_Role__c, breg_Type__c, breg_Entity_Name__c, breg_Entity_Location__c,
                breg_Entity_Location_Country__c, breg_First_Name__c, breg_Last_Name__c,
                breg_Address__CountryCode__s, breg_Address__Street__s, breg_Address_Street_2__c,
                breg_Address__StateCode__s, breg_Address_State_Text__c, breg_Address__City__s,
                breg_Address__PostalCode__s, breg_Officer_Director_Titles__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :entityIds
                AND breg_Role__c IN :RELEVANT_ROLES
                AND breg_End_Date__c = null
                AND breg_Status__c = 'A'
        ];
    }

    public static List<breg_Account_Affiliation__c> getCaseAffiliations(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<breg_Account_Affiliation__c>();
        }

        return [
            SELECT
                breg_Case__c, breg_Role__c, breg_Type__c, breg_Entity_Name__c, breg_Entity_Location__c,
                breg_Entity_Location_Country__c, breg_First_Name__c, breg_Last_Name__c,
                breg_Address__CountryCode__s, breg_Address__Street__s, breg_Address_Street_2__c,
                breg_Address__StateCode__s, breg_Address_State_Text__c, breg_Address__City__s,
                breg_Address__PostalCode__s, breg_Officer_Director_Titles__c, breg_To_Remove__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds
        ];
    }

    public static List<breg_Stock__c> getCaseStocks(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<breg_Stock__c>();
        }

        return [
            SELECT
                breg_Case__c, breg_Class_Series__c, breg_Per_Value__c, breg_Class_Detail__c,
                breg_Number_of_Issued_Shares__c, breg_Paid_Shares__c, breg_Remarks__c,
                breg_Stock_Amount__c, breg_Stock_Class__c
            FROM breg_Stock__c
            WHERE breg_Case__c IN :caseIds
        ];
    }

    public static List<breg_Stock__c> getEntityStocks(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<breg_Stock__c>();
        }

        return [
            SELECT
                breg_Account__c, breg_Class_Series__c, breg_Per_Value__c, breg_Class_Detail__c,
                breg_Number_of_Issued_Shares__c, breg_Paid_Shares__c, breg_Remarks__c,
                breg_Stock_Amount__c, breg_Stock_Class__c
            FROM breg_Stock__c
            WHERE breg_Account__c IN :entityIds
                AND breg_Start_Date__c != null
                AND breg_End_Date__c = null
        ];
    }

    public static List<breg_Account_Affiliation__c> getActiveAgents(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<breg_Account_Affiliation__c>();
        }

        return [
            SELECT
                breg_Entity__c,
                breg_Account__c,
                breg_Type__c,
                breg_Account__r.breg_BRIM_CRA_FL__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :entityIds
                AND breg_Role__c = 'Agent'
                AND breg_End_Date__c = null
                AND breg_Status__c = 'A'
            ORDER BY breg_Entity__c, breg_Start_Date__c DESC
        ];
    }

    public static List<breg_Annual__c> getAnnuals(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<breg_Annual__c>();
        }

        return [
            SELECT Id, breg_Account__c, breg_Filing_Year__c, breg_Status__c
            FROM breg_Annual__c
            WHERE breg_Account__c IN :entityIds
        ];
    }

    public static List<Case> getRelatedAnnualCases(Set<Id> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return new List<Case>();
        }

        return [
            SELECT Id, breg_Entity__c, breg_Annual_Report_Filing_Year__c, Status, breg_No_Changes__c, RecordType.DeveloperName, breg_Annual_Robot_Status__c, breg_Annual__r.breg_Filing_Year__c
            FROM Case
            WHERE breg_Entity__c IN :entityIds
                AND RecordType.DeveloperName = 'BREG_Case'
                AND breg_Annual__c != null
                AND Status = 'Received'
                AND breg_Form_Code__c LIKE 'ANN-%'
        ];
    }

    public static List<breg_WEB_WEB_FILING_INFO__c> getWebFilingInfos(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new List<breg_WEB_WEB_FILING_INFO__c>();
        }

        return [
            SELECT Id, breg_WEB_Case__c, breg_Mapping_Status__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c IN :caseIds
        ];
    }
}