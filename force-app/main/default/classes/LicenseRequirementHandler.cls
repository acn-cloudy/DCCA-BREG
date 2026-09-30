/*
 * ___________________________________________________________________________________
 * Class for the LicenseRequirement Handler used to handle
 * LicenseRequirement trigger
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
public with sharing class LicenseRequirementHandler implements ITrigger{
    public void bulkBefore() {
    }

    public void bulkAfter() {
        if (Trigger.isAfter && Trigger.isUpdate) {
            LicenseRequirementService.cleanIsDeficientFlag(Trigger.newMap, Trigger.oldMap);
        }
    }

    public void beforeInsert(SObject so) {
    }

    public void beforeUpdate(List<SObject> newlstObj,
                             List<SObject> oldlstObj,
                             Map<Id, SObject> newMapObj,
                             Map<Id, SObject> oldMapObj) {
    }

    public void beforeUpdate(SObject oldSo,
                             SObject so) {
    }

    public void beforeDelete(SObject so) {
    }

    public void beforeUnDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
    }

    public void afterUpdate(SObject oldSo, SObject so) {
    }

    public void beforeInsert(List<SObject> newlstObj) {
    }

    public void afterDelete(SObject so) {
    }

    public void afterUnDelete(SObject so) {
    }

    public void andFinally() {
    }
}