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
private class AttestToMailingNoticesControllerTest {
    @TestSetup
    static void setup() {
        Notification__c n = new Notification__c();
        n.Status__c = 'Completed';
        n.TimeDelivered__c = Datetime.now();
        n.Scheduled__c = true;
        insert n;
    }

    @IsTest
    static void blankParamNoticeConstructorTest() {
        AttestToMailingNoticesController.Notice notice = new AttestToMailingNoticesController.Notice();
    }

    @IsTest
    static void executeBatchTest() {
        List<AttestToMailingNoticesController.Notice> notices = AttestToMailingNoticesController.getNotifications();
        List<AttestToMailingNoticesController.Notice> drafts = new List<AttestToMailingNoticesController.Notice>();
        Test.startTest();
        AttestToMailingNoticesController.executeBatch(notices, drafts);
        Test.stopTest();
    }
}