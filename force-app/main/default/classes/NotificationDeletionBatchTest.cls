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
private class NotificationDeletionBatchTest {
    @TestSetup
    static void setup() {
        Notification__c toDelete = new Notification__c();
        toDelete.Status__c = 'Cancelled';

        Notification__c notToDelete = new Notification__c();
        notToDelete.Status__c = 'Cancelled';

        insert new Notification__c[]{toDelete, notToDelete};
        Test.setCreatedDate(toDelete.Id, Datetime.now().addDays(-8));
        Test.setCreatedDate(notToDelete.Id, Datetime.now().addDays(-7));
    }

    @IsTest
    static void testBatch() {
        Test.startTest();
        String CRON_EXP = '0 0 0 3 9 ?';
        System.schedule('Test', CRON_EXP, new NotificationDeletionBatch());
        Database.executeBatch(new NotificationDeletionBatch());
        Test.stopTest();

        System.assertEquals(1, [SELECT Id FROM Notification__c].size());
    }
}