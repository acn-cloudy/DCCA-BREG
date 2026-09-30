// when annual is auto approved, this class can be invoked by portal or guest user by BREGCaseStatusHandlerAnnuals.cls, hence the inherited sharing
public inherited sharing class BREGCaseStatusHandlerHelper {
    private static final Set<String> corporationEntityTypes = new Set<String>{
        'D1',
        'D2',
        'D9',
        'F1',
        'F2',
        'P1',
        'Profit Corporation',
        'Nonprofit Corporation',
        'Corporation'
    };
    private static final Set<String> partnershipEntityTypes = new Set<String>{
        'G5',
        'G6',
        'Q5',
        'L5',
        'Q6',
        'L6',
        'Partnership',
        'General Partnership',
        'Limited Partnership',
        'Limited Liability Limited Partnership'
    };
    private static final Set<String> llcEntityTypes = new Set<String>{'C5', 'C6', 'Limited Liability Company'};
    private static final Set<String> llpEntityTypes = new Set<String>{'K5', 'K6', 'Limited Liability Partnership'};
    private static final Set<String> unincAssociationEntityTypes = new Set<String>{'Unincorporated Association'};
    private static final Set<String> MANAGED_MEMBER_ROLES = new Set<String>{
        'Agent',
        'Member',
        'Officer',
        'Director',
        'Manager',
        'Partner'
    };

    public static void populateEntityRelatedFields(List<breg_Account_Affiliation__c> affiliations) {
        populateEntityRelatedFields(affiliations, null);
    }

    public static void populateEntityRelatedFields(
        List<breg_Account_Affiliation__c> affiliations,
        Map<Id, breg_Account_Affiliation__c> oldMap
    ) {
        if (affiliations == null || affiliations.isEmpty()) {
            return;
        }

        List<breg_Account_Affiliation__c> affiliationsWithAccountUpdate = new List<breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            breg_Account_Affiliation__c oldAffiliation = oldMap != null ? oldMap.get(affiliation.Id) : null;
            Boolean accountChanged = oldAffiliation == null || oldAffiliation.breg_Account__c != affiliation.breg_Account__c;
            if (!accountChanged) {
                continue;
            }

            if (affiliation.breg_Account__c != null) {
                affiliationsWithAccountUpdate.add(affiliation);
            } 
        }

        if (affiliationsWithAccountUpdate.isEmpty()) {
            return;
        }

        Set<Id> entityIds = new Set<Id>();
        for (breg_Account_Affiliation__c affiliation : affiliationsWithAccountUpdate) {
            entityIds.add(affiliation.breg_Account__c);
        }

        Map<Id, Account> entityMap = new Map<Id, Account>([
            SELECT
                Id,
                Name,
                breg_Entity_Type__c,
                breg_Formation_Country__c,
                breg_Formation_State__c,
                breg_Formation_State_Label__c,
                breg_Formation_Country_Label__c,
                breg_Entity_Type_Description__c,
                breg_File_Suffix__c,
                breg_File__c,
                breg_Authorized_Shares_Count__c
            FROM Account
            WHERE Id IN :entityIds
        ]);

        for (breg_Account_Affiliation__c affiliation : affiliationsWithAccountUpdate) {
            Account entity = entityMap.get(affiliation.breg_Account__c);
            if (entity == null) {
                clearEntityRelatedFields(affiliation);
                continue;
            }
            populateAffiliationEntityFieldsFromEntity(affiliation, entity);
           
        }
    }

    public static void populateAffiliationEntityFieldsFromEntity(breg_Account_Affiliation__c affiliation, Account entity){
         String entityLocation = '';
        if (entity.breg_Formation_Country__c != null) {
            entityLocation = entity.breg_Formation_Country_Label__c == null ? 
                entity.breg_Formation_Country__c : 
                entity.breg_Formation_Country_Label__c;
        }
        if (entity.breg_Formation_State__c != null) {
            if (entityLocation != '') {
                entityLocation += ', ';
            }
            entityLocation += entity.breg_Formation_State_Label__c == null ? 
                entity.breg_Formation_State__c : 
                entity.breg_Formation_State_Label__c;
        }

        affiliation.breg_Entity_Name__c = entity.Name;
        affiliation.breg_Entity_Type__c = entity.breg_Entity_Type__c != null ? getGeneralEntityType(entity.breg_Entity_Type__c) : affiliation.breg_Entity_Type__c;
        affiliation.breg_Entity_Type_Description__c = entity.breg_Entity_Type_Description__c != null
            ? entity.breg_Entity_Type_Description__c
            : entity.breg_Entity_Type__c != null ? entity.breg_Entity_Type__c : affiliation.breg_Entity_Type_Description__c;
            
        affiliation.breg_Suffix__c = entity.breg_File_Suffix__c != null ? entity.breg_File_Suffix__c : affiliation.breg_Suffix__c;
        affiliation.breg_File__c = entity.breg_File__c != null ? entity.breg_File__c : affiliation.breg_File__c;
        affiliation.breg_Number_of_shares__c = entity.breg_Authorized_Shares_Count__c != null ? entity.breg_Authorized_Shares_Count__c : affiliation.breg_Number_of_shares__c;
        affiliation.breg_Entity_Location__c = affiliation.breg_Entity_Location__c != null ? affiliation.breg_Entity_Location__c : entityLocation;
    }

    @TestVisible
    public static String getGeneralEntityType(String entityType) {
        if (corporationEntityTypes.contains(entityType)) {
            return 'Corporation';
        } else if (partnershipEntityTypes.contains(entityType)) {
            return 'Partnership';
        } else if (llcEntityTypes.contains(entityType)) {
            return 'Limited Liability Company';
        } else if (llpEntityTypes.contains(entityType)) {
            return 'Limited Liability Partnership';
        } else if (unincAssociationEntityTypes.contains(entityType)) {
            return 'Unincorporated Association';
        } else {
            return 'Other';
        }
    }

    public static void updateMemberAddressesFromAffiliations(Map<Id, Case> memberCaseMap, List<Case> cases) {
        updateMemberAddressesFromAffiliations(memberCaseMap, cases, true);
    }

    public static void updateMemberAddressesFromAffiliations(Map<Id, Case> memberCaseMap, List<Case> cases, Boolean createTransactions) {
        Set<Id> memberIds = memberCaseMap.keySet();
        Map<Id, Case> entityCases = new Map<Id, Case>();
        for (Case c : memberCaseMap.values()) {
            if (c.breg_Entity__c != null) {
                entityCases.put(c.breg_Entity__c, c);
            }
        }
        Map<Id, Case> caseMap = new Map<Id, Case>();

        for (Case c : cases) {
            caseMap.put(c.Id, c);
        }
        if (caseMap.isEmpty()) {
            return;
        }

        List<breg_Account_Affiliation__c> affiliations = [
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
                breg_Entity_Type__c,
                breg_Entity_Type_Description__c,
                breg_Suffix__c,
                breg_File__c,
                breg_Number_of_shares__c,
                breg_Entity_Location__c,
                breg_Entity_Location_Country__c,
                breg_Role__c,
                breg_Bypass_Validation_Token__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Case__c IN :cases
        ];

        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (Id id : memberIds) {
            Schema.SObjectType type = id.getSObjectType();
            if (type == Account.SObjectType) {
                accountIds.add(id);
            } else if (type == Contact.SObjectType) {
                contactIds.add(id);
            }
        }
       for (breg_Account_Affiliation__c aff : affiliations) {
            if (aff.breg_Account__c != null) {
                accountIds.add(aff.breg_Account__c);
            } else if (aff.breg_Contact__c != null) {
                contactIds.add(aff.breg_Contact__c);
            }
        }

        // Query current member records. Addresses are no longer written back to the member
        // Account/Contact, so only the name fields used for the managed-role checks are needed.
        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountMap = new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :accountIds]);
        }

        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactMap = new Map<Id, Contact>([SELECT Id, FirstName, LastName FROM Contact WHERE Id IN :contactIds]);
        }

        // Previously filed (still active) affiliations of the same entities, keyed by
        // entity + linked Account/Contact + role. Address changes are detected against
        // these rather than against the member Account/Contact record. The entity set covers
        // both lookup paths below (entityCases, and the caseMap fallback).
        Set<Id> previousAffiliationEntityIds = new Set<Id>(entityCases.keySet());
        for (Case c : caseMap.values()) {
            if (c.breg_Entity__c != null) {
                previousAffiliationEntityIds.add(c.breg_Entity__c);
            }
        }
        Map<String, breg_Account_Affiliation__c> previousAffiliationMap = getPreviousAffiliationMap(previousAffiliationEntityIds, caseMap.keySet());
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id bregContactRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('BREG_Contact').getRecordTypeId();

        Map<Id, Account> affiliationAccountMap = new Map<Id, Account>();
        Map<Id, Contact> affiliationContactMap = new Map<Id, Contact>();
        List<Account> accountsToCreate = new List<Account>();
        List<Contact> contactsToCreate = new List<Contact>();
        Set<Id> processedAccountIds = new Set<Id>(); // To Deactivate unused account afiliations
        Set<Id> processedContactIds = new Set<Id>(); // To Deactivate unused contact afiliations

        // Collections to track account affiliations that will change (existing vs new)
        List<breg_Account_Affiliation__c> existingAccountAffiliationsChanged = new List<breg_Account_Affiliation__c>();
        Map<Id, Case> accountIdToCaseMapForTrans = new Map<Id, Case>();
        Map<Id, Id> caseIdToAffiliationIdForTrans = new Map<Id, Id>();

        for (breg_Account_Affiliation__c aff : affiliations) {
            Id targetId;
            Schema.SObjectType type;
            Case cs = entityCases.get(aff.breg_Entity__c) ?? caseMap.get(aff.breg_Case__c);
            aff.breg_Bypass_Validation_Token__c = Datetime.now();
            if (cs == null) {
                continue;
            }
            // if (cs.Id != aff.breg_Case__c) {
            //     aff.breg_End_Date__c = cs.breg_Effective_Date__c;
            //     aff.breg_Status__c = 'I';
            //     continue;
            // }

            if (aff.breg_To_Remove__c == true) {
                aff.breg_Status__c = 'I';
                aff.breg_End_Date__c = cs.breg_Effective_Date__c;
                if (aff.breg_Account__c != null) {
                    processedAccountIds.add(aff.breg_Account__c);
                }
                if (aff.breg_Contact__c != null) {
                    processedContactIds.add(aff.breg_Contact__c);
                }
                continue;
            }
            Boolean isAnyChanges = false;
            if (aff.breg_Account__c != null) {
                targetId = aff.breg_Account__c;
                type = Account.SObjectType;
            } else if (aff.breg_Contact__c != null) {
                targetId = aff.breg_Contact__c;
                type = Contact.SObjectType;
            } else {
                if (aff.breg_Type__c == 'Entity') {
                    // Create Account for company
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
                    aff.breg_Status__c = 'A';
                    aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                    accountsToCreate.add(newAccount);
                    affiliationAccountMap.put(aff.Id, newAccount);
                    isAnyChanges = true;
                } else if (aff.breg_Type__c == 'Individual') {
                    // Create Contact for individual
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
                    aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                    aff.breg_Status__c = 'A';
                    contactsToCreate.add(newContact);
                    affiliationContactMap.put(aff.Id, newContact);
                    isAnyChanges = true;
                }
            }

            if (type == Account.SObjectType) {
                Account acc = accountMap.get(targetId);

                if (acc == null) {
                    continue;
                }
                if (
                    aff.breg_Role__c == 'Agent' ||
                    aff.breg_Role__c == 'Member' ||
                    aff.breg_Role__c == 'Officer' ||
                    aff.breg_Role__c == 'Director' ||
                    aff.breg_Role__c == 'Manager' ||
                    aff.breg_Role__c == 'Partner'
                ) {
                    // Agent role must have an existing Account, skip if not found
                    if (aff.breg_Type__c == 'Entity') {
                        if (isDifferent(acc.Name, aff.breg_Entity_Name__c)) {
                            //TODO Create new Account for Agent role if name is different
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
                            aff.breg_Status__c = 'A';
                            aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                            aff.breg_Entity__c = cs.breg_Entity__c;
                            accountsToCreate.add(newAccount);
                            affiliationAccountMap.put(aff.Id, newAccount);
                            processedAccountIds.add(acc.Id);
                            isAnyChanges = true;
                            continue;
                        }
                    } else if (aff.breg_Type__c == 'Individual') {
                        // Agent role must have an existing Account, skip if not found
                        //TODO Create new Account for Agent role if name is different
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
                        aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                        aff.breg_Status__c = 'A';
                        aff.breg_Account__c = null;
                        aff.breg_Entity__c = cs.breg_Entity__c;
                        contactsToCreate.add(newContact);
                        affiliationContactMap.put(aff.Id, newContact);
                        processedAccountIds.add(acc.Id);
                        isAnyChanges = true;
                        continue;
                    }
                }

                // Compare against the entity's previous active affiliation for this member/role,
                // not against the member Account itself. The Account address is left untouched.
                Boolean changed = isAffiliationAddressChanged(
                    previousAffiliationMap.get(getPreviousAffiliationKey(cs.breg_Entity__c, targetId, aff.breg_Role__c)),
                    aff
                );

                if (changed) {
                    // track existing account affiliation changes for transaction logging
                    existingAccountAffiliationsChanged.add(aff);
                    accountIdToCaseMapForTrans.put(cs.breg_Entity__c, cs);
                    caseIdToAffiliationIdForTrans.put(cs.Id, aff.Id);
                    processedAccountIds.add(acc.Id);
                }
                isAnyChanges = isAnyChanges || changed;
            } else if (type == Contact.SObjectType) {
                Contact con = contactMap.get(targetId);
                if (con == null)
                    continue;

                if (
                    aff.breg_Role__c == 'Agent' ||
                    aff.breg_Role__c == 'Member' ||
                    aff.breg_Role__c == 'Officer' ||
                    aff.breg_Role__c == 'Director' ||
                    aff.breg_Role__c == 'Manager' ||
                    aff.breg_Role__c == 'Partner'
                ) {
                    // Agent role must have an existing Account, skip if not found
                    if (aff.breg_Type__c == 'Entity') {
                        //TODO Create new Account for Agent role if name is different
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
                        aff.breg_Status__c = 'A';
                        aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                        aff.breg_Contact__c = null;
                        aff.breg_Entity__c = cs.breg_Entity__c;
                        accountsToCreate.add(newAccount);
                        affiliationAccountMap.put(aff.Id, newAccount);
                        processedContactIds.add(con.Id);
                        continue;
                    } else if (aff.breg_Type__c == 'Individual') {
                        // Agent role must have an existing Account, skip if not found
                        if (isDifferent(con.FirstName, aff.breg_First_Name__c) || isDifferent(con.LastName, aff.breg_Last_Name__c)) {
                            //TODO Create new Account for Agent role if name is different
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
                            aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                            aff.breg_Status__c = 'A';
                            aff.breg_Entity__c = cs.breg_Entity__c;
                            contactsToCreate.add(newContact);
                            affiliationContactMap.put(aff.Id, newContact);
                            processedContactIds.add(con.Id);
                            continue;
                        }
                    }
                }
                // Compare against the entity's previous active affiliation for this member/role,
                // not against the member Contact itself. The Contact address is left untouched.
                Boolean changed = isAffiliationAddressChanged(
                    previousAffiliationMap.get(getPreviousAffiliationKey(cs.breg_Entity__c, targetId, aff.breg_Role__c)),
                    aff
                );

                if (changed) {
                    // track existing account affiliation changes for transaction logging
                    existingAccountAffiliationsChanged.add(aff);
                    accountIdToCaseMapForTrans.put(cs.breg_Entity__c, cs);
                    caseIdToAffiliationIdForTrans.put(cs.Id, aff.Id);
                    processedContactIds.add(con.Id);
                }

                isAnyChanges = isAnyChanges || changed;
            }

            if (isAnyChanges) {
                aff.breg_Status__c = 'A';
                aff.breg_Start_Date__c = cs.breg_Effective_Date__c;
                aff.breg_Entity__c = cs.breg_Entity__c;
            }
        }

        // Before applying updates to member Accounts, create transactions and transaction address records
        if (!existingAccountAffiliationsChanged.isEmpty()) {
            // Build casesMap and case->account map for transactions
            Map<Id, Case> casesMapForTrans = new Map<Id, Case>();
            Map<Id, Id> caseToAccountMap = new Map<Id, Id>();
            List<Account> accountsForTrans = new List<Account>();

            for (breg_Account_Affiliation__c aff : existingAccountAffiliationsChanged) {
                Id accId = aff.breg_Entity__c;
                Case cs = accountIdToCaseMapForTrans.get(accId);
                if (cs == null){
                    continue;
                }
                if (!BREGUtils.isNBRForm(cs.breg_Form_Code__c)){ 
                    casesMapForTrans.put(cs.Id, cs);
                    caseToAccountMap.put(cs.Id, accId);
                    accountsForTrans.add(new Account(Id = accId));
                }
            }

            if (!caseToAccountMap.isEmpty()) {

                // update end date in last transaction address records for affected accounts (filter by affiliation)
                if (!accountsForTrans.isEmpty()) {
                    BREGTransactionUtils.updateEndDateInLastTransAddressRecords(
                        accountsForTrans,
                        accountIdToCaseMapForTrans,
                        caseIdToAffiliationIdForTrans
                    );
                }
            }
        }

        if (!accountsToCreate.isEmpty()) {
            insert accountsToCreate;
            // Update affiliations with new Account IDs
            for (breg_Account_Affiliation__c aff : affiliations) {
                if (aff.breg_Contact__c == null && affiliationAccountMap.containsKey(aff.Id)) {
                    aff.breg_Account__c = affiliationAccountMap.get(aff.Id)?.Id;
                }
            }
        }
        // For affiliations that resulted in newly created Accounts, create ADD-MEMBER transactions and transaction addresses
        List<breg_Transaction__c> newAccountMemberTransactions = new List<breg_Transaction__c>();
        List<breg_Transaction_Address__c> newAccountMemberTransAddrs = new List<breg_Transaction_Address__c>();
        if (!affiliationAccountMap.isEmpty()) {
            Map<Id, Case> casesMapForTransNew = new Map<Id, Case>();
            Map<Id, Id> caseToAccountMapNew = new Map<Id, Id>();
            //List<Account> accountsForTransNew = new List<Account>();
            Map<Id, Id> caseIdToAffiliationIdForTransNew = new Map<Id, Id>();

            for (breg_Account_Affiliation__c aff : affiliations) {
                // affiliationAccountMap contains the created Account SObject for newly created ones
                Case cs = caseMap.get(aff.breg_Case__c);
                if (cs == null){
                    continue;
                }
                if (!BREGUtils.isNBRForm(cs.breg_Form_Code__c)){ 
                    //don't create ADD-MEMBER transaction for NBR cases
                    Account createdAcc = affiliationAccountMap.get(aff.Id);
                    if (createdAcc == null || createdAcc.Id == null){
                        continue;
                    }
                    
                    casesMapForTransNew.put(cs.Id, cs);
                    caseToAccountMapNew.put(cs.Id, createdAcc.Id);
                    //accountsForTransNew.add(new Account(Id = createdAcc.Id));
                    caseIdToAffiliationIdForTransNew.put(cs.Id, aff.Id);
                }
                
            }
        }
        if (!contactsToCreate.isEmpty()) {
            insert contactsToCreate;
            // Update affiliations with new Contact IDs
            for (breg_Account_Affiliation__c aff : affiliations) {
                if (aff.breg_Account__c == null && affiliationContactMap.containsKey(aff.Id)) {
                    aff.breg_Contact__c = affiliationContactMap.get(aff.Id)?.Id;
                }
            }
        }

        if (affiliations.size() > 0) {
            update affiliations;
        }

        // Deactivate unused account affiliations

        List<breg_Account_Affiliation__c> affiliationsToDeactivate = [
            SELECT Id, breg_Account__c, breg_Contact__c, breg_Status__c, breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE
                (breg_Account__c IN :processedAccountIds
                OR breg_Contact__c IN :processedContactIds)
                AND breg_Case__c NOT IN :cases
                AND breg_Entity__c IN :entityCases.keySet()
                AND breg_End_Date__c = NULL
                AND breg_Status__c != 'I'
        ];

        for (breg_Account_Affiliation__c aff : affiliationsToDeactivate) {
            aff.breg_Status__c = 'I';
            aff.breg_End_Date__c = Date.today();
            aff.breg_Bypass_Validation_Token__c = Datetime.now();
        }
        if (!affiliationsToDeactivate.isEmpty()) {
            update affiliationsToDeactivate;
        }
    }


    public static Map<Id, Case> getAccountAffiliationCaseMap(List<Case> cases, Boolean includeAllRoles) {
        return getAccountAffiliationCaseMap(cases, includeAllRoles, ConstantsHelper.ODMMS_ROLES);
    }

    public static Map<Id, Case> getAccountAffiliationCaseMap(List<Case> cases, Boolean includeAllRoles, List<String> rolesFilter) {
        Map<Id, Case> entityCaseMap = new Map<Id, Case>();
        Map<Id, Case> memberCaseMap = new Map<Id, Case>();
        for (Case c : cases) {
            entityCaseMap.put(c.breg_Entity__c, c);
        }
        Set<Id> entityIds = entityCaseMap.keySet();
        List<String> memberRoles = ConstantsHelper.ODMMS_ROLES;
        String soql =
            'SELECT Id, breg_Role__c, breg_Account__c, breg_Contact__c, breg_Entity__c ' +
            'FROM breg_Account_Affiliation__c ' +
            'WHERE breg_Entity__c IN :entityIds ' +
            'AND (breg_Account__c != NULL OR breg_Contact__c != NULL)';

        if (!includeAllRoles) {
            soql += ' AND breg_Role__c IN :rolesFilter';
        }

        soql += ' LIMIT 9000';

        List<breg_Account_Affiliation__c> ODMMs = Database.query(soql);
        for (breg_Account_Affiliation__c aff : ODMMs) {
            if (aff.breg_Contact__c != null) {
                memberCaseMap.put(aff.breg_Contact__c, entityCaseMap.get(aff.breg_Entity__c));
            } else if (aff.breg_Account__c != null) {
                memberCaseMap.put(aff.breg_Account__c, entityCaseMap.get(aff.breg_Entity__c));
            }
        }
        return memberCaseMap;
    }

    public static Map<Id, Case> getMembersCaseMap(List<Case> cases) {
        return getAccountAffiliationCaseMap(cases, false);
    }

    private static Boolean isDifferent(Object oldValue, Object newValue) {
        return oldValue != newValue && (oldValue == null || !oldValue.equals(newValue));
    }

    private static void clearEntityRelatedFields(breg_Account_Affiliation__c affiliation) {
        affiliation.breg_Entity_Name__c = null;
        affiliation.breg_Entity_Type__c = null;
        affiliation.breg_Entity_Type_Description__c = null;
        affiliation.breg_Suffix__c = null;
        affiliation.breg_File__c = null;
        affiliation.breg_Number_of_shares__c = null;
        affiliation.breg_Entity_Location__c = null;
    }

    private static Boolean isManagedMemberRole(String role) {
        return role != null && MANAGED_MEMBER_ROLES.contains(role);
    }

    /**
     * Builds the "previous affiliation" lookup used to detect address changes: the still active
     * affiliations of the given entities that were not filed by the cases being processed,
     * keyed by entity + linked Account/Contact + role.
     */
    private static Map<String, breg_Account_Affiliation__c> getPreviousAffiliationMap(Set<Id> entityIds, Set<Id> caseIds) {
        Map<String, breg_Account_Affiliation__c> previousAffiliationMap = new Map<String, breg_Account_Affiliation__c>();
        if (entityIds == null || entityIds.isEmpty()) {
            return previousAffiliationMap;
        }

        for (breg_Account_Affiliation__c aff : [
            SELECT
                Id,
                breg_Entity__c,
                breg_Account__c,
                breg_Contact__c,
                breg_Role__c,
                breg_Address__Street__s,
                breg_Address_Street_2__c,
                breg_Address__City__s,
                breg_Address__StateCode__s,
                breg_Address__PostalCode__s,
                breg_Address__CountryCode__s
            FROM breg_Account_Affiliation__c
            WHERE
                breg_Entity__c IN :entityIds
                AND breg_Case__c NOT IN :caseIds
                AND breg_End_Date__c = NULL
                AND breg_Status__c != 'I'
                AND (breg_Account__c != NULL
                OR breg_Contact__c != NULL)
            ORDER BY LastModifiedDate ASC
            LIMIT 9000
        ]) {
            // Account first, mirroring how the member record is resolved when applying the filing
            Id memberId = aff.breg_Account__c != null ? aff.breg_Account__c : aff.breg_Contact__c;
            String key = getPreviousAffiliationKey(aff.breg_Entity__c, memberId, aff.breg_Role__c);
            if (key != null) {
                // last one wins: the most recently touched active affiliation is the current one
                previousAffiliationMap.put(key, aff);
            }
        }

        return previousAffiliationMap;
    }

    private static String getPreviousAffiliationKey(Id entityId, Id memberId, String role) {
        if (entityId == null || memberId == null) {
            return null;
        }
        return String.valueOf(entityId) + '|' + String.valueOf(memberId) + '|' + (role == null ? '' : role);
    }

    /**
     * True when the affiliation being filed carries a different address than the entity's previous
     * active affiliation for the same member and role. A missing previous affiliation means the
     * member/role is new on this entity, which counts as an address change.
     */
    private static Boolean isAffiliationAddressChanged(breg_Account_Affiliation__c previousAff, breg_Account_Affiliation__c newAff) {
        if (previousAff == null) {
            return true;
        }
        return isDifferent(previousAff.breg_Address__Street__s, newAff.breg_Address__Street__s) ||
            isDifferent(previousAff.breg_Address_Street_2__c, newAff.breg_Address_Street_2__c) ||
            isDifferent(previousAff.breg_Address__City__s, newAff.breg_Address__City__s) ||
            isDifferent(previousAff.breg_Address__StateCode__s, newAff.breg_Address__StateCode__s) ||
            isDifferent(previousAff.breg_Address__PostalCode__s, newAff.breg_Address__PostalCode__s) ||
            isDifferent(previousAff.breg_Address__CountryCode__s, newAff.breg_Address__CountryCode__s);
    }

    private static Boolean applyAffiliationAddressFromSource(
        breg_Account_Affiliation__c targetAff,
        breg_Account_Affiliation__c sourceAff
    ) {
        Boolean changed = false;
        if (isDifferent(targetAff.breg_Address__Street__s, sourceAff.breg_Address__Street__s)) {
            targetAff.breg_Address__Street__s = sourceAff.breg_Address__Street__s;
            changed = true;
        }
        if (isDifferent(targetAff.breg_Address_Street_2__c, sourceAff.breg_Address_Street_2__c)) {
            targetAff.breg_Address_Street_2__c = sourceAff.breg_Address_Street_2__c;
            changed = true;
        }
        if (isDifferent(targetAff.breg_Address__City__s, sourceAff.breg_Address__City__s)) {
            targetAff.breg_Address__City__s = sourceAff.breg_Address__City__s;
            changed = true;
        }
        if (isDifferent(targetAff.breg_Address__StateCode__s, sourceAff.breg_Address__StateCode__s)) {
            targetAff.breg_Address__StateCode__s = sourceAff.breg_Address__StateCode__s;
            changed = true;
        }
        if (isDifferent(targetAff.breg_Address__PostalCode__s, sourceAff.breg_Address__PostalCode__s)) {
            targetAff.breg_Address__PostalCode__s = sourceAff.breg_Address__PostalCode__s;
            changed = true;
        }
        if (isDifferent(targetAff.breg_Address__CountryCode__s, sourceAff.breg_Address__CountryCode__s)) {
            targetAff.breg_Address__CountryCode__s = sourceAff.breg_Address__CountryCode__s;
            changed = true;
        }
        return changed;
    }

    private static Boolean applyAccountAddressFromAffiliation(Account targetAcc, breg_Account_Affiliation__c sourceAff) {
        Boolean changed = false;
        if (isDifferent(targetAcc.BillingStreet, sourceAff.breg_Address__Street__s)) {
            targetAcc.BillingStreet = sourceAff.breg_Address__Street__s;
            changed = true;
        }
        if (isDifferent(targetAcc.breg_Billing_Address_Street_2__c, sourceAff.breg_Address_Street_2__c)) {
            targetAcc.breg_Billing_Address_Street_2__c = sourceAff.breg_Address_Street_2__c;
            changed = true;
        }
        if (isDifferent(targetAcc.BillingCity, sourceAff.breg_Address__City__s)) {
            targetAcc.BillingCity = sourceAff.breg_Address__City__s;
            changed = true;
        }
        if (isDifferent(targetAcc.BillingStateCode, sourceAff.breg_Address__StateCode__s)) {
            targetAcc.BillingStateCode = sourceAff.breg_Address__StateCode__s;
            changed = true;
        }
        if (isDifferent(targetAcc.BillingPostalCode, sourceAff.breg_Address__PostalCode__s)) {
            targetAcc.BillingPostalCode = sourceAff.breg_Address__PostalCode__s;
            changed = true;
        }
        if (isDifferent(targetAcc.BillingCountryCode, sourceAff.breg_Address__CountryCode__s)) {
            targetAcc.BillingCountryCode = sourceAff.breg_Address__CountryCode__s;
            changed = true;
        }
        return changed;
    }

    private static Boolean applyContactAddressFromAffiliation(Contact targetCon, breg_Account_Affiliation__c sourceAff) {
        Boolean changed = false;
        if (isDifferent(targetCon.MailingStreet, sourceAff.breg_Address__Street__s)) {
            targetCon.MailingStreet = sourceAff.breg_Address__Street__s;
            changed = true;
        }
        if (isDifferent(targetCon.breg_Mailing_Address_Street_2__c, sourceAff.breg_Address_Street_2__c)) {
            targetCon.breg_Mailing_Address_Street_2__c = sourceAff.breg_Address_Street_2__c;
            changed = true;
        }
        if (isDifferent(targetCon.MailingCity, sourceAff.breg_Address__City__s)) {
            targetCon.MailingCity = sourceAff.breg_Address__City__s;
            changed = true;
        }
        if (isDifferent(targetCon.MailingStateCode, sourceAff.breg_Address__StateCode__s)) {
            targetCon.MailingStateCode = sourceAff.breg_Address__StateCode__s;
            changed = true;
        }
        if (isDifferent(targetCon.MailingPostalCode, sourceAff.breg_Address__PostalCode__s)) {
            targetCon.MailingPostalCode = sourceAff.breg_Address__PostalCode__s;
            changed = true;
        }
        if (isDifferent(targetCon.MailingCountryCode, sourceAff.breg_Address__CountryCode__s)) {
            targetCon.MailingCountryCode = sourceAff.breg_Address__CountryCode__s;
            changed = true;
        }
        return changed;
    }

    /**
     * Compares old and new Account records and returns a set of changed field API names
     * @param oldAccount - Account record from Trigger.oldMap (or null if new record)
     * @param newAccount - updated Account record
     * @param fieldsToCheck - list of field API names to check for changes
     * @return Set of API names of fields that changed
     */
    public static Set<String> getChangedFields(Account oldAccount, Account newAccount, List<String> fieldsToCheck) {
        Set<String> changedFields = new Set<String>();
        if (oldAccount == null) {
            // If no old account, all fields are considered "changed"
            changedFields.addAll(fieldsToCheck);
            return changedFields;
        }

        for (String field : fieldsToCheck) {
            Object oldValue = oldAccount.get(field);
            Object newValue = newAccount.get(field);
            if (oldValue != newValue) {
                changedFields.add(field);
            }
        }
        return changedFields;
    }

    /**
     * Dynamically retrieves field API names from a FieldSet
     * @param objectName - SObject name (e.g., 'Account')
     * @param fieldSetName - FieldSet API name (e.g., 'BREG_TBI_Fields_Set')
     * @return List of field API names defined in the FieldSet
     */
    public static List<String> getFieldsFromFieldSet(String objectName, String fieldSetName) {
        List<String> fieldNames = new List<String>();
        try {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
            if (sObjectType != null) {
                Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
                Schema.FieldSet fieldSet = describeResult.fieldSets.getMap().get(fieldSetName);
                if (fieldSet != null) {
                    for (Schema.FieldSetMember fsm : fieldSet.getFields()) {
                        fieldNames.add(fsm.getFieldPath());
                    }
                }
            }
        } catch (Exception e) {
            // Log error and return empty list - fallback gracefully
            System.debug('Error reading FieldSet ' + fieldSetName + ': ' + e.getMessage());
        }
        return fieldNames;
    }

    public static void createBusinessInfoLogsAndUpdate(
        List<Account> accountsToUpdate,
        Map<Id, Set<String>> accountUpdatedFieldsMap,
        Map<Id, Case> entityToCaseMap
    ) {
        List<Account> accountsForLog = new List<Account>();

        for (Account acc : accountsToUpdate) {
            Set<String> updatedFieldsForCurrentAccount = accountUpdatedFieldsMap.get(acc.Id);
            if (BREGUtils.anyFieldInFieldSet('Account', updatedFieldsForCurrentAccount, 'BREG_TBI_Fields_Set')) {
                accountsForLog.add(acc);
            }
        }

        // Capture the account values as they currently exist in the DB (i.e. before
        // accountsToUpdate is committed) so the TBI history record reflects the
        // previous business info, not the values being applied by this update.
        if (accountsForLog.size() > 0) {
            BREGTransactionUtils.updateEndDateInLastTransBusinessInfoRecords(accountsForLog, entityToCaseMap);
        }
        if (!accountsForLog.isEmpty()) {
            BREGTransactionUtils.createTransBusinessInfoRecords(accountsForLog, entityToCaseMap);
        }
        update accountsToUpdate;

       
    }
}