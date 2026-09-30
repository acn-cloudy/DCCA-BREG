@IsTest
private class BREGCaseStatusHandlerCorrectionsTest {
    @TestSetup
    static void makeData() {
        breg_Form_Configuration__c correctionsForm = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'X-3'
        );
        insert correctionsForm;

        BREGTestDataFactory.createEntityAccounts(1);
        Account oldEntity = makeOldEntity('111111', 'C5');
        Case baseCase = makeCase(oldEntity, '111111', correctionsForm.Id);
        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'Test Payment for Case ' + baseCase.Id,
            breg_Case__c = baseCase.Id,
            pymt__Status__c = 'Completed'
        );
        insert payment;
    }

    private static Account makeOldEntity(String fileNo, String fileSuffix) {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account a = new Account(
            Name = 'Old Entity Corporation',
            RecordTypeId = bregAccountRecordTypeId,
            breg_File__c = fileNo,
            breg_File_Suffix__c = fileSuffix,
            breg_Entity_Status__c = 'Active (A)'
        );
        insert a;
        return a;
    }

    private static Case makeCase(Account oldEntity, String fileNo, Id formConfig) {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case c = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = oldEntity.Id,
            breg_Form_Configuration__c = formConfig,
            breg_Name_of_the_Entity__c = 'Old Entity Corporation',
            breg_new_entity_name__c = 'New Entity Name',
            breg_File__c = fileNo,
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__PostalCode__s = '98613',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__City__s = 'City',
            breg_Mailing_Address__PostalCode__s = '98613',
            breg_Mailing_Address__Street__s = '123 Test St',
            breg_Reg_Agent_Type__c = 'Individual',
            breg_Formation_State__c = 'HI',
            breg_Number_of_initial_members__c = 1,
            breg_Purposes__c = 'Purpose',
            breg_subscribe_owner_free_email_alerts__c = false,
            breg_Effective_Date__c = Date.today().addDays(-5),
            RecordTypeId = bregCaseRecordTypeId
        );
        insert c;
        return c;
    }

    @IsTest
    static void validateAccsAndContactsLinkedTest() {
        Case baseCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Resubmission_Due_Date__c,
                breg_Resubmission_Received_Date__c,
                breg_Effective_Date__c,
                Subject,
                breg_Form_Code__c,
                breg_Last_Rejection_Date__c,
                breg_Override_Payment__c,
                breg_File__c
            FROM Case
            WHERE Subject = 'Test Case'
            LIMIT 1
        ];

        createCompletedPayment(baseCase.Id);

        breg_Account_Affiliation__c aff = new breg_Account_Affiliation__c(breg_Case__c = baseCase.Id, breg_Role__c = 'Member');
        insert aff;

        BREGCaseStatusHandlerCorrections handler = new BREGCaseStatusHandlerCorrections();

        Boolean exceptionThrown = false;
        try {
            handler.handleStatusChange(new List<Case>{ baseCase }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            System.assertEquals('One of the related account affiliations has neither Account nor Contact lookup populated', e.errorMessage);
        }
        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void addRelationToCRATest() {
        Account craAcc = makeCRAAccount('Test CRA');
        insert craAcc;
        Case baseCase = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                Subject,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case'
            LIMIT 1
        ];
        baseCase.breg_Reg_Agent_Has_Changed__c = true;
        baseCase.breg_Reg_Agent_Entity_Name__c = craAcc.Name;
        baseCase.breg_Effective_Date__c = Date.today().addDays(-5);
        update baseCase;

        BREGCaseStatusHandlerCorrections handler = new BREGCaseStatusHandlerCorrections();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ baseCase }, 'Approved', false, true);
        Test.stopTest();

        List<breg_Account_Affiliation__c> agents = [
            SELECT Id
            FROM breg_Account_Affiliation__c
            WHERE breg_Role__c = 'Agent' AND breg_Account__c = :craAcc.Id AND breg_Entity__c = :baseCase.breg_Entity__c
        ];

        System.assertEquals(1, agents.size());
    }

    @IsTest
    static void updateAffiliationsTest() {
        Account relAcc = new Account(Name = 'Related Acc');
        insert relAcc;
        Case baseCase = [SELECT Id, breg_Entity__c, breg_Effective_Date__c, Subject, breg_Form_Code__c FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        breg_Account_Affiliation__c newAff = new breg_Account_Affiliation__c(
            breg_Case__c = baseCase.Id,
            breg_Role__c = 'Director',
            breg_Account__c = relAcc.Id
        );

        Date closingDate = Date.today().addDays(-1);
        breg_Account_Affiliation__c closingAff = new breg_Account_Affiliation__c(
            breg_Case__c = baseCase.Id,
            breg_Role__c = 'Director',
            breg_Account__c = relAcc.Id,
            breg_End_Date__c = closingDate
        );

        insert new List<breg_Account_Affiliation__c>{ newAff, closingAff };

        breg_Account_Affiliation__c activeEntityAff = new breg_Account_Affiliation__c(
            breg_Entity__c = baseCase.breg_Entity__c,
            breg_Account__c = relAcc.Id,
            breg_Role__c = 'Director'
        );
        insert activeEntityAff;

        Map<Id, Case> caseMap = new Map<Id, Case>{ baseCase.Id => baseCase };

        Test.startTest();
        BREGCaseStatusHandlerCorrections.updateAffiliations(caseMap);
        Test.stopTest();

        breg_Account_Affiliation__c newAffReload = [
            SELECT breg_Entity__c, breg_Start_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :newAff.Id
        ];

        breg_Account_Affiliation__c activeReload = [
            SELECT breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :activeEntityAff.Id
        ];

        System.assertEquals(baseCase.breg_Entity__c, newAffReload.breg_Entity__c);
        System.assertEquals(baseCase.breg_Effective_Date__c, newAffReload.breg_Start_Date__c);
        System.assertEquals(closingDate, activeReload.breg_End_Date__c);
    }

    @IsTest
    static void updateRelatedEntitiesTest() {
        Account oldEntity = [SELECT Id, Name FROM Account WHERE Name = 'Old Entity Corporation' LIMIT 1];
        Account entity = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode
            FROM Account
            WHERE Name = 'Old Entity Corporation'
            LIMIT 1
        ];
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_New_Entity_Jurisdiction__c,
                breg_new_entity_name__c,
                breg_Mailing_Address_Number_and_Street_2__c,
                breg_Company_Address_Street2__c,
                breg_Reg_Agent_Address_Street2__c,
                breg_Form_Configuration__c,
                CaseNumber,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case'
            LIMIT 1
        ];

        c.breg_new_entity_name__c = 'Updated Entity Name';
        c.breg_Name_of_the_Entity__c = entity.Name;
        c.breg_Company_Address__Street__s = 'Company St 1';
        c.breg_Company_Address__City__s = 'Honolulu';
        c.breg_Company_Address__StateCode__s = 'HI';
        c.breg_Company_Address__PostalCode__s = '12345';
        c.breg_Company_Address__CountryCode__s = 'US';

        c.breg_Mailing_Address__Street__s = 'Mail St 2';
        c.breg_Mailing_Address__City__s = 'Kailua';
        c.breg_Mailing_Address__StateCode__s = 'HI';
        c.breg_Mailing_Address__PostalCode__s = '54321';
        c.breg_Mailing_Address__CountryCode__s = 'US';

        c.breg_Reg_Agent_Address_Has_Changed__c = true;
        c.breg_Registered_Agent_Address__Street__s = 'Agent St 9';
        c.breg_Registered_Agent_Address__City__s = 'Hilo';
        c.breg_Registered_Agent_Address__StateCode__s = 'HI';
        c.breg_Registered_Agent_Address__PostalCode__s = '98765';
        c.breg_Registered_Agent_Address__CountryCode__s = 'US';
        c.breg_Form_Code__c = 'X-3';
        c.breg_New_Entity_Type__c = 'C5';
        c.breg_Effective_Date__c = Date.today();
        update c;

        BREGCaseStatusHandlerCorrections handler = new BREGCaseStatusHandlerCorrections();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        Test.stopTest();

        Account updated = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode
            FROM Account
            WHERE Id = :oldEntity.Id
            LIMIT 1
        ];

        System.assertEquals('Updated Entity Name', updated.Name);
        System.assertEquals('Agent St 9', updated.BillingStreet);
        System.assertEquals('Hilo', updated.BillingCity);
        System.assertEquals('98765', updated.BillingPostalCode);
    }

    @IsTest
    static void addEndDateToPreviousCRATest() {
        Account craAcc = makeCRAAccount('CRA With Previous');
        insert craAcc;

        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case'
            LIMIT 1
        ];
        c.breg_Reg_Agent_Has_Changed__c = true;
        c.breg_Reg_Agent_Entity_Name__c = craAcc.Name;
        c.breg_Effective_Date__c = Date.today().addDays(-3);
        update c;

        breg_Account_Affiliation__c previousAgent = new breg_Account_Affiliation__c(
            breg_Entity__c = c.breg_Entity__c,
            breg_Account__c = craAcc.Id,
            breg_Role__c = 'Agent'
        );
        insert previousAgent;

        BREGCaseStatusHandlerCorrections handler = new BREGCaseStatusHandlerCorrections();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Approved', false, true);
        Test.stopTest();

        breg_Account_Affiliation__c prevReload = [
            SELECT breg_End_Date__c
            FROM breg_Account_Affiliation__c
            WHERE Id = :previousAgent.Id
        ];

        System.assertEquals(c.breg_Effective_Date__c, prevReload.breg_End_Date__c);
    }

    @IsTest
    static void getAccCRACaseMapTest() {
        Account oldEntity = [SELECT Id, Name FROM Account WHERE Name = 'Old Entity Corporation' LIMIT 1];
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'X-3' LIMIT 1];
        Account craByName = makeCRAAccount('CRA Name');
        insert craByName;

        Account craByFullName = makeCRAAccount('John Doe');
        insert craByFullName;

        Case c1 = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Effective_Date__c,
                breg_New_Entity_Jurisdiction__c,
                breg_Form_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Transaction_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE Subject = 'Test Case'
            LIMIT 1
        ];
        c1.breg_Reg_Agent_Has_Changed__c = true;
        c1.breg_Reg_Agent_Entity_Name__c = craByName.Name;
        update c1;
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        Case c2 = new Case(
            Subject = 'Test Case CRA2',
            Status = 'New',
            Origin = 'Phone',
            breg_Entity__c = oldEntity.Id,
            breg_Form_Configuration__c = formConfig.Id,
            breg_new_entity_name__c = 'New Entity Name 2',
            breg_File__c = '222222',
            breg_Company_Address__CountryCode__s = 'US',
            breg_Company_Address__StateCode__s = 'HI',
            breg_Company_Address__City__s = 'Honolulu',
            breg_Company_Address__PostalCode__s = '98613',
            breg_Mailing_Address__CountryCode__s = 'US',
            breg_Mailing_Address__StateCode__s = 'HI',
            breg_Mailing_Address__City__s = 'City',
            breg_Mailing_Address__PostalCode__s = '98613',
            breg_Mailing_Address__Street__s = '456 Test St',
            breg_Reg_Agent_Type__c = 'Individual',
            breg_Formation_State__c = 'HI',
            breg_Number_of_initial_members__c = 1,
            breg_Purposes__c = 'Purpose',
            breg_subscribe_owner_free_email_alerts__c = false,
            breg_Effective_Date__c = Date.today().addDays(-2),
            breg_Reg_Agent_Has_Changed__c = true,
            breg_Reg_Agent_First_Name__c = 'John',
            breg_Reg_Agent_Last_Name__c = 'Doe',
            breg_Form_Code__c = 'X-3',
            RecordTypeId = bregCaseRecordTypeId
        );
        insert c2;

        BREGCaseStatusHandlerCorrections handler = new BREGCaseStatusHandlerCorrections();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c1, c2 }, 'Approved', false, true);
        Test.stopTest();

        List<breg_Account_Affiliation__c> agents = [
            SELECT Id, breg_Account__c, breg_Case__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Role__c = 'Agent' AND breg_Account__c IN :new Set<Id>{ craByName.Id, craByFullName.Id }
        ];

        System.assertEquals(2, agents.size());

        Boolean foundByName = false;
        Boolean foundByFullName = false;
        for (breg_Account_Affiliation__c a : agents) {
            if (a.breg_Account__c == craByName.Id && a.breg_Case__c == c1.Id) {
                foundByName = true;
            }
            if (a.breg_Account__c == craByFullName.Id && a.breg_Case__c == c2.Id) {
                foundByFullName = true;
            }
        }
        System.assertEquals(true, foundByName);
        System.assertEquals(true, foundByFullName);
    }

    private static void createCompletedPayment(Id caseId) {
        Transaction__c trans = new Transaction__c();
        insert trans;
        pymt__PaymentX__c payment = new pymt__PaymentX__c(breg_Case__c = caseId, pymt__Status__c = 'Completed');
        insert payment;

        TransactionLine__c line = new TransactionLine__c(
            Transaction__c = trans.Id,
            breg_Case__c = caseId,
            PaidStatus__c = 'Paid',
            Payment__c = payment.Id,
            Amount__c = 100
        );
        insert line;
    }

    private static Account makeCRAAccount(String name) {
        return new Account(
            Name = name,
            breg_BRIM_CRA_FL__c = true,
            breg_Formation_State__c = 'HI',
            breg_Entity_Type__c = 'C5',
            breg_Registrant_Address__Street__s = '123 CRA St',
            BillingStreet = '123 CRA St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountryCode = 'US'
        );
    }
}