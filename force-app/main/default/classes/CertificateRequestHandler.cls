public with sharing class CertificateRequestHandler implements ITrigger {
    public CertificateRequestHandler(){}
    public void bulkBefore() {}
    public void bulkAfter() {}
    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}
    public void beforeInsert(SObject so) {}
    public void afterInsert(SObject so) {  
        CertificateRequestService.captureForPocketWallCertReq(so);
     }
    public void beforeUpdate(SObject oldSo, SObject so) {}
    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {}
    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {}
    public void andFinally() {

    }
}