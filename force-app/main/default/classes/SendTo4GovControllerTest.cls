/*
* ─────────────────────────────────────────────────────────
* SendTo4GovControllerTest Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ171019 - Created for PVL 4Gov Integration
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-10-17
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
@isTest(seeAllData = false)
public class SendTo4GovControllerTest {
   @TestSetup
    static void setup() {
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

		Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 100.00;
        trn.Contact__c = cnt.Id;
        insert trn;

        CashierCode__c cc1 = new CashierCode__c();
        cc1.Name = 'Cashier Code 1';
        cc1.Amount__c = 70;
        cc1.CashierCode__c = '000011';
        cc1.Category__c = 'Categ1';
        cc1.Division__c = 'BREG';
        insert cc1;

        TransactionLine__c tl11 = new TransactionLine__c();
        tl11.Transaction__c = trn.Id;
        tl11.Amount__c = 30;
        tl11.CashierCode__c = cc1.Id;
        tl11.Description__c = 'aaa';
        tl11.PaidStatus__c = 'Paid';
        insert tl11;

        pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
        currentYearPayment1.pymt__Status__c = 'Completed';
        currentYearPayment1.pymt__Date__c = system.today();
        currentYearPayment1.CreditCardFee__c = 20;
        currentYearPayment1.pymt__Transaction_Fee__c  = 50;
        currentYearPayment1.pymt__Amount__c = 1000;
        currentYearPayment1.Transaction__c = trn.Id;
        insert currentYearPayment1;

        CollectionsAllocation__c ca = new CollectionsAllocation__c();
        ca.Transaction__c = trn.id;
        ca.AmountAllocated__c = 200;
        ca.TransactionLine__c = tl11.id;
        ca.Payment__c = currentYearPayment1.Id;
        ca.CutOffBatchDate__c = system.today() - 1;
        insert ca;
    }

    @IsTest
    static void testSendTo4GovController() {
        Reconciliation_Batch__c rb = new Reconciliation_Batch__c();
        rb.Status__c = 'Pending Review';
        rb.Batch_Time__c = system.today() - 1;
        insert rb;

        Reconciliation_Batch__c rbNew = [select Id, Name from Reconciliation_Batch__c where id =: rb.Id];
        //Create File Attached
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = Blob.valueOf('test');
        cv.Title = rbNew.Name + '.csv';
        cv.PathOnClient = rbNew.Name;
        insert cv;
                    
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: cv.Id].ContentDocumentId;
        cdl.LinkedEntityId = rbNew.Id;
        cdl.ShareType = 'I';
        insert cdl;

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(rb);
        SendTo4GovController testBatch = new SendTo4GovController(sc);
        
        PageReference pageRef = Page.SendTo4Gov;
        pageRef.getParameters().put('id', String.valueOf(rb.Id));
        Test.setCurrentPage(pageRef);
        
        testBatch.sendEmailAtt();
        testBatch.doCancel();
        Test.stopTest();
    }
}