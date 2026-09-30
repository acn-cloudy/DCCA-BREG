/*
 * -----------------------------------------------------------------------------------
 * Description
 * We need to create a new batch job that can run daily and check the current date with
 * every course's (CE and Prelic) Start Date and change statuses from Open to Closed,
 * Closed to Completed and perhaps blanks if there are blanks to Open perhaps.
 * See lucid chart:
 * https://lucid.app/lucidchart/aaa20ac0-4780-4bce-9904-0a8391f2a01d/edit?beaconFlowId=B668BA449425F3FB&invitationId=inv_13fa9641-cba6-4bf9-b4fc-51b6f257e626&page=pYIxHz~x-iIN#?folder_id=home&browser=icon
 * -----------------------------------------------------------------------------------
 * Covered by: CourseStatusUpdateBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL08182022 - Created for case 00022621
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 08/18/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class CourseStatusUpdateBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful{
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        List<Course__c> courses = (List<Course__c>) scope;
        List<Course__c> coursesForUpdate = new List<Course__c>();
        Date today = Date.today();
        for (Course__c c : courses) {
            if ((c.StartDate__c != null && c.EndDate__c != null) &&
                    today > c.StartDate__c &&
                    today < c.EndDate__c &&
                            c.Medium__c == 'Classroom' &&
                            c.Status__c != 'Closed') {
                c.Status__c = 'Closed';
                coursesForUpdate.add(c);
            } else if (c.StartDate__c != null && c.StartDate__c > today && c.Status__c != 'Open') {
                c.Status__c = 'Open';
                coursesForUpdate.add(c);
            }
        }

        update coursesForUpdate;
    }

    public void finish(Database.BatchableContext bc) {
        BatchJobFinishNotification notification = new BatchJobFinishNotification('Update Course Status');
        notification.sendEmail();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, StartDate__c, EndDate__c, Medium__c, Status__c ' +
                                                'FROM Course__c ' +
                                                'WHERE Status__c IN (\'Open\',\'Closed\')');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CourseStatusUpdateBatch(), 200);
    }
}