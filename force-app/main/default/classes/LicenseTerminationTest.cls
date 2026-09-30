/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Test class
 *  - checkLicenseStatus : Find and set the status of Licenses with License Types Start of RenewalPerios = Today
 *  Covered for LicenseUpdateStatus
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Irene Cahilo - PacificPointCorp 
 *  @created      PacPoint-IC071819 - Created for PVL Phase 1
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 * Review Irene's Code - Chris Z
 * Logic update - Chris L 10/30/2020 @case 00011612
 * Logic update - Chris L 06/22/2022 @case 00022198
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class LicenseTerminationTest {
    @TestSetup
    static void setup() {
        BusinessAccountCounter__c accountCounterSetting = new BusinessAccountCounter__c();
        accountCounterSetting.ResetDate__c = Date.today();
        accountCounterSetting.Counter__c = 1;
        insert accountCounterSetting;

        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'lct';
        licenseType.RollingLicensePeriod__c = false;
        licenseType.LicenseTypeEffectiveDate__c = Date.today().addDays(-1);
        licenseType.DurationofLicenseInMonths__c = 0;
        licenseType.DurationofRestorationInMonths__c = 0;
        licenseType.StatusDuetoNonRestore__c = 'F - Terminated; Needs to Reapply';
        licenseType.Status__c = 'Active';
        licenseType.AbleToInactivate__c = true;
        licenseType.GenerateLicenseStatus__c = 'D - Forfeited; Needs to Restore';
        licenseType.RenewalWindowInDays__c = 5;
        insert licenseType;
    }

    @IsTest
    static void licenseStatusUpdatesTest() {
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        LicenseType__c licenseType = [SELECT Id FROM LicenseType__c];

        Id licenseRtId = License__c.getSObjectType()
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PVLCTEntity')
                .getRecordTypeId();

        Account acc = new Account();
        acc.Name = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';

        insert app;

        License__c license = new License__c();
        license.Name = 'acc';
        license.Application__c = app.Id;
        license.LicenseType__c = licenseType.Id;
        license.RecordTypeId = licenseRtId;
        license.ActiveInactive__c = 'Active';
        license.RestorationDeadline__c = Date.today().addDays(-1);
        license.Status__c = 'D - Forfeited; Needs to Restore';

        insert license;

        Classification__c classification = new Classification__c();
        classification.Name = 'c';
        classification.LicenseType__c = licenseType.Id;
        insert classification;

        LicenseClassification__c licClassification = new LicenseClassification__c();
        licClassification.License__c = license.Id;
        licClassification.Classification__c = classification.Id;
        licClassification.Status__c = 'D - Class No Longer Active (License Delinquent)';
        insert licClassification;

        Test.startTest();
        LicenseTermination scheduler = new LicenseTermination();
        scheduler.execute(null);
        Test.stopTest();
    }

    @IsTest
    static void licenseStatusUpdatesTest2() {
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        LicenseType__c licenseType = [SELECT Id FROM LicenseType__c];

        Id licenseRtId = License__c.getSObjectType()
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PVLCTEntity')
                .getRecordTypeId();

        Account acc = new Account();
        acc.Name = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';

        insert app;

        License__c license = new License__c();
        license.Name = 'acc';
        license.Application__c = app.Id;
        license.LicenseType__c = licenseType.Id;
        license.RecordTypeId = licenseRtId;
        license.RestorationDeadline__c = Date.today().addDays(-1);
        license.ActiveInactive__c = 'Active';
        insert license;

        license.Status__c = 'ZD - Forfeited Disciplined License; Needs To Restore';
        license.CancelDate__c = Date.today();

        update license;

        Test.startTest();
        LicenseTermination scheduler = new LicenseTermination();
        scheduler.execute(null);
        Test.stopTest();
    }

    @IsTest
    static void skipRstrTest() {
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');

        Account acc = new Account();
        acc.Name = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;

        LicenseType__c licenseType = [SELECT Id FROM LicenseType__c];

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RSTR - Restore - No A/I Status';
        app.Phase__c = 'A - Application Received';
        app.Status__c = 'A1 - Application Submitted, Awaiting Review';
        insert app;

        License__c license = new License__c();
        license.Name = 'acc1';
        license.Application__c = app.Id;
        license.LicenseType__c = licenseType.Id;
        license.ActiveInactive__c = 'Active';
        license.RestorationDeadline__c = Date.today().addDays(-1);
        license.Status__c = 'D - Forfeited; Needs to Restore';
        insert license;

        app.CurrentLicense__c = license.Id;
        update app;

        Test.startTest();
        LicenseTermination scheduler = new LicenseTermination();
        scheduler.execute(null);
        Test.stopTest();
    }
}