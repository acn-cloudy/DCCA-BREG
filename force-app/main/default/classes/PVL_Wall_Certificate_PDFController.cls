public without sharing class PVL_Wall_Certificate_PDFController {
    // defination
	public Id licenseId       {get;set;}
	public License__c lic     {get;set;}
	
    //construction
    public PVL_Wall_Certificate_PDFController() {
        licenseId = apexpages.currentpage().getparameters().get('id');
        
        // eagarao: CASE 27606
        // 02/17/2023 09:28 AM
        // Added BoardProgramName__c in query 
        lic = [select Id, Name, LicenseTypeDescription__c, BoardProgramName__c,LicenseName__c, Licensee__r.Name,LicenseTypeDescriptionWallCert__c,WallCertTypeofSeal__c ,
                WallCertLicenseRegistrationText__c, WallCertStateofHawaiiText__c, OriginalDateofLicensure__c, LicenseNumberFormula__c,
                WallCertStateofHawaiiDate__c, WallCertBusinessAddressLocatedAt__c, WallCertBusinessAddress__c, WallCertBottomVerbiage__c,
                LicenseType__r.WallCertMiddleVerbiage__c, WallCertMiddleDate__c, WallCertSignatureType__c,LicenseType__r.BoardProgram__c
               from License__c where id =: licenseId];
    }
    public String signatureImage;
    public String getSignatureImage() {
        if(lic != null && lic.LicenseType__r.BoardProgram__c != null) {
            String contentDocId;
            String boardProgramId = lic.LicenseType__r.BoardProgram__c;
            List<ContentDocumentLink> links = [Select Id, ContentDocumentId from ContentDocumentLink where LinkedEntityId=: boardProgramId];
            List<String> documentIds = new List<String>();
            for(ContentDocumentLink link: links) {
                documentIds.add(link.ContentDocumentId);
            }
            String sUrl;
            List<ContentDistribution> contentDocuments = [select ContentDownloadUrl, Name from ContentDistribution where ContentDocumentId in: documentIds and Name like 'WallCert-%' ];
            for(ContentDistribution doc: contentDocuments) {
                sUrl = doc.ContentDownloadUrl;
                break;
            }
            return sUrl;
        } else {
            return null;
        }
    }
}