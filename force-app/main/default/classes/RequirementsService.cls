/*
* ─────────────────────────────────────────────────────────
* class for manage business logic for the Requirement
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
public class RequirementsService {
    public static Map<String, List<Requirements__c>> generateChildren(List<String> requirementIds) {
        // Query Requirements 
        List<Requirements__c> childrenRequirements 
            = RequirementsSelector.getChildrenRequirement(requirementIds);
        Map<String, List<Requirements__c>> children = (new RequirementsDomain(childrenRequirements)).getChildren();
        return children;
    }
}