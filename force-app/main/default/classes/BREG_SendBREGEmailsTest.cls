@isTest
private class BREG_SendBREGEmailsTest {
    @testSetup
    private static void setup() {
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;

        CashierCode__c cc1 = new CashierCode__c();
        cc1.Description__c = 'test1 - 5';
        cc1.Name = 'cc1';

        CashierCode__c cc2 = new CashierCode__c();
        cc2.Description__c = 'test1';
        cc2.Name = 'cc1';

        insert new CashierCode__c[]{cc1, cc2};

        TransactionLine__c tl1 = new TransactionLine__c();
        tl1.CashierCode__c = cc1.Id;
        tl1.Transaction__c = trn.Id;
        tl1.Amount__c = 20;

        TransactionLine__c tl2 = new TransactionLine__c();
        tl2.CashierCode__c = cc2.Id;
        tl2.Transaction__c = trn.Id;
        tl2.Amount__c = 85;

        insert new TransactionLine__c[]{tl1, tl2};

        FeeSchedule__c fs = new FeeSchedule__c();
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 110;
        pymt.pymt__Payment_Type__c = 'Cash';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        pymt.pymt__Billing_Email__c = 'testSample@test.com';
        pymt.pymt__Transaction_Id__c = 'TXN-123456';
        pymt.pymt__Payment_Type__c = 'Credit Card';
        insert pymt;        
    }
    @isTest
    private static void testSendBREGEmailsWithFiling() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Filing__c filing = new Filing__c();
        filing.Name = 'Test 398624';
        insert filing;

        Transaction__c trn = [SELECT Id FROM Transaction__c LIMIT 1];
        trn.Filing__c = filing.Id;
        update trn;

        pymt__PaymentX__c pymt = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        BREG_SendBREGEmails.sendBREGEmails(new List<Id> {pymt.Id});
        Test.stopTest();
    }

    @isTest
    private static void testSendBREGEmailsWithTransactionLineItems() {
        pymt__PaymentX__c pymt = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        BREG_SendBREGEmails.sendBREGEmails(new List<Id> {pymt.Id});
        Test.stopTest();
    }

    @isTest
    private static void testSendBREGRefundEmail() {
        pymt__PaymentX__c payment = [
            SELECT
                Id,
                Transaction__c,
                pymt__Amount__c,
                pymt__Transaction_Type__c
            FROM pymt__PaymentX__c
            LIMIT 1
        ];

        RecordType refundCaseRecordType = [
            SELECT
                Id,
                Name,
                DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Case'
                AND Name = 'BREG Refund Request Case'
            LIMIT 1
        ];

        Case refundCase = new Case(
            RecordTypeId = refundCaseRecordType.Id,
            Subject = 'Refund test case',
            Status = 'New',
            Origin = 'Web',
            breg_Total_Refund_Amount__c = 50
        );
        insert refundCase;

        refundCase = [
            SELECT
                Id,
                RecordTypeId,
                RecordType.Name,
                RecordType.DeveloperName,
                breg_Total_Refund_Amount__c
            FROM Case
            WHERE Id = :refundCase.Id
        ];

        System.assertEquals(
            'BREG Refund Request Case',
            refundCase.RecordType.Name,
            'Refund Case must have the Record Type required by the breg_Refund_Case__c lookup filter.'
        );

        List<TransactionLine__c> transactionLines = [
            SELECT
                Id,
                Transaction__c,
                RefundAmount__c,
                breg_Refund_Case__c,
                breg_Quantity__c
            FROM TransactionLine__c
            WHERE Transaction__c = :payment.Transaction__c
            ORDER BY CreatedDate
        ];

        System.assertEquals(
            2,
            transactionLines.size(),
            'The test setup should contain two Transaction Lines.'
        );

        transactionLines[0].RefundAmount__c = 20;
        transactionLines[0].breg_Refund_Case__c = refundCase.Id;
        transactionLines[0].breg_Quantity__c = 1;

        transactionLines[1].RefundAmount__c = 30;
        transactionLines[1].breg_Refund_Case__c = refundCase.Id;
        transactionLines[1].breg_Quantity__c = 1;

        update transactionLines;

        payment.pymt__Transaction_Type__c = 'Refund';
        update payment;

        Test.startTest();

        BREG_SendBREGEmails.sendBREGEmails(
            new List<Id>{ payment.Id }
        );

        Test.stopTest();

        pymt__PaymentX__c updatedPayment = [
            SELECT
                pymt__Transaction_Type__c,
                pymt__Amount__c
            FROM pymt__PaymentX__c
            WHERE Id = :payment.Id
        ];

        System.assertEquals(
            'Refund',
            updatedPayment.pymt__Transaction_Type__c
        );

        List<TransactionLine__c> updatedLines = [
            SELECT
                RefundAmount__c,
                breg_Refund_Case__c
            FROM TransactionLine__c
            WHERE Transaction__c = :payment.Transaction__c
                AND RefundAmount__c != null
            ORDER BY CreatedDate
        ];

        System.assertEquals(2, updatedLines.size());
        System.assertEquals(20, updatedLines[0].RefundAmount__c);
        System.assertEquals(30, updatedLines[1].RefundAmount__c);
        System.assertEquals(refundCase.Id, updatedLines[0].breg_Refund_Case__c);
        System.assertEquals(refundCase.Id, updatedLines[1].breg_Refund_Case__c);
    }
}