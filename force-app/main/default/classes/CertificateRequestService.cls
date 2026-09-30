public with sharing class CertificateRequestService {
    private static Set<String>  pocketIds = new Set<String>();
    private static Set<String>  wallCertIds = new Set<String>();
    public static void captureForPocketWallCertReq(SObject so) {
        CertificateRequest__c record = (CertificateRequest__c) so;
        String pocketId, wallCertId;
        if(record.CertificateType__c == 'B - POCKET ID & WALL CERTIFICATE') {
            wallCertId =record.License__c;
            pocketId = record.License__c;
        } 
        if(record.CertificateType__c == 'C - WALL CERTIFICATE') {
            wallCertId =record.License__c;
        } 
        if(record.CertificateType__c == 'P - POCKET IDENTIFICATION CARD') {
            pocketId = record.License__c;
        } 
        if(pocketId != null || wallCertId != null) {
            generatePocketFiles(pocketId, wallCertId);
        }
    }
    @future(callout=true)
    public static void generatePocketFiles(String pocketId, String wallCertId ) {
        Map<String, Blob>  fileMap = new Map<String, Blob>();
        String recordId;
        if(pocketId != null){
            PageReference pageRef = Page.PVL_Pocket_ID_PDF;
            pageRef.getParameters().put('id', pocketId);
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
            }
            
            fileMap.put('Pocket ID.pdf', content);
            recordId = pocketId;
        }
        if(wallCertId != null) {
            PageReference pageRef = Page.PVL_Wall_Certificate_PDF;
            pageRef.getParameters().put('id', wallCertId);
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
            }
            fileMap.put('Wall Certification.pdf', content);
            recordId = wallCertId;
        }


        List<SpringCMDocument> result = SpringCMConnector.createFiles(recordId, fileMap);

    }
   
}