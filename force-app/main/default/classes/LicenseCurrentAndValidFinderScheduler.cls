/*
 * ___________________________________________________________________________________
 * Batch job that will change the license status="C - Current, Valid & In Good Standing" if the Licenses
 * with status = "CP - Current Pending" and OriginalDateofLicensure=TODAY()
 * The batch job will be running daily.
 * Covered by LicenseCurrentAndValidFinderSchedulerTest
 * __________________________________________________________________________________
 * PacPoint-CL110419 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 02/25/19
 * __________________________________________________________________________________
 *
 * @See Case 00006151
 */
// public class LicenseCurrentAndValidFinderScheduler implements Schedulable{
//     public void execute(SchedulableContext c) {
//         List<License__c> licensesToUpdate = [
//                 SELECT
//                         Id
//                 FROM License__c
//                 WHERE Status__c = 'CP - Current Pending'
//                 AND OriginalDateofLicensure__c = TODAY
//         ];

//         for (License__c lc : licensesToUpdate) {
//             lc.Status__c = 'C - Current, Valid & In Good Standing';
//         }

//         if (!licensesToUpdate.isEmpty()) {
//             update licensesToUpdate;
//         }
//     }
// }

global class LicenseCurrentAndValidFinderScheduler implements schedulable, Database.Batchable<SObject> {
	/* variables */
    public String query ;
    global LicenseCurrentAndValidFinderScheduler() {
        query = 'SELECT Id, Status__c FROM License__c '
        +'WHERE Status__c = \'CP - Current Pending\' AND (OriginalDateofLicensure__c = TODAY or MovetoC__c = true) ';
    }
	/* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

	global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> records = (List<License__c> ) scope;
        for (License__c lc : records) {
            lc.Status__c = 'C - Current, Valid & In Good Standing';
        }

        if (!records.isEmpty()) {
            update records;
        }
    }
	public void execute(System.SchedulableContext context) {
		Database.executeBatch(new LicenseCurrentAndValidFinderScheduler(), 100);
	}
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        /* To send confirmation emails or execute post-processing operations. */
    }

}