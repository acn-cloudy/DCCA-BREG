/*
 * ___________________________________________________________________________________
 * Covered by LicenseOverdueFinderSchedulerTest
 * __________________________________________________________________________________
 * PacPoint-CL11072019 - Created for
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/7/2019
 * __________________________________________________________________________________
 * @See 00006229
 */

global class LicenseConditionOverdueFinderScheduler implements schedulable, Database.Batchable<SObject> {
	/* variables */
    public String query ;
    global LicenseConditionOverdueFinderScheduler() {
        query = 'SELECT Id, Overdue__c FROM LicenseConditions__c WHERE Overdue__c != true AND DateDue__c < TODAY';
    }
	/* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

	global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<LicenseConditions__c> records = (List<LicenseConditions__c> ) scope;
        for (LicenseConditions__c con : records) {
                con.Overdue__c = true;
            }

            update records;
    }
	public void execute(System.SchedulableContext context) {
		Database.executeBatch(new LicenseConditionOverdueFinderScheduler(), 100);
	}
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        /* To send confirmation emails or execute post-processing operations. */
    }

}

// public class LicenseConditionOverdueFinderScheduler implements Schedulable{

//     public void execute(SchedulableContext c) {
//         List<LicenseConditions__c> overdueLicenseConditions = [
//                 SELECT
//                         Id
//                 FROM LicenseConditions__c
//                 WHERE Overdue__c != true
//                 AND DateDue__c < TODAY
//         ];

//         if (!overdueLicenseConditions.isEmpty()) {
//             for (LicenseConditions__c con : overdueLicenseConditions) {
//                 con.Overdue__c = true;
//             }

//             update overdueLicenseConditions;
//         }
//     }
// }