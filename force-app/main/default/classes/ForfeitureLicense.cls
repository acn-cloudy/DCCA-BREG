/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* checkLicenseStatus : Batch job that runs overnight and looks Licenses with a forfeituredate__c = today
* 
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      PacPoint-AZ110220 - Created for PVL
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* 
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/

global class ForfeitureLicense implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    String query ='Select Id, ForfeitureDate__c, Status__c, LicenseType__r.StatusDueToNonRenewal__c, ' 
        + ' LicenseType__r.StatusDueToLossOfInsurance__c from License__c ' 
        + ' where ForfeitureDate__c <= Yesterday and Status__c in: statusList';
    global List<String> statusList = new List<String>();
    global ForfeitureLicense() {
        statusList.add('C - Current, Valid & In Good Standing');
        statusList.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');
        statusList.add('R - Valid Thru Expiration Date, Subject To Renewal');
        statusList.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');
        
        statusList.add('ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)');
    }
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> records = (List<License__c> ) scope;
        // Get String List for 
        List<String> licenseIds = (new LicenseDomain(records)).getIds();
        List<Suspense__c> suspenses = SuspenseSelector.getSuspenseByLicenseIds(licenseIds);
        Map<String, List<Suspense__c>> licenseId2Suspenses = (new SuspenseDomain(suspenses)).getLicenseId2Suspenses(new Map<String, License__c>(records));
        // to update license records and suspense records.
        List<Suspense__c> suspensesForUpdate = (new LicenseDomain(records)).updateLicenseRecords(licenseId2Suspenses);
        if(!suspensesForUpdate.isEmpty()) {
            update suspensesForUpdate;
        }
        List<String> licenseIdsForUpdate = (List<String>) (new SuspenseDomain(suspensesForUpdate)).getFieldValues('License__c') ;
        Set<String> licenseIdSet = new Set<String>();
        licenseIdSet.addAll(licenseIdsForUpdate);
        
        List<License__c> licenseForUpdate = (new LicenseDomain(records)).filterLicenseFromSet(licenseIdSet);
        // update license;
        if(!licenseForUpdate.isEmpty()) {
            update licenseForUpdate;
        }
        
        // Case 00026392
        for (License__c l : records) {
            Map<String, Object> flowParam = new Map<String, Object>();
            flowParam.put('InputLicense', l);
            Flow.Interview i = Flow.Interview.createInterview('License_Create_License_History', flowParam);
            i.start();
        }
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new ForfeitureLicense(), 100);
    }
    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        
    }
}