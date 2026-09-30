public with sharing class BREGCaseStatusHandlerConversion extends BREGCaseStatusHandlerBase {
    private static final String CONVERTED_STATUS = 'Converted (9)';
    private static final String MESSAGE_CORRECTIONS_ARE_NOT_ELIGIBLE_FOR_APPROVAL = 'Conversions are not eligible for approval.';
    private static final String MESSAGE_EFFECTIVE_DATE_EMPTY = 'You should set an Effective date';
    private static final String MESSAGE_EFFECTIVE_DATE_IN_FUTURE = 'You can not complete this case before Effective date';

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
        // add specific actions for different statuses
        switch on newStatus {
            when 'Completed' {
                checkEffectiveDate(cases);
            }
            when else {
                // do nothing
            }
        }
    }

    private void checkEffectiveDate(List<Case> cases) {
        Date today = Date.today();
        for (Case c : cases) {
            if (c.breg_Effective_Date__c == null) {
                addErrorMessage(c, 'breg_Effective_Date__c', MESSAGE_EFFECTIVE_DATE_EMPTY);
                continue;
            } else if (c.breg_Effective_Date__c > today) {
                addErrorMessage(c, 'breg_Effective_Date__c', MESSAGE_EFFECTIVE_DATE_IN_FUTURE);
                continue;
            }
        }
    }

    private void performActions(List<Case> cases, String newStatus) {
        // add specific actions for different statuses
        Map<Id, Case> casesMap = new Map<Id, Case>();
         Map<Id, Id> caseToEntityMap = new Map<Id, Id>();
                
        for (Case c : cases) {
            caseToEntityMap.put(c.Id, c.breg_Entity__c);
        }
        List<Case> casesWithFields = getCasesWithFields(caseToEntityMap.keySet());
        for (Case currentCase : casesWithFields) {
            casesMap.put(currentCase.Id, currentCase);
        }
        switch on newStatus {
            when 'Received' {
                createTransactionsForConvertedEntities(casesMap);
            }
            when 'Approved' {
                updateCaseWithAssignmentRules(cases);
            }
            when 'Completed' {
                System.debug('Starting post-completion actions for conversion case status change');
                updateOriginalEntityStatusForCases(cases, CONVERTED_STATUS);
                Map<Id, Id> caseToNewEntityMap = createNewEntities(casesWithFields);
                createTransactionsForNewEntities(casesMap, caseToNewEntityMap);
                updateTNTMSM(caseToEntityMap, caseToNewEntityMap, casesMap); // reassign TNTMSM to new entity, assign new file number, create TNTR/PRTR transactions
                addAgentsToNewEntity(casesWithFields, caseToNewEntityMap); // move agents to new entity
            }
            when 'Rejected' {
            }
            when else {
                // do nothing
            }
        }
    }

    private void createTransactionsForConvertedEntities(Map<Id, Case> casesMap){
         Map<Id, Id> caseToEntityMap = new Map<Id, Id>();
                
        for (Case c : casesMap.values()) {
            caseToEntityMap.put(c.Id, c.breg_Entity__c);
        }

        List<breg_Transaction__c> cvto_transactions = BREGTransactionUtils.upsertTransactionRecords(
            casesMap,
            caseToEntityMap,
            'CVTO',
            'R'
        );
        upsert cvto_transactions;
    }

    private void createTransactionsForNewEntities(Map<Id,Case> casesMap, Map<Id, Id> caseToNewEntityMap){
        List<breg_Transaction__c> cv_transactions = BREGTransactionUtils.upsertTransactionRecords(
            casesMap,
            caseToNewEntityMap,
            'CV',
            'C'
        );

        upsert cv_transactions;
    }

    public static List<Case> updateCaseWithAssignmentRules(List<Case> cases) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.useDefaultRule = true;
        for (Case c : cases) {
            c.setOptions(dmlOpts);
        }
        return cases;
    }

    public static void updateOriginalEntityStatusForCases(List<Case> cases, String newStatus) {
        Map<Id, Case> entityToCaseMap = new Map<Id, Case>();
        List<Account> entitiesToUpdate = new List<Account>();
        Map<Id, Set<String>> accountUpdatedFieldsMap = new Map<Id, Set<String>>();
        for (Case c : cases) {
            entitiesToUpdate.add(new Account(Id = c.breg_Entity__c, breg_Entity_Status__c = newStatus));
            entityToCaseMap.put(c.breg_Entity__c, c);
            accountUpdatedFieldsMap.put(c.breg_Entity__c, new Set<String>{ 'breg_Entity_Status__c' });
        }
        if (!entitiesToUpdate.isEmpty()) {
            BREGCaseStatusHandlerHelper.createBusinessInfoLogsAndUpdate(entitiesToUpdate, accountUpdatedFieldsMap, entityToCaseMap);
        }
    }

    public void updateTNTMSM(Map<Id, Id> caseToEntityMap, Map<Id, Id> caseToNewEntityMap, Map<Id, Case> casesMap) {
        //define TN_TM_SM records to be moved
        Map<Id, Id> entityToCaseMap = new Map<Id, Id>();

        List<breg_TN_TM_SM__c> tntmsmsToMove = getTNTMSMRecordsWithAllFields(caseToEntityMap.values());
        for (Id caseId : caseToEntityMap.keyset()) {
            entityToCaseMap.put(caseToEntityMap.get(caseId), caseId);
        }

        createTransactionsForTNTMSM(tntmsmsToMove, caseToEntityMap, casesMap);
        List<breg_TN_TM_SM__c> tntmsmsToInsert = new List<breg_TN_TM_SM__c>();
        List<breg_TN_TM_SM__c> tntmsmsToUpdate = new List<breg_TN_TM_SM__c>();

        for (breg_TN_TM_SM__c tn : tntmsmsToMove) {
            Id caseId = entityToCaseMap.get(tn.breg_Account__c);
            Case currentCase = casesMap.get(caseId);
            breg_TN_TM_SM__c newTntmsm = tn.clone(false, true, false, false);
            newTntmsm.breg_Account__c = caseToNewEntityMap.get(caseId);
            newTntmsm.breg_File__c = currentCase.breg_File__c;
            newTntmsm.breg_File_Suffix__c = currentCase.breg_File_Suffix__c;
            newTntmsm.Id = null;
            newTntmsm.breg_Start_Date__c = currentCase.breg_Effective_Date__c;
            tntmsmsToInsert.add(newTntmsm);

            if (tn.breg_End_Date__c == null) {
                tn.breg_End_Date__c = currentCase.breg_Effective_Date__c;
                tntmsmsToUpdate.add(tn);
            }
        }
        update tntmsmsToUpdate;
        insert tntmsmsToInsert;
    }

    private static void createTransactionsForTNTMSM(
        List<breg_TN_TM_SM__c> tntmsmsToMove,
        Map<Id, Id> caseToEntityMap,
        Map<Id, Case> casesMap
    ) {
        List<String> tntmsmTypes = new List<String>{ 'Trade Name', 'Trademark', 'Service Mark' };
        Map<Id, Id> caseTntmsmMap = new Map<Id, Id>();
        Map<Id, Id> casePrMap = new Map<Id, Id>();
        Map<Id, Id> entityToCaseMap = new Map<Id, Id>();
        for (Id caseId : caseToEntityMap.keySet()) {
            entityToCaseMap.put(caseToEntityMap.get(caseId), caseId);
        }

        for (breg_TN_TM_SM__c tn : tntmsmsToMove) {
            if (tntmsmTypes.contains(tn.breg_Type__c)) {
                caseTntmsmMap.put(entityToCaseMap.get(tn.breg_Account__c), tn.Id);
            } else if (tn.breg_Type__c == 'Publicity Rights Name') {
                casePrMap.put(entityToCaseMap.get(tn.breg_Account__c), tn.Id);
            }
        }

        List<breg_Transaction__c> tntr_transactions = BREGTransactionUtils.upsertTransactionRecords(casesMap, caseTntmsmMap, 'TNTR', 'R');
        List<breg_Transaction__c> prtr_transactions = BREGTransactionUtils.upsertTransactionRecords(casesMap, casePrMap, 'PRTR', 'R');
        List<breg_Transaction__c> all_transactions = new List<breg_Transaction__c>();
        all_transactions.addAll(tntr_transactions);
        all_transactions.addAll(prtr_transactions);
        upsert all_transactions;
    }

    public static Map<Id, Id> createNewEntities(List<Case> cases) {
        Map<Id, Id> caseToNewEntityMap = new Map<Id, Id>();
        List<Account> newEntities = new List<Account>();
        Map<Id, Case> accIdToCaseMap = new Map<Id, Case>();
        Map<String, Case> accNameToCaseMap = new Map<String, Case>();
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        for (Case c : cases) {
            String countryOrState = BREGUtils.mapJurisdictionToPicklists(c.breg_New_Entity_Jurisdiction__c);
            BREGFileNumberAssignmentController.FileNumberAssignmentResult generatedResult = BREGFileNumberAssignmentController.generateFileNumber(
                null,
                c.breg_New_Entity_Type__c
            );
            Account newEntity = new Account(
                Name = c.breg_New_Entity_Name__c,
                breg_File__c = generatedResult.fileNumber,
                breg_File_Suffix__c = generatedResult.fileSuffix,
                breg_Entity_Status__c = 'Active (A)',
                BillingCity = c.breg_Company_Address__City__s,
                breg_Billing_Address_Street_2__c = c.breg_Company_Address_Street2__c,
                BillingStreet = c.breg_Company_Address__Street__s,
                BillingStateCode = c.breg_Company_Address__StateCode__s,
                breg_Billing_Address_State_Text__c = c.breg_Company_Address_State__c,
                BillingPostalCode = c.breg_Company_Address__PostalCode__s,
                BillingCountryCode = c.breg_Company_Address__CountryCode__s,
                RecordTypeId = bregAccRecordType,
                breg_Entity_Type__c = c.breg_New_Entity_Type__c,
                breg_Creator__c = c.CreatedById,
                breg_Incorporation_Date__c = c.breg_Effective_Date_Time__c?.date(),
                breg_Good_Standing__c = true,
                breg_Subscribe_Owner_Free_Email_Alerts__c = c.breg_Subscribe_Owner_Free_Email_Alerts__c
            );
            if (countryOrState == 'State') {
                newEntity.breg_Formation_State__c = c.breg_New_Entity_Jurisdiction__c;
            } else if (countryOrState == 'Country') {
                newEntity.breg_Formation_Country__c = c.breg_New_Entity_Jurisdiction__c;
            }
            accNameToCaseMap.put(c.breg_New_Entity_Name__c, c);
            newEntities.add(newEntity);
        }
        insert newEntities;
        for (Account acc : newEntities) {
            accIdToCaseMap.put(acc.Id, accNameToCaseMap.get(acc.Name));
            caseToNewEntityMap.put(accNameToCaseMap.get(acc.Name)?.Id, acc.Id);
        }
        BREGTransactionUtils.createTransBusinessInfoRecords(newEntities, accIdToCaseMap);

        return caseToNewEntityMap;
    }

    private List<Case> getCasesWithFields(Set<Id> caseIds) {
        return [
            SELECT
                Id,
                breg_Form_Code__c,
                breg_New_Entity_Name__c,
                breg_New_Entity_Jurisdiction__c,
                breg_New_Entity_Type__c,
                breg_Effective_Date_Time__c,
                breg_Subscribe_Owner_Free_Email_Alerts__c,
                breg_File_Suffix__c,
                breg_File__c,
                breg_Effective_Date__c,
                breg_Entity__c,
                breg_Company_Address__City__s,
                breg_Company_Address__Street__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__StateCode__s,
                breg_Company_Address_State__c,
                breg_Company_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                CreatedById,
                breg_Form_Configuration__c,
                breg_TN_TM_SM__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Id IN :caseIds
        ];
    }

    private List<breg_TN_TM_SM__c> getTNTMSMRecordsWithAllFields(List<Id> entityIds) {
        return [
            SELECT
                Id,
                Name,
                OwnerId,
                CreatedDate,
                CreatedById,
                LastModifiedDate,
                LastModifiedById,
                SystemModstamp,
                breg_Account__c,
                breg_Account_Name__c,
                breg_Additional_Entity_States__c,
                breg_Applicant_Name__c,
                breg_BRIM_TRADE_MARK_ID__c,
                breg_Cancellation_Date__c,
                breg_Cert_Date__c,
                breg_Cert_Number__c,
                breg_Certificate__c,
                breg_Consent__c,
                breg_Descriptors__c,
                breg_Details__c,
                breg_DocuSign_Envelope_Document__c,
                breg_End_Date__c,
                breg_End_Date_Active__c,
                breg_Entity_Nature_Of_Business__c,
                breg_Expiration_Date__c,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Has_Pending_Renewal__c,
                breg_Is_Active__c,
                breg_Last_Renewal_Case__c,
                breg_Last_Renewal_Submission_Date__c,
                breg_Mailing_Address__c,
                breg_Notes__c,
                breg_Registrant_Address__c,
                breg_Registrant_First_Name__c,
                breg_Registrant_Last_Name__c,
                breg_Registrant_Name__c,
                breg_Registrant_Type__c,
                breg_Registration_Date__c,
                breg_Registration_Type__c,
                breg_Similar_Name__c,
                breg_Start_Date__c,
                breg_Status__c,
                breg_Status_Preview__c,
                breg_Status_Preview_Date__c,
                breg_Status_Preview_Reason__c,
                breg_Subscribe_Owner_Free_Email_Alerts__c,
                breg_TM_SM_Category__c,
                breg_Trade_Name__c,
                breg_Trade_Type__c,
                breg_Transaction__c,
                breg_Type__c,
                breg_XREF_Name1__c,
                breg_XREF_Name2__c,
                Pending_Transaction__c
            FROM breg_TN_TM_SM__c
            WHERE breg_Account__c IN :entityIds
        ];
    }

    private void addAgentsToNewEntity(List<Case> cases, Map<Id, Id> caseToNewEntityMap) {
        List<SObject> toUpdate = new List<SObject>();
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id bregContactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BREG_Contact').getRecordTypeId();
        Map<Id, Account> affiliationAccountMap = new Map<Id, Account>();
        Map<Id, Contact> affiliationContactMap = new Map<Id, Contact>();
        List<Account> accountsToCreate = new List<Account>();
        List<Contact> contactsToCreate = new List<Contact>();
        Map<Id, Case> casesMap = new Map<Id, Case>(cases);
        List<breg_Account_Affiliation__c> agentsToUpdate = [
            SELECT
                Id,
                breg_Account__c,
                breg_Contact__c,
                breg_Case__c,
                breg_Entity__c,
                breg_Address__Street__s,
                breg_Address_Street_2__c,
                breg_Address__City__s,
                breg_Address__StateCode__s,
                breg_Address__PostalCode__s,
                breg_Address__CountryCode__s,
                breg_First_Name__c,
                breg_Last_Name__c,
                breg_Type__c,
                breg_To_Remove__c,
                breg_Entity_Name__c,
                breg_Role__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :cases
        ];

        for (breg_Account_Affiliation__c aff : agentsToUpdate) {
            Id newEntityId = caseToNewEntityMap.get(aff.breg_Case__c);
            Case cs = casesMap.get(aff.breg_Case__c);
            if (aff.breg_Contact__c == null && aff.breg_Account__c == null) {
                if (aff.breg_Type__c == 'Individual') {
                    Contact newContact = new Contact(
                        FirstName = aff.breg_First_Name__c,
                        LastName = aff.breg_Last_Name__c,
                        MailingStreet = aff.breg_Address__Street__s,
                        breg_Mailing_Address_Street_2__c = aff.breg_Address_Street_2__c,
                        MailingCity = aff.breg_Address__City__s,
                        MailingStateCode = aff.breg_Address__StateCode__s,
                        MailingPostalCode = aff.breg_Address__PostalCode__s,
                        MailingCountryCode = aff.breg_Address__CountryCode__s,
                        RecordTypeId = bregContactRecordTypeId
                    );
                    contactsToCreate.add(newContact);
                    affiliationContactMap.put(aff.Id, newContact);
                } else if (aff.breg_Type__c == 'Entity') {
                    Account newAccount = new Account(
                        Name = aff.breg_Entity_Name__c,
                        BillingStreet = aff.breg_Address__Street__s,
                        breg_Billing_Address_Street_2__c = aff.breg_Address_Street_2__c,
                        BillingCity = aff.breg_Address__City__s,
                        BillingStateCode = aff.breg_Address__StateCode__s,
                        BillingPostalCode = aff.breg_Address__PostalCode__s,
                        BillingCountryCode = aff.breg_Address__CountryCode__s,
                        RecordTypeId = bregAccountRecordTypeId
                    );
                    accountsToCreate.add(newAccount);
                    affiliationAccountMap.put(aff.Id, newAccount);
                }
            }
            aff.breg_Entity__c = newEntityId;
            aff.breg_Start_Date__c = cs?.breg_Effective_Date__c;
            aff.breg_Status__c = 'A';
        }

        if (!contactsToCreate.isEmpty()) {
            insert contactsToCreate;
            // Update affiliations with new Contact IDs
            for (breg_Account_Affiliation__c aff : agentsToUpdate) {
                if (aff.breg_Account__c == null) {
                    aff.breg_Contact__c = affiliationContactMap.get(aff.Id)?.Id;
                }
            }
        }

        if (!accountsToCreate.isEmpty()) {
            insert accountsToCreate;
            // Update affiliations with new Account IDs
            for (breg_Account_Affiliation__c aff : agentsToUpdate) {
                if (aff.breg_Contact__c == null) {
                    aff.breg_Account__c = affiliationAccountMap.get(aff.Id)?.Id;
                }
            }
        }

        update agentsToUpdate;
    }
}