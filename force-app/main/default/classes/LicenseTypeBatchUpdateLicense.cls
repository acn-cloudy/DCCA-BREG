/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the LicenseTypeBatchUpdateLicense
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
*  PacPoint-AZ011920 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global with sharing class LicenseTypeBatchUpdateLicense implements  Database.Batchable<SObject>, Database.Stateful  {
    global String fieldToUpdate;
    global String valueToUpdate;
    global Boolean isRenewal = false;
    public String query;
    public String licenseTypeId;
    public Date licenseTypeExpireDate;

    global LicenseTypeBatchUpdateLicense(String fieldToUpdate, String valueToUpdate, String licenseTypeId, String batchConditionField) {
        this.fieldToUpdate = fieldToUpdate;
        this.valueToUpdate = valueToUpdate;
        LicenseType__c lt = [SELECT Id, LicenseTypeExpireDate__c FROM LicenseType__c WHERE Id = :licenseTypeId];
        this.licenseTypeExpireDate = lt.LicenseTypeExpireDate__c;

        query = 'SELECT Id, ' + fieldToUpdate +
                ' FROM License__c WHERE LicenseType__c = \'' + licenseTypeId + '\' ' +
                ' AND ' + batchConditionField + ' = true ' +
                ' AND EffectiveExpireDate__c = :licenseTypeExpireDate';

        this.licenseTypeId = licenseTypeId;
    }

    global LicenseTypeBatchUpdateLicense(String fieldToUpdate,
                                         String valueToUpdate,
                                         String licenseTypeId,
                                         String batchConditionField,
                                         Boolean isStartRenewal) {
        this(fieldToUpdate, valueToUpdate,licenseTypeId,batchConditionField);
        this.isRenewal = isStartRenewal;
    }

    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        System.debug('####query######' + query);
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {

        for(SObject record: scope) {
            if(valueToUpdate.equalsIgnoreCase('true')) {
                record.put(fieldToUpdate, true);
            } else {
                record.put(fieldToUpdate, valueToUpdate);
            }

            if (this.isRenewal) {
                record.put('ThisLicenseRenewed__c', false);
            }
        }
        System.debug('####scope######' + scope);
        disableLicenseTriggers();
        update scope;
        enableLicenseTriggers();
    }

    private void disableLicenseTriggers(){
        OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.DisableTriggers__c = true;
        orgSetting.DisableLicenseTriggers__c = true;
        if(orgSetting.Id != null) update orgSetting;
    }

    private void enableLicenseTriggers(){
        OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.DisableTriggers__c = false;
        orgSetting.DisableLicenseTriggers__c = false;
        if(orgSetting.Id != null) update orgSetting;
    }

    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        /*
         * To send confirmation emails or execute post-processing operations.
         */
        if (this.isRenewal) {
            LicenseType__c lt = [SELECT Id, Name FROM LicenseType__c WHERE Id = :this.licenseTypeId];
            BatchJobFinishNotification notification = new BatchJobFinishNotification('Start Renewal Cycle', lt.Name);
            notification.sendEmail();
        }
    }
}