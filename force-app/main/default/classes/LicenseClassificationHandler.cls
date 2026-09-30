/*
* ─────────────────────────────────────────────────────────
* class for the Application Handller used to handle 
* Application trigger
* ─────────────────────────────────────────────────────────
* PacPoint-CZ190919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-09-19
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseClassificationHandler implements ITrigger{
    public LicenseClassificationHandler() {}
    public void bulkBefore() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {
        //00005655 : Creation of trigger that will update the Class Prefix field on the license based on the Current Classifications
        LicenseClassificationService.updateLicensePrefix(so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        //00005655 : Creation of trigger that will update the Class Prefix field on the license based on the Current Classifications
        LicenseClassificationService.updateLicensePrefix(oldSo, so);
    }
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {
        //00005655 : Creation of trigger that will update the Class Prefix field on the license based on the Current Classifications
        LicenseClassificationService.updateLicensePrefix(so);
    } 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        LicenseClassificationService.runFinally(Trigger.new);
    }
}