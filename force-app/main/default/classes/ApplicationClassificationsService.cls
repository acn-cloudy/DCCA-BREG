/*
* ─────────────────────────────────────────────────────────
* Used for the Business logic around
* Application Classifications records
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
public class ApplicationClassificationsService {
    private static Set<String> applicationIds = new Set<String>();
    public static void captureApplications(SObject so) {
        ApplicationClassifications__c record = (ApplicationClassifications__c) so;
        applicationIds.add(record.Application__c);
    }
    public static Map<String, Set<String>> getClassificationMap(List<String> applicationIds) {
        List<ApplicationClassifications__c> records 
            = ApplicationClassificationsSelector.getApplicationClassifications(applicationIds);
        return (new ApplicationClassificationsDomain(records)).getAppClassificationMap();
    }
    // 00003563 
    public static void replaceRequirements(Set<String> applicationIdSet){
        List<Application__c> records = ApplicationSelector.getApplications(applicationIdSet);
        ApplicationService.updateAppRequirements(records);
    }

    public static void updateClassificationComments(Set<String> applicationIdSet){
        List<String> licenseTypeCodes = new List<String>();
        licenseTypeCodes.add('CT - RME');
        licenseTypeCodes.add('CT - ENTITY');
        List<Application__c> records = ApplicationSelector.getApplicationsByLicenseCode(applicationIdSet, licenseTypeCodes);
        if(!records.isEmpty())
            ApplicationService.updateClassifications(records);
    }

    public static void runFinally(List<ApplicationClassifications__c> records){
        if(Trigger.isAfter != null && Trigger.isAfter ) {
            if(!applicationIds.isEmpty()) {
                replaceRequirements(applicationIds);
                updateClassificationComments(applicationIds);
                reGenerateTransactionLines(applicationIds);
                applicationIds.clear();
            }
        }
    }
    @future
    private static void reGenerateTransactionLines(Set<String> applicationIds) {
        List<String> appIds = new List<String> ();
        appIds.addAll(applicationIds);
        // regenerate transaction line items. 
        ApplicationService.reCreateTransactionLines(appIds);
    }

    // Used to get Applicaiton Id => Application Classifications 
    // Used by LicenseService.createClassifications
    public static Map<String, List<ApplicationClassifications__c>> getAppClassifications(
        List<String> applicationIds, List<String> statusList ) {
        List<ApplicationClassifications__c> applicationClassifciations
            = ApplicationClassificationsSelector.getApplicationClassifications(applicationIds, statusList);
        return (new ApplicationClassificationsDomain(applicationClassifciations)).getAppClassifications();
    }

    public static Map<String, List<ApplicationClassifications__c>> getAppClassifications(List<String> applicationIds) {
        List<ApplicationClassifications__c> applicationClassifciations
            = ApplicationClassificationsSelector.getApplicationClassifications(applicationIds);
        return (new ApplicationClassificationsDomain(applicationClassifciations)).getAppClassifications();
    }

    public static Map<String, List<Classification__c>> getClassifications(List<String> applicationIds) {
        List<ApplicationClassifications__c> applicationClassifciations
            = ApplicationClassificationsSelector.getApplicationClassifications(applicationIds);
        return (new ApplicationClassificationsDomain(applicationClassifciations)).getClassifications();
    }

    // CASE 00005272 : Creation of a trigger to populate Application Classification Records based on Classification__c
    public static Map<String, List<Classification__c>> getLicenseTypeClassificationsMap(List<String> licenseTypeIds) {
        List<Classification__c> classificationsList = ApplicationClassificationsSelector.getClassificationsByLicenseTypeIds(licenseTypeIds);
        Map<String, List<Classification__c>> licenseTypeClassificationsMap = new Map<String, List<Classification__c>>();
        for(Classification__c classification : classificationsList) {
            if (licenseTypeClassificationsMap.containsKey(classification.LicenseType__c)) {
                licenseTypeClassificationsMap.get(classification.LicenseType__c).add(classification);
            } else {
                licenseTypeClassificationsMap.put(classification.LicenseType__c, new List<Classification__c>{classification});
            }
        }
        return licenseTypeClassificationsMap;
    }

    @AuraEnabled
    public static void createRecord(String str){
        ApplicationClassifications__c appClassification = (ApplicationClassifications__c)JSON.deserialize(str, ApplicationClassifications__c.class);
        insert appClassification;
    }
}