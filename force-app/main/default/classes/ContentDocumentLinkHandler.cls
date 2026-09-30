/*
* ─────────────────────────────────────────────────────────
* class for the Content Document Link Handller used to handle 
* ContentDocumentLink trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ091521 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2021-09-15
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class ContentDocumentLinkHandler implements ITrigger{
    public ContentDocumentLinkHandler() {}
    List<Id> relatedToCaseLinks = new List<Id>();
    public void bulkBefore() {
        if(Trigger.isInsert) {
            ContentDocumentLinkService.captureInvalidCapture(Trigger.new);
        } else if(Trigger.isDelete) {
            ContentDocumentLinkService.captureInvalidCapture(Trigger.old);
        }
    }
    public void bulkAfter() {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {
        ContentDocumentLink record = (ContentDocumentLink)so;
        if(String.isNotBlank(record.LinkedEntityId) && record.LinkedEntityId.getSObjectType() == Case.SobjectType) relatedToCaseLinks.add(record.Id);
        ContentDocumentLinkService.captureDocusignStatusIdMap(so);
    }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
       ContentDocumentLinkService.runFinally();
        if(!relatedToCaseLinks.isEmpty()) System.enqueueJob(new UploadCaseFileToDocSignQueueable(this.relatedToCaseLinks));
    }
}