public with sharing class JVFormController {
    public List<Map<String, Object>> allRecords {set;get;}
    public List<FiscalFormFeed> values {set;get;}
    public JVFormController() {
        values = new List<FiscalFormFeed>();
        
        String recordId = System.currentPageReference().getParameters().get('recordId');
        if(recordId != null) {
            FiscalForm__c record = [Select Id, StartDate__c, EndDate__c, Request__c
             from FiscalForm__c where Id =: recordId ];
             String request = record.Request__c; 
             values = (List<FiscalFormFeed>)JSON.deserialize(request, List<FiscalFormFeed>.class);
        } else {
            
            FiscalFormFeed formFeed = new FiscalFormFeed();
            formFeed.bankDeposit = '99999.99';
            formFeed.dateStr = '99/99/9999';
            formFeed.detailFund = 'detailFund REGISTRATION - CRF';
            formFeed.fundName = 'fundName';
            formFeed.remarks = '02/25.26.27 First Hawaii';
            formFeed.remarks = 'remarks remarksremarks remark  sremar ksremarksremarksremarks';
            formFeed.totalDeposit = '99999.99';
            formFeed.totalDeposit2 = '9999.99';

            FiscalFormFeed.DataFeed dateFeed = new FiscalFormFeed.DataFeed();
            dateFeed.indexValue = '99';
            dateFeed.tcValue = '999';
            dateFeed.sValue = 'S';
            dateFeed.yrValue = '99';
            dateFeed.appValue = '999';
            dateFeed.dValue = 'P';
            dateFeed.sourceObjValue = '9999';
            dateFeed.costCenterValue = '9999';
            dateFeed.amount = 99999.99;

            List<FiscalFormFeed.DataFeed> fundsList = new List<FiscalFormFeed.DataFeed>();
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);
            fundsList.add(dateFeed);

            formFeed.funds = fundsList;

            values.add(formFeed);
            values.add(formFeed);
            values.add(formFeed);
            values.add(formFeed);
            values.add(formFeed);
            values.add(formFeed);
        }

    }
}