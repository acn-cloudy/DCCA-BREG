@isTest
public with sharing class FilingControlerTest {
    private static testMethod void testFunction() {
        Account acc = new Account();
        acc.Name = 'Test 398624';
        acc.BPID__c = '2323442';
        insert acc;
        String recordSTR = FilingController.getRecord('Account', acc.Id, ' Id, Name, BPID__c ');
        List<Account> records = (List<Account>)JSON.deserialize(recordSTR, List<Account>.class);
        FilingController.updateRecord(JSON.serialize(records.get(0)));
    }
}