/*
* ─────────────────────────────────────────────────────────
* class for managing the application requirement unit logic
* ─────────────────────────────────────────────────────────
* PacPoint-AZ280819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-08-28
* ───────────────────────────────────────────────────────────
* 
* 
* 
* ───────────────────────────────────────────────────────────
*/
public class ApplicationRequirementDomain extends SObjectDomain{
    public ApplicationRequirementDomain(List<ApplicationRequirement__c> appRequirements) {
        super(appRequirements);
    }
    // 00011586
    public List<ApplicationRequirement__c> filterAppRequirementForDelete() {
        List<ApplicationRequirement__c> recordsForDelete = new List<ApplicationRequirement__c>();
        for(ApplicationRequirement__c record: (List<ApplicationRequirement__c>)records) {
            if(!record.IsDeficient__c || String.isBlank(record.Remarks__c)) {
                recordsForDelete.add(record);
            }
        }
        return recordsForDelete;
    }
     
    // 0003563 used to provide Children Application Requirements
    public List<ApplicationRequirement__c> getChildrenApplicationRequirements(Map<String, List<Requirements__c>> childrenRequirements) {
        List<ApplicationRequirement__c> appRequirements = new List<ApplicationRequirement__c>();
        for(SObject record: records) {
            ApplicationRequirement__c parent = (ApplicationRequirement__c) record;
            if(!childrenRequirements.containskey(parent.Requirement__c)) {
                continue;
            }
            List<Requirements__c> requirements = childrenRequirements.get(parent.Requirement__c);
            List<ApplicationRequirement__c> childAppReqlist 
                = (new RequirementsDomain(requirements)).getChildrenApplicationRequirements(parent);
            appRequirements.addAll(childAppReqlist );
        }
        return appRequirements;
    }

    // 00003563 used to generate Application Id => Id Set of Application Requirement Ids
    public Map<String, Set<String>> getAppToRequirementIdSet() {
        Map<String, Set<String>> appIdToRequirementIdSet = new Map<String, Set<String>>();
        for(SObject record: records) {
            ApplicationRequirement__c appRequirement = (ApplicationRequirement__c) record;
            Set<String> requirementIdSet = new Set<String>();
            if(appIdToRequirementIdSet.containsKey(appRequirement.Application__c)) {
                requirementIdSet = appIdToRequirementIdSet.get(appRequirement.Application__c);
            }
            requirementIdSet.add(appRequirement.Requirement__c);
            appIdToRequirementIdSet.put(appRequirement.Application__c, requirementIdSet);
        }
        return appIdToRequirementIdSet;
    }
    
    // 00003563 used to get applicaiton requirements from existing requirement Id
    public List<ApplicationRequirement__c> filterRecordsFromSet(Map<String, Set<String>> appIdToRequirementIdSet ) {
        List<ApplicationRequirement__c> filteredRecords = new List<ApplicationRequirement__c>();
        for(SObject record: records) {
            ApplicationRequirement__c appRequirement = (ApplicationRequirement__c) record;
            Set<String> existingRequirementIdSet = appIdToRequirementIdSet.get(appRequirement.Application__c);
            String requirementId = appRequirement.Requirement__c;
            if(existingRequirementIdSet == null 
                || !existingRequirementIdSet.contains(requirementId)) {
                    
                filteredRecords.add(appRequirement);
            }
        }
        return filteredRecords;
    }
}