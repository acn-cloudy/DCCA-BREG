/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
* Checklist records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
* Changed since the Object name was changed:
* Checklist to Requirements
* Application Checklist to Application Requirements
* ───────────────────────────────────────────────────────────
*/
public class LicenseTypeRequirementsDomain extends SObjectDomain {
    public LicenseTypeRequirementsDomain(List<LicenseTypeRequirements__c> requirementsList) {
        super(requirementsList);
    }
    public Map<String, List<LicenseTypeRequirements__c>> getLicenseTypeToRequirements(){
        Map<String, List<LicenseTypeRequirements__c>> licenseTypeReqList = new Map<String, List<LicenseTypeRequirements__c>>();
        for(Sobject record: records) {
            LicenseTypeRequirements__c reqRecord = (LicenseTypeRequirements__c) record;
            List<LicenseTypeRequirements__c> requirementsList = licenseTypeReqList.get(reqRecord.LicenseType__c);
            if(requirementsList == null ) {
                requirementsList = new List<LicenseTypeRequirements__c>();
            }
            requirementsList.add(reqRecord);
            licenseTypeReqList.put(reqRecord.LicenseType__c, requirementsList);
        }
        return licenseTypeReqList;
    }

    public List<ApplicationRequirement__c> getAppRequirements(Application__c app, Set<String> classificationIds){
        List<ApplicationRequirement__c> appReqlist = new List<ApplicationRequirement__c>();
        for(Sobject record: records) {
            LicenseTypeRequirements__c licenseTypeRequirement = (LicenseTypeRequirements__c) record;
            if(licenseTypeRequirement.Classification__c != null && !classificationIds.contains(licenseTypeRequirement.Classification__c)){
                continue;
            }
            String appPhase = app.Phase__c;
            String appType = app.Type__c;

            // Need to map the license type requirement phase and type with App Phase and Type
            if(licenseTypeRequirement.Requirement__c == null 
                || licenseTypeRequirement.Phase__c != appPhase || licenseTypeRequirement.Type__c != appType) {
                continue;
            }
            if(licenseTypeRequirement.TypeofEntity__c != null && licenseTypeRequirement.TypeofEntity__c != app.TypeofEntity__c) {
                continue;
            }
            if(licenseTypeRequirement.MethodofLicensure__c != null && licenseTypeRequirement.MethodofLicensure__c != app.MethodofLicensure__c) {
                continue;
            }
            if(licenseTypeRequirement.ActiveInactive__c != null && licenseTypeRequirement.ActiveInactive__c != app.ActiveInactive__c) {
                continue;
            }
            
            ApplicationRequirement__c applicationRequirement = new ApplicationRequirement__c();
            applicationRequirement.Application__c = app.Id;
            // Changes to move License Type Requirement Matching to Requirements
            // Case: 00003563
            applicationRequirement.Requirement__c = licenseTypeRequirement.Requirement__c;
            applicationRequirement.RequirementLongDescription__c 
                = licenseTypeRequirement.Requirement__r.RequirementLongDescription__c;
            applicationRequirement.RequirementShortDescription__c 
                = licenseTypeRequirement.Requirement__r.RequirementShortDescription__c;
            applicationRequirement.IsDeficient__c = licenseTypeRequirement.Required__c;
            applicationRequirement.Required__c = licenseTypeRequirement.Required__c;
            appReqlist.add(applicationRequirement);
        }
        return appReqlist;
    }

   /*** public List<ApplicationRequirement__c> getAppRequirements(String appId, Set<String> classificationIds){
        List<ApplicationRequirement__c> appReqlist = new List<ApplicationRequirement__c>();
        for(Sobject record: records) {
            LicenseTypeRequirements__c requirementsRecord = (LicenseTypeRequirements__c) record;
            if(requirementsRecord.Classification__c != null && !classificationIds.contains(requirementsRecord.Classification__c)){
                continue;
            }
            ApplicationRequirement__c applicationRequirement = new ApplicationRequirement__c();
            applicationRequirement.Application__c = appId;
            // Changes to move License Type Requirement Matching to Requirements
            // Case: 00003563
            applicationRequirement.Requirement__c = requirementsRecord.Requirement__c;
            applicationRequirement.RequirementLongDescription__c 
                = requirementsRecord.Requirement__r.RequirementLongDescription__c;
            applicationRequirement.RequirementShortDescription__c 
                = requirementsRecord.Requirement__r.RequirementShortDescription__c;

            applicationRequirement.IsDeficient__c = false;
            appReqlist.add(applicationRequirement);
        }
        return appReqlist;

    }*** */
}