/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
* License Condition records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ201119 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-11-20
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseConditionDomain extends SObjectDomain {
    public LicenseConditionDomain(List<LicenseConditions__c> conditions) {
        super(conditions);
    }
    public List<LicenseConditions__c> cloneLicenseConditions() {
        List<LicenseConditions__c> clonedLicenseConditions = new List<LicenseConditions__c>();
        for(LicenseConditions__c condition: (List<LicenseConditions__c>)records) {
            LicenseConditions__c newRec = new LicenseConditions__c();
            newRec = condition.clone();
            
            newRec.LicenseCondition__c = condition.Id;
            newRec.License__c = condition.DependentLicense__c;
            newRec.Id = null;
            clonedLicenseConditions.add(newRec);
        }
        return clonedLicenseConditions;
    }
    public List<LicenseConditions__c> getLicenseConditionsRecords() {
        List<LicenseConditions__c> filteredConditions = new List<LicenseConditions__c>();        
        for(LicenseConditions__c record: (List<LicenseConditions__c>) records) {
            if(record.RMEandEntity__c) {
                filteredConditions.add(record);
            }
        }
        return filteredConditions;
    }

    public List<LicenseConditions__c> filterLicenseConditionsForDeletion( 
            Map<String, Set<String>> dependentLicenseIdToConditionIdSet) {
        
        List<LicenseConditions__c> conditionsForDeletion = new List<LicenseConditions__c>();        
        for(LicenseConditions__c record: (List<LicenseConditions__c>) records) {
            String parentLicenseConditionId = record.LicenseCondition__c;
            String licenseId = record.License__c;
            Set<String> conditionSet = dependentLicenseIdToConditionIdSet.get(licenseId);
            if(conditionSet!= null && conditionSet.contains(parentLicenseConditionId)) {
                conditionsForDeletion.add(record);
            }
        }
        return conditionsForDeletion;
    }

    public Map<String, Set<String>> getLicenseConditionIdSet(Map<String, String> licenseIdsForDependentLicenseIds) {
        Map<String, Set<String>> licenseIdToConditionIdSet = new Map<String, Set<String>>();
        for(LicenseConditions__c record: (List<LicenseConditions__c>) records) {
            Set<String> idSet = new Set<String>();
            if(!record.RMEandEntity__c) {
                continue;
            }
            String licenseId = record.License__c;
            String dependentId = licenseIdsForDependentLicenseIds.get(licenseId);
            if(licenseIdToConditionIdSet.containsKey(dependentId)) {
                idSet = licenseIdToConditionIdSet.get(dependentId);
            }
            
            idSet.add(record.Id);
            licenseIdToConditionIdSet.put(dependentId, idSet);
        }
        return licenseIdToConditionIdSet;
    }
}