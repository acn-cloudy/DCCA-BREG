/**
 * Handler for the TNTMSM Assignment form (T-4)
 */
public with sharing class BREGCaseStatusHandlerTNTMSMAssignment extends BREGCaseStatusHandlerBase {
    public static final String ERROR_TNTMSM_LOOKUP_REQUIRED = 'The TN/TM/SM lookup must be populated before approving this case.';
    public static final String ERROR_TNTMSM_CERTIFICATE_REQUIRED = 'The TN/TM/SM Certificate field must be populated before approving this case.';
    public static final String ERROR_TNTMSM_TYPE_REQUIRED = 'The TN/TM/SM Type field must be populated before approving this case.';
    public static final String ERROR_ASSIGNOR_ACCOUNT_OR_CONTACT_REQUIRED = 'Account affiliation with role Assignor must have either an account or contact populated before approving this case.';

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
                checkForTNTMSMPopulation(cases);
         }
         when else {
                // do nothing
         }
     }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        switch on newStatus {
            when 'Received' {
                updateApplicantRolesToAssignor(cases);
            }
            when 'Approved' {
                updateOwnership(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void checkForTNTMSMPopulation(List<Case> cases) {
        for (Case c : cases) {
            if (c.breg_TN_TM_SM__c == null) {
                addErrorMessage(c, 'breg_TN_TM_SM__c', ERROR_TNTMSM_LOOKUP_REQUIRED);
                continue;
            }
            if (c.breg_TNTMSM_Certificate__c == null) {
                addErrorMessage(c, 'breg_TNTMSM_Certificate__c', ERROR_TNTMSM_CERTIFICATE_REQUIRED);
                continue;
            }
            if (c.breg_TNTMSM_Type__c == null) {
                addErrorMessage(c, 'breg_TNTMSM_Type__c', ERROR_TNTMSM_TYPE_REQUIRED);
                continue;
            }
            
            List<breg_Account_Affiliation__c> affiliations = [
                SELECT Id, breg_Account__c, breg_Contact__c
                FROM breg_Account_Affiliation__c
                WHERE breg_Case__c = :c.Id AND breg_Role__c = 'Assignor'
                
            ];
            for (breg_Account_Affiliation__c affiliation : affiliations) {
                if (affiliation.breg_Account__c == null && affiliation.breg_Contact__c == null) {
                    addErrorMessage(c, null, ERROR_ASSIGNOR_ACCOUNT_OR_CONTACT_REQUIRED);
                    continue;
                }
            }
        }
    }

    private void updateApplicantRolesToAssignor(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        if (caseIds.isEmpty()) {
            return;
        }

        List<String> quotedIds = new List<String>();
        for (Id recordId : caseIds) {
            quotedIds.add('\'' + String.escapeSingleQuotes(String.valueOf(recordId)) + '\'');
        }

        BREGSObjectUpdaterWithoutSharing.updateRecordsByQuery(
            'SELECT Id FROM breg_Account_Affiliation__c WHERE breg_Case__c IN (' + String.join(quotedIds, ',') + ') AND breg_Role__c = \'Applicant\'',
            new Map<String, Object>{ 'breg_Role__c' => 'Assignor' }
        );
    }

    private void updateOwnership(List<Case> cases) {
        Set<Id> caseIds = getCaseIds(cases);
        Set<Id> entityIds = getEntityIds(cases);
        Map<Id, Account> accountsMap = getAccountsByIds(entityIds);
        Map<Id, List<breg_Account_Affiliation__c>> caseIdToAccAffsMap = getCaseIdToAccAffsMap(caseIds);
        Map<Id, breg_TN_TM_SM__c> caseIdToTNTMSMMap = getCaseIdToTNTMSMMap(cases);
        List<Account> accountsToUpsert = new List<Account>();
        List<Account> accountsToUpdate = new List<Account>();
        List<Account> accountsToInsert = new List<Account>();
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        List<breg_TN_TM_SM__c> tnTmSmsToUpdate = new List<breg_TN_TM_SM__c>();
        List<Case> casesToUpdate = new List<Case>();
        Map<Integer, breg_TN_TM_SM__c> accountIndexToTnTmSmMap = new Map<Integer, breg_TN_TM_SM__c>();
        Map<Integer, Case> accountIndexToCaseMap = new Map<Integer, Case>();

        deactivateOldestActiveApplicantAffiliations(cases, caseIdToTNTMSMMap);

        for (Case c : cases) {
            breg_TN_TM_SM__c tnTmSm = caseIdToTNTMSMMap.get(c.Id);
            entityToCaseMap.put(c.breg_Entity__c, c);
            if (tnTmSm != null) {
                if (c.breg_Entity__c != null) {
                    if (tnTmSm.breg_Account__c != null) {
                        Account oldAccount = new Account();
                        oldAccount.Id = tnTmSm.breg_Account__c;
                        oldAccount.breg_End_Date__c = c.breg_Effective_Date__c;
                        accountUpdatedFieldsMap.put(tnTmSm.breg_Account__c, new Set<String>{ 'breg_End_Date__c' });
                        accountsToUpdate.add(oldAccount);
                    }

                    Account newAccount = new Account();
                    newAccount.Id = c.breg_Entity__c;
                    newAccount.breg_Start_Date__c = c.breg_Effective_Date__c;
                    accountsToInsert.add(newAccount);
                    tnTmSm.breg_Account__c = c.breg_Entity__c;
                    tnTmSm.breg_File__c = accountsMap.get(c.breg_Entity__c)?.breg_File__c;
                    tnTmSm.breg_File_Suffix__c = accountsMap.get(c.breg_Entity__c)?.breg_File_Suffix__c;
                    tnTmSmsToUpdate.add(tnTmSm);
                } else {
                    List<breg_Account_Affiliation__c> accAffs = caseIdToAccAffsMap.containsKey(c.Id)
                        ? caseIdToAccAffsMap.get(c.Id)
                        : new List<breg_Account_Affiliation__c>();
                    for (breg_Account_Affiliation__c accAff : accAffs) {
                        if (accAff.breg_Role__c == 'Applicant') {
                            Account newAccount = new Account();
                            Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                                .get('BREG_Account')
                                .getRecordTypeId();
                            newAccount.RecordTypeId = bregAccountRecordTypeId;
                            if (accAff.breg_Type__c == 'Entity') {
                                newAccount.Name = accAff.breg_Entity_Name__c;
                                newAccount.breg_Registrant_Type__c = 'Entity';
                                newAccount.breg_Entity_Type_Description__c = accAff.breg_Entity_Type_Description__c;
                                newAccount.breg_Formation_State__c = accAff.breg_Entity_Location__c;
                                newAccount.breg_Formation_Country__c = accAff.breg_Entity_Location_Country__c;
                            } else if (accAff.breg_Type__c == 'Individual') {
                                newAccount.breg_Registrant_Type__c = 'Individual';
                                newAccount.Name = accAff.breg_First_Name__c + ' ' + accAff.breg_Last_Name__c;
                                
                            }
                            newAccount.breg_File__c = c.breg_File__c;
                            newAccount.breg_File_Suffix__c = c.breg_File_Suffix__c ?? 'ZZ';
                            newAccount.breg_Entity_Type__c = 'ZZ';
                            newAccount.BillingCountryCode = accAff.breg_Address__CountryCode__s;
                            newAccount.BillingStreet = accAff.breg_Address__Street__s;
                            newAccount.BillingCity = accAff.breg_Address__City__s;
                            newAccount.BillingStateCode = accAff.breg_Address__StateCode__s;
                            newAccount.BillingPostalCode = accAff.breg_Address__PostalCode__s;
                            newAccount.breg_Billing_Address_Street_2__c = accAff.breg_Address_Street_2__c;
                            newAccount.breg_Start_Date__c = c.breg_Effective_Date__c;

                            if (tnTmSm.breg_Account__c != null) {
                                Account oldAccount = new Account();
                                oldAccount.Id = tnTmSm.breg_Account__c;
                                oldAccount.breg_End_Date__c = c.breg_Effective_Date__c;
                                accountsToUpsert.add(oldAccount);
                            }

                            accountsToInsert.add(newAccount);

                            // Track the index of the new account (will be inserted) and its corresponding TN/TM/SM record
                            accountIndexToTnTmSmMap.put(accountsToInsert.size() - 1, tnTmSm);
                            accountIndexToCaseMap.put(accountsToInsert.size() - 1, c);
                        }
                    }
                }
            }
        }

        if (!accountsToInsert.isEmpty()) {
            upsert accountsToInsert;
            Map<Id, Case> accIdToCaseMap = new Map<Id, Case>();
            // After insert, assign the newly created Account Ids to their corresponding TN/TM/SM records
            for (Integer accountIndex : accountIndexToTnTmSmMap.keySet()) {
                breg_TN_TM_SM__c tnTmSm = accountIndexToTnTmSmMap.get(accountIndex);
                Account newAcc = accountsToInsert.get(accountIndex);
                tnTmSm.breg_Account__c = newAcc.Id;
                tnTmSm.breg_File__c = newAcc.breg_File__c;
                tnTmSm.breg_File_Suffix__c = newAcc.breg_File_Suffix__c;
                tnTmSmsToUpdate.add(tnTmSm);
            }

            // After upsert, assign the newly created Account Ids to their corresponding case records
            for (Integer accountIndex : accountIndexToCaseMap.keySet()) {
                Case caseRecord = new Case();
                caseRecord.Id = accountIndexToCaseMap.get(accountIndex).Id;
                caseRecord.breg_Entity__c = accountsToInsert.get(accountIndex).Id;
                casesToUpdate.add(caseRecord);
                accIdToCaseMap.put(accountsToInsert.get(accountIndex).Id, accountIndexToCaseMap.get(accountIndex));
            }
            BREGTransactionUtils.createTransBusinessInfoRecords(accountsToInsert, accIdToCaseMap);
        }

        if (!tnTmSmsToUpdate.isEmpty()) {
            update tnTmSmsToUpdate;
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    private void deactivateOldestActiveApplicantAffiliations(List<Case> cases, Map<Id, breg_TN_TM_SM__c> caseIdToTNTMSMMap) {
        Set<Id> caseIds = getCaseIds(cases);
        Map<Id, Date> tnTmSmIdToEffectiveDateMap = new Map<Id, Date>();

        for (Case c : cases) {
            Id tnTmSmId = caseIdToTNTMSMMap.get(c.Id)?.Id;
            if (tnTmSmId != null && c.breg_Effective_Date__c != null) {
                tnTmSmIdToEffectiveDateMap.put(tnTmSmId, c.breg_Effective_Date__c);
            }
        }

        if (tnTmSmIdToEffectiveDateMap.isEmpty()) {
            return;
        }

        List<breg_Account_Affiliation__c> affiliationsToDeactivate = [
            SELECT Id, breg_Case__c, breg_TN_TM_SM__c, breg_Status__c, breg_End_Date__c, CreatedDate
            FROM breg_Account_Affiliation__c
            WHERE
                breg_TN_TM_SM__c IN :tnTmSmIdToEffectiveDateMap.keySet()
                AND breg_Role__c = 'Applicant'
                AND breg_End_Date__c = NULL
                AND breg_Status__c != 'I'
                AND (breg_Case__c = NULL OR breg_Case__c NOT IN :caseIds)
            ORDER BY breg_TN_TM_SM__c ASC, CreatedDate ASC
        ];

        Set<Id> handledTnTmSmIds = new Set<Id>();
        List<breg_Account_Affiliation__c> recordsToUpdate = new List<breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c affiliation : affiliationsToDeactivate) {
            if (handledTnTmSmIds.contains(affiliation.breg_TN_TM_SM__c)) {
                continue;
            }
            handledTnTmSmIds.add(affiliation.breg_TN_TM_SM__c);
            affiliation.breg_Status__c = 'I';
            affiliation.breg_End_Date__c = tnTmSmIdToEffectiveDateMap.get(affiliation.breg_TN_TM_SM__c);
            affiliation.breg_Bypass_Validation_Token__c = Datetime.now();
            recordsToUpdate.add(affiliation);
        }

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }

    private Set<Id> getTNTMSMIds(List<Case> cases) {
        Set<Id> ids = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_TN_TM_SM__c != null) {
                ids.add(c.breg_TN_TM_SM__c);
            }
        }
        return ids;
    }

    private Map<Id, breg_TN_TM_SM__c> getCaseIdToTNTMSMMap(List<Case> cases) {
        Map<Id, breg_TN_TM_SM__c> caseIdToTNTMSMMap = new Map<Id, breg_TN_TM_SM__c>();
        Set<Id> tnTmSmsIds = getTNTMSMIds(cases);
        Map<Id, breg_TN_TM_SM__c> tnTmSmsMap = new Map<Id, breg_TN_TM_SM__c>(
            [
                SELECT Id, breg_Account__c
                FROM breg_TN_TM_SM__c
                WHERE Id IN :tnTmSmsIds
            ]
        );

        for (Case c : cases) {
            if (tnTmSmsMap.containsKey(c.breg_TN_TM_SM__c)) {
                caseIdToTNTMSMMap.put(c.Id, tnTmSmsMap.get(c.breg_TN_TM_SM__c));
            }
        }
        return caseIdToTNTMSMMap;
    }

    private Map<Id, List<breg_Account_Affiliation__c>> getCaseIdToAccAffsMap(Set<Id> caseIds) {
        Map<Id, List<breg_Account_Affiliation__c>> caseIdToAccAffsMap = new Map<Id, List<breg_Account_Affiliation__c>>();

        List<breg_Account_Affiliation__c> accAffs = [
            SELECT
                Id,
                breg_Type__c,
                breg_Entity_Name__c,
                breg_Entity_Location__c,
                breg_Entity_Location_Country__c,
                breg_File__c,
                breg_Entity_Type__c,
                breg_Entity_Type_Description__c,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Address__CountryCode__s,
                breg_Address__Street__s,
                breg_Address_Street_2__c,
                breg_Address__StateCode__s,
                breg_Address_State_Text__c,
                breg_Address__City__s,
                breg_Address__PostalCode__s,
                breg_Role__c,
                breg_Case__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :caseIds
        ];

        for (breg_Account_Affiliation__c accAff : accAffs) {
            if (!caseIdToAccAffsMap.containsKey(accAff.breg_Case__c)) {
                caseIdToAccAffsMap.put(accAff.breg_Case__c, new List<breg_Account_Affiliation__c>());
            }
            caseIdToAccAffsMap.get(accAff.breg_Case__c).add(accAff);
        }
        return caseIdToAccAffsMap;
    }

    private Set<id> getEntityIds(List<Case> cases) {
        Set<Id> entityIds = new Set<Id>();
        for (Case c : cases) {
            if (c.breg_Entity__c != null) {
                entityIds.add(c.breg_Entity__c);
            }
        }
        return entityIds;
    }

    private Map<Id, Account> getAccountsByIds(Set<Id> accountIds) {
        Map<Id, Account> accountsMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name, breg_File__c, breg_File_Suffix__c
                FROM Account
                WHERE Id IN :accountIds
            ]) {
                accountsMap.put(acc.Id, acc);
            }
        }
        return accountsMap;
    }
}