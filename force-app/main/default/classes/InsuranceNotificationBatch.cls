/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Insurance notifications to batch generate the notification batch.
* 00008968
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      PacPoint-AZ071620 - Created for PVL Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* 
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class InsuranceNotificationBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    public Set<String> licenseIdSet = new Set<String>();
    public String query = 'Select Id, License__c from InsuranceBond__c '
        + ' where SendINSBondReminderNotice__c = yesterday and (Status__c = \'Active\' or Status__c = \'Waived\') order by License__c';
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<InsuranceBond__c> insuranceBonds = (List<InsuranceBond__c>) scope;
        Set<String> licenseIdsToCheck = InsuranceBondService.checkForExpiringInsuranceBond(insuranceBonds);
        
        List<String> licenseIds = new List<String>();
        for(String licenseId: (List<String>)(new InsuranceBondDomain(insuranceBonds)).getFieldValues('License__c')) {
            if(!licenseIdsToCheck.contains(licenseId)) {
                licenseIds.add(licenseId);
            }
        }
        
        
        List<String> licenseIdList = new List<String>();
        for(String licenseId: licenseIds) {
            if(!licenseIdSet.contains(licenseId)) {
                licenseIdList.add(licenseId);
            }
        }
        //query license records
        List<License__c> records = LicenseSelector.getLicenses(licenseIdList);
        // generate notifications
        List<Notification__c> notifications = (new LicenseDomain(records)).getNotifications();
        insert notifications;
        // update status of the license 
        licenseIdSet.clear();
        for(String licenseId: licenseIdList) {
            licenseIdSet.add(licenseId);
        }
        (new LicenseDomain(records)).updateLicensesForBondReminder();
        update records;
    }

    global void execute(System.SchedulableContext context) {
        Database.executeBatch(new InsuranceNotificationBatch(), 100);
    }
    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        
    }

}