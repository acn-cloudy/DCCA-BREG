/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Application Record Create component
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class ApplicationRecordsCreation {
    
    
    //Case: 5473 - Method reads custom metadata and returns value to populate Type for 
    //ApplicationCreation Component
    @AuraEnabled
    public static String licenseApplicationType() {
        //default license type for Application
            return [SELECT WizardApplicationType__c 
                                FROM  PVLSettings__mdt LIMIT 1].WizardApplicationType__c;
                
    }
    
    @AuraEnabled
    public static List<String> getRecordTypesBySobjectType() {
        List<String> recordTypeNames = new List<String>();
        Schema.DescribeSObjectResult d = Schema.SObjectType.Application__c;
        Map<Id,Schema.RecordTypeInfo> rtMapById = d.getRecordTypeInfosById();
        
        for(Schema.RecordTypeInfo recordT: rtMapById.values()) {
            if(recordT.isAvailable()) {
                recordTypeNames.add(recordT.getName());
            }
        }
        return recordTypeNames;
    }
    
    @AuraEnabled
    public static string getLicenseTypes(String accountId){
        String accountType = null;
        if(accountId != null) {
            List<Account> accounts = [Select Id, IsPersonAccount from Account where Id =: accountId];
            if(!accounts.isEmpty()) {
                if(accounts[0].IsPersonAccount) {
                    accountType = 'Person Account';
                } else {
                    accountType = 'Business Account';
                }
            }
        }
        List<String> recordTypes = getRecordTypesBySobjectType();
        List<LicenseType__c> licenseTypes = new List<LicenseType__c>();
        // 00011599
        // if(accountType == null )
            licenseTypes = LicenseTypeSelector.getLicenseTypes(recordTypes);
        // else 
        //     licenseTypes = LicenseTypeSelector.getLicenseTypes(recordTypes, accountType);
        if(accountType != null ) {
            for(LicenseType__c licenseRecord: licenseTypes) {
                licenseRecord.AccountType__c = accountType;
            }
        }
        // End
        List<PVLSettings__mdt> settings = PVLSettingsSelector.getSettingsByName('PVL Settings');    
        PVLSettings__mdt setting = new PVLSettings__mdt();
        if(settings!= null ) {
            setting = settings.get(0);
        }
        (new LicenseTypeDomain(licenseTypes)).updateWithDefaultPageLayout(setting);
        return JSON.serialize(licenseTypes);
    }
    
    @AuraEnabled
    public static String getClassifications(String licenseTypeId){
        List<Classification__c> classifications = [Select Id, Name, Description__c,
            LicenseType__c from Classification__c where Status__c = 'Active' and LicenseType__c =: licenseTypeId order by Name];
        return JSON.serialize(classifications);
    }
    @AuraEnabled
    public static String getApplicationRecordTypes(String recordTypeName){
        List<RecordType> recordTypes = [Select Id, Name 
                                        from RecordType where Name=: recordTypeName and SObjectType='Application__c'];
        return JSON.serialize(recordTypes);
    }
    @AuraEnabled
    public static String getFieldSetByName(String fieldSetName) {
        return JSON.serialize(AccountRecordsSearchCreate.getFieldSet(fieldSetName, 'License__c'));
    }
    @AuraEnabled
    public static String checkDuplicateLicense(String record, String fieldSetName) {
        Application__c application = (Application__c)JSON.deserialize(record, Application__c.class);
        String applicantId = application.Applicant__c;
        String licenseTypeId = application.LicenseType__c;
        List<AccountRecordsSearchCreate.Option> fieldAPISet = AccountRecordsSearchCreate.getFieldSet(fieldSetName, 'License__c');
        List<String> fieldApiNames = new List<String>();
        for(AccountRecordsSearchCreate.Option fieldAPI: fieldAPISet) {
            fieldApiNames.add(fieldAPI.name);
        }

        String fieldString = String.join(fieldApiNames, ',') ;
        List<String> statusList = new List<String>();
        statusList.add('C - Current, Valid & In Good Standing');
        statusList.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');
        statusList.add('CR - Current/Next Renewal Paid", "DM - Forfeited/Maintenance Requirement Due');
        statusList.add('R - Valid Thru Expiration Date, Subject To Renewal');
        statusList.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');
        statusList.add('Z - Current & Valid, But Subject To Disciplinary Requirement');
        statusList.add('ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)');
        statusList.add('ZM - Current & Valid, But Subject To Disciplinary/Maintenanc');
        List<License__c> licenses = LicenseSelector.getLicensesByLicenseTypeAndLicenseeAndStatus(licenseTypeId, applicantId, statusList);
        List<String> licenseIds = (new LicenseDomain(licenses)).getIds();
        List<License__c> generatedLicenses = (List<License__c>) (new PVL_Selector()).getSObjectRecordsByField('License__c', fieldApiNames, 
            (List<Id>)licenseIds, 'CreatedDate').getSObjectList();
        return JSON.serialize(generatedLicenses);
    }
    @AuraEnabled 
    public static String getContactRecord(String accountId) {
        return JSON.serialize([Select Id, PersonContact.MailingStreet, PersonContact.MailingCity, 
                PersonContact.MailingCountry, PersonContact.MailingState,PersonContact.MailingStateCode, 
                PersonContact.MailingPostalCode from Account where Id=: accountId]);
    }
    @AuraEnabled
    public static String createApplicationRecord(String record, String classificationsStr) {
        // Call CustomRecordCreate to create Application record
        system.debug('record>>>>  ' + record);
        
        String response = CustomRecordCreate.SaveRecord('Application__c', record, null);
        Map<String, String> resultMap = (Map<String, String> )JSON.deserialize(response, Map<String, String>.class);
        if(resultMap.get('status') == 'OK') {
            String recordId = resultMap.get('id');
            // select License Type Id
            Application__c application = ApplicationSelector.getApplications(new List<String>{recordId}).get(0);
            List<Classification__c> classifications = (List<Classification__c>) JSON.deserialize(
                classificationsStr, List<Classification__c>.class);
            List<ApplicationClassifications__c> records = new List<ApplicationClassifications__c> ();
            for(Classification__c classification: classifications) {
                ApplicationClassifications__c appClassRecord = new ApplicationClassifications__c ();
                if(application.LicenseType__r.DefaultClassStatus__c != null) {
                    appClassRecord.Status__c = application.LicenseType__r.DefaultClassStatus__c;
                }
                 
                appClassRecord.Classification__c  = classification.Id;
                appClassRecord.Application__c   = recordId;
                records.add(appClassRecord);
            }
            insert records;
        } else {
            String errorMessage = resultMap.get('message');
            System.debug('error message' + errorMessage);
            // AuraHandledException auExp = new AuraHandledException(errorMessage);
            // auExp.setMessage(errorMessage);
            // throw auExp;
        }
        return response;
    }
}