global virtual class ApplicationRenewalPushThru  implements Database.Batchable<SObject>, Database.Stateful {
    public List<String> licenseStatuses = new List<String>();
    public List<String> licenseCodes = new List<String>();
    public List<String> appStatuses = new List<String> {'D1 - Awaiting Dependency Review'};
    public List<String> appTypes = new List<String> {'RNEW - Renewal'};
    public Map<Id, Application__c> appMap = new Map<Id, Application__c>();

    public String query = 'Select Id, CurrentLicense__r.NotificationEmail__c, CurrentLicense__c, RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.Name, CurrentLicense__r.EffectiveExpireDate__c, SoleOwner__c, '
        + ' CurrentLicense__r.SoleOwner__c, CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c, '
        + ' CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, ActiveInactive__c, LicenseTypeCode__c, CurrentLicense__r.ActiveInactive__c, '
        + ' CurrentLicense__r.ExcludeFromInactivationProcess__c, CurrentLicense__r.DependentLicense__c, '
        + ' CurrentLicense__r.LicenseType__r.Name, '
        + ' CurrentLicense__r.LicenseType__r.LicenseTypeEffectiveDate__c, '
        + ' CurrentLicense__r.LicenseType__r.PreviousLicensePeriod__c, '
        + ' LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, '
        + ' Status__c, Phase__c, Name from Application__c ' 
        + ' where CurrentLicense__r.LicenseType__r.Name =: licenseCodes ' 
        + ' and CurrentLicense__r.Status__c =: licenseStatuses and CurrentLicense__r.ThisLicenseRenewed__c = true ' 
        + ' and Type__c in: appTypes  and Status__c in: appStatuses and SameAsLicenseTypeRenewPeriod__c = true';
    
    global ApplicationRenewalPushThru(List<String> licenseCodes, List<String> licenseStatuses) {
        this.licenseStatuses = licenseStatuses;
        this.licenseCodes = licenseCodes;
    }

    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        turnOffAppRenewFlow();
        // initiate appMap
        appMap = new Map<Id, Application__c>();
        List<Application__c> records = (List<Application__c>) scope;
        processRecords(records);
        ApplicationService.renewApplicationLicenses(appMap.values());
        turnOnAppRenewFlow();
    }

    global virtual void processRecords(List<Application__c> records) {}

    private static void turnOffAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = true;
        upsert orgSetting;
    }
    private static void turnOnAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = false;
        upsert orgSetting;
    }
    /* 
     * batch finish class
     */
    global virtual void finish(Database.BatchableContext context) {}

    
}