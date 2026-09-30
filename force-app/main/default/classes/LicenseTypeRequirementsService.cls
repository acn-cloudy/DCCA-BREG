/*
* ─────────────────────────────────────────────────────────
* Used for the Business logic around
* Checklist records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class LicenseTypeRequirementsService {
    /* Changes
    *   // 00003563
    *   PacPoint-AZ280819 - Created for PVL phase 1
    * ───────────────────────────────────────────────────────────
    */
    public static Map<String, List<LicenseTypeRequirements__c>> getLicenseTypeRequirements(List<String> licenseTypeIds) {
        List<LicenseTypeRequirements__c> licenseTypeRequirementsList = LicenseTypeRequirementsSelector.getRequirementsByLicenseTypes(licenseTypeIds);
        // used to get license Type Id => licenseType Requirements 
        return (new LicenseTypeRequirementsDomain(licenseTypeRequirementsList)).getLicenseTypeToRequirements();
    }
    /* ───────────────────────────────────────────────────────────
    */
    public static Map<String, List<LicenseTypeRequirements__c>> getLicenseTypeRequirementsMap(List<String> licenseTypeIds, List<String> phaseList, List<String> classificationIds, List<String> typeList) {
        List<LicenseTypeRequirements__c> licenseTypeRequirementsList = LicenseTypeRequirementsSelector.getRequirementsByLicenseTypes(licenseTypeIds, phaseList, classificationIds, typeList);
        return (new LicenseTypeRequirementsDomain(licenseTypeRequirementsList)).getLicenseTypeToRequirements();
    }
}