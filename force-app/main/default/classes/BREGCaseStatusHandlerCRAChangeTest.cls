@isTest
private class BREGCaseStatusHandlerCRAChangeTest {
    @TestSetup
    static void setupData() {
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-7',
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;

        Account stateEntity = new Account(
            Name = 'CRA Change Entity State',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Formation_State__c = 'HI',
            BillingStreet = 'Old State St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US'
        );

        Account countryEntity = new Account(
            Name = 'CRA Change Entity Country',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Formation_Country__c = 'US',
            BillingStreet = 'Old Country St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US'
        );
        insert new List<Account>{ stateEntity, countryEntity };

        Case stateCase = new Case(
            Subject = 'CRA Change State Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = stateEntity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-7',
            breg_File_Suffix__c = '001',
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = stateEntity.Name,
            breg_Reg_Agent_Has_Changed__c = true,
            breg_Reg_Agent_Address_Has_Changed__c = true,
            breg_Entity_Type_Has_Changed__c = true,
            breg_Entity_Jurisdiction_Has_Changed__c = true,
            breg_Reg_Agent_First_Name__c = 'John',
            breg_Reg_Agent_Last_Name__c = 'Smith',
            breg_Registered_Agent_Address__Street__s = '123 New State St',
            breg_Reg_Agent_Address_Street2__c = 'Suite 200',
            breg_Registered_Agent_Address__City__s = 'Honolulu',
            breg_Registered_Agent_Address__StateCode__s = 'HI',
            breg_Registered_Agent_Address__PostalCode__s = '96814',
            breg_Registered_Agent_Address__CountryCode__s = 'US',
            breg_Entity_Type__c = 'D2',
            breg_Entity_Jurisdiction__c = 'HI'
        );

        Case countryCase = new Case(
            Subject = 'CRA Change Country Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = countryEntity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'X-7',
            breg_File_Suffix__c = '002',
            breg_Effective_Date__c = Date.today(),
            breg_Name_of_the_Entity__c = countryEntity.Name,
            breg_Reg_Agent_Has_Changed__c = true,
            breg_Reg_Agent_Address_Has_Changed__c = true,
            breg_Entity_Type_Has_Changed__c = true,
            breg_Entity_Jurisdiction_Has_Changed__c = true,
            breg_Reg_Agent_Entity_Name__c = 'Agent Entity LLC',
            breg_Registered_Agent_Address__Street__s = '456 New Country St',
            breg_Reg_Agent_Address_Street2__c = 'Floor 3',
            breg_Registered_Agent_Address__City__s = 'Honolulu',
            breg_Registered_Agent_Address__StateCode__s = 'HI',
            breg_Registered_Agent_Address__PostalCode__s = '96815',
            breg_Registered_Agent_Address__CountryCode__s = 'US',
            breg_Entity_Type__c = 'A1',
            breg_Entity_Jurisdiction__c = 'US'
        );

        insert new List<Case>{ stateCase, countryCase };
    }

    @isTest
    static void handleStatusChangeApprovedNoActionTest() {
        Case stateCase = [SELECT Id FROM Case WHERE Subject = 'CRA Change State Case' LIMIT 1];
        BREGCaseStatusHandlerCRAChange handler = new BREGCaseStatusHandlerCRAChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ stateCase }, 'Approved', false, true);
        Test.stopTest();

        Integer transactionCount = [
            SELECT COUNT()
            FROM breg_Transaction__c
            WHERE breg_Case__c = :stateCase.Id AND breg_Transaction_Code__c = :BREGCaseStatusHandlerCRAChange.CRA_CHANGE_TRANSACTION_CODE
        ];
        System.assertEquals(0, transactionCount, 'Approved should not create CRC transactions');
    }

    @isTest
    static void handleStatusChangeReceivedCreatesTransactionTest() {
        Case stateCase = [SELECT Id FROM Case WHERE Subject = 'CRA Change State Case' LIMIT 1];
        BREGCaseStatusHandlerCRAChange handler = new BREGCaseStatusHandlerCRAChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ stateCase }, 'Received', false, true);
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Status__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :stateCase.Id AND breg_Transaction_Code__c = :BREGCaseStatusHandlerCRAChange.CRA_CHANGE_TRANSACTION_CODE
        ];
        System.assertEquals(1, transactions.size(), 'Received should create one CRC transaction');
        System.assertEquals('R', transactions[0].breg_Status__c, 'Received transaction should have status R');
    }

    @isTest
    static void handleStatusChangeCompletedCreatesTransactionsAndUpdatesAgentsTest() {
        List<Case> casesToProcess = [
            SELECT Id, breg_Entity__c
            FROM Case
            WHERE Subject IN ('CRA Change State Case', 'CRA Change Country Case')
            ORDER BY Subject ASC
        ];

        BREGCaseStatusHandlerCRAChange handler = new BREGCaseStatusHandlerCRAChange();

        Test.startTest();
        handler.handleStatusChange(casesToProcess, 'Completed', false, true);
        Test.stopTest();

        Set<Id> caseIds = new Set<Id>();
        for (Case c : casesToProcess) {
            caseIds.add(c.Id);
        }

        Integer transactionCount = [
            SELECT COUNT()
            FROM breg_Transaction__c
            WHERE breg_Case__c IN :caseIds AND breg_Transaction_Code__c = :BREGCaseStatusHandlerCRAChange.CRA_CHANGE_TRANSACTION_CODE
        ];
        System.assertEquals(0, transactionCount, 'Completed should create 0 transactions for each case');

        Account updatedStateEntity = [
            SELECT
                Id,
                FirstName__c,
                LastName__c,
                breg_Registrant_Address__Street__s,
                breg_Registrant_Address_Street_2__c,
                breg_Registrant_Address__City__s,
                breg_Registrant_Address__StateCode__s,
                breg_Registrant_Address__PostalCode__s,
                breg_Registrant_Address__CountryCode__s,
                breg_Entity_Type__c,
                breg_Formation_State__c
            FROM Account
            WHERE Name = 'CRA Change Entity State'
            LIMIT 1
        ];

        System.assertEquals('John', updatedStateEntity.FirstName__c, 'Individual branch should update first name');
        System.assertEquals('Smith', updatedStateEntity.LastName__c, 'Individual branch should update last name');
        System.assertEquals('123 New State St', updatedStateEntity.breg_Registrant_Address__Street__s, 'Address should be updated from case');
        System.assertEquals('Suite 200', updatedStateEntity.breg_Registrant_Address_Street_2__c, 'Address line 2 should be updated');
        System.assertEquals('D2', updatedStateEntity.breg_Entity_Type__c, 'Entity type should be updated');
        System.assertEquals('HI', updatedStateEntity.breg_Formation_State__c, 'State jurisdiction branch should update formation state');

        Account updatedCountryEntity = [
            SELECT
                Id,
                Name,
                breg_Registrant_Address__Street__s,
                breg_Registrant_Address_Street_2__c,
                breg_Registrant_Address__City__s,
                breg_Registrant_Address__StateCode__s,
                breg_Registrant_Address__PostalCode__s,
                breg_Registrant_Address__CountryCode__s,
                breg_Entity_Type__c,
                breg_Formation_Country__c
            FROM Account
            WHERE Name = 'Agent Entity LLC'
            LIMIT 1
        ];

        System.assertEquals('Agent Entity LLC', updatedCountryEntity.Name, 'Entity-name branch should update account name');
        System.assertEquals('456 New Country St', updatedCountryEntity.breg_Registrant_Address__Street__s, 'Address should be updated from case');
        System.assertEquals('Floor 3', updatedCountryEntity.breg_Registrant_Address_Street_2__c, 'Address line 2 should be updated');
        System.assertEquals('A1', updatedCountryEntity.breg_Entity_Type__c, 'Entity type should be updated');
        System.assertEquals('US', updatedCountryEntity.breg_Formation_Country__c, 'Country jurisdiction branch should update formation country');
    }

    @isTest
    static void handleStatusChangeUnhandledStatusNoActionTest() {
        Case stateCase = [SELECT Id FROM Case WHERE Subject = 'CRA Change State Case' LIMIT 1];
        BREGCaseStatusHandlerCRAChange handler = new BREGCaseStatusHandlerCRAChange();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ stateCase }, 'Rejected', false, true);
        Test.stopTest();

        Integer transactionCount = [
            SELECT COUNT()
            FROM breg_Transaction__c
            WHERE breg_Case__c = :stateCase.Id AND breg_Transaction_Code__c = :BREGCaseStatusHandlerCRAChange.CRA_CHANGE_TRANSACTION_CODE
        ];
        System.assertEquals(0, transactionCount, 'No transactions should be created for unhandled statuses');
    }
}