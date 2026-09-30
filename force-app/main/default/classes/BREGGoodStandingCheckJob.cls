public without sharing class BREGGoodStandingCheckJob extends BREGBatchInterface { // since process records can call from Site Guest User, we need to make this class without sharing
    private static final String SOLE_ENTITY_TYPE = 'D9';
    private static final String ACTIVE_ENTITY_STATUS = 'Active (A)';

    // G5/G6 (General Partnership) entities are registered as children of a K5/K6 (LLP) parent account and are
    // administered together with that parent: BREGAnnualRollOverJob generates the GP's annuals from the parent's
    // incorporation quarter, and the annual robot already propagates a GP's bounced check up to the parent.
    // Good standing therefore evaluates a GP against the pair (GP + LLP parent):
    //   - blocking checks (entity status, bounced check) must pass on BOTH records;
    //   - requirement checks (registered agent, filed annual) are satisfied by EITHER record;
    //   - the annuals due date is driven by the parent's registration date.
    private static final Set<String> GP_ENTITY_TYPES = new Set<String>{ ConstantsHelper.G5_ENTITY_TYPE, ConstantsHelper.G6_ENTITY_TYPE };
    private static final Set<String> LLP_ENTITY_TYPES = new Set<String>{ ConstantsHelper.K5_ENTITY_TYPE, ConstantsHelper.K6_ENTITY_TYPE };

    public override BatchProcessingResult processRecords(Map<Id, SObject> recordsMap, String sObjectType) {
        BatchProcessingResult result = new BatchProcessingResult();
        List<Account> accounts = (List<Account>) recordsMap.values();

        // Resolved once so every check evaluates a GP against the same K5/K6 parent
        Map<Id, Account> llpParentByGpAccountId = getLlpParentByGpAccountId(accounts);

        //certified agent check
        this.certAgentCheck(accounts, llpParentByGpAccountId);
        System.debug('Accounts after cert agent check: ' + accounts);
        //status check
        this.statusCheck(accounts, llpParentByGpAccountId);
        System.debug('Accounts after status check: ' + accounts);
        //filed annuals check
        this.annualsCheck(accounts, llpParentByGpAccountId);
        System.debug('Accounts after annuals check: ' + accounts);
        //bounce email check
        this.bounceCheck(accounts, llpParentByGpAccountId);
        System.debug('Accounts after good standing check: ' + accounts);
        result.recordsToUpsert = new Map<Id, SObject>(accounts);
        return result;
    }

    @TestVisible
    private void statusCheck(List<Account> accounts) {
        statusCheck(accounts, getLlpParentByGpAccountId(accounts));
    }

    @TestVisible
    private void statusCheck(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        for (Account acc : accounts) {
            Account llpParent = getLlpParent(acc, llpParentByGpAccountId);
            // Blocking check: a GP is only active while its LLP parent is active too
            Boolean isActive =
                acc.breg_Entity_Status__c == ACTIVE_ENTITY_STATUS && (llpParent == null || llpParent.breg_Entity_Status__c == ACTIVE_ENTITY_STATUS);
            if (!isActive) {
                acc.breg_Good_Standing__c = false;
            }
        }
    }

    @TestVisible
    private void annualsCheck(List<Account> accounts) {
        annualsCheck(accounts, getLlpParentByGpAccountId(accounts));
    }

    @TestVisible
    private void annualsCheck(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        Map<Id, breg_Annual__c> existingAnnualsByAccountMap = getExistingAnnualsByAccountMap(accounts, llpParentByGpAccountId);
        Date today = Date.today();

        Date startQUarterDate = Date.newInstance(today.year(), ((getQuarter(today) - 1) * 3) + 1, 1);
        for (Account acc : accounts) {
            Account llpParent = getLlpParent(acc, llpParentByGpAccountId);
            Date accRegisterDate = getAnnualsRegisterDate(acc, llpParent);
            if (accRegisterDate == null) {
                continue;
            }

            breg_Annual__c existingAnnual = getExistingAnnual(acc, llpParent, existingAnnualsByAccountMap);
            if (existingAnnual != null) {
                acc.breg_Last_Annual_Filed_Date__c = existingAnnual.breg_Filing_Date__c;
                if (
                    (existingAnnual.breg_Status__c == 'P' || existingAnnual.breg_Status__c == 'NR') &&
                    existingAnnual.breg_Filing_Date__c >= startQUarterDate.addYears(-1)
                ) {
                    continue;
                }

                if (existingAnnual.breg_Status__c == 'F' && existingAnnual.breg_Filing_Date__c >= startQUarterDate) {
                    continue;
                }
            }

            if (startQUarterDate.addYears(-1) <= accRegisterDate) {
                continue;
            }
            acc.breg_Good_Standing__c = false;
        }
    }

    @TestVisible
    private void bounceCheck(List<Account> accounts) {
        bounceCheck(accounts, getLlpParentByGpAccountId(accounts));
    }

    @TestVisible
    private void bounceCheck(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        for (Account acc : accounts) {
            Account llpParent = getLlpParent(acc, llpParentByGpAccountId);
            // Blocking check: a bounced check on either the GP or its LLP parent breaks good standing
            if (acc.breg_Bounced_Check__c == true || (llpParent != null && llpParent.breg_Bounced_Check__c == true)) {
                acc.breg_Good_Standing__c = false;
            }
        }
    }

    @TestVisible
    private void certAgentCheck(List<Account> accounts) {
        certAgentCheck(accounts, getLlpParentByGpAccountId(accounts));
    }

    @TestVisible
    private void certAgentCheck(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        Map<Id, breg_Account_Affiliation__c> accountAffiliationMap = getActiveAgentsAffiliations(accounts, llpParentByGpAccountId);
        System.debug('Account Affiliation Map: ' + accountAffiliationMap);
        for (Account acc : accounts) {
            Account llpParent = getLlpParent(acc, llpParentByGpAccountId);
            // Requirement check: the GP's own agent, or the LLP parent's agent when the GP has none of its own
            breg_Account_Affiliation__c affiliation = accountAffiliationMap.get(acc.Id);
            if (affiliation == null && llpParent != null) {
                affiliation = accountAffiliationMap.get(llpParent.Id);
            }

            if (acc.breg_Entity_Type__c == SOLE_ENTITY_TYPE) {
                acc.breg_Good_Standing__c = true;
                continue;
            }

            if (affiliation == null) {
                acc.breg_Good_Standing__c = false;
            } else {
                if (acc.breg_Certified_Register_Agent__c == null) {
                    acc.breg_Certified_Register_Agent__c = affiliation.Id;
                }
                acc.breg_Good_Standing__c = true;
            }
        }
    }

    @TestVisible
    private Integer getQuarter(Date d) {
        Integer month = d.month();
        if (month >= 1 && month <= 3)
            return 1;
        if (month >= 4 && month <= 6)
            return 2;
        if (month >= 7 && month <= 9)
            return 3;
        return 4;
    }

    @TestVisible
    private Boolean lastAnnualFiledDateWithinTheQuarter(Integer quarter, Date lastAnnualFiledDate, Date today) {
        if (lastAnnualFiledDate == null)
            return false;
        Integer lastAnnualFiledQuarter = getQuarter(lastAnnualFiledDate);
        Integer lastAnnualFiledYear = lastAnnualFiledDate.year();
        //if filing quarter is 4 it means that the filing year is previous year
        Integer filingYear = today.year() - (quarter == 4 ? 1 : 0);
        if (lastAnnualFiledQuarter == quarter && lastAnnualFiledYear == filingYear) {
            return true;
        }
        return false;
    }

    @testVisible
    private Map<Id, breg_Account_Affiliation__c> getActiveAgentsAffiliations(List<Account> accounts) {
        return getActiveAgentsAffiliations(accounts, getLlpParentByGpAccountId(accounts));
    }

    @testVisible
    private Map<Id, breg_Account_Affiliation__c> getActiveAgentsAffiliations(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        // GP accounts also need their LLP parent's agent, so both sides of the pair are queried
        Set<Id> accountIds = getAccountIdsWithLlpParents(accounts, llpParentByGpAccountId);

        Map<Id, breg_Account_Affiliation__c> affiliationMap = new Map<Id, breg_Account_Affiliation__c>();
        List<breg_Account_Affiliation__c> affiliations = [
            SELECT Id, breg_Account__c, breg_Entity__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :accountIds AND breg_Role__c = 'Agent' AND breg_Status__c = 'A' AND breg_End_Date__c = NULL
        ];

        for (breg_Account_Affiliation__c affiliation : affiliations) {
            affiliationMap.put(affiliation.breg_Entity__c, affiliation);
        }
        return affiliationMap;
    }

    @TestVisible
    private Boolean isRelevantForAnnualCheck(Date today, Date accRegisterDate, Integer currentQuarter, Integer filingQuarter) {
        return today.addYears(-1) > accRegisterDate && (currentQuarter - 1 == filingQuarter || (currentQuarter == 1 && filingQuarter == 4));
    }

    /**
     * Returns the K5/K6 parent a G5/G6 account is administered under, or null when the account is not a GP
     * or has no K5/K6 parent (in which case it is evaluated on its own records only).
     */
    @TestVisible
    private Account getLlpParent(Account acc, Map<Id, Account> llpParentByGpAccountId) {
        if (llpParentByGpAccountId == null || !GP_ENTITY_TYPES.contains(acc.breg_Entity_Type__c)) {
            return null;
        }
        return llpParentByGpAccountId.get(acc.Id);
    }

    /**
     * Returns the registration date the annuals check must be evaluated against.
     * For a GP filed under a K5/K6 parent that is the parent's registration date, because the GP's annuals are
     * generated from the parent's incorporation quarter (see BREGAnnualRollOverJob).
     */
    @TestVisible
    private Date getAnnualsRegisterDate(Account acc, Account llpParent) {
        if (llpParent != null && llpParent.breg_Incorporation_Date__c != null) {
            return llpParent.breg_Incorporation_Date__c;
        }
        return acc.breg_Incorporation_Date__c;
    }

    /**
     * Requirement check: an annual filed on the LLP parent also covers its GP children,
     * so the most recently filed of the two records wins.
     */
    @TestVisible
    private breg_Annual__c getExistingAnnual(Account acc, Account llpParent, Map<Id, breg_Annual__c> existingAnnualsByAccountMap) {
        breg_Annual__c ownAnnual = existingAnnualsByAccountMap.get(acc.Id);
        breg_Annual__c parentAnnual = llpParent == null ? null : existingAnnualsByAccountMap.get(llpParent.Id);

        if (ownAnnual == null) {
            return parentAnnual;
        }
        if (parentAnnual == null || parentAnnual.breg_Filing_Date__c == null) {
            return ownAnnual;
        }
        if (ownAnnual.breg_Filing_Date__c == null || parentAnnual.breg_Filing_Date__c > ownAnnual.breg_Filing_Date__c) {
            return parentAnnual;
        }
        return ownAnnual;
    }

    /**
     * Maps each G5/G6 account in scope to its K5/K6 parent, with the fields the good standing checks need.
     * ParentId is not part of the BREG_Batch_Fields field set, so the relationship is queried separately.
     */
    @TestVisible
    private Map<Id, Account> getLlpParentByGpAccountId(List<Account> accounts) {
        Map<Id, Account> llpParentByGpAccountId = new Map<Id, Account>();

        Set<Id> gpAccountIds = new Set<Id>();
        for (Account acc : accounts) {
            if (acc.Id != null && GP_ENTITY_TYPES.contains(acc.breg_Entity_Type__c)) {
                gpAccountIds.add(acc.Id);
            }
        }

        if (gpAccountIds.isEmpty()) {
            return llpParentByGpAccountId;
        }

        List<Account> gpAccountsWithLlpParent = [
            SELECT
                Id,
                ParentId,
                Parent.Id,
                Parent.breg_Entity_Type__c,
                Parent.breg_Entity_Status__c,
                Parent.breg_Incorporation_Date__c,
                Parent.breg_Bounced_Check__c
            FROM Account
            WHERE Id IN :gpAccountIds AND ParentId != NULL AND Parent.breg_Entity_Type__c IN :LLP_ENTITY_TYPES
        ];

        for (Account gpAccount : gpAccountsWithLlpParent) {
            llpParentByGpAccountId.put(gpAccount.Id, gpAccount.Parent);
        }

        return llpParentByGpAccountId;
    }

    private Set<Id> getAccountIdsWithLlpParents(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
            Account llpParent = getLlpParent(acc, llpParentByGpAccountId);
            if (llpParent != null) {
                accountIds.add(llpParent.Id);
            }
        }
        return accountIds;
    }

    private Map<Id, breg_Annual__c> getExistingAnnualsByAccountMap(List<Account> accounts, Map<Id, Account> llpParentByGpAccountId) {
        String referenceYear = String.valueOf(Date.today().year());
        Set<Id> accountIds = getAccountIdsWithLlpParents(accounts, llpParentByGpAccountId);

        Map<Id, breg_Annual__c> annualsByAccountMap = new Map<Id, breg_Annual__c>();
        List<breg_Annual__c> existingAnnuals = [
            SELECT Id, breg_Account__c, breg_Filing_Year__c, breg_Filing_Date__c, breg_Status__c
            FROM breg_Annual__c
            WHERE breg_Account__c IN :accountIds AND (breg_Status__c = 'P' OR breg_Status__c = 'NR')
            ORDER BY breg_Filing_Date__c ASC
        ];

        for (breg_Annual__c annual : existingAnnuals) {
            annualsByAccountMap.put(annual.breg_Account__c, annual);
        }

        return annualsByAccountMap;
    }
}