/*
 * ___________________________________________________________________________________
 * Class for managing the license requirement logic
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-CL10222019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 10/22/2019
 * __________________________________________________________________________________
 */
public with sharing class LicenseRequirementService {

    //00005929 Trigger to clean "Is Deficient" flag
    public static void cleanIsDeficientFlag(Map<Id, SObject> newSoMap,
                                            Map<Id, SObject>oldSoMap) {
        Map<Id, LicenseRequirements__c> newMap = (Map<Id, LicenseRequirements__c>) newSoMap;
        Map<Id, LicenseRequirements__c> oldMap = (Map<Id, LicenseRequirements__c>) oldSoMap;

        List<Id> parentLicenseRequirementIds = new List<Id>();

        //get parent license requirements
        for (LicenseRequirements__c r : newMap.values()) {
            if (r.IsDeficient__c != oldMap.get(r.Id).IsDeficient__c &&
                    !r.IsDeficient__c &&
                            r.ParentLicenseRequirement__c != null) {
                parentLicenseRequirementIds.add(r.ParentLicenseRequirement__c);
            }
        }

        if (!parentLicenseRequirementIds.isEmpty()) {
            //get parent license requirements records with its related deficient requirements
            List<LicenseRequirements__c> applicationRequirementWithChildInfo = [
                    SELECT
                            Id,
                            (SELECT Id
                            FROM LicenseRequirements__r
                            WHERE IsDeficient__c = true)
                    FROM LicenseRequirements__c
                    WHERE Id IN :parentLicenseRequirementIds
            ];

            List<LicenseRequirements__c> toUpdate = new List<LicenseRequirements__c>();

            //check if parent license requirements has related deficient license requirements
            //if none then set its IsDeficient = false
            for (LicenseRequirements__c ar : applicationRequirementWithChildInfo) {
                if (ar.LicenseRequirements__r.isEmpty()) {
                    ar.IsDeficient__c = false;
                    toUpdate.add(ar);
                }
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }
    }
}