/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10182022 - Created for case 00025290
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/18/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class AttestToMailingNoticesBatchTest {
    @TestSetup
    static void setup() {
        Notification__c n = new Notification__c();
        n.Status__c = 'Completed';
        n.TimeDelivered__c = Datetime.now();
        n.Scheduled__c = true;
        insert n;
    }

    @IsTest
    static void batchTest() {
        List<Notification__c> notifications = [
            SELECT
                Id,
                TimeDelivered__c
            FROM Notification__c
        ];
        List<AttestToMailingNoticesController.Notice> selectedRows = new List<AttestToMailingNoticesController.Notice>();
        List<AttestToMailingNoticesController.Notice> drafts = new List<AttestToMailingNoticesController.Notice>();

        AttestToMailingNoticesController.Notice n = new AttestToMailingNoticesController.Notice(notifications[0].TimeDelivered__c.date(), notifications);
        selectedRows.add(n);
        drafts.add(n);

        Test.startTest();
        Database.executeBatch(new AttestToMailingNoticesBatch(selectedRows, drafts));
        Test.stopTest();
    }
}