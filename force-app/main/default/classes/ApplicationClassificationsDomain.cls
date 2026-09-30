/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around 
* ApplicationClassifications records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ140619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-14
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class ApplicationClassificationsDomain extends SObjectDomain {
    public ApplicationClassificationsDomain(List<ApplicationClassifications__c> applicationClassifications){
        super(applicationClassifications);
    }

    // Used to Convert to license classification List from Application Classifications
    // Used by 
    public List<LicenseClassification__c> convertToLicenseClassifications(License__c license) {
        List<LicenseClassification__c> licenseClassifications = new List<LicenseClassification__c>();
        for(SObject record: records) {
            ApplicationClassifications__c appClassification = (ApplicationClassifications__c) record;
            LicenseClassification__c licenseClassificationRecord = new LicenseClassification__c();
            licenseClassificationRecord.License__c = license.Id;
            licenseClassificationRecord.Classification__c = appClassification.Classification__c;
            licenseClassificationRecord.EffectiveStartDate__c = appClassification.EffectiveStartDate__c;
            licenseClassificationRecord.Status__c = 'C - CURRENT, VALID & IN GOOD STANDING';
            licenseClassifications.add(licenseClassificationRecord);
        }
        return licenseClassifications;
    }
    public Map<String, Set<String>> getAppClassificationMap(){
        Map<String, Set<String>> appClassificationIds = new Map<String, Set<String>>();
        for(SObject record: records) {
            ApplicationClassifications__c appClassification = (ApplicationClassifications__c) record;
            Set<String> classificationIds = appClassificationIds.get(appClassification.Application__c);
            if(classificationIds == null ) {
                classificationIds = new Set<String>();
            }
            classificationIds.add(appClassification.Classification__c);
            appClassificationIds.put(appClassification.Application__c, classificationIds);
        }
        return appClassificationIds;
    }

    public Map<String, List<ApplicationClassifications__c>> getAppClassifications(){
        Map<String, List<ApplicationClassifications__c>> appClassifications = new Map<String, List<ApplicationClassifications__c>>();
        for(SObject record: records) {
            ApplicationClassifications__c appClassification = (ApplicationClassifications__c) record;
            List<ApplicationClassifications__c> classifications = appClassifications.get(appClassification.Application__c);
            if(classifications == null ) {
                classifications = new List<ApplicationClassifications__c>();
            }
            classifications.add(appClassification);
            appClassifications.put(appClassification.Application__c, classifications);
        }
        return appClassifications;
    }

    public Map<String, List<Classification__c>> getClassifications(){
        Map<String, List<Classification__c>> appClassifications = new Map<String, List<Classification__c>>();
        for(SObject record: records) {
            ApplicationClassifications__c appClassification = (ApplicationClassifications__c) record;
            List<Classification__c> classifications = appClassifications.get(appClassification.Application__c);
            if(classifications == null ) {
                classifications = new List<Classification__c>();
            }
            classifications.add(appClassification.Classification__r);
            appClassifications.put(appClassification.Application__c, classifications);
        }
        return appClassifications;
    }
}