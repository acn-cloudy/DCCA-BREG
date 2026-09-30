@isTest
public with sharing class PaymentRecwkstCmpControllerTest {
    @TestSetup
    static void makeData(){
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
        
        Transaction__c trns1 = new Transaction__c();
        trns1.Account__c = acc.Id;
        trns1.WorkitemID__c = '1';
        insert trns1;
        
        TransactionLine__c trLine = new TransactionLine__c();
        trLine.Transaction__c = trns1.Id;
        insert trLine;
        
        CollectionsAllocation__c alloc = new CollectionsAllocation__c();
        alloc.Deposit__c = xDeposit.Id;
        alloc.TransactionLine__c = trLine.Id;
        alloc.CutOffBatchDate__c = System.now();
        alloc.Payment__c = currentYearPayment1.Id;
        insert alloc;
    }
    public static testMethod void testReport() {
        PaymentRecwkstCmpController.runReport(Date.Today().addDays(-400));
        List<pymt__PaymentX__c> payments = [
            SELECT
                    Id,
                    pymt__Payment_Type__c,
                    pymt__Amount__c,
                    CreatedBy.Terminal__c
            FROM pymt__PaymentX__c];
        for(pymt__PaymentX__c record: payments) {
            record.pymt__Amount__c = 233.32;
        }
        PaymentRecwkstCmpController.RecwkstReport rec = new PaymentRecwkstCmpController.RecwkstReport(payments);
    }
    public static testMethod void testSaveAndCreateFile() {
        Schema.DescribeSObjectResult d = Schema.SObjectType.FiscalForm__c; 
        Map<String ,Schema.RecordTypeInfo> rtMapById = d.getRecordTypeInfosByName();
        String recordTypeId =  rtMapById.get('RECWKST').getRecordTypeId();
        String data = + '{"runningUser":{"attributes":{"type":"User"},"FirstName":"Alvin","LastName":"Zhou"},"batchDate":"2020-11-02","runningName":"Alvin Zhou","batchDate2":"2020-11-02","terminal3TotalCash":0,"terminal13TotalCash":0,'
        +' "terminal3TotalCoins":0,"terminal13TotalCoins":0,"terminal3TotalCheck":0,"terminal13TotalCheck":0,"tape1Check":0,"tape2Check":0,"tape3Check":0,"tape4Check":0,"tape5Check":0,"tape6Check":0,"tape1CheckTextarea":"",'
        +' "tape2CheckTextarea":"","tape3CheckTextarea":"","tape4CheckTextarea":"","tape5CheckTextarea":"","tape6CheckTextarea":"","moreTapesCheck":[],"calculatedValue":0,"gov3TotalCheck":0,"gov13TotalCheck":0,"totalDeposit":0,'
        +' "totalCash":0,"totalCoins":0,"totalReceipt":0,"depositNotesTextarea":""}';
        String recordId = PaymentRecwkstCmpController.saveAndCreateFile(null, data, recordTypeId);
        PaymentRecwkstCmpController.getCutOffDate(recordId);

    }
}