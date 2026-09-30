@isTest
private class ContentDocumentTriggerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createExams();
    }
    @isTest
    private static void testBeforeDelete() {
        Test.startTest();
        GlobalConstants.SYSTEMADMIN = 'Test Admin';
        FileDetails__c fileDetail = [Select Id from FileDetails__c];
        List<ContentDocumentLink> links = [Select ContentDocumentId, Id from ContentDocumentLink where LinkedEntityId =: fileDetail.Id];

        try{
            //Create ContentDocumentLink
            List<ContentDocument> docs = [Select Id from ContentDocument where Id =: links.get(0).ContentDocumentId];
            delete docs;
        } catch(Exception ex) {

        } 
    }
    
}