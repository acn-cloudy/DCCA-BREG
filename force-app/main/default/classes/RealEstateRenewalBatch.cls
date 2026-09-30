global without sharing class RealEstateRenewalBatch implements 
Database.Batchable<SObject>, Database.Stateful {
    Map<String, License__c> licsForUpdate = new Map<String, License__c>();
    Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
    Set<String> appIds = new Set<String>();
    Set<String> processedLics = new Set<String>();

    global RealEstateRenewalBatch(Map<String, License__c> licsForUpdate, Map<String, Application__c> appsForUpdate) {
        this();
        this.licsForUpdate = licsForUpdate;
        this.appsForUpdate = appsForUpdate;
        this.appIds = appsForUpdate.keySet();    
    }
    
    global RealEstateRenewalBatch() {
        this.licsForUpdate.clear();
        this.appsForUpdate.clear();
        this.appIds.clear();
    }

    /* collect the batches of records or objects to be passed to execute */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        String query = 'SELECT Id, CurrentLicense__c FROM Application__c WHERE Id in: appIds';
        return Database.getQueryLocator(query);
    }

    /* process each batch of records */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> forUpdateLics = new List<License__c>();
        List<Application__c> forUpdateApps = new List<Application__c>();
        for(sObject s : scope) {
            processedLics.add((String)s.get('CurrentLicense__c'));
            if(licsForUpdate.get((String)s.get('CurrentLicense__c')) != null) forUpdateLics.add(licsForUpdate.get((String)s.get('CurrentLicense__c')));
            if(appsForUpdate.get((String)s.get('Id')) != null) forUpdateApps.add(appsForUpdate.get((String)s.get('Id')));
        }

        turnOffAppRenewFlow();
        ApplicationHandler.bypassInsuranceValidation = true;
        if(!forUpdateApps.isEmpty()) update forUpdateApps;
        ApplicationHandler.bypassInsuranceValidation = false;
        turnOnAppRenewFlow();

        licenseService.disableUpdateAssociatedEntity = true;
        if(!forUpdateLics.isEmpty()) update forUpdateLics;
        licenseService.disableUpdateAssociatedEntity = false;
    }
    
    global void turnOffAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = true;
        upsert orgSetting;
    }

    global void turnOnAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = false;
        upsert orgSetting;
    }

    global void finish(Database.BatchableContext bc) {
        if(!processedLics.isEmpty()){
            Database.executeBatch(new BatchUpdateActiveEmployeeLicenseNum(new List<String>(processedLics)), 50);
            processedLics.clear();
        }
    }
}