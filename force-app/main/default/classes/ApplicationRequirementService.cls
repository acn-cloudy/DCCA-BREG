/*
* ─────────────────────────────────────────────────────────
* class for managing the application requirement logics
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
public class ApplicationRequirementService {
    // 00003563 used to generate Application Id => Id Set of Application Requirement Ids
    public static Map<String, Set<String>> getAppRequirementIdSet(List<String> appIds) {
        // Query Application Requirements
        List<ApplicationRequirement__c> applicationRequirementList
            = ApplicationRequirementSelector.getApplicationRequirementByAppIds(appIds);
        // Get Application Id => requirement Id Set
        return (new ApplicationRequirementDomain(applicationRequirementList)).getAppToRequirementIdSet();
    }
    // 00003563 used to create children application requirement 
    public static void createChildrenApplicationRequirements(List<ApplicationRequirement__c> applicationRequirements) {
        //get requirement Ids
        List<String> requirementIds = (List<String>) (new ApplicationRequirementDomain(
                        applicationRequirements)).getFieldValues('Requirement__c');
        // Query the children requirements;
        Map<String, List<Requirements__c>> childrenRequirements 
            = RequirementsService.generateChildren(requirementIds);
        // get new Application Requirement list 
        List<ApplicationRequirement__c> childAppRequirements = (new ApplicationRequirementDomain(
            applicationRequirements)).getChildrenApplicationRequirements(childrenRequirements);
        insert childAppRequirements;
    }
    // 00005902
    public static void updateRemarkTagsForDocGen(SObject oldSo, SObject so) {
        ApplicationRequirement__c appRequirement = (ApplicationRequirement__c) so;
        if(String.isBlank(appRequirement.Remarks__c)) {
            appRequirement.RemarksTag__c = '';
        } else {
            appRequirement.RemarksTag__c 
                = '<tr><td colspan="1" rowspan="1" style="width: 16.8pt;" valign="top"></td><td colspan="1" rowspan="1" style="width: 450.7pt;" valign="top" >'
            +'<table><tr><td colspan="1" rowspan="1" style="width: 16.8pt;" valign="top">'
            +'<u>x</u></span></td><td colspan="1" rowspan="1" style="width: 417.1pt;" valign="top">'
            + appRequirement.Remarks__c +'</span></td></tr></table></td></tr>';
        }    
    }
    //00005929 Trigger to clean "Is Deficient" flag
    public static void cleanIsDeficientFlag(Map<Id, SObject> newSoMap,
                                            Map<Id, SObject>oldSoMap) {
        Map<Id, ApplicationRequirement__c> newMap = (Map<Id, ApplicationRequirement__c>) newSoMap;
        Map<Id, ApplicationRequirement__c> oldMap = (Map<Id, ApplicationRequirement__c>) oldSoMap;

        List<Id> parentApplicationRequirementIds = new List<Id>();

        //get parent application requirements
        for (ApplicationRequirement__c r : newMap.values()) {
            if (r.IsDeficient__c != oldMap.get(r.Id).IsDeficient__c &&
                    !r.IsDeficient__c &&
                            r.ParentApplicationRequirement__c != null) {
                parentApplicationRequirementIds.add(r.ParentApplicationRequirement__c);
            }
        }

        if (!parentApplicationRequirementIds.isEmpty()) {
            //get parent application requirements records with its related deficient requirements
            List<ApplicationRequirement__c> applicationRequirementWithChildInfo = [
                    SELECT
                            Id,
                            (SELECT Id
                            FROM ApplicationRequirements__r
                            WHERE IsDeficient__c = true)
                    FROM ApplicationRequirement__c
                    WHERE Id IN :parentApplicationRequirementIds
            ];

            List<ApplicationRequirement__c> toUpdate = new List<ApplicationRequirement__c>();

            //check if parent application requirements has related deficient application requirements
            //if none then set its IsDeficient = false
            for (ApplicationRequirement__c ar : applicationRequirementWithChildInfo) {
                if (ar.ApplicationRequirements__r.isEmpty()) {
                    ar.IsDeficient__c = false;
                    toUpdate.add(ar);
                }
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }
    }

    public static void runFinally(List<ApplicationRequirement__c> applicationRequirements) {
        if(Trigger.isafter) {
            if(Trigger.isInsert) {
                createChildrenApplicationRequirements(applicationRequirements);
            }
        }
    }
}