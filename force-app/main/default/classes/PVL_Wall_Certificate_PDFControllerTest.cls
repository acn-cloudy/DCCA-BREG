@isTest
private class PVL_Wall_Certificate_PDFControllerTest {
    private static testMethod void testUnit() {
        TestDataFactory.createLicense();
        List<License__c> licenses =  [Select Id, LicenseType__c, LicenseType__r.Id, LicenseType__r.BoardProgram__c, FlaggedforAudit__c from License__c];
        if(!licenses.isEmpty()) {
            if(licenses.get(0).LicenseType__c != null && licenses.get(0).LicenseType__r.BoardProgram__c == null) {
                BoardProgram__c boardProgram = new BoardProgram__c();
                boardProgram.Type__c = 'Program';
                boardProgram.Name = 'Test';
                insert boardProgram;
                LicenseType__c ltype = licenses.get(0).LicenseType__r;
                ltype.BoardProgram__c = boardProgram.Id;
                update ltype;
                String docName = 'WallCert-Test.pdf';
                ContentVersion cv = new ContentVersion();
                cv.ContentLocation = 'S';
                cv.VersionData = Blob.valueOf('Test Data');
                cv.Title = docName;
                cv.PathOnClient = '/'+docName;
                insert cv;
                
                // First get the content document Id from ContentVersion
                Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

                Test.startTest();
                //Create ContentDocumentLink
                ContentDocumentLink cDe = new ContentDocumentLink();
                cDe.ContentDocumentId = conDoc;
                cDe.LinkedEntityId = boardProgram.Id;
                cDe.ShareType = 'I';
                cDe.Visibility = 'AllUsers';
                insert cDe;
            }
        }

        PageReference myVfPage = Page.PVL_Wall_Certificate_PDF;
        Test.setCurrentPage(myVfPage);

		// Put Id into the current page Parameters
		ApexPages.currentPage().getParameters().put('id', licenses.get(0).Id);
        PVL_Wall_Certificate_PDFController con = new PVL_Wall_Certificate_PDFController();
        con.getSignatureImage();
    }
}