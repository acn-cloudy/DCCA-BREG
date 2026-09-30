@isTest
public with sharing class BREGPaymentTriggerHandlerTest {
    @testSetup
    public static void setupTransactionLine() {
        BREGTestDataFactory.createTransactionLineForEntityList(null);
    }

    private static Case createTestCase() {
        Account acc = BREGTestDataFactory.createEntityAccounts(1)[0];

        return new Case(
            Subject = 'Test Case',
            Origin = 'Web',
            Status = 'New',
            breg_Entity__c = acc.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId()
        );
    }

    @isTest
    static void testRefundWithParent_setsField() {
        pymt__PaymentX__c payment = [SELECT Id, Transaction__c FROM pymt__PaymentX__c ORDER BY CreatedDate DESC LIMIT 1];
        TransactionLine__c line = [SELECT Id FROM TransactionLine__c WHERE Payment__c = :payment.Id ORDER BY CreatedDate DESC LIMIT 1];
        Case c = createTestCase();
        insert c;

        TransactionLine__c lineToUpdate = [SELECT Id FROM TransactionLine__c WHERE Id = :line.Id];
        lineToUpdate.breg_Case__c = c.Id;
        update lineToUpdate;

        pymt__PaymentX__c parent = [SELECT Id, Transaction__c FROM pymt__PaymentX__c WHERE Id = :payment.Id];

        pymt__PaymentX__c childRefund = new pymt__PaymentX__c(
            Name = 'Refund Child',
            pymt__Parent_Transaction__c = parent.Id,
            Transaction__c = parent.Transaction__c
        );
        insert childRefund;

        Case updated = [SELECT breg_Refund_Payment__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(childRefund.Id, updated.breg_Refund_Payment__c, 'Child refund payment should be set on case');
    }

    @isTest
    static void testNonRefundPayment_doesNotSetField() {
        pymt__PaymentX__c payment = [SELECT Id, Transaction__c FROM pymt__PaymentX__c ORDER BY CreatedDate DESC LIMIT 1];
        TransactionLine__c line = [SELECT Id FROM TransactionLine__c WHERE Payment__c = :payment.Id ORDER BY CreatedDate DESC LIMIT 1];
        Case c = createTestCase();
        insert c;

        TransactionLine__c lineToUpdate = [SELECT Id FROM TransactionLine__c WHERE Id = :line.Id];
        lineToUpdate.breg_Case__c = c.Id;
        update lineToUpdate;

        pymt__PaymentX__c normal = new pymt__PaymentX__c(
            Name = 'Normal Payment',
            Transaction__c = [SELECT Transaction__c FROM pymt__PaymentX__c WHERE Id = :payment.Id]
            .Transaction__c
        );
        insert normal;

        Case updated = [SELECT breg_Refund_Payment__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(null, updated.breg_Refund_Payment__c, 'Non-refund payment should not set field');
    }

    @isTest
    static void testRefundWithTransactionNoCase_doesNotCrash() {
        pymt__PaymentX__c payment = [SELECT Id, Transaction__c FROM pymt__PaymentX__c ORDER BY CreatedDate DESC LIMIT 1];
        TransactionLine__c line = [SELECT Id FROM TransactionLine__c WHERE Payment__c = :payment.Id ORDER BY CreatedDate DESC LIMIT 1];
        pymt__PaymentX__c parent = [SELECT Id, Transaction__c FROM pymt__PaymentX__c WHERE Id = :payment.Id];

        TransactionLine__c lineToUpdate = [SELECT Id FROM TransactionLine__c WHERE Id = :line.Id];
        lineToUpdate.breg_Case__c = null;
        update lineToUpdate;

        pymt__PaymentX__c refund = new pymt__PaymentX__c(
            Name = 'Refund With No Case',
            pymt__Parent_Transaction__c = parent.Id,
            Transaction__c = parent.Transaction__c
        );
        insert refund;

        System.assert(true, 'Trigger should not throw when refund has no related case');
    }

    @IsTest
    static void beforeInsert_setsAccountFromStandardContactWhenAccountBlank() {
        Account acc = BREGTestDataFactory.createEntityAccounts(1)[0];
        Contact payer = new Contact(FirstName = 'Std', LastName = 'Payer', AccountId = acc.Id);
        insert payer;

        Transaction__c trans = new Transaction__c(Division__c = 'BREG');
        insert trans;

        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'Contact-only payment',
            Transaction__c = trans.Id,
            pymt__Contact__c = payer.Id
        );
        insert payment;

        payment = [SELECT pymt__Account__c FROM pymt__PaymentX__c WHERE Id = :payment.Id];
        Assert.areEqual(acc.Id, payment.pymt__Account__c, 'pymt__Account__c should default from Contact.AccountId');
    }

    @IsTest
    static void beforeInsert_setsAccountFromPersonContactWhenAccountBlank() {
        Schema.RecordTypeInfo personRt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount');
        if (personRt == null || !personRt.isAvailable()) {
            Assert.isTrue(true, 'PersonAccount record type not available; skipping person-account scenario');
            return;
        }

        Account person = new Account(
            FirstName = 'Pay',
            LastName = 'PersonAcct',
            RecordTypeId = personRt.getRecordTypeId()
        );
        insert person;

        Account personReload = [SELECT PersonContactId FROM Account WHERE Id = :person.Id];
        Id personContactId = personReload.PersonContactId;

        Transaction__c trans = new Transaction__c(Division__c = 'BREG');
        insert trans;

        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'Person contact payment',
            Transaction__c = trans.Id,
            pymt__Contact__c = personContactId
        );
        insert payment;

        payment = [SELECT pymt__Account__c FROM pymt__PaymentX__c WHERE Id = :payment.Id];
        Assert.areEqual(person.Id, payment.pymt__Account__c, 'Person Contact should map pymt__Account__c to the Person Account');
    }

    @IsTest
    static void afterInsert_setsTransactionAccountFromPayment() {
        Account acc = BREGTestDataFactory.createEntityAccounts(1)[0];
        Transaction__c trans = new Transaction__c(Division__c = 'BREG');
        insert trans;

        pymt__PaymentX__c payment = new pymt__PaymentX__c(
            Name = 'BREG payment with account',
            Transaction__c = trans.Id,
            pymt__Account__c = acc.Id
        );
        insert payment;

        trans = [SELECT Account__c FROM Transaction__c WHERE Id = :trans.Id];
        Assert.areEqual(acc.Id, trans.Account__c, 'Transaction.Account__c should match payment pymt__Account__c for BREG division');
    }
}