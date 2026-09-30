@isTest
public class UploadCaseFileToDocSignQueueableTest {
    @isTest
    static void test_execute() {
        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'Account', 
            PersonEmail = 'test@Account.com',
            RecordTypeId = Schema.SobjectType.Account.getRecordTypeInfosByDeveloperName().get('Complainant').getRecordTypeId()
        );
        insert acc;

        Case c = new Case();
        c.RecordTypeId = Schema.SobjectType.Case.getRecordTypeInfosByDeveloperName().get('CATV_Complaint').getRecordTypeId();
        c.AccountId = acc.Id;
        c.Type = 'My Type';
        c.Origin = 'My Origin';
        c.Status = 'My Status';
        insert c;

        String docName = 'test.pdf';
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = Blob.valueOf('Test Data');
        cv.Title = docName;
        cv.PathOnClient = '/'+docName;
        
        insert cv;
        
        Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

        Test.startTest();
        ContentDocumentLink cDe = new ContentDocumentLink();
        cDe.ContentDocumentId = conDoc;
        cDe.LinkedEntityId = c.Id;
        cDe.ShareType = 'I';
        cDe.Visibility = 'AllUsers';
        insert cDe;
        Test.stopTest();
    }
}