/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Requirement
* ─────────────────────────────────────────────────────────
* PacPoint-AZ210919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-09-21
* ───────────────────────────────────────────────────────────
*
* ───────────────────────────────────────────────────────────
*/
public class RequirementsSelector {
    public static List<Requirements__c> getChildrenRequirement(List<String> parentIds) {
        return [ Select Id, ParentRequirement__c, RequirementLongDescription__c, 
                RequirementShortDescription__c from Requirements__c where ParentRequirement__c in: parentIds];
    }
    
}