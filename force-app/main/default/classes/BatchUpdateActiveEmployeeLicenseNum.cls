/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Batch to update active employee license number
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* @author       Alvin ZHou - PacificPointCorp 
* @created      2021-01-18
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global with sharing class BatchUpdateActiveEmployeeLicenseNum implements Database.Batchable<SObject>, Database.Stateful  {
    global List<Id> entityLicenseIds;
    public String query ;
    global BatchUpdateActiveEmployeeLicenseNum(List<Id> entityLicenseIds) {
        this.entityLicenseIds = entityLicenseIds;
        query = 'Select Id, EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c ' 
            + 'WHERE EntityLicense__c IN ' + GlobalUtilities.convertIdsToIdStr(entityLicenseIds);
    }
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<AssociatedLicense__c> associatedLicenses = (List<AssociatedLicense__c>) scope;
        AssociatedLicenseService.licenseIdsEmploymentCount.addAll((List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c'));

        disableLicenseTriggers();
        AssociatedLicenseService.countLicenseRecords();
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
      
    }
}