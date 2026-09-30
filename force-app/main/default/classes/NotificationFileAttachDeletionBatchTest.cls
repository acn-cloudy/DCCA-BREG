/*
 * -----------------------------------------------------------------------------------
 * Description
 * Unit test for NotificationDeletionBatch
 * -----------------------------------------------------------------------------------
 * PacPoint-CL05182022 - Created for PVL Case 00021633
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 05/18/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private  class NotificationFileAttachDeletionBatchTest {
    @TestSetup
    static void setup() {
        Notification__c notif = new Notification__c();
        notif.Status__c = 'Completed';

        insert notif;

        ContentVersion contentVersion = new ContentVersion(
                    Title          = 'a picture',         
                    PathOnClient   = 'Pic.jpg',           
                    VersionData    = Blob.valueOf('Test Content'),
                    IsMajorVersion = true);
        insert contentVersion;

        List<ContentDocument> cDocs = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];

        ContentDocumentLink cDocLink = new ContentDocumentLink();
        cDocLink.LinkedEntityId = notif.Id;
        cDocLink.ContentDocumentId = cDocs[0].Id;
        
        insert cDocLink;
        
        Test.setCreatedDate(notif.Id, Datetime.now().addDays(-8));        
    }

    @IsTest
    static void testBatch() {
        Test.startTest();
        String CRON_EXP = '0 0 0 3 9 ?';
        System.schedule('Test', CRON_EXP, new NotificationFileAttachDeletionBatch());
        NotificationFileAttachDeletionBatch nfadb = new NotificationFileAttachDeletionBatch();        
        Database.executeBatch(new NotificationFileAttachDeletionBatch());
        Test.stopTest();
        
        List<ContentDocument> cDocs = [SELECT Id, isDeleted FROM ContentDocument];
        
        System.assertEquals(0, cDocs.size());
    }
}