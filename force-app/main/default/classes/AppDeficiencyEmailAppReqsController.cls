/*
 * ___________________________________________________________________________________
 * Controller for AppDeficiencyEmailAppReqs component
 * Covered by: AppDeficiencyEmailAppReqsControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL10162019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 10/16/2019
 * __________________________________________________________________________________
 */
public class AppDeficiencyEmailAppReqsController {
    public String applicationId{
        get;set;
    }

    public List<ApplicationRequirement__c> getApplicationRequirements() {
        return [
                SELECT Id,
                        IsDeficient__c,
                        RemarksTag__c,
                        Requirement__r.RequirementLongDescription__c,
                        (SELECT
                                 Id,
                                 IsDeficient__c,
                                 RemarksTag__c,
                                 Requirement__r.RequirementLongDescription__c
                        FROM ApplicationRequirements__r
                        WHERE IsDeficient__c = true
                        ORDER BY SUB__c ASC)
                FROM ApplicationRequirement__c
                WHERE Application__c = :applicationId
                AND IsDeficient__c = true
                AND ParentApplicationRequirement__c = null
                ORDER BY REQMT__c ASC
        ];
    }
}