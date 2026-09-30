@isTest
private class TravelApprovalTriggerTest {
    @isTest
    private static void testInsertTrigger() {
        TravelApproval__c record = new TravelApproval__c();
        record.NameOfTraveler__c = 'test record';
        record.ContactPersonEmail__c = 'testrecord2@sample.com';
        record.ContactPerson__c = 'Name 1';
        insert record;

    }
}