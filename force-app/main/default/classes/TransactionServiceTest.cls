@isTest
public with sharing class TransactionServiceTest {
    public static testMethod void testDelet() {
        TestDataFactory.createTransaction();
        List<Transaction__c> records = [Select Id, Status__c, Application__c, Application__r.LicensePeriod__c, Description__c from Transaction__c];
        TransactionService.reGenerateTransactionLines(records);
    }
}