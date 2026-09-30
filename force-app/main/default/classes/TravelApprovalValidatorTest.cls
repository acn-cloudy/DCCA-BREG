@isTest
private class TravelApprovalValidatorTest {
    @TestSetup
    static void makeData(){
        TravelApproval__c record = new TravelApproval__c();
        record.NameOfTraveler__c = 'test record';
        record.TravelerEmail__c = 'testrecord@sample.com';
        record.TravelType__c = 'OCONUS (Foreign or Alaska)';
        record.ContactPersonEmail__c = 'testrecord1@sample.com';
        record.BusinessOnlyReturnDate__c = Date.today().addDays(-31);
        record.ContactPerson__c = 'Name 1';
        insert record;

        TravelApproval__c record2 = new TravelApproval__c();
        record2.NameOfTraveler__c = 'test record';
        record2.TravelType__c = 'OCONUS (Foreign or Alaska)';
        record2.ContactPersonEmail__c = 'testrecord2@sample.com';
        record2.TravelerEmail__c = 'testrecord@sample.com';
        record2.ContactPerson__c = 'Name 2';
        insert record2;

        
    }
    @isTest
    static void testValidatedTravelApprovals() {
        TravelApproval__c record = [Select Id from TravelApproval__c where ContactPerson__c = 'Name 2'];
        List<TravelApproval__c> records = TravelApprovalValidator.validatedTravelApprovals(record.Id);
        System.assert(!records.isEmpty());
    }

    @isTest
    static void testRedirectURL() {
        TravelApproval__c record = [Select Id from TravelApproval__c limit 1];
        String url = TravelApprovalValidator.redirectURL(record.Id, 'test');
        System.assert(url != null);
    }

}