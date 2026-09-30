/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Application Requirement
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
* PacPoint-IC071619 - Updated for PVL Phase 1
* Changed the Object name from Application Checklist to Application Requirement
* ───────────────────────────────────────────────────────────
*/
public class ApplicationRequirementSelector {
    public static List<ApplicationRequirement__c> getApplicationRequirementByAppIds(List<String> appIds) {
        return [ Select Id, Remarks__c,
        // Changes to move License Type Requirement Matching to Requirements
        // Case: 00003563
                Requirement__c, RequirementLongDescription__c, RequirementShortDescription__c, 
                IsDeficient__c, Application__c from ApplicationRequirement__c where Application__c in: appIds];
    }
}