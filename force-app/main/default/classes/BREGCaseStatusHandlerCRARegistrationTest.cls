@isTest
private class BREGCaseStatusHandlerCRARegistrationTest {
    @testSetup
    static void setupData() {
        Id accRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        // Active Entity Account
        Account entityAcc = new Account(
            Name = 'Entity Acc',
            RecordTypeId = accRtId,
            breg_Entity_Status__c = 'Active (A)',
            breg_File__c = '123456CA',
            breg_Entity_Type__c = 'D1',
            breg_Formation_State__c = 'CA',
            BillingCity = 'Los Angeles',
            BillingStateCode = 'CA',
            BillingCountryCode = 'US',
            BillingStreet = '123 Main St, Los Angeles, CA, US'
        );
        insert entityAcc;

        Case entityCase = new Case(
            Subject = 'Entity Case',
            Status = 'Pen',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Code__c = 'X-11',
            breg_Reg_Agent_Type__c = 'Entity',
            breg_Entity_Type__c = 'D1',
            breg_Entity__c = entityAcc.Id,
            breg_Registered_Agent_Address__Street__s = '123 New State St',
            breg_Reg_Agent_Address_Street2__c = 'Suite 200',
            breg_Registered_Agent_Address__City__s = 'Honolulu',
            breg_Registered_Agent_Address__StateCode__s = 'HI',
            breg_Registered_Agent_Address__PostalCode__s = '96814',
            breg_Registered_Agent_Address__CountryCode__s = 'US',
            breg_Effective_Date__c = System.today()
        );

        // Case for Individual flow
        Case individualCase = new Case(
            Subject = 'Individual Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Form_Code__c = 'X-11',
            breg_Reg_Agent_Type__c = 'Individual',
            breg_Reg_Agent_First_Name__c = 'John',
            breg_Reg_Agent_Last_Name__c = 'Doe',
            breg_Registered_Agent_Address__Street__s = '123 New State St',
            breg_Reg_Agent_Address_Street2__c = 'Suite 200',
            breg_Registered_Agent_Address__City__s = 'Honolulu',
            breg_Registered_Agent_Address__StateCode__s = 'HI',
            breg_Registered_Agent_Address__PostalCode__s = '96814',
            breg_Registered_Agent_Address__CountryCode__s = 'US',
            breg_Effective_Date__c = System.today()
        );

        insert new List<Case>{ entityCase, individualCase };
    }

    @isTest
    static void testCompleted_updatesEntityAccount() {
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Form_Code__c,
                breg_Reg_Agent_Type__c,
                breg_Effective_Date__c,
                breg_Entity_Type__c,
                breg_Registered_Agent_Address__CountryCode__s,
                breg_Registered_Agent_Address__StateCode__s,
                breg_Registered_Agent_Address__Street__s,
                breg_Reg_Agent_Address_Street2__c,
                breg_Registered_Agent_Address__City__s,
                breg_Registered_Agent_Address__PostalCode__s
            FROM Case
            WHERE breg_Reg_Agent_Type__c = 'Entity'
            LIMIT 1
        ];

        createCompletedPayment(c.Id);
        BREGCaseStatusHandlerCRARegistration handler = new BREGCaseStatusHandlerCRARegistration();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Completed', false, true);
        Test.stopTest();

        Account acc = [
            SELECT breg_BRIM_CRA_FL__c, breg_Formation_State__c
            FROM Account
            WHERE Id = :c.breg_Entity__c
        ];

        System.assertEquals(true, acc.breg_BRIM_CRA_FL__c, 'CRA flag should be set');
        System.assertEquals('CA', acc.breg_Formation_State__c, 'Formation state should be set');
    }

    @isTest
    static void testApproved_createsIndividualAccount() {
        Case c = [
            SELECT
                Id,
                breg_Entity__c,
                breg_Form_Code__c,
                breg_Reg_Agent_Type__c,
                breg_Reg_Agent_First_Name__c,
                breg_Reg_Agent_Last_Name__c,
                breg_Registered_Agent_Address__Street__s,
                breg_Reg_Agent_Address_Street2__c,
                breg_Registered_Agent_Address__City__s,
                breg_Reg_Agent_Address_State__c,
                breg_Registered_Agent_Address__StateCode__s,
                breg_Registered_Agent_Address__PostalCode__s,
                breg_Registered_Agent_Address__CountryCode__s,
                breg_BRIM_FILE_NO__c,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Effective_Date__c,
                breg_Transaction_Code__c,
                breg_Form_Configuration__c,
                breg_Form_Configuration__r.breg_Transaction_Code__c,
                breg_Name_of_the_Entity__c,
                breg_Received_Date_Formula__c
            FROM Case
            WHERE breg_Reg_Agent_Type__c = 'Individual'
            LIMIT 1
        ];

        createCompletedPayment(c.Id);
        BREGCaseStatusHandlerCRARegistration handler = new BREGCaseStatusHandlerCRARegistration();

        Test.startTest();
        handler.handleStatusChange(new List<Case>{ c }, 'Approved', false, true);
        Test.stopTest();

        Case updatedCase = [SELECT breg_Entity__c FROM Case WHERE Id = :c.Id];
        System.assertNotEquals(null, updatedCase.breg_Entity__c, 'New account should be linked');

        Account acc = [
            SELECT
                Name,
                breg_BRIM_CRA_FL__c,
                breg_Registrant_Type__c,
                breg_Entity_Type__c,
                BillingStreet,
                breg_Billing_Address_Street_2__c,
                BillingCity,
                BillingStateCode,
                BillingPostalCode,
                BillingCountryCode
            FROM Account
            WHERE Id = :updatedCase.breg_Entity__c
        ];

        System.assertEquals('John Doe', acc.Name, 'Account name should be combination of first and last name');
        System.assertEquals(true, acc.breg_BRIM_CRA_FL__c, 'CRA flag should be set');
        System.assertEquals('Individual', acc.breg_Registrant_Type__c, 'Registrant type should be Individual');
        System.assertEquals('CA', acc.breg_Entity_Type__c, 'Entity type should be CA');
        System.assertEquals('123 New State St', acc.BillingStreet, 'Billing street should be set');
        System.assertEquals('Suite 200', acc.breg_Billing_Address_Street_2__c, 'Billing street 2 should be set');
        System.assertEquals('Honolulu', acc.BillingCity, 'Billing city should be set');
        System.assertEquals('HI', acc.BillingStateCode, 'Billing state should be set');
        System.assertEquals('96814', acc.BillingPostalCode, 'Billing postal code should be set');
        System.assertEquals('US', acc.BillingCountryCode, 'Billing country should be set');
    }

    @isTest
    static void testValidation_entityMissing_throwsError() {
        Case c = new Case(
            Subject = 'Invalid Case',
            Status = 'New',
            breg_File__c = '999999CA',
            breg_Reg_Agent_Type__c = 'Entity',
            breg_Effective_Date__c = System.today()
        );
        insert c;

        createCompletedPayment(c.Id);
        BREGCaseStatusHandlerCRARegistration handler = new BREGCaseStatusHandlerCRARegistration();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (Exception e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for missing entity');
        String caseEntityLabel = BREGUtils.returnFielLabelByApiName('Case', 'breg_Entity__c');
        System.assert(exceptionMessage.contains(caseEntityLabel), exceptionMessage + ' Exception message should indicate a missing required field.');
    }

    @isTest
    static void testValidation_entityNotActive() {
        Id accRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account inactiveAcc = new Account(Name = 'Inactive', RecordTypeId = accRtId, breg_Entity_Status__c = 'New (Y)', breg_File__c = '654321CA');
        insert inactiveAcc;

        Case c = new Case(
            Subject = 'Inactive Entity Case',
            Status = 'New',
            breg_File__c = '654321CA',
            breg_Reg_Agent_Type__c = 'Entity',
            breg_Entity__c = inactiveAcc.Id,
            breg_Effective_Date__c = System.today()
        );
        insert c;

        createCompletedPayment(c.Id);

        BREGCaseStatusHandlerCRARegistration handler = new BREGCaseStatusHandlerCRARegistration();

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        try {
            handler.handleStatusChange(new List<Case>{ c }, 'Approved', true, false);
        } catch (BREGCaseStatusHandlerUtils.BREGCaseStatusHandlerException e) {
            exceptionThrown = true;
            exceptionMessage = e.errorMessage;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown for inactive entity');
        System.assert(exceptionMessage.contains('Entity should be Active to proceed'), ' Exception Message should indicate inactive status');
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
}