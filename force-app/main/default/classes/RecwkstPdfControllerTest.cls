@isTest
public with sharing class RecwkstPdfControllerTest {
    public static testMethod void testFunc() {
        Schema.DescribeSObjectResult d = Schema.SObjectType.FiscalForm__c; 
        Map<String ,Schema.RecordTypeInfo> rtMapById = d.getRecordTypeInfosByName();
        String recordTypeId =  rtMapById.get('RECWKST').getRecordTypeId();
        String data = + '{"runningUser":{"attributes":{"type":"User"},"FirstName":"Alvin","LastName":"Zhou"},"batchDate":"2020-11-02","runningName":"Alvin Zhou","batchDate2":"2020-11-02","terminal3TotalCash":0,"terminal13TotalCash":0,'
        +' "terminal3TotalCoins":0,"terminal13TotalCoins":0,"terminal3TotalCheck":0,"terminal13TotalCheck":0,"tape1Check":0,"tape2Check":0,"tape3Check":0,"tape4Check":0,"tape5Check":0,"tape6Check":0,"tape1CheckTextarea":"",'
        +' "tape2CheckTextarea":"","tape3CheckTextarea":"","tape4CheckTextarea":"","tape5CheckTextarea":"","tape6CheckTextarea":"","moreTapesCheck":[],"calculatedValue":0,"gov3TotalCheck":0,"gov13TotalCheck":0,"totalDeposit":0,'
        +' "totalCash":0,"totalCoins":0,"totalReceipt":0,"depositNotesTextarea":""}';
        String recordId = PaymentRecwkstCmpController.saveAndCreateFile(null, data, recordTypeId);
        FiscalForm__c ff = [Select Id, Request__c, RecordTypeId from FiscalForm__c where Id =: recordId];
        ApexPages.StandardController std = new ApexPages.StandardController(ff);
        
        RecwkstPdfController ctr = new RecwkstPdfController(std);
        ctr.getCreatingUser();
        ctr.getMoreTapes();
        ctr.getRunningName();
        ctr.getDepositNotesTextarea();
        ctr.getBatchDate2();
        ctr.getBatchDate();
        ctr.getCalculatedValue();
        ctr.getTerminal3TotalCash();
        ctr.getTerminal13TotalCash();
        ctr.getTerminal3TotalCheck();
        ctr.getTerminal13TotalCheck();
        ctr.getTerminal3TotalCoins();
        ctr.getTerminal13TotalCoins();
        ctr.getTape1CheckTextarea();
        ctr.getTape2CheckTextarea();
        ctr.getTape3CheckTextarea();
        ctr.getTape4CheckTextarea();
        ctr.getTape5CheckTextarea();
        ctr.getTape6CheckTextarea();
        ctr.getTape1Check();
        ctr.getTape2Check();
        ctr.getTape3Check();
        ctr.getTape4Check();
        ctr.getTape5Check();
        ctr.getTape6Check();
        ctr.getGov3TotalCheck();
        ctr.getGov13TotalCheck();
        ctr.getTotalCash();
        ctr.getTotalCoins();
        ctr.getTotalDeposit();
        ctr.getTotalReceipt();
    }
}