/********************************************************************************************************
*    Name:  DepositRollupsBatchProgressTest.cls
*    Author: PacificPoint 
*    Date:  10/16/2018
*    
*    Class: DepositRollupsBatchProgress.cls
********************************************************************************************************/
@isTest
public class PaymentXBatchProgressTest{
    
    private static testmethod void testDepositRollupsBatchProgress(){
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;
        
        
        date sd = Date.Today();
        
        Deposits__c xDeposit = new Deposits__c();
        xDeposit.DepositDate__c = sd;
        xDeposit.DepositNumber__c = '223322';
        xDeposit.DepositNumber__c = 'Draft';
        insert xDeposit;
        
        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();
        
        pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
        currentYearPayment1.pymt__Status__c = 'Completed';
        currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment1.RemitToDCCA__c = 50; 
        currentYearPayment1.PPIFeeAmount__c = 100;
        currentYearPayment1.HIGETaxAmount__c = 150; 
        currentYearPayment1.DepositBatch__c = xDeposit.Id;
        currentYearPayment1.pymt__Payment_Type__c = 'Cash';
        payments.add(currentYearPayment1);

        pymt__PaymentX__c currentYearPayment2 = new pymt__PaymentX__c();
        currentYearPayment2.pymt__Status__c = 'Completed';
        currentYearPayment2.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment2.RemitToDCCA__c = 50; 
        currentYearPayment2.PPIFeeAmount__c = 100;
        currentYearPayment2.HIGETaxAmount__c = 150; 
        currentYearPayment2.DepositBatch__c = xDeposit.Id;
        currentYearPayment2.pymt__Payment_Type__c = 'Check or Money Order';
        payments.add(currentYearPayment2);
        
        pymt__PaymentX__c currentYearPayment3 = new pymt__PaymentX__c();
        currentYearPayment3.pymt__Status__c = 'Completed';
        currentYearPayment3.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment3.RemitToDCCA__c = 50; 
        currentYearPayment3.PPIFeeAmount__c = 100;
        currentYearPayment3.HIGETaxAmount__c = 150; 
        currentYearPayment3.DepositBatch__c = xDeposit.Id;
        currentYearPayment3.pymt__Payment_Type__c = 'Credit Card';
        payments.add(currentYearPayment3);
        
        insert payments;

        Test.StartTest();
            PaymentXBatchProgress PXBP = New PaymentXBatchProgress();
            PXBP.StartPaymentXBatch();
            PXBP.BacktolistView();
        Test.StopTest();
         
    }
}