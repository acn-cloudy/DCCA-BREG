public with sharing class BREGCaseStatusHandlerCorrections extends BREGCaseStatusHandlerBase {
    public override void handleStatusChange(List<Case> cases, String newStatus, Boolean performValidation, Boolean performActions) {
        if (performValidation) {
            super.handleStatusChange(cases, newStatus, true, false);
            performValidation(cases, newStatus);
        }

        if (performActions) {
            super.handleStatusChange(cases, newStatus, false, true);
            performActions(cases, newStatus);
        }
    }

    private void performValidation(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Approved' {
                validateAccsAndContactsLinked(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific validation for different statuses
        switch on newStatus {
            when 'Received' {
                BREGTransactionUtils.createTransactionsForEntities(new Map<Id, Case>(cases), 'R');
            }
            when 'Approved' {
                addRelationToCRA(cases);
            }
            when 'Completed' {
                updateRelatedEntities(cases);
                updateRegAgentAddress(cases);
                updateAffiliations(getIdCaseMap(cases));
            }
            when else {
                // do nothing
            }
        }
    }

    private void validateAccsAndContactsLinked(List<Case> cases) {
        Map<Id, Case> caseMap = getIdCaseMap(cases);
        List<breg_Account_Affiliation__c> caseAffs = loadCaseAffiliations(caseMap.keySet());
        for (breg_Account_Affiliation__c aff : caseAffs) {
            if (aff.breg_Account__c == null && aff.breg_Contact__c == null) {
                addErrorMessage(
                    caseMap.get(aff.breg_Case__c),
                    null,
                    'One of the related account affiliations has neither Account nor Contact lookup populated'
                );
                continue;
            }
        }
    }

    private static void addRelationToCRA(List<Case> cases) {
        Map<Id, Case> accCRACaseMap = getAccCRACaseMap(cases);
        Map<Id, Case> entityCaseMap = getEntityCaseMap(cases);
        if(accCRACaseMap.isEmpty()) {
            return;
        }
        addEndDateToPreviousCRA(entityCaseMap);
        Date today = Date.today();
        List<breg_Account_Affiliation__c> agentsToInsert = new List<breg_Account_Affiliation__c>();
        for (Id accId : accCRACaseMap.keyset()) {
            breg_Account_Affiliation__c newAgent = new breg_Account_Affiliation__c();
            Case relatedCase = accCRACaseMap.get(accId);
            newAgent.breg_Case__c = relatedCase.Id;
            newAgent.breg_Account__c = accId;
            newAgent.breg_Entity__c = relatedCase.breg_Entity__c;
            newAgent.breg_Role__c = 'Agent';
            newAgent.breg_Start_Date__c = today;
            agentsToInsert.add(newAgent);
        }

        insert agentsToInsert;
    }

    private static void addEndDateToPreviousCRA(Map<Id, Case> entityCaseMap) {
        Date today = Date.today();

        List<breg_Account_Affiliation__c> previousAgents = [
            SELECT Id, breg_Entity__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c IN :entityCaseMap.keyset() AND breg_Role__c = 'Agent' AND (breg_End_Date__c = NULL OR breg_End_Date__c > :today)
        ];
        List<breg_Account_Affiliation__c> agentsToUpdate = new List<breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c agent : previousAgents) {
            agent.breg_Bypass_Validation_Token__c = Datetime.now();
            agent.breg_End_Date__c = entityCaseMap.get(agent.breg_Entity__c).breg_Effective_Date__c;
            agentsToUpdate.add(agent);
        }
        update agentsToUpdate;
    }

    private static Map<Id, Case> getAccCRACaseMap(List<Case> cases) {
        Map<Id, Case> accCRACaseMap = new Map<Id, Case>();
        Map<String, Case> craNameCaseMap = new Map<String, Case>();
        List<String> craEntityNames = new List<String>();
        for (Case c : cases) {
            if (c.breg_Reg_Agent_Has_Changed__c) {
                if (c.breg_Reg_Agent_Entity_Name__c != null) {
                    craEntityNames.add(c.breg_Reg_Agent_Entity_Name__c);
                    craNameCaseMap.put(c.breg_Reg_Agent_Entity_Name__c, c);
                } else if (c.breg_Reg_Agent_First_Name__c != null && c.breg_Reg_Agent_Last_Name__c != null) {
                    String name = c.breg_Reg_Agent_First_Name__c + ' ' + c.breg_Reg_Agent_Last_Name__c;
                    craEntityNames.add(name);
                    craNameCaseMap.put(name, c);
                }
            }
        }
        List<Account> CRAAccs = [SELECT Id, Name, breg_BRIM_CRA_FL__c FROM Account WHERE Name IN :craEntityNames AND breg_BRIM_CRA_FL__c = TRUE];
        for (Account acc : CRAAccs) {
            accCRACaseMap.put(acc.Id, craNameCaseMap.get(acc.Name));
        }
        return accCRACaseMap;
    }

    private static void updateRelatedEntities(List<Case> cases) {
        Map<Id, Case> accCasesMap = getEntityCaseMap(cases);
        BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(accCasesMap, 'Account', getEntityFieldMapping());
    }

    private static Map<Id, Case> getEntityCaseMap(List<Case> cases) {
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            entityCaseMap.put(c.breg_Entity__c, c);
        }
        return entityCaseMap;
    }

    private static Map<Id, Case> getIdCaseMap(List<Case> cases) {
        Map<Id, Case> idCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            idCaseMap.put(c.Id, c);
        }
        return idCaseMap;
    }

    private static Map<SObjectField, SObjectField> getEntityFieldMapping() {
        return new Map<SObjectField, SObjectField>{
            Case.breg_Mailing_Address__CountryCode__s => Account.breg_Mailing_Address__CountryCode__s,
            Case.breg_Mailing_Address__Street__s => Account.breg_Mailing_Address__Street__s,
            Case.breg_Mailing_Address_Number_and_Street_2__c => Account.breg_Mailing_Address_Street_2__c,
            Case.breg_Mailing_Address__StateCode__s => Account.breg_Mailing_Address__StateCode__s,
            Case.breg_Mailing_Address__City__s => Account.breg_Mailing_Address__City__s,
            Case.breg_Mailing_Address__PostalCode__s => Account.breg_Mailing_Address__PostalCode__s,
            Case.breg_Company_Address__CountryCode__s => Account.BillingCountryCode,
            Case.breg_Company_Address__Street__s => Account.BillingStreet,
            Case.breg_Company_Address_Street2__c => Account.breg_Billing_Address_Street_2__c,
            Case.breg_Company_Address__StateCode__s => Account.BillingStateCode,
            Case.breg_Company_Address__City__s => Account.BillingCity,
            Case.breg_Company_Address__PostalCode__s => Account.BillingPostalCode,
            Case.breg_New_Entity_Jurisdiction__c => Account.breg_Formation_Country__c,
            Case.breg_New_Entity_Name__c => Account.Name,
            Case.breg_New_Entity_Type__c => Account.breg_Entity_Type__c
        };
    }

    private static void updateRegAgentAddress(List<Case> cases) {
        List<Case> casesWithChangeAddress = new List<Case>();
        for (Case c : cases) {
            if (c.breg_Reg_Agent_Address_Has_Changed__c) {
                casesWithChangeAddress.add(c);
            }
        }
        if (casesWithChangeAddress.size() > 0) {
            Map<Id, Case> accCasesMap = getEntityCaseMap(casesWithChangeAddress);
            BREGCaseStatusHandlerUtils.updateTargetRecordsFromCaseMap(accCasesMap, 'Account', getCRAAdressFieldMapping());
        }
    }

    private static Map<SObjectField, SObjectField> getCRAAdressFieldMapping() {
        return new Map<SObjectField, SObjectField>{
            Case.breg_Registered_Agent_Address__CountryCode__s => Account.BillingCountryCode,
            Case.breg_Registered_Agent_Address__Street__s => Account.BillingStreet,
            Case.breg_Reg_Agent_Address_Street2__c => Account.breg_Billing_Address_Street_2__c,
            Case.breg_Registered_Agent_Address__StateCode__s => Account.BillingStateCode,
            Case.breg_Registered_Agent_Address__City__s => Account.BillingCity,
            Case.breg_Registered_Agent_Address__PostalCode__s => Account.BillingPostalCode
        };
    }

    public static void updateAffiliations(Map<Id, Case> caseMap) {
        if (caseMap == null || caseMap.isEmpty())
            return;

        Set<Id> entityIds = extractEntityIds(caseMap);
        if (entityIds.isEmpty())
            return;

        List<breg_Account_Affiliation__c> caseAffs = loadCaseAffiliations(caseMap.keySet());

        CaseAffResult classified = classifyCaseAffiliations(caseAffs, caseMap);

        Map<String, breg_Account_Affiliation__c> activeByKey = loadActiveAffiliations(
            entityIds,
            classified.roles,
            classified.accountIds,
            classified.contactIds
        );

        List<breg_Account_Affiliation__c> oldAffToUpdate = matchClosingToActive(classified.closingByKey, activeByKey);

        dmlUpdate(classified.newAffToUpdate, oldAffToUpdate);
    }

    private static Set<Id> extractEntityIds(Map<Id, Case> caseMap) {
        Set<Id> ids = new Set<Id>();
        for (Case c : caseMap.values()) {
            if (c.breg_Entity__c != null)
                ids.add(c.breg_Entity__c);
        }
        return ids;
    }

    private static List<breg_Account_Affiliation__c> loadCaseAffiliations(Set<Id> caseIds) {
        return [
            SELECT Id, breg_Entity__c, breg_Case__c, breg_Account__c, breg_Contact__c, breg_Start_Date__c, breg_End_Date__c, breg_Role__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds
        ];
    }

    private class CaseAffResult {
        List<breg_Account_Affiliation__c> newAffToUpdate;
        Map<String, breg_Account_Affiliation__c> closingByKey;
        Set<String> roles;
        Set<Id> accountIds;
        Set<Id> contactIds;
    }

    private static CaseAffResult classifyCaseAffiliations(List<breg_Account_Affiliation__c> caseAffs, Map<Id, Case> caseMap) {
        CaseAffResult r = new CaseAffResult();
        r.newAffToUpdate = new List<breg_Account_Affiliation__c>();
        r.closingByKey = new Map<String, breg_Account_Affiliation__c>();
        r.roles = new Set<String>();
        r.accountIds = new Set<Id>();
        r.contactIds = new Set<Id>();

        for (breg_Account_Affiliation__c aff : caseAffs) {
            if (aff.breg_End_Date__c == null) {
                Case c = caseMap.get(aff.breg_Case__c);
                aff.breg_Entity__c = c.breg_Entity__c;
                aff.breg_Start_Date__c = c.breg_Effective_Date__c;
                r.newAffToUpdate.add(aff);
                continue;
            }

            r.roles.add(aff.breg_Role__c);
            if (aff.breg_Account__c != null)
                r.accountIds.add(aff.breg_Account__c);
            if (aff.breg_Contact__c != null)
                r.contactIds.add(aff.breg_Contact__c);

            String key = makeKey(aff.breg_Role__c, aff.breg_Account__c, aff.breg_Contact__c);
            if (r.closingByKey.containsKey(key)) {
                System.debug(LoggingLevel.WARN, 'Duplicate affiliation on Case for key=' + key + ' IDs=' + r.closingByKey.get(key).Id + ', ' + aff.Id);
            }
            r.closingByKey.put(key, aff);
        }

        return r;
    }

    private static Map<String, breg_Account_Affiliation__c> loadActiveAffiliations(
        Set<Id> entityIds,
        Set<String> roles,
        Set<Id> accountIds,
        Set<Id> contactIds
    ) {
        if (roles.isEmpty() || (accountIds.isEmpty() && contactIds.isEmpty())) {
            return new Map<String, breg_Account_Affiliation__c>();
        }

        List<breg_Account_Affiliation__c> active = [
            SELECT Id, breg_Entity__c, breg_Account__c, breg_Contact__c, breg_Role__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE
                breg_Entity__c IN :entityIds
                AND breg_Role__c IN :roles
                AND breg_End_Date__c = NULL
                AND breg_Status__c != 'I'
                AND (breg_Account__c IN :accountIds
                OR breg_Contact__c IN :contactIds)
        ];

        Map<String, breg_Account_Affiliation__c> mapByKey = new Map<String, breg_Account_Affiliation__c>();

        for (breg_Account_Affiliation__c aff : active) {
            String key = makeKey(aff.breg_Role__c, aff.breg_Account__c, aff.breg_Contact__c);
            if (mapByKey.containsKey(key)) {
                System.debug(
                    LoggingLevel.WARN,
                    'Duplicate affiliation on entity for key=' + key + ' Existing=' + mapByKey.get(key).Id + ', New=' + aff.Id
                );
            }
            mapByKey.put(key, aff);
        }

        return mapByKey;
    }

    private static List<breg_Account_Affiliation__c> matchClosingToActive(
        Map<String, breg_Account_Affiliation__c> closingByKey,
        Map<String, breg_Account_Affiliation__c> activeByKey
    ) {
        List<breg_Account_Affiliation__c> listToUpdate = new List<breg_Account_Affiliation__c>();

        for (String key : closingByKey.keySet()) {
            breg_Account_Affiliation__c closing = closingByKey.get(key);
            breg_Account_Affiliation__c active = activeByKey.get(key);

            if (active == null) {
                System.debug(LoggingLevel.INFO, 'No active affiliation found for key=' + key + ' ClosingId=' + closing.Id);
                continue;
            }

            active.breg_End_Date__c = closing.breg_End_Date__c;
            listToUpdate.add(active);
        }

        return listToUpdate;
    }

    private static void dmlUpdate(List<breg_Account_Affiliation__c> newAffs, List<breg_Account_Affiliation__c> oldAffs) {
        if (!newAffs.isEmpty())
            update newAffs;
        if (!oldAffs.isEmpty())
            update oldAffs;
    }

    private static String makeKey(String role, Id accountId, Id contactId) {
        return role + '|' + accountId + '|' + contactId;
    }
}