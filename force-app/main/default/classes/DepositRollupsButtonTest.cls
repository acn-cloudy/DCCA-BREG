/********************************************************************************************************
*    Name:  DepositRollupsButtonTest.cls
*    Author: PacificPoint 
*    Date:  4/7/2018
*    
*    Class: DepositRollupsButton.cls
********************************************************************************************************/
@isTest
public class DepositRollupsButtonTest{
    
    private static testmethod void testDepositRollupsButton(){
        
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
        currentYearPayment1.pymt__Payment_Type__c = 'Cash';
        currentYearPayment1.DepositBatch__c = xDeposit.Id;
        payments.add(currentYearPayment1);

        pymt__PaymentX__c currentYearPayment2 = new pymt__PaymentX__c();
        currentYearPayment2.pymt__Status__c = 'Completed';
        currentYearPayment2.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment2.RemitToDCCA__c = 50; 
        currentYearPayment2.PPIFeeAmount__c = 100;
        currentYearPayment2.HIGETaxAmount__c = 150; 
        currentYearPayment2.pymt__Payment_Type__c = 'Check or Money Order';
        currentYearPayment2.DepositBatch__c = xDeposit.Id;
        payments.add(currentYearPayment2);
        
        pymt__PaymentX__c currentYearPayment3 = new pymt__PaymentX__c();
        currentYearPayment3.pymt__Status__c = 'Completed';
        currentYearPayment3.pymt__Date__c = Date.newInstance(sd.year(),1,12);
        currentYearPayment3.RemitToDCCA__c = 50; 
        currentYearPayment3.PPIFeeAmount__c = 100;
        currentYearPayment3.HIGETaxAmount__c = 150; 
        currentYearPayment3.pymt__Payment_Type__c = 'Credit Card';
        currentYearPayment3.DepositBatch__c = xDeposit.Id;
        payments.add(currentYearPayment3);
        
        insert payments;

        Test.StartTest();
            Apexpages.StandardController sc = new Apexpages.StandardController(xDeposit);
            DepositRollupsButton DRB = new DepositRollupsButton(sc);
            DRB.StartRollupBatch();
        Test.StopTest();
        
        Deposits__c deposit = [SELECT Id, NetCollectionsafterFees__c, PPIFeesfromCashCheckMoneyOrders__c, HIGETaxfromCashCheckMoneyOrders__c FROM Deposits__c];
    
        System.assertEquals(150, deposit.NetCollectionsafterFees__c);
        System.assertEquals(200, deposit.PPIFeesfromCashCheckMoneyOrders__c);
        System.assertEquals(300, deposit.HIGETaxfromCashCheckMoneyOrders__c);
        
    }
}