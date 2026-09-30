@isTest
private class ContentDocumentLinkTriggerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createExams();
    }
    public static testmethod void testCreateContentDocumentLinks() {
        
        TravelApproval__c record = new TravelApproval__c();
        record.NameOfTraveler__c = 'test record';
        record.ContactPerson__c = 'Name 1';
        record.ContactPersonEmail__c = 'testrecord2@sample.com';
        insert record;
        dsfs__DocuSign_Status__c statusRec = new dsfs__DocuSign_Status__c();
        statusRec.TravelApproval__c = record.Id;
        insert statusRec;

        String docName = 'test.pdf';
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = Blob.valueOf('Test Data');
        cv.Title = docName;
        cv.PathOnClient = '/'+docName;
        
        insert cv;
        
        // First get the content document Id from ContentVersion
        Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

        Test.startTest();
        //Create ContentDocumentLink
        ContentDocumentLink cDe = new ContentDocumentLink();
        cDe.ContentDocumentId = conDoc;
        cDe.LinkedEntityId = statusRec.Id;
        cDe.ShareType = 'I';
        cDe.Visibility = 'AllUsers';
        insert cDe;

    }
    @isTest
    private static void testBeforeDeleteInsert() {
        Test.startTest();
        GlobalConstants.SYSTEMADMIN = 'Test Admin';
        FileDetails__c fileDetail = [Select Id from FileDetails__c];
        List<ContentDocumentLink> links = [Select ContentDocumentId, Id from ContentDocumentLink where LinkedEntityId =: fileDetail.Id];

        try{   
            delete links;
        } catch(Exception ex) {

        }
        try{
            //Create ContentDocumentLink
            ContentDocumentLink cDe = new ContentDocumentLink();
            cDe.ContentDocumentId = links.get(0).Id;
            cDe.LinkedEntityId = fileDetail.Id;
            cDe.ShareType = 'I';
            cDe.Visibility = 'AllUsers';
            insert cDe;
        } catch(Exception ex) {

        }
    }
}