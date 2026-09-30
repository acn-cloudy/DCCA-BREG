public with sharing class BREGAccountTriggerHandler extends BREGBaseTriggerHandler {
    private static final String ENTITY_STATUS_ANNUAL_REPORT_2YR_DELINQUENT = 'Annual report 2 yr delinquent (2)';
    private static final String INVOLUNTARY_DISSOLUTION_WORKFLOW = 'BREG Involuntary Dissolution Notice';
    public static final String STATUS_REVOKED = 'Inv. Revoked (R)';
    public static final String STATUS_CANCELLED = 'Inv. Cancelled (X)';
    public static final String STATUS_DISSOLVED = 'Inv. Dissolved (7)';
    public static final String STATUS_TERMINATED = 'Adm. Terminated (V)';
    public static final String MEMBER_MANAGED_VALUE = 'Member Managed';
    public static final String MANAGER_MANAGED_VALUE = 'Manager Managed';
    private static final Id BREG_ACCOUNT_RECORD_TYPE_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('BREG_Account')
        .getRecordTypeId();
    private static breg_Docusign_Settings__c settings = breg_Docusign_Settings__c.getOrgDefaults();
    private static Map<String, String> STATUS_TRANS_CODE_MAP = new Map<String, String>{
        'Dissolved (D)' => 'INDS',
        'Adm. Terminated (V)' => 'INDBX',
        'Cancelled (C)' => 'INCN',
        'Inv. Revoked (R)' => 'INVR'
    };
    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        'Terminated (T)',
        'Cancelled (C)',
        'Dissolved (D)',
        'Merged (M)',
        'Converted (9)',
        'Expired (E)',
        'Inv. Dissolved (7)',
        'Inv. Cancelled (X)',
        'Inv. Revoked (R)',
        'Adm. Terminated (V)'
    };
    public static Boolean skipDocusignWorkflow = false;
    private static Set<String> enqueuedBatches = new Set<String>();
    private List<Account> bregNewList;

    private List<Account> getBregNewList() {
        if (bregNewList == null) {
            bregNewList = new List<Account>();
            for (Account account : (List<Account>) this.newList) {
                if (account.RecordTypeId == BREG_ACCOUNT_RECORD_TYPE_ID) {
                    bregNewList.add(account);
                }
            }
        }
        return bregNewList;
    }

    public override void afterUpdate() {
        List<Account> bregNewList = getBregNewList();
        if (bregNewList.isEmpty()) {
            return;
        }

        List<Account> delinquentAccounts = getAccountsWithChangedStatus(new List<String>{ ENTITY_STATUS_ANNUAL_REPORT_2YR_DELINQUENT });
        List<Account> dissolvedAccounts = getAccountsWithChangedStatus(
            new List<String>{ STATUS_REVOKED, STATUS_CANCELLED, STATUS_DISSOLVED, STATUS_TERMINATED }
        );
        if (skipDocusignWorkflow) {
            return;
        }
        if (!dissolvedAccounts.isEmpty()) {
            // Start integration with DocuSign for involuntary dissolution notice using Batch Apex
            startWorkflowBatch(INVOLUNTARY_DISSOLUTION_WORKFLOW, dissolvedAccounts);
        }
        createTransactionsForRelatedAccounts(dissolvedAccounts);
    }

    public static void createTransactionsForRelatedAccounts(List<Account> accountsToUpdate) {
        List<breg_Transaction__c> transactionsToInsert = new List<breg_Transaction__c>();
        for (Account acc : accountsToUpdate) {
            breg_Transaction__c newTransaction = BREGTransactionUtils.buildBaseTransactionForAccount(
                acc,
                STATUS_TRANS_CODE_MAP.get(acc.breg_Entity_Status__c),
                Date.today(),
                Date.today(),
                'C'
            );
            transactionsToInsert.add(newTransaction);
        }
        insert transactionsToInsert;
    }

    public override void beforeUpdate() {
        List<Account> bregNewList = getBregNewList();
        if (bregNewList.isEmpty()) {
            return;
        }

        syncManagementType((List<SObject>) bregNewList, this.oldMap);
        setDissolutionDateForClosedStatus((List<SObject>) bregNewList, this.oldMap);
        new BREGGoodStandingCheckJob().processRecords(new Map<Id, SObject>(bregNewList), 'Account');

        Boolean hasCountryChanges = false;
        List<SObject> recordsWithStateOrCountryChanges = new List<SObject>();
        for (Account currentAccount : bregNewList) {
            Account oldAccount = (Account) this.oldMap.get(currentAccount.Id);
            if (oldAccount == null) {
                continue;
            }

            Boolean countryChanged = currentAccount.breg_Formation_Country__c != oldAccount.breg_Formation_Country__c;
            Boolean stateChanged = currentAccount.breg_Formation_State__c != oldAccount.breg_Formation_State__c;

            if (countryChanged) {
                hasCountryChanges = true;
            }
            if (countryChanged || stateChanged) {
                recordsWithStateOrCountryChanges.add(currentAccount);
            }
        }

        Map<String, String> formationCountryLabelMap = hasCountryChanges ? BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode') : null;

        Map<String, String> dependentStateLabelMap = recordsWithStateOrCountryChanges.isEmpty()
            ? null
            : BREGUtils.getStateLabelMapByCountry(recordsWithStateOrCountryChanges, 'breg_Formation_Country__c');

        BREGUtils.LabelFieldConfig formationCountryLabelConfig = new BREGUtils.LabelFieldConfig(
            'breg_Formation_Country__c',
            'breg_Formation_Country_Label__c',
            null,
            formationCountryLabelMap
        );

        BREGUtils.LabelFieldConfig formationStateLabelConfig = new BREGUtils.LabelFieldConfig(
            'breg_Formation_State__c',
            'breg_Formation_State_Label__c',
            'breg_Formation_Country__c',
            dependentStateLabelMap
        );

        for (Account currentAccount : bregNewList) {
            Account oldAccount = (Account) this.oldMap.get(currentAccount.Id);
            if (oldAccount == null) {
                continue;
            }

            if (currentAccount.Name != oldAccount.Name) {
                currentAccount.breg_Search_Name__c = BREGUtils.cleanBusinessName(currentAccount.Name);
                currentAccount.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentAccount.Name);
            }

            if (currentAccount.breg_Xref_Name_1__c != oldAccount.breg_Xref_Name_1__c) {
                currentAccount.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(currentAccount.breg_Xref_Name_1__c);
            }

            if (currentAccount.breg_Xref_Name_2__c != oldAccount.breg_Xref_Name_2__c) {
                currentAccount.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(currentAccount.breg_Xref_Name_2__c);
            }

            updateLabelField(oldAccount, currentAccount, formationCountryLabelConfig);
            updateLabelField(oldAccount, currentAccount, formationStateLabelConfig);
        }
    }

    public override void beforeInsert() {
        List<Account> bregNewList = getBregNewList();
        if (bregNewList.isEmpty()) {
            return;
        }

        syncManagementType((List<SObject>) bregNewList, null);
        Map<String, String> formationCountryLabelMap = BREGUtils.getPicklistLabelMap('Account', 'BillingCountryCode');
        Map<String, String> dependentStateLabelMap = BREGUtils.getStateLabelMapByCountry((List<SObject>) bregNewList, 'breg_Formation_Country__c');

        BREGUtils.LabelFieldConfig formationCountryLabelConfig = new BREGUtils.LabelFieldConfig(
            'breg_Formation_Country__c',
            'breg_Formation_Country_Label__c',
            null,
            formationCountryLabelMap
        );

        BREGUtils.LabelFieldConfig formationStateLabelConfig = new BREGUtils.LabelFieldConfig(
            'breg_Formation_State__c',
            'breg_Formation_State_Label__c',
            'breg_Formation_Country__c',
            dependentStateLabelMap
        );

        for (Account currentAccount : bregNewList) {
            currentAccount.breg_Search_Name__c = BREGUtils.cleanBusinessName(currentAccount.Name);
            currentAccount.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(currentAccount.Name);
            currentAccount.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(currentAccount.breg_Xref_Name_1__c);
            currentAccount.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(currentAccount.breg_Xref_Name_2__c);

            updateLabelField(null, currentAccount, formationCountryLabelConfig);
            updateLabelField(null, currentAccount, formationStateLabelConfig);
        }
    }

    public static void syncManagementType(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        Boolean isInsert = (oldMap == null);

        for (SObject sobj : newRecords) {
            if (!(sobj instanceof Account)) {
                continue;
            }

            Account a = (Account) sobj;

            if (isInsert) {
                normalizeOnInsert(a);
            } else {
                Account oldA = (Account) oldMap.get(a.Id);
                normalizeOnUpdate(a, oldA);
            }
        }
    }

    private static void normalizeOnInsert(Account a) {
        if (a.breg_Management_Type__c != null) {
            a.breg_Is_Manager_Managed__c = a.breg_Management_Type__c == MANAGER_MANAGED_VALUE;
            return;
        }
        if (a.breg_Is_Manager_Managed__c != null) {
            a.breg_Management_Type__c = a.breg_Is_Manager_Managed__c ? MANAGER_MANAGED_VALUE : MEMBER_MANAGED_VALUE;
        }
    }

    private static void normalizeOnUpdate(Account a, Account oldA) {
        Boolean mmChanged = a.breg_Is_Manager_Managed__c != oldA.breg_Is_Manager_Managed__c;

        Boolean typeChanged = a.breg_Management_Type__c != oldA.breg_Management_Type__c;

        if (!mmChanged && !typeChanged)
            return;

        if (mmChanged) {
            a.breg_Management_Type__c = a.breg_Is_Manager_Managed__c ? MANAGER_MANAGED_VALUE : MEMBER_MANAGED_VALUE;
            return;
        }

        if (typeChanged) {
            if (a.breg_Management_Type__c == MANAGER_MANAGED_VALUE) {
                a.breg_Is_Manager_Managed__c = true;
            } else if (a.breg_Management_Type__c == MEMBER_MANAGED_VALUE) {
                a.breg_Is_Manager_Managed__c = false;
            }
        }
    }

    private List<Account> getAccountsWithChangedStatus(List<String> statuses) {
        List<Account> bregNewList = getBregNewList();
        List<Account> changedAccounts = new List<Account>();
        for (Account account : bregNewList) {
            Account oldAccount = (Account) this.oldMap.get(account.Id);
            if (oldAccount.breg_Entity_Status__c != account.breg_Entity_Status__c && statuses.contains(account.breg_Entity_Status__c)) {
                changedAccounts.add(account);
            }
        }

        return changedAccounts;
    }

    public static void startWorkflowBatch(String workflowName, List<Account> accounts) {
        List<Id> accountIds = new List<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        if (!accountIds.isEmpty()) {
            String requiredIds = String.join(accountIds, ',');
            String params = '<recordIds>' + requiredIds + '</recordIds>';
            String integrationEmail = settings.Integration_User_Email__c;
            if (String.isNotBlank(integrationEmail)) {
                params += '<email>' + integrationEmail + '</email>';
            }
            String rootLink = settings.Documents_Root_Link__c;
            params += '<rootLink>' + DocuSignAPI.escapeXml(rootLink) + '</rootLink>';

            System.enqueueJob(new BREGStartDocusignWorkflow(workflowName, null, params, 'Account Trigger Handler', false));
        }
    }

    private static Integer getActiveBatchCount() {
        Integer activeBatches = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex' AND Status IN ('Processing', 'Holding', 'Queued', 'Preparing')
        ];
        return activeBatches;
    }

    private static void setDissolutionDateForClosedStatus(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        Date today = Date.today();
        List<Account> newAccounts = (List<Account>) newRecords;
        Map<Id, Account> oldAccounts = (Map<Id, Account>) oldMap;
        for (Account newAccount : newAccounts) {
            Account oldAccount = oldAccounts.get(newAccount.Id);
            Boolean statusChangedToClosed =
                oldAccount.breg_Entity_Status__c != newAccount.breg_Entity_Status__c && CLOSED_STATUSES.contains(newAccount.breg_Entity_Status__c);

            if (statusChangedToClosed && newAccount.breg_Date_of_dissol_cancel_revoc_term__c == null) {
                newAccount.breg_Date_of_dissol_cancel_revoc_term__c = newAccount.breg_Involuntary_Dissolution_Due_Date__c ?? today;
            }
        }
    }

    private static void updateLabelField(Account oldAccount, Account newAccount, BREGUtils.LabelFieldConfig config) {
        if (newAccount == null) {
            return;
        }

        String newValue = toStringValue(newAccount.get(config.sourceFieldApiName));
        String oldValue = oldAccount == null ? null : toStringValue(oldAccount.get(config.sourceFieldApiName));
        String newControllerValue = config.isDependentPicklist() ? toStringValue(newAccount.get(config.controllerFieldApiName)) : null;
        String oldControllerValue = config.isDependentPicklist() && oldAccount != null
            ? toStringValue(oldAccount.get(config.controllerFieldApiName))
            : null;

        // On update, only recalculate when source/controller fields changed.
        if (oldAccount != null && newValue == oldValue && newControllerValue == oldControllerValue) {
            return;
        }

        Map<String, String> valueToLabelMap = config.valueToLabelMap;

        String lookupKey = config.isDependentPicklist() ? (newControllerValue + '.' + newValue) : newValue;
        String labelValue = valueToLabelMap != null && valueToLabelMap.containsKey(lookupKey) ? valueToLabelMap.get(lookupKey) : newValue;
        newAccount.put(config.targetLabelFieldApiName, labelValue);
    }

    private static String toStringValue(Object valueObj) {
        return valueObj == null ? null : String.valueOf(valueObj);
    }
}