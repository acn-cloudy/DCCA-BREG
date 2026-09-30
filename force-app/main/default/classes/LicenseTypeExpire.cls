/*
* ─────────────────────────────────────────────────────────
* class for the LicenseTypeRenew 
* 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ150520 - Created for PVL phase 1 for case 00008273
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2020-05-15
* ───────────────────────────────────────────────────────────
* Changes
* PacPoint-CL-06282022 - for case 00022281
*
* ───────────────────────────────────────────────────────────
*/
global with sharing class LicenseTypeExpire implements Schedulable, Database.Batchable<SObject> {
    //  we need to capture LicenseTypeExpireDate is today AND in the past to cover that scenario
    public String query = 'SELECT Id, ' +
    'DurationofLicenseInMonths__c, ' +
    'PreviousLicensePeriodEffectiveDate__c, ' +
    'PreviousLicensePeriodExpireDate__c, ' +
    'LicenseTypeExpireDate__c, ' +
    'LicenseTypeEffectiveDate__c, ' +
    'StartofRenewalPeriod__c, ' +
    'LastReceivedDateAccepted__c ' +
    'FROM LicenseType__c ' +
    'WHERE LicenseTypeExpireDate__c < today ' +
    'AND StartofRenewalPeriod__c != null';

    global LicenseTypeExpire() {
    }

    global LicenseTypeExpire(List<Id> licenseTypeIds) {
        query = 'SELECT Id, ' +
                'DurationofLicenseInMonths__c, ' +
                'PreviousLicensePeriodEffectiveDate__c, ' +
                'PreviousLicensePeriodExpireDate__c, ' +
                'LicenseTypeExpireDate__c, ' +
                'LicenseTypeEffectiveDate__c, ' +
                'StartofRenewalPeriod__c, ' +
                'LastReceivedDateAccepted__c ' +
                'FROM LicenseType__c ' +
                'WHERE Id IN ' + GlobalUtilities.convertIdsToIdStr(licenseTypeIds) + ' ' +
                'AND StartofRenewalPeriod__c != null';
    }
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<LicenseType__c> records = (List<LicenseType__c> )scope;
        for(LicenseType__c record: records )  {
            Integer duration = Integer.valueOf(record.DurationofLicenseInMonths__c);
            record.PreviousLicensePeriodEffectiveDate__c = record.LicenseTypeEffectiveDate__c;
            record.PreviousLicensePeriodExpireDate__c = record.LicenseTypeExpireDate__c;
            record.LicenseTypeEffectiveDate__c = record.LicenseTypeEffectiveDate__c.addMonths(duration);
            record.LastReceivedDateAccepted__c = record.LicenseTypeExpireDate__c;
            record.StartofRenewalPeriod__c = record.StartofRenewalPeriod__c.addMonths(duration);
        }
        update records;
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new LicenseTypeExpire(), 100);
    }
    /* batch finish class */
    global void finish(Database.BatchableContext context) {
      
    }
}