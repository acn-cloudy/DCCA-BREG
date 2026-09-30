/*
 * ___________________________________________________________________________________
 * Code coverage for LicenseMassScannerController
 * __________________________________________________________________________________
 * PacPoint-CL12122019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 12/12/2019
 * __________________________________________________________________________________
 */
@IsTest
public class LicenseMassScannerControllerTest {
    @TestSetup
    public static void setup() {
        BusinessAccountCounter__c accountCounterSetting = new BusinessAccountCounter__c();
        accountCounterSetting.ResetDate__c = Date.today();
        accountCounterSetting.Counter__c = 1;
        insert accountCounterSetting;

        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');

        Id licenseRtId = License__c.getSObjectType()
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PVLCTEntity')
                .getRecordTypeId();

        Account acc = new Account();
        acc.Name = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;

        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'lct';
        licenseType.AbleToInactivate__c = true;
        licenseType.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';

        LicenseType__c licenseTypeCeRequired = new LicenseType__c();
        licenseTypeCeRequired.Name = 'lct';
        licenseTypeCeRequired.AbleToInactivate__c = true;
        licenseTypeCeRequired.CERequired__c = true;
        licenseTypeCeRequired.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';

        LicenseType__c licenseTypeInsuranceBondRequired = new LicenseType__c();
        licenseTypeInsuranceBondRequired.Name = 'lct';
        licenseTypeInsuranceBondRequired.AbleToInactivate__c = true;
        licenseTypeInsuranceBondRequired.RequiresInsurance__c = true;
        licenseTypeInsuranceBondRequired.ContinuousInsuranceRequired__c = true;
        licenseTypeInsuranceBondRequired.InsuranceBondTypesRequired__c = 'BD - BOND;EX - EXEMPTION';
        licenseTypeInsuranceBondRequired.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        insert new List<LicenseType__c>{licenseType, licenseTypeCeRequired, licenseTypeInsuranceBondRequired};

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';

        Application__c appSameLicPeriod = new Application__c();
        appSameLicPeriod.Name = 'app2';
        appSameLicPeriod.LicenseType__c = licenseType.Id;
        appSameLicPeriod.Applicant__c = acc.Id;
        appSameLicPeriod.LicensePeriod__c = 'This License Period';
        appSameLicPeriod.Type__c = 'RNEW - Renewal';

        Application__c appSameLicPeriod2 = new Application__c();
        appSameLicPeriod2.Name = 'app2';
        appSameLicPeriod2.LicenseType__c = licenseType.Id;
        appSameLicPeriod2.Applicant__c = acc.Id;
        appSameLicPeriod2.LicensePeriod__c = 'This License Period';
        appSameLicPeriod2.Type__c = 'RNEW - Renewal';

        insert new List<Application__c>{app, appSameLicPeriod, appSameLicPeriod2};

        License__c license = new License__c();
        license.Name = 'acc';
        license.Application__c = app.Id;
        license.Licensee__c = acc.Id;
        license.LicenseType__c = licenseType.Id;
        license.RecordTypeId = licenseRtId;
        license.Status__c = 'C - Current, Valid & In Good Standing';

        License__c validLicenseNoApp = new License__c();
        validLicenseNoApp.Name = 'vcc';
        validLicenseNoApp.Licensee__c = acc.Id;
        validLicenseNoApp.LicenseType__c = licenseType.Id;
        validLicenseNoApp.RecordTypeId = licenseRtId;
        validLicenseNoApp.Status__c = 'C - Current, Valid & In Good Standing';

        License__c invalidLicense = new License__c();
        invalidLicense.Name = 'iacc';
        invalidLicense.Application__c = app.Id;
        invalidLicense.Licensee__c = acc.Id;
        invalidLicense.LicenseType__c = licenseType.Id;
        invalidLicense.Status__c =
                'Z1 - Susp Due To 1)Loss Of Bond By Licensee And/Or Dependent Or 2)Loss of RME, If Def Not Cured by Renewal, Must Re-Apply';

        License__c validateLicenseWithAppsSameLicensePeriod = new License__c();
        validateLicenseWithAppsSameLicensePeriod.Name = 'vpcc';
        validateLicenseWithAppsSameLicensePeriod.Application__c = appSameLicPeriod.Id;
        validateLicenseWithAppsSameLicensePeriod.Licensee__c = acc.Id;
        validateLicenseWithAppsSameLicensePeriod.LicenseType__c = licenseType.Id;
        validateLicenseWithAppsSameLicensePeriod.Status__c = 'C - Current, Valid & In Good Standing';

        insert new List<License__c>{
                validateLicenseWithAppsSameLicensePeriod,
                validLicenseNoApp,
                license,
                invalidLicense
                };

        app.CurrentLicense__c = license.Id;
        appSameLicPeriod.CurrentLicense__c = validateLicenseWithAppsSameLicensePeriod.Id;
        appSameLicPeriod2.CurrentLicense__c = validateLicenseWithAppsSameLicensePeriod.Id;
        update new List<Application__c>{app, appSameLicPeriod, appSameLicPeriod2};

        //need to force the status for this "valid" licenses
        //somehow the status is blanked out after insert (maybe a process builder or something)
        validLicenseNoApp.Status__c = 'C - Current, Valid & In Good Standing';
        license.Status__c = 'C - Current, Valid & In Good Standing';
        update new List<License__c>{validLicenseNoApp, license};
    }

    @IsTest
    static void testGetPickListEntries() {
        LicenseMassScannerController.getPickListEntries();
    }

    @IsTest
    static void testScanRenewalUpdateNomatch() {
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'nomatch'}, true,
                'A1 - Application Submitted, Awaiting Review');
    }

    @IsTest
    static void testScanRenewalUpdateA1InActiveNotEligible() {
        LicenseType__c lcType = [
                SELECT
                        Id
                FROM LicenseType__c
                LIMIT 1
        ];

        lcType.AbleToInactivate__c = false;
        update lcType;

        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc',
                                                                        'vcc'}, true,
                'A3 - Deficiency Notice Sent');
    }

    @IsTest
    static void testScanRenewalUpdateA3Active() {
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc',
                                                                        'vcc'}, false,
                'A3 - Deficiency Notice Sent');
    }

    @IsTest
    static void testScanRenewalUpdateA3InActive() {
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc',
                                                                        'vcc'}, true,
                'A3 - Deficiency Notice Sent');
    }

    @IsTest
    static void testScanRenewalUpdateE1Active() {
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc',
                                                                        'vcc'}, false,
                'E1 - Awaiting EO Review');
    }

    @IsTest
    static void testScanRenewalUpdateHActive() {
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc',
                                                                        'vcc'}, false,
                'HC - Application Completed');
    }

    @IsTest
    static void testScanRenewalUpdateHCFlaggedForAudit() {
        License__c lc = [SELECT Id FROM License__c WHERE Name='vcc'];
        lc.FlaggedforAudit__c = true;
        update lc;
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'vcc'}, false,
                'HC - Application Completed');
    }

    @IsTest
    static void testScanRenewalUpdateHCInsuranceRequiredNoRelatedBonds() {
        LicenseType__c insuranceRequired = [
                SELECT
                        Id
                FROM LicenseType__c
                WHERE RequiresInsurance__c = true
                AND ContinuousInsuranceRequired__c = true
        ];

        License__c lc = [SELECT Id FROM License__c WHERE Name='acc'];
        lc.LicenseType__c = insuranceRequired.Id;
        update lc;
        Test.startTest();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = insuranceRequired.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';
        app.CurrentLicense__c = lc.Id;
        insert app;

        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc'}, false,
                'HC - Application Completed');
        Test.stopTest();
    }

    // @IsTest
    // static void testScanRenewalUpdateHCInsuranceRequiredNoValidRelatedBonds() {
    //     LicenseType__c insuranceRequired = [
    //             SELECT
    //                     Id
    //             FROM LicenseType__c
    //             WHERE RequiresInsurance__c = true
    //             AND ContinuousInsuranceRequired__c = true
    //     ];

    //     License__c lc = [SELECT Id FROM License__c WHERE Name='acc'];
    //     lc.LicenseType__c = insuranceRequired.Id;
    //     lc.EffectiveExpireDate__c = Date.today().addDays(1);
    //     update lc;

    //     InsuranceBond__c bond1 = new InsuranceBond__c();
    //     bond1.Type__c = 'BD - Bond';
    //     bond1.Amount__c = 1;
    //     bond1.EffectiveDate__c = Date.today();
    //     bond1.TermDate__c = Date.today().addDays(1);
    //     bond1.CancelDate__c = Date.today().addDays(1);
    //     bond1.Status__c = 'Active';
    //     bond1.License__c = lc.Id;

    //     InsuranceBond__c bond2 = new InsuranceBond__c();
    //     bond2.Type__c = 'BD - Bond';
    //     bond2.Amount__c = 1;
    //     bond2.EffectiveDate__c = Date.today();
    //     bond2.TermDate__c = Date.today().addDays(1);
    //     bond2.CancelDate__c = Date.today().addDays(1);
    //     bond2.Status__c = 'Active';
    //     bond2.License__c = lc.Id;
    //     insert new List<InsuranceBond__c>{bond1, bond2};

    //     Account acc = [SELECT Id FROM Account LIMIT 1];
    //     Application__c app = new Application__c();
    //     app.Name = 'app';
    //     app.LicenseType__c = insuranceRequired.Id;
    //     app.Applicant__c = acc.Id;
    //     app.Type__c = 'RNEW - Renewal';
    //     app.CurrentLicense__c = lc.Id;
    //     insert app;
    //     test.startTest();
    //     LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc'}, false,
    //             'HC - Application Completed');
    //     test.stopTest();
    // }

    @IsTest
    static void testScanRenewalUpdateHCInsuranceRequiredWithValidRelatedBonds() {
        LicenseType__c insuranceRequired = [
                SELECT
                        Id
                FROM LicenseType__c
                WHERE RequiresInsurance__c = true
                AND ContinuousInsuranceRequired__c = true
        ];

        License__c lc = [SELECT Id FROM License__c WHERE Name='acc'];
        lc.LicenseType__c = insuranceRequired.Id;
        lc.EffectiveExpireDate__c = Date.today();
        update lc;

        InsuranceBond__c bond1 = new InsuranceBond__c();
        bond1.Type__c = 'BD - Bond';
        bond1.Amount__c = 1;
        bond1.EffectiveDate__c = Date.today();
        bond1.TermDate__c = Date.today().addDays(1);
        bond1.CancelDate__c = Date.today().addDays(1);
        bond1.Status__c = 'Active';
        bond1.License__c = lc.Id;

        InsuranceBond__c bond2 = new InsuranceBond__c();
        bond2.Type__c = 'BD - Bond';
        bond2.Amount__c = 1;
        bond2.EffectiveDate__c = Date.today();
        bond2.TermDate__c = Date.today().addDays(1);
        bond2.CancelDate__c = Date.today().addDays(1);
        bond2.Status__c = 'Active';
        bond2.License__c = lc.Id;
        insert new List<InsuranceBond__c>{bond1, bond2};
        Test.startTest();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = insuranceRequired.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';
        app.CurrentLicense__c = lc.Id;
        insert app;

        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc'}, false,
                'HC - Application Completed');
        Test.stopTest();
    }

    @IsTest
    static void testScanWithAppsSameLicensePeriod() {
        LicenseMassScannerController.scanRenewalUpdate(new List<String>{'vpcc'}, true,
                'A3 - Deficiency Notice Sent');
    }

    @IsTest
    static void testScanCreateNotFound() {
        LicenseMassScannerController.scanCreate(new List<String>{'nomatch'}, Date.today(), 'RSTR', 'Yes', 'Partner', false);
    }

    @IsTest
    static void testScanCreateWrongStatus() {
        LicenseMassScannerController.scanCreate(new List<String>{'iacc'}, Date.today(), 'RSTR', 'Yes', 'Partner', false);
    }

    @IsTest
    static void testScanCreateWithExistingRenewalApplication() {
        LicenseMassScannerController.scanCreate(new List<String>{'acc'}, Date.today(), 'RSTR', 'Yes', 'Partner', false);
    }

    @IsTest
    static void testScanCreateValidLicenseActive() {
        License__c vc = [SELECT Id FROM License__c WHERE Name ='vcc'];
        vc.ActiveInactive__c = 'Active';
        update vc;

        LicenseMassScannerController.scanCreate(new List<String>{'vcc'}, Date.today(), 'RSTR', 'Yes', 'Partner', false);
    }

    @IsTest
    static void testScanCreateValidLicenseInActive() {
        License__c vc = [SELECT Id FROM License__c WHERE Name ='vcc'];
        vc.ActiveInactive__c = 'Inactive';
        update vc;

        LicenseMassScannerController.scanCreate(new List<String>{'vcc'}, Date.today(), 'RSTR', 'Yes', 'Partner', false);
    }

    @IsTest
    static void testPrintResult() {
        LicenseMassScannerController.ScanResult scanResult =
                LicenseMassScannerController.scanCreate(new List<String>{ 'vcc'},
                        Date.today(), 'RSTR', 'Yes', 'Partner', false);
        LicenseMassScannerController.printResult(JSON.serialize(scanResult));
    }

    @IsTest
    static void testCommitScanRenewalUpdateResult() {
        LicenseMassScannerController.ScanResult scanResult =
                LicenseMassScannerController.scanRenewalUpdate(new List<String>{'acc',
                                                                                'vcc'}, false,
                        'HC - Application Completed');

        LicenseMassScannerController.commitScanResult(JSON.serialize(scanResult));
    }

    @IsTest
    static void testCommitScanCreateResult() {
        LicenseMassScannerController.ScanResult scanResult =
                LicenseMassScannerController.scanCreate(new List<String>{'vcc'}, Date.today(), 'RSTR', 'Yes',
                        'Partner', false);

        LicenseMassScannerController.commitScanResult(JSON.serialize(scanResult));
    }
}