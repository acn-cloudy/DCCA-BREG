public without sharing class BREGWebFilingWrapper {
    public Case WebCase;
    public List<BREGWebAccountAffiliationWrapper> AccountAffiliations;
    public List<breg_Stock__c> Stocks;
    public List<breg_TN_TM_SM__c> TradeMarks;

    public BREGWebFilingWrapper() {
        this.WebCase = new Case();
        this.AccountAffiliations = new List<BREGWebAccountAffiliationWrapper>();
        this.Stocks = new List<breg_Stock__c>();
        this.TradeMarks = new List<breg_TN_TM_SM__c>();
    }

    public static List<BREGWebAccountAffiliationWrapper> createMembers(BREGWebFilingWrapper filingWrapper) {
        if (filingWrapper == null || filingWrapper.AccountAffiliations == null || filingWrapper.AccountAffiliations.isEmpty()) {
            return new List<BREGWebAccountAffiliationWrapper>();
        }

        List<Account> accountsToInsert = collectAccountsToInsert(filingWrapper.AccountAffiliations);
        List<Contact> contactsToInsert = collectContactsToInsert(filingWrapper.AccountAffiliations);

        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
        }
        if (!contactsToInsert.isEmpty()) {
            insert contactsToInsert;
        }

        List<breg_Account_Affiliation__c> affiliationsToInsert = collectAffiliationsToInsert(filingWrapper);

        if (!affiliationsToInsert.isEmpty()) {
            insert affiliationsToInsert;
        }

        return filingWrapper.AccountAffiliations;
    }

    private static List<Account> collectAccountsToInsert(List<BREGWebAccountAffiliationWrapper> wrappers) {
        List<Account> accountsToInsert = new List<Account>();
        for (BREGWebAccountAffiliationWrapper wrapperItem : wrappers) {
            if (wrapperItem != null && wrapperItem.Account != null && wrapperItem.Account.Id == null) {
                accountsToInsert.add(wrapperItem.Account);
            }
        }
        return accountsToInsert;
    }

    private static List<Contact> collectContactsToInsert(List<BREGWebAccountAffiliationWrapper> wrappers) {
        List<Contact> contactsToInsert = new List<Contact>();
        for (BREGWebAccountAffiliationWrapper wrapperItem : wrappers) {
            if (wrapperItem != null && wrapperItem.Contact != null && wrapperItem.Contact.Id == null) {
                contactsToInsert.add(wrapperItem.Contact);
            }
        }
        return contactsToInsert;
    }

    private static List<breg_Account_Affiliation__c> collectAffiliationsToInsert(BREGWebFilingWrapper filingWrapper) {
        List<breg_Account_Affiliation__c> affiliationsToInsert = new List<breg_Account_Affiliation__c>();
        for (BREGWebAccountAffiliationWrapper affiliationWrapper : filingWrapper.AccountAffiliations) {
            if (affiliationWrapper == null || affiliationWrapper.accountAffiliation == null) {
                continue;
            }

            breg_Account_Affiliation__c affiliation = affiliationWrapper.accountAffiliation;
            setAffiliationLookups(filingWrapper, affiliationWrapper, affiliation);

            if (affiliation.Id == null) {
                affiliationsToInsert.add(affiliation);
            }
        }
        return affiliationsToInsert;
    }

    private static void setAffiliationLookups(
        BREGWebFilingWrapper filingWrapper,
        BREGWebAccountAffiliationWrapper affiliationWrapper,
        breg_Account_Affiliation__c affiliation
    ) {
        if (filingWrapper.WebCase != null && filingWrapper.WebCase.Id != null && affiliation.breg_Case__c == null) {
            affiliation.breg_Case__c = filingWrapper.WebCase.Id;
        }
        if (affiliationWrapper.Account != null && affiliationWrapper.Account.Id != null && affiliation.breg_Account__c == null) {
            affiliation.breg_Account__c = affiliationWrapper.Account.Id;
        }
        if (affiliationWrapper.Contact != null && affiliationWrapper.Contact.Id != null && affiliation.breg_Contact__c == null) {
            affiliation.breg_Contact__c = affiliationWrapper.Contact.Id;
        }
    }
}