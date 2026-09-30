/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* 
* - execute : Schedule LicenseUpdateStatus
* Covered by 
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Irene Cahilo - PacificPointCorp 
* @created      PacPoint-IC071819 - Created for PVL Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
// global class LicenseUpdateStatusScheduler implements Schedulable{
// 	public void execute(System.SchedulableContext context) {
// 		LicenseUpdateStatus.checkLicenseStatus();
// 	}
// }
global class LicenseUpdateStatusScheduler implements schedulable, Database.Batchable<SObject> {
	/* variables */
    public String query ;
    global LicenseUpdateStatusScheduler() {
        query = 'SELECT Id, LicenseType__c, Status__c FROM License__c WHERE ' 
            + ' (Status__c = \'C - Current, Valid & In Good Standing\' ' 
            + 'or Status__c = \'CR - Current/Next Renewal Paid\' ' 
            + ' or Status__c = \'CM - Current, Valid & In Good Standing/Maint. Requirement Due\') and LicenseType__r.StartofRenewalPeriod__c = Today';
    }
	/* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

	global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> records = (List<License__c> ) scope;
        LicenseUpdateStatus.checkLicenseStatus(records);
    }
	public void execute(System.SchedulableContext context) {
		Database.executeBatch(new LicenseUpdateStatusScheduler(), 100);
	}
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        /* To send confirmation emails or execute post-processing operations. */
    }

}