@isTest
public with sharing class LookupServiceTest {
    public static testMethod void testLookup() {
        Account record = TestDataFactory.createAccountUnit('test aas', '24234234');
        insert record;
        System.assert(LookupService.getSearchResults(record.Name, 'Name', 'Account',null, null) != null);
        System.assert(LookupService.getSearchResults('t', 'Name', 'Account', ' name != null ', null) != null);
    }
}