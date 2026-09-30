@isTest
private class AssociatedLicenseExpireTest {
    @isTest
    static void testTerminateAssociatedLicense() {
        TestDataFactory.prepareAssociatedLicenses();
        
        Map<Id, Date> lId2TerminateDate = new Map<Id, Date>();
        List<AssociatedLicense__c> records = [Select Id from AssociatedLicense__c ];
        for(AssociatedLicense__c record: records) {
            lId2TerminateDate.put(record.Id, Date.today());
        }
        Test.startTest();
        Database.executeBatch(new AssociatedLicenseExpire(lId2TerminateDate));
        
        Test.stopTest();

    }
}