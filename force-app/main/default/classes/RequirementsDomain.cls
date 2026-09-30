/*
* ─────────────────────────────────────────────────────────
* class for manage unit record logic for the Requirement
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
public class RequirementsDomain extends SObjectDomain {
    public RequirementsDomain(List<Requirements__c> requirements) {
        super(requirements);
    }

    // 00003563 used to generate Parent Requirement Id => Requirements
    public Map<String, List<Requirements__c>> getChildren() {
        Map<String, List<Requirements__c>> children = new Map<String, List<Requirements__c>>();
        for(Sobject record: records) {
            Requirements__c requirement = (Requirements__c) record;
            if(requirement.ParentRequirement__c == null ) {
                continue;
            }
            List<Requirements__c> requirements = new List<Requirements__c>();
            if(children.containsKey(requirement.ParentRequirement__c)) {
                requirements = children.get(requirement.ParentRequirement__c);
            }
            requirements.add(requirement);
            children.put(requirement.ParentRequirement__c, requirements);
        }
        return children;
    }
    // 0003563 used to generate Application Requirement records
    public List<ApplicationRequirement__c> getChildrenApplicationRequirements(ApplicationRequirement__c parentRecord) {
        List<ApplicationRequirement__c> appReqlist = new List<ApplicationRequirement__c>();
        for(SObject record: records) {
            Requirements__c childRecord = (Requirements__c)record;
            ApplicationRequirement__c applicationRequirement = new ApplicationRequirement__c();
            applicationRequirement.Application__c = parentRecord.Application__c;
            applicationRequirement.ParentApplicationRequirement__c = parentRecord.Id;
            // Changes to move License Type Requirement Matching to Requirements
            // Case: 00003563
            applicationRequirement.Requirement__c = childRecord.Id;
            applicationRequirement.RequirementLongDescription__c 
                = childRecord.RequirementLongDescription__c;
            applicationRequirement.RequirementShortDescription__c 
                = childRecord.RequirementShortDescription__c;
            applicationRequirement.IsDeficient__c = false;
            appReqlist.add(applicationRequirement);
        }
        return appReqlist;
    }
}