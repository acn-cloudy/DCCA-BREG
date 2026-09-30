/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: FileDetailHandlerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL11162021 - Created for Phase #
 * -----------------------------------------------------------------------------------
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/16/2021
 * __________________________________________________________________________________
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class FileDetailHandler implements ITrigger{
    public void bulkBefore() {
        if (Trigger.isUpdate) {
            new FileDetailDomain(Trigger.new).validateEditPermission();
        }
    }

    public void bulkAfter() {
        if (Trigger.isInsert) {
            new FileDetailDomain(Trigger.new).validateCreatePermission();
            new FileDetailDomain(Trigger.new).shareWithAssistantExaminers();
        }
    }

    public void beforeInsert(SObject so) {
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
    }

    public void beforeDelete(SObject so) {
    }

    public void beforeUnDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
    }

    public void afterUpdate(SObject oldSo, SObject so) {
    }

    public void afterDelete(SObject so) {
        FileDetailService.captureDeletion(so);
    }

    public void afterUnDelete(SObject so) {
    }

    public void andFinally() {
        if(Trigger.isAfter){
            FileDetailService.andFinally();
        }
    }
}