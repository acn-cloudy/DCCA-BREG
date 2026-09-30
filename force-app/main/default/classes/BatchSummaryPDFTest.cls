@isTest
public with sharing class BatchSummaryPDFTest {
    public static testMethod void testSummary() {
        Transaction__c record = TestDataFactory.createTransaction();
        Map<String, String> obj = new Map<String, String>();
        obj.put('Transaction__c', 'Name');
        List<Map<String, String>> objs = new List<Map<String, String>>();
        objs.add(obj);
        Map<String, Object> rec = new Map<String, Object>();
        rec.put('data', objs);
        ApexPages.currentPage().getParameters().put('printFields', JSON.serialize(rec));
        ApexPages.currentPage().getParameters().put('batch', record.BatchNumber__c);
        BatchSummaryPDF pdfFile = new BatchSummaryPDF();


    }
}