/*
 * ___________________________________________________________________________________
 * Test class for FileDetailCreatorController
 * __________________________________________________________________________________
 * PacPoint-CL013019 - Created for BREG phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author Chris Loyola - PacificPointCorp
 *
 * @created 01/30/2019
 * __________________________________________________________________________________
 */
@IsTest
private class FileDetailCreatorControllerTest {
    @TestSetup
    static void setup() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;

        Filing__c filing = new Filing__c();
        filing.FiscalYearEnd__c = Date.today().addYears(1);
        filing.Account__c = acct.Id;
        filing.Status__c = 'Deficiency Letter Sent';
        insert filing;

        RecordTypeInfo fdSeb = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('SEB');
        FileDetails__c fd = new FileDetails__c();
        fd.RecordTypeId = fdSeb.getRecordTypeId();
        fd.Category__c = 'SEB Clerical';
        fd.Type__c = 'Memorandum';
        insert fd;
    }

    @isTest
    static void testSaveRecords() {
        Filing__c filing = [SElECT Id, ShowGenericUploadButton__c FROM Filing__c where ShowGenericUploadButton__c = true];
        RecordTypeInfo fdSeb = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('SEB');
        FileDetails__c fd = new FileDetails__c();
        fd.RecordTypeId = fdSeb.getRecordTypeId();
        fd.Category__c = 'SEB Clerical';
        fd.Type__c = 'Memorandum';
        fd.Filing__c = filing.Id;

        FileDetailCreatorController.saveRecord('test', fd);
    }

    @isTest
    static void testSaveRecordsException() {
        RecordTypeInfo fdSeb = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('SEB');
        FileDetails__c fd = new FileDetails__c();
        fd.RecordTypeId = fdSeb.getRecordTypeId();
        fd.Category__c = 'SEB Clerical';
        fd.Type__c = 'Memorandum';
        FileDetailCreatorController.checkIfFileDetail(fd.Id);
        FileDetailCreatorController.saveRecord('test', fd);
    }

    @IsTest
    static void getAvailableRecordTypesTest() {
        List<FileDetailCreatorController.AvailableRecordType> rts =
                FileDetailCreatorController.getAvailableRecordTypes();
        List<RecordTypeInfo> rtis = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfos();
        System.assertEquals(rts.size(), rtis.size() - 1);
    }

    @IsTest
    static void isVisibleTest() {
        Filing__c filing = [SElECT Id, ShowGenericUploadButton__c FROM Filing__c];

        Boolean isVisibile = FileDetailCreatorController.isVisible(filing.Id, 'ShowGenericUploadButton__c');
        System.assertEquals(filing.ShowGenericUploadButton__c, isVisibile);
    }

    @IsTest
    static void deleteTest() {
        FileDetails__c fd = [SElECT Id FROM FileDetails__c];
        FileDetailCreatorController.deleteFileDetail(fd.Id);

        List<FileDetails__c> fds = [SELECT Id FROM FileDetails__c];

        System.assert(fds.isEmpty());
    }
}