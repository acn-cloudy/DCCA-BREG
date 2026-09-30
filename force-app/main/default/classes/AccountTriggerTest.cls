@isTest
private class AccountTriggerTest {
    private static testmethod void tesCreatAccount() {
        String recordTypeId 
            = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(FirstName = 'Test Account', LastName='aaa', RecordTypeId = recordTypeId);
        
        insert acc;
        acc.PersonMailingStreet = 'test street';
        acc.FirstName = 'test UpdatedName';
        update acc;
    }
    
}