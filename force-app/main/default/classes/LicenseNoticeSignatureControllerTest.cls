/*
 * ___________________________________________________________________________________
 * LicenseNoticeSignatureController test
 * __________________________________________________________________________________
 * PacPoint-CL02142022 - Created for Case 00013106
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 02/14/2022
 * __________________________________________________________________________________
 */
@IsTest
private class LicenseNoticeSignatureControllerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
        BoardProgram__c boardProgram = new BoardProgram__c();
        boardProgram.Name = 'testBoard';
        boardProgram.Type__c = 'Board';
        boardProgram.BoardProgramNumber__c = '1';
        insert boardProgram;

        LicenseType__c licenseType = [SELECT Id FROM LicenseType__c LIMIT 1];
        licenseType.BoardProgram__c = boardProgram.Id;
        update licenseType;

        ContentVersion cv = new ContentVersion();
        cv.Description = 'test description';
        cv.PathOnClient = 'test_file.txt';
        cv.Title = 'EOSignature';
        cv.versiondata = Blob.valueOf('test file body');
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: cv.Id].ContentDocumentId;
        cdl.LinkedEntityId = boardProgram.Id;
        cdl.ShareType = 'V';
        insert cdl;

        ContentDistribution cd = new ContentDistribution();
        cd.Name = 'Test';
        cd.ContentVersionId = cv.id;
        cd.PreferencesAllowViewInBrowser= true;
        cd.PreferencesLinkLatestVersion=true;
        cd.PreferencesNotifyOnVisit=false;
        cd.PreferencesPasswordRequired=false;
        cd.PreferencesAllowOriginalDownload= true;
        insert cd;
    }

    @IsTest
    static void testGetImageData() {
        License__c lic = [SELECT Id FROM License__c WHERE Name = 'acc'];
        LicenseNoticeSignatureController ctrl = new LicenseNoticeSignatureController();
        ctrl.lic = lic;
        ctrl.getImageData();
    }
}