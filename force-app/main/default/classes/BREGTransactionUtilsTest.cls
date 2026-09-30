@isTest
private class BREGTransactionUtilsTest {
    @testSetup
    static void setup() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account acc = new Account(
            Name = 'Test Business',
            breg_Commence_Date__c = Date.today().addDays(-10),
            Sic = '1234',
            RecordTypeId = bregAccRecordType
        );
        insert acc;

        Case c = new Case(breg_Entity__c = acc.Id, breg_Form_Code__c = 'T1', breg_Effective_Date__c = Date.today().addDays(-5), Status = 'New');
        insert c;

        breg_Transaction_Business_Info__c oldTbi = new breg_Transaction_Business_Info__c(
            breg_Entity__c = acc.Id,
            breg_Start_Date__c = Date.today().addDays(-30)
        );
        insert oldTbi;

        breg_Transaction_Business_Info__c lastTbi = new breg_Transaction_Business_Info__c(
            breg_Entity__c = acc.Id,
            breg_Start_Date__c = Date.today().addDays(-10)
        );
        insert lastTbi;
    }

    @isTest
    static void testGetObjectTypeById() {
        Account a = [SELECT Id FROM Account LIMIT 1];
        String typeName = BREGTransactionUtils.getObjectTypeById(a.Id);

        System.assertEquals('Account', typeName, 'Object type should be resolved correctly');

        System.assertEquals(null, BREGTransactionUtils.getObjectTypeById(null));
    }

    @isTest
    static void testCreateTransactionsForEntityChildAccounts() {
        Account parentAcc = [SELECT Id, RecordTypeId FROM Account LIMIT 1];
        Case c = [
            SELECT Id, breg_Entity__c, breg_Form_Code__c, breg_Effective_Date__c, breg_Name_of_the_Entity__c, breg_Form_Configuration__c, breg_Transaction_Code__c, breg_Received_Date_Formula__c
            FROM Case
            LIMIT 1
        ];

        Account childAcc = new Account(
            Name = 'Child Account',
            ParentId = parentAcc.Id,
            RecordTypeId = parentAcc.RecordTypeId
        );
        insert childAcc;

        Map<Id, Case> caseMap = new Map<Id, Case>{ c.Id => c };

        Test.startTest();
        BREGTransactionUtils.createTransactionsForEntityChildAccounts(caseMap, 'A');
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id, breg_Case__c, breg_Account__c, breg_Status__c, breg_Start_Date__c
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id
                AND breg_Account__c = :childAcc.Id
        ];

        System.assertEquals(1, transactions.size(), 'Transaction should be created for child account');
        breg_Transaction__c transactionRecord = transactions[0];
        System.assertEquals(c.Id, transactionRecord.breg_Case__c);
        System.assertEquals(childAcc.Id, transactionRecord.breg_Account__c);
        System.assertEquals('A', transactionRecord.breg_Status__c);
        System.assertEquals(c.breg_Effective_Date__c, transactionRecord.breg_Start_Date__c);
    }

    @isTest
    static void testCreateTransBusinessInfoRecords() {
        List<Schema.FieldSetMember> fsmList = Account.SObjectType.getDescribe().fieldSets.getMap().get('BREG_TBI_Fields_Set').getFields();

        List<String> selectFields = new List<String>{ 'Id' };
        for (Schema.FieldSetMember fsm : fsmList) {
            selectFields.add(fsm.getFieldPath());
        }

        String soql = 'SELECT ' + String.join(selectFields, ', ') + ' FROM Account LIMIT 1';

        Account acc = (Account) Database.query(soql);
        Case c = [SELECT Id, breg_Entity__c, breg_Effective_Date__c FROM Case LIMIT 1];

        Map<Id, Case> entityToCaseMap = new Map<Id, Case>{ acc.Id => c };

        Test.startTest();
        BREGTransactionUtils.createTransBusinessInfoRecords(new List<Account>{ acc }, entityToCaseMap);
        Test.stopTest();

        List<breg_Transaction_Business_Info__c> tbiList = [
            SELECT breg_Entity__c, breg_Sic_Code__c, breg_Commence_Date__c, breg_Start_Date__c
            FROM breg_Transaction_Business_Info__c
            WHERE breg_Entity__c = :acc.Id AND breg_Sic_Code__c != NULL
            ORDER BY CreatedDate DESC
        ];

        breg_Transaction_Business_Info__c created = tbiList[0];

        System.assertEquals(acc.Id, created.breg_Entity__c);
        System.assertEquals(acc.Sic, created.breg_Sic_Code__c);
        System.assertEquals(acc.breg_Commence_Date__c, created.breg_Commence_Date__c);
        System.assertEquals(c.breg_Effective_Date__c, created.breg_Start_Date__c);
    }

    @isTest
    static void testUpdateEndDateInLastTransBusinessInfoRecords() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Case c = [SELECT Id, breg_Entity__c, breg_Effective_Date__c, breg_Form_Configuration__c, breg_Received_Date_Formula__c FROM Case LIMIT 1];

        Map<Id, Case> entityToCaseMap = new Map<Id, Case>{ acc.Id => c };

        Test.startTest();
        BREGTransactionUtils.updateEndDateInLastTransBusinessInfoRecords(new List<Account>{ acc }, entityToCaseMap);
        Test.stopTest();

        breg_Transaction_Business_Info__c lastTbi = [
            SELECT Id, breg_End_Date__c
            FROM breg_Transaction_Business_Info__c
            WHERE breg_Entity__c = :acc.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals(c.breg_Effective_Date__c, lastTbi.breg_End_Date__c, 'End Date in last TBI should be updated');
    }

    @isTest
    static void testBuildBaseTransactionForAccount() {
        Account acc = [
            SELECT Id, Name, breg_File_Suffix__c
            FROM Account
            LIMIT 1
        ];

        Date effectiveDate = Date.today();
        Date receivedDate = Date.today().addDays(-1);

        breg_Transaction__c result = BREGTransactionUtils.buildBaseTransactionForAccount(
            acc,
            'TESTCODE',
            effectiveDate,
            receivedDate,
            'A'
        );

        System.assertEquals(acc.Id, result.breg_Account__c);
        System.assertEquals('TESTCODE', result.breg_Transaction_Code__c);
        System.assertEquals(effectiveDate, result.breg_Effective_Date__c);
        System.assertEquals(receivedDate, result.breg_Received_Date__c);
        System.assertEquals('A', result.breg_Status__c);
    }

    @isTest
    static void testBuildBaseTransactionForRecord() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Case c = [
            SELECT
                Id,
                breg_Effective_Date__c,
                breg_Received_Date_Formula__c,
                breg_File_Suffix__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c
            FROM Case
            LIMIT 1
        ];

        breg_Transaction__c result = BREGTransactionUtils.buildBaseTransactionForRecord(
            c,
            acc.Id,
            'REC001',
            'A'
        );

        System.assertEquals(acc.Id, result.breg_Account__c);
        System.assertEquals(c.Id, result.breg_Case__c);
        System.assertEquals('REC001', result.breg_Transaction_Code__c);
    }

    @isTest
    static void testBuildBaseTransactionForRecord_WithNullRelatedRecordId() {
        Case c = [
            SELECT
                Id,
                breg_Effective_Date__c,
                breg_Received_Date_Formula__c,
                breg_File_Suffix__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c
            FROM Case
            LIMIT 1
        ];

        breg_Transaction__c result = BREGTransactionUtils.buildBaseTransactionForRecord(
            c,
            null,
            'REC002',
            'R'
        );

        System.assertEquals(c.Id, result.breg_Case__c);
        System.assertEquals('REC002', result.breg_Transaction_Code__c);
        System.assertEquals('R', result.breg_Status__c);
        System.assertEquals(null, result.breg_Account__c, 'Account should not be set when relatedRecordId is null');
        System.assertEquals(null, result.breg_TN_TM_SM__c, 'TN/TM/SM should not be set when relatedRecordId is null');
    }

 
    @isTest
    static void testCreateTransactionsForEntities() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Case c = [
            SELECT
                Id,
                Status,
                breg_Entity__c,
                breg_Form_Code__c,
                breg_Effective_Date__c,
                breg_Form_Configuration__c,
                breg_Received_Date_Formula__c,
                breg_Transaction_Code__c,
                breg_Form_Configuration__r.breg_Entity_Type__c,
                breg_Name_of_the_Entity__c,
                breg_TN_TM_SM__c
            FROM Case
            LIMIT 1
        ];

        Map<Id, Case> caseMap = new Map<Id, Case>{ c.Id => c };

        Test.startTest();
        BREGTransactionUtils.createTransactionsForEntities(caseMap, 'A');
        Test.stopTest();

        List<breg_Transaction__c> transactions = [
            SELECT Id
            FROM breg_Transaction__c
            WHERE breg_Case__c = :c.Id
        ];

        System.assert(!transactions.isEmpty());
    }

    @isTest
    static void testCreateMassTransactionRecord() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];

        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Entity__r.Name,
                breg_Effective_Date__c,
                breg_Received_Date_Formula__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Name_of_the_Entity__c,
                breg_File_Suffix__c
            FROM Case
            LIMIT 1
        ];

        Map<Id, Case> casesMap = new Map<Id, Case>{ c.Id => c };

        Map<Id, List<Id>> mapping = new Map<Id, List<Id>>{
            c.Id => new List<Id>{ acc.Id }
        };

        List<breg_Transaction__c> result =
            BREGTransactionUtils.createMassTransactionRecord(
                casesMap,
                mapping,
                'MASS01',
                true,
                'A'
            );

        System.assertEquals(1, result.size());
        System.assert(result[0].breg_Description__c.contains('Merged By:'));
    }

    @isTest
    static void testCreateTransactionAddresses() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Case c = [
            SELECT
                Id,
                CaseNumber,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address__Street__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Mailing_Address_State__c
            FROM Case
            LIMIT 1
        ];

        breg_Transaction__c trans = new breg_Transaction__c(
            breg_Case__c = c.Id
        );
        insert trans;

        List<breg_Transaction_Address__c> result =
            BREGTransactionUtils.createTransactionAdresses(
                new Map<Id, Case>{ c.Id => c },
                new List<breg_Transaction__c>{ trans },
                null
            );

        System.assertEquals(1, result.size());
        System.assertEquals(c.Id, trans.breg_Case__c);
    }

    @isTest
    static void testUpdateTransactionStatusByCases_UsesEntityWhenPresent() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account nameReservation = new Account(
            Name = 'Test Name Reservation',
            RecordTypeId = bregAccRecordType,
            breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
            breg_Entity_Status__c = 'Active (A)',
            breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
        );
        insert nameReservation;

        Case c = [SELECT Id, breg_Entity__c, breg_Name_Reservation__c, breg_TN_TM_SM__c, breg_Form_Code__c FROM Case LIMIT 1];
        c.breg_Name_Reservation__c = nameReservation.Id;
        update c;

        breg_Transaction__c trans = new breg_Transaction__c(
            breg_Case__c = c.Id,
            breg_Account__c = nameReservation.Id,
            breg_Status__c = 'R'
        );
        insert trans;

        Test.startTest();
        BREGTransactionUtils.updateTransactionStatusByCases(new Map<Id, Case>(new List<Case>{c}), 'A');
        Test.stopTest();

        breg_Transaction__c updatedTrans = [
            SELECT Id, breg_Account__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE Id = :trans.Id
            LIMIT 1
        ];

        System.assertEquals(c.breg_Entity__c, updatedTrans.breg_Account__c, 'Entity should take priority over Name Reservation');
        System.assertEquals('A', updatedTrans.breg_Status__c, 'Status should be updated');
    }

    @isTest
    static void testUpdateTransactionStatusByCases_UsesNameReservationWhenEntityIsNull() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account nameReservation = new Account(
            Name = 'Test Name Reservation Fallback',
            RecordTypeId = bregAccRecordType,
            breg_Entity_Type__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE,
            breg_Entity_Status__c = 'Active (A)',
            breg_File_Suffix__c = ConstantsHelper.NAME_RESERVATION_ENTITY_TYPE
        );
        insert nameReservation;

        Case c = new Case(
            Status = 'New',
            breg_Form_Code__c = 'T1',
            breg_Effective_Date__c = Date.today().addDays(-1),
            breg_Name_Reservation__c = nameReservation.Id
        );
        insert c;

        breg_Transaction__c trans = new breg_Transaction__c(
            breg_Case__c = c.Id,
            breg_Status__c = 'R'
        );
        insert trans;

        Case caseForUpdate = [SELECT Id, breg_Entity__c, breg_Name_Reservation__c, breg_TN_TM_SM__c, breg_Form_Code__c FROM Case WHERE Id = :c.Id LIMIT 1];

        Test.startTest();
        BREGTransactionUtils.updateTransactionStatusByCases(new Map<Id, Case>(new List<Case>{caseForUpdate}), 'A');
        Test.stopTest();

        breg_Transaction__c updatedTrans = [
            SELECT Id, breg_Account__c, breg_Status__c
            FROM breg_Transaction__c
            WHERE Id = :trans.Id
            LIMIT 1
        ];

        System.assertEquals(nameReservation.Id, updatedTrans.breg_Account__c, 'Name Reservation should be used when Entity is null');
        System.assertEquals('A', updatedTrans.breg_Status__c, 'Status should be updated');
    }
}