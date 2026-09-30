/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: NotificationDeletionBatchTest
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
public class NotificationDeletionBatch implements Schedulable, Database.Batchable<SObject>{

    public String query;

    public NotificationDeletionBatch() {
        query = 'SELECT Id ' +
                'FROM Notification__c ' +
                'WHERE (Status__c = \'Failed\' OR Status__c = \'Cancelled\') ' +
                'AND CreatedDate < LAST_N_DAYS:7';
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Notification__c> notifications = (List<Notification__c>) scope;
        delete notifications;
    }

    public void finish(Database.BatchableContext bc) {
    }

    public Database.QueryLocator start(Database.BatchableContext param1) {
        return Database.getQueryLocator(query);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new NotificationDeletionBatch());
    }
}