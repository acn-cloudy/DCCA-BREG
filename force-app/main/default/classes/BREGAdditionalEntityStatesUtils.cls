public without sharing class BREGAdditionalEntityStatesUtils {
    private static final String STATUS_APPROVED = 'Approved';
    private static final Set<String> CASE_STATUSES_EXCLUDED_FROM_PENDING = new Set<String>{
        'Approved', 'Rejected', 'Cancelled', 'Completed', 'Expired'
    };
    private static final Id bregCaseRtId = getBregCaseRecordTypeId();

    private static Id getBregCaseRecordTypeId() {
        Schema.RecordTypeInfo rti = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case');
        return rti != null ? rti.getRecordTypeId() : null;
    }
    public static final Set<String> CLOSED_STATUSES = new Set<String>{
        'Terminated (T)', 'Cancelled (C)', 'Dissolved (D)', 'Merged (M)',
        'Converted (9)', 'Expired (E)', 'Inv. Dissolved (7) or (I)', 'Inv. Cancelled (X)',
        'Inv. Revoked (R)'
    };

    private static final Set<String> AMENDMENT_FORM_CONFIG_NAMES = new Set<String>{
        'DNP-3', 'FLP-2', 'GP-3', 'LLC-3', 'LLP-2', 'LLP-3', 'DC-3', 'LP-2', 'DNP-2', 
        'GP-2', 'LLC-2', 'DC-2', 'DC-6', 'DC-7', 'DC-7', 'X-12', 'DC-5', 'X-7', 'X-8', 
        'X-9', 'X-3'
    };

    private static final Set<String> CLOSED_STATUSES_TNTMSM = new Set<String>{
        'E', 'R', 'C'
    };

    private static final Set<String> TNTMSM_FILE_SUFFIXES = new Set<String>{
        'AG-1', 'LLC-1', 'FLLC-1', 'DC-1', 'DNP-1', 'SOLE-1', 'FC-1', 'GP-1',
        'LLP-1', 'FLLP-1', 'LP-1', 'FLP-1', 'PC-1', 'X-1', 'SBC-1', 'CONS-1'
    };

    private static final String SOBJECT_ACCOUNT = 'Account';
    private static final String SOBJECT_TN_TM_SM = 'breg_TN_TM_SM__c';

    /**
     * Result for front-end: computed Additional Entity States (no DB write).
     */
    public class AdditionalEntityStatesResult {
        @AuraEnabled public String valueString { get; set; }
        @AuraEnabled public List<String> values { get; set; }
        public AdditionalEntityStatesResult(String valueString, List<String> values) {
            this.valueString = valueString;
            this.values = values;
        }
    }

    /**
     * Computes Additional Entity States for the given record Id. Record type is determined from the Id:
     * Account or breg_TN_TM_SM__c. Call from front-end (e.g. LWC) when the entity type may be either.
     * @param recordId Account Id or breg_TN_TM_SM__c Id
     * @return Wrapper with valueString (semicolon-separated) and values (list), or null if recordId is null, unsupported type, or record not found
     */
    public static AdditionalEntityStatesResult getAdditionalEntityStatesForRecord(Id recordId) {
        if (recordId == null) {
            return null;
        }
        String objectType = recordId.getSObjectType().getDescribe().getName();
        if (objectType == SOBJECT_ACCOUNT) {
            return getAdditionalEntityStatesForAccount(recordId);
        }
        if (objectType == SOBJECT_TN_TM_SM) {
            return getAdditionalEntityStatesForTNTMSM(recordId);
        }
        return null;
    }

    /**
     * Computes Additional Entity States for the given Account Id using the same business rules
     * as trigger logic, without writing to the database. Call from front-end (e.g. LWC).
     * @param accountId Account Id
     * @return Wrapper with valueString (semicolon-separated) and values (list), or null if account not found
     */
    public static AdditionalEntityStatesResult getAdditionalEntityStatesForAccount(Id accountId) {
        if (accountId == null) {
            return null;
        }
        List<Account> accounts = [
            SELECT Id, breg_Entity_Status__c, breg_Good_Standing__c,
                breg_Certified_Register_Agent__c, breg_BRIM_CRA_FL__c, breg_File_Suffix__c,
                breg_Incorporation_Date__c, breg_Expiration_Date__c, breg_Date_of_dissol_cancel_revoc_term__c,
                breg_Registrant_Type__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            return null;
        }
        Account acc = accounts[0];
        Set<String> stateSet = new Set<String>();

        // Account-based states (same rules as handle* methods)
        computeAccountBasedStates(acc, stateSet);

        // Case-based states: pending requests and bounce check (no-op if BREG_Case record type missing)
        if (bregCaseRtId != null) {
            computeCaseBasedStates(accountId, stateSet);
            computeHasNoAmendmentsApproved(accountId, stateSet);
        }

        // No active registered agent: no Account Affiliation with Role=Agent, Status=A, End_Date=null
        computeNoActiveRegisteredAgent(accountId, stateSet);

        List<String> valueList = new List<String>(stateSet);
        valueList.sort();
        String valueString = valueList.isEmpty() ? null : String.join(valueList, ';');
        return new AdditionalEntityStatesResult(valueString, valueList);
    }

    /**
     * Computes Additional Entity States for the given TN/TM/SM record Id using TNTMSM-specific rules.
     * Uses Case lookup breg_TN_TM_SM__c, Registration Date (not Incorporation), and does not use
     * dissolution date or CRA fields. Available from Lightning (e.g. LWC).
     * @param tntmsmId breg_TN_TM_SM__c Id
     * @return Wrapper with valueString (semicolon-separated) and values (list), or null if record not found
     */
    public static AdditionalEntityStatesResult getAdditionalEntityStatesForTNTMSM(Id tntmsmId) {
        if (tntmsmId == null) {
            return null;
        }
        List<breg_TN_TM_SM__c> records = [
            SELECT Id, breg_Status__c, breg_File_Suffix__c, breg_Registration_Date__c,
                breg_Expiration_Date__c, breg_Registrant_Type__c
            FROM breg_TN_TM_SM__c
            WHERE Id = :tntmsmId
            LIMIT 1
        ];
        if (records.isEmpty()) {
            return null;
        }
        breg_TN_TM_SM__c rec = records[0];
        Set<String> stateSet = new Set<String>();

        computeTNTMSMBasedStates(rec, stateSet);

        if (bregCaseRtId != null) {
            computeCaseBasedStatesForTNTMSM(tntmsmId, stateSet);
        }

        List<String> valueList = new List<String>(stateSet);
        valueList.sort();
        String valueString = valueList.isEmpty() ? null : String.join(valueList, ';');
        return new AdditionalEntityStatesResult(valueString, valueList);
    }

    private static void computeTNTMSMBasedStates(breg_TN_TM_SM__c rec, Set<String> stateSet) {
        if (rec.breg_Status__c != null && CLOSED_STATUSES_TNTMSM.contains(rec.breg_Status__c)) {
            stateSet.add('Not active');
        }
        if (rec.breg_Status__c == 'E') {
            stateSet.add('Expired');
        }
        if (rec.breg_File_Suffix__c != null && rec.breg_File_Suffix__c != 'ZZ') {
            stateSet.add('Not have a ZZ file suffix');
        }
        if (rec.breg_Registrant_Type__c != 'Individual') {
            stateSet.add('Not Individual');
        }
        if (rec.breg_Registrant_Type__c != 'Entity') {
            stateSet.add('Not Entity');
        }

        Date today = Date.today();
        if (rec.breg_Expiration_Date__c != null && rec.breg_Expiration_Date__c > today && rec.breg_Expiration_Date__c.daysBetween(today) >= 180) {
            stateSet.add('Current date is not within the last 180 days of active term');
        }
        if (rec.breg_Expiration_Date__c != null && today.daysBetween(rec.breg_Expiration_Date__c) > 14) {
            stateSet.add('More than 14 days prior to the expiration date');
        }
        if (rec.breg_Expiration_Date__c != null && rec.breg_Expiration_Date__c < today
                && rec.breg_Expiration_Date__c.daysBetween(today) > 180) {
            stateSet.add('Expired more than 180 days');
        }
    }

    private static void computeCaseBasedStatesForTNTMSM(Id tntmsmId, Set<String> stateSet) {
        List<Case> cases = [
            SELECT Id, Status, breg_TN_TM_SM__c, breg_Bounced_Check__c, breg_Form_Configuration__c,
                breg_Form_Configuration__r.Name, breg_Form_Configuration__r.breg_Form_Name__c
            FROM Case
            WHERE RecordTypeId = :bregCaseRtId
                AND breg_TN_TM_SM__c = :tntmsmId
                AND breg_Form_Configuration__c != null
            LIMIT 1000
        ];
        Map<Id, breg_Form_Configuration__c> formConfigMap = new Map<Id, breg_Form_Configuration__c>();
        Set<Id> formConfigIds = new Set<Id>();
        for (Case caseRecord : cases) {
            if (caseRecord.breg_Form_Configuration__c != null) {
                formConfigIds.add(caseRecord.breg_Form_Configuration__c);
            }
        }
        if (!formConfigIds.isEmpty()) {
            for (breg_Form_Configuration__c fc : [
                SELECT Id, Name, breg_Form_Name__c FROM breg_Form_Configuration__c WHERE Id IN :formConfigIds
            ]) {
                formConfigMap.put(fc.Id, fc);
            }
        }

        for (Case iCase : cases) {
            if (CASE_STATUSES_EXCLUDED_FROM_PENDING.contains(iCase.Status)) {
                continue;
            }
            if (iCase.breg_Bounced_Check__c == true) {
                stateSet.add('Bounce check in progress');
            }
            breg_Form_Configuration__c formConfig = iCase.breg_Form_Configuration__c != null
                ? formConfigMap.get(iCase.breg_Form_Configuration__c)
                : null;
            if (formConfig == null || !isEligibleFormConfigurationForTNTMSM(formConfig)) {
                continue;
            }
            String picklistValue = getPicklistValueForTNTMSM(formConfig);
            if (picklistValue != null) {
                stateSet.add(picklistValue);
            }
        }
    }

    private static Boolean isEligibleFormConfigurationForTNTMSM(breg_Form_Configuration__c formConfig) {
        return formConfig != null && formConfig.Name == 'ADD-TNTMSM';
    }

    private static String getPicklistValueForTNTMSM(breg_Form_Configuration__c formConfig) {
        if (formConfig == null) {
            return null;
        }
        if (formConfig.Name == 'ADD-TNTMSM') {
            return 'Pending ADD request';
        }
        return null;
    }

    private static void computeAccountBasedStates(Account acc, Set<String> stateSet) {
        if (hasNoActiveNonCraAgent(acc)) {
            stateSet.add('No active agent associated who is not a CRA');
        }
        if (acc.breg_BRIM_CRA_FL__c == true) {
            stateSet.add('Registered CRA');
        }
        if (acc.breg_Good_Standing__c == false) {
            stateSet.add('Not in good standing');
        }
        if (acc.breg_Entity_Status__c != null && CLOSED_STATUSES.contains(acc.breg_Entity_Status__c)) {
            stateSet.add('Not active');
        }
        if (acc.breg_Entity_Status__c == 'Expired (E)') {
            stateSet.add('Expired');
        }
        if (acc.breg_Entity_Status__c == 'Merged (M)') {
            stateSet.add('Not survivor or merged entity');
        }
        if (acc.breg_BRIM_CRA_FL__c == false) {
            stateSet.add('Not a CRA');
        }
        if (acc.breg_File_Suffix__c != 'ZZ') {
            stateSet.add('Not have a ZZ file suffix');
        }
        if (acc.breg_Registrant_Type__c != 'Individual') {
            stateSet.add('Not Individual');
        }
        if (acc.breg_Registrant_Type__c != 'Entity') {
            stateSet.add('Not Entity');
        }

        Date today = Date.today();
        if (acc.breg_Incorporation_Date__c != null && acc.breg_Incorporation_Date__c.daysBetween(today) >= 180) {
            stateSet.add('Current date is not within the last 180 days of active term');
        }
        if (acc.breg_Expiration_Date__c != null && today.daysBetween(acc.breg_Expiration_Date__c) > 14) {
            stateSet.add('More than 14 days prior to the expiration date');
        }
        if (acc.breg_Expiration_Date__c != null && acc.breg_Expiration_Date__c < today && acc.breg_Expiration_Date__c.daysBetween(today) > 180) {
            stateSet.add('Expired more than 180 days');
        }
        if (acc.breg_Date_of_dissol_cancel_revoc_term__c != null && acc.breg_Date_of_dissol_cancel_revoc_term__c.daysBetween(today) > 120) {
            stateSet.add('120 days after dissolution effective date');
        }
        if (acc.breg_Entity_Status__c == 'Dissolved (D)'
                && acc.breg_Date_of_dissol_cancel_revoc_term__c != null
                && acc.breg_Date_of_dissol_cancel_revoc_term__c.daysBetween(today) > 730) {
            stateSet.add('2 years after dissolution');
        }
    }

    private static Boolean hasNoActiveNonCraAgent(Account acc) {
        if (acc == null || acc.Id == null) {
            return true;
        }

        Integer activeAgentCount = [
            SELECT COUNT()
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :acc.Id
                AND breg_Role__c = 'Agent'
                AND (breg_Type__c != 'CRA' AND breg_Account__r.breg_BRIM_CRA_FL__c = false)
                AND breg_Status__c = 'A'
                AND breg_End_Date__c = null
            LIMIT 1
        ];

        return activeAgentCount == 0 || acc.breg_BRIM_CRA_FL__c;
    }

    private static void computeCaseBasedStates(Id accountId, Set<String> stateSet) {
        List<Case> cases = [
            SELECT Id, Status, breg_Entity__c, breg_Portal_User_Entity_Selected__c,
                breg_Bounced_Check__c, breg_Form_Configuration__c,
                breg_Form_Configuration__r.Name, breg_Form_Configuration__r.breg_Form_Name__c
            FROM Case
            WHERE RecordTypeId = :bregCaseRtId
                AND (breg_Entity__c = :accountId OR breg_Portal_User_Entity_Selected__c = :accountId)
                AND breg_Form_Configuration__c != null
            LIMIT 1000
        ];
        Map<Id, breg_Form_Configuration__c> formConfigMap = new Map<Id, breg_Form_Configuration__c>();
        Set<Id> formConfigIds = new Set<Id>();
        for (Case caseRecord : cases) {
            if (caseRecord.breg_Form_Configuration__c != null) {
                formConfigIds.add(caseRecord.breg_Form_Configuration__c);
            }
        }
        if (!formConfigIds.isEmpty()) {
            for (breg_Form_Configuration__c fc : [
                SELECT Id, Name, breg_Form_Name__c FROM breg_Form_Configuration__c WHERE Id IN :formConfigIds
            ]) {
                formConfigMap.put(fc.Id, fc);
            }
        }

        for (Case iCase : cases) {
            if (CASE_STATUSES_EXCLUDED_FROM_PENDING.contains(iCase.Status)) {
                continue;
            }
            if (iCase.breg_Bounced_Check__c == true && iCase.breg_Entity__c == accountId) {
                stateSet.add('Bounce check in progress');
            }
            Id accountThatGetsPending = iCase.breg_Portal_User_Entity_Selected__c != null
                ? iCase.breg_Portal_User_Entity_Selected__c
                : iCase.breg_Entity__c;
            if (accountThatGetsPending != accountId) {
                continue;
            }
            breg_Form_Configuration__c formConfig = iCase.breg_Form_Configuration__c != null
                ? formConfigMap.get(iCase.breg_Form_Configuration__c)
                : null;
            if (formConfig == null || !isEligibleFormConfiguration(formConfig)) {
                continue;
            }
            String picklistValue = getPicklistValueForAccount(formConfig);
            if (picklistValue != null) {
                stateSet.add(picklistValue);
            }
        }
    }

    private static void computeHasNoAmendmentsApproved(Id accountId, Set<String> stateSet) {
        List<breg_Form_Configuration__c> amendmentConfigs = [
            SELECT Id FROM breg_Form_Configuration__c
            WHERE Name IN :AMENDMENT_FORM_CONFIG_NAMES
            LIMIT 100
        ];
        if (amendmentConfigs.isEmpty()) {
            return;
        }
        Set<Id> amendmentFormConfigIds = new Set<Id>();
        for (breg_Form_Configuration__c fc : amendmentConfigs) {
            amendmentFormConfigIds.add(fc.Id);
        }
        Integer approvedCount = [
            SELECT COUNT()
            FROM Case
            WHERE RecordTypeId = :bregCaseRtId
                AND breg_Form_Configuration__c IN :amendmentFormConfigIds
                AND Status = :STATUS_APPROVED
                AND (breg_Entity__c = :accountId OR breg_Portal_User_Entity_Selected__c = :accountId)
            LIMIT 1
        ];
        if (approvedCount == 0) {
            stateSet.add('Has no amendments approved');
        }
    }

    /**
     * Adds "No active registered agent" when no Account Affiliation exists with Role = 'Agent',
     * Status = 'A', and End_Date = null (active = no end date) for this entity account.
     */
    private static void computeNoActiveRegisteredAgent(Id accountId, Set<String> stateSet) {
        Integer activeAgentCount = [
            SELECT COUNT()
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :accountId
                AND breg_Role__c = 'Agent'
                AND breg_Status__c = 'A'
                AND breg_End_Date__c = null
            LIMIT 1
        ];
        if (activeAgentCount == 0) {
            stateSet.add('No active registered agent');
        }
    }

    private static Boolean isEligibleFormConfiguration(breg_Form_Configuration__c formConfig) {
        Set<String> formConfigurationNames = new Set<String> {
            'ADD', 'ADD-TNTMSM', 'ADD-MEMBER', 'X-2', 'R7-CANC-ENTITY','R7-CANC-INDIVIDUAL'
        };
        return formConfigurationNames.contains(formConfig.Name)
            || formConfig.breg_Form_Name__c == 'ODC'
            || (formConfig.Name != null && formConfig.Name.startsWith('ANN'));
    }

    private static String getPicklistValueForAccount(breg_Form_Configuration__c formConfig) {
        String result = null;

        if (formConfig == null) {
            return result;
        }

        String formConfigName = formConfig.Name;
        String formName = formConfig.breg_Form_Name__c;

        switch on formConfigName {
            when 'ADD', 'ADD-TNTMSM' {
                result = 'Pending ADD request';
            }
            when 'ADD-MEMBER' {
                result = 'Pending O/D/M/M/P ADD request';
            }
            when 'X-2' {
                result = 'Pending transfer of name reservation';
            }
            when 'R7-CANC-ENTITY', 'R7-CANC-INDIVIDUAL' {
                result = 'Pending cancellation of name reservation';
            }
            when else {
                if (formConfigName.startsWith('ANN')) {
                    result = 'Pending annual';
                } else if (formName == 'ODC') {
                    result = 'Pending ODC request';
                }
            }
        }

        return result;
    }
}