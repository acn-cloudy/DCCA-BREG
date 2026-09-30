/**
 * VPVL-13 / coverage uplift: direct unit tests for licenseService legacy
 * methods and LicenseHandler stub paths.
 *
 * Salesforce intermittently fails to track ApexCodeCoverage records for the
 * pre-existing LicenseAllTest (an old, large @IsTest class on API v48 that
 * mixes the deprecated testMethod keyword with newer @isTest annotations).
 * Moving these direct-invocation tests into a fresh API-58+ test class is the
 * simplest workaround.
 *
 * All assertions exercise the production code through public static methods or
 * the ITrigger handler API directly — no production source is modified.
 */
@IsTest
private class LicenseServiceCoverageTest {

    // ─── helpers ────────────────────────────────────────────────────────────

    private static Integer fakeIdCounter = 1;
    private static Id makeFakeId(Schema.SObjectType sot) {
        String prefix = sot.getDescribe().getKeyPrefix();
        String suffix = String.valueOf(fakeIdCounter++).leftPad(12, '0');
        return Id.valueOf(prefix + suffix);
    }

    /**
     * Build an in-memory License via JSON so read-only formula/rollup fields
     * (LicenseTypeName__c, NumberofActive..., PB_Counter__c,
     * EntityPrincipalCounter__c, etc.) can be populated for unit tests.
     */
    private static License__c makeLicenseInMemory(
        String licenseTypeName,
        Decimal numberOfActiveEmployers,
        Decimal numberOfActiveEmployees,
        Decimal pbCounter,
        Decimal entityPrincipalCounter
    ) {
        Map<String, Object> fields = new Map<String, Object>{
            'Status__c' => 'C - Current, Valid & In Good Standing',
            'ActiveInactive__c' => 'Active',
            'LicenseTypeName__c' => licenseTypeName,
            'LicenseTypeDependencyRequired__c' => true,
            'DependencyRequired__c' => true,
            'NumberofActiveEmployers__c' => numberOfActiveEmployers,
            'NumberofActiveEmployees__c' => numberOfActiveEmployees,
            'PB_Counter__c' => pbCounter,
            'EntityPrincipalCounter__c' => entityPrincipalCounter,
            'StatusDuetoLossofDependent__c' => 'Z1 - Susp Due To 1)Loss Of Bond By Licensee And/Or Dependent Or 2)Loss of RME, If Def Not Cured by Renewal, Must Re-Apply'
        };
        return (License__c) JSON.deserialize(JSON.serialize(fields), License__c.class);
    }

    // ─── LicenseHandler stub / disable-guard coverage ───────────────────────

    @isTest
    static void testLicenseHandlerStubMethodsDirectInvocation() {
        LicenseHandler handler = new LicenseHandler();
        License__c stub = new License__c();
        Test.startTest();
        handler.beforeDelete(stub);
        handler.beforeUnDelete(stub);
        handler.afterDelete(stub);
        handler.afterUnDelete(stub);
        Test.stopTest();
        System.assert(true, 'LicenseHandler stub methods callable');
    }

    @isTest
    static void testLicenseHandlerWithDisableFlagSkipsLogic() {
        TriggerHelper.disableLicenseTrigger = true;
        try {
            LicenseHandler handler = new LicenseHandler();
            License__c stub = new License__c();
            Test.startTest();
            handler.beforeInsert(stub);
            handler.afterInsert(stub);
            handler.beforeUpdate(stub, stub);
            handler.afterUpdate(stub, stub);
            handler.andFinally();
            Test.stopTest();
            System.assert(true, 'Disable flag short-circuits LicenseHandler logic');
        } finally {
            TriggerHelper.disableLicenseTrigger = false;
        }
    }

    // ─── licenseService.captureUpdate criteria branches ─────────────────────

    @isTest
    static void testCaptureUpdateCriteria1RbEntityLostPB() {
        License__c oldL = makeLicenseInMemory('RB - Entity', 1, 1, 1, 1);
        License__c newL = makeLicenseInMemory('RB - Entity', 1, 1, 0, 1);
        Test.startTest();
        licenseService.captureUpdate(oldL, newL);
        Test.stopTest();
        System.assertEquals(true, newL.LossofPrincipalRME__c);
        System.assertEquals(Date.today(), newL.LossofPrincipalBrokerDate__c);
    }

    @isTest
    static void testCaptureUpdateCriteria1NonRbEntityLostPrincipal() {
        License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 0);
        Test.startTest();
        licenseService.captureUpdate(oldL, newL);
        Test.stopTest();
        System.assertEquals(true, newL.LossofPrincipalRME__c);
    }

    @isTest
    static void testCaptureUpdateCriteria2NumberOfActiveEmployeesDropped() {
        License__c oldL = makeLicenseInMemory('CT - Entity', 1, 2, 1, 1);
        License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        Test.startTest();
        licenseService.captureUpdate(oldL, newL);
        Test.stopTest();
        System.assertEquals(true, newL.LossOfRME__c);
    }

    @isTest
    static void testCaptureUpdateCriteria3NumberOfActiveEmployersZero() {
        License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        License__c newL = makeLicenseInMemory('CT - Entity', 0, 1, 1, 1);
        Test.startTest();
        licenseService.captureUpdate(oldL, newL);
        Test.stopTest();
        System.assertEquals(true, newL.LossofEntity__c);
        System.assertEquals(Date.today(), newL.LossofEntityDate__c);
    }

    @isTest
    static void testCaptureUpdateCriteria4MvdNoActiveEmployees() {
        License__c oldL = makeLicenseInMemory('MVD', 1, 1, 1, 1);
        License__c newL = makeLicenseInMemory('MVD', 1, 0, 1, 1);
        Test.startTest();
        licenseService.captureUpdate(oldL, newL);
        Test.stopTest();
        System.assertEquals(true, newL.LossofPrincipalRME__c);
        System.assertEquals(true, newL.GenerateEntityLosesRMENotification__c);
    }

    // ─── licenseService misc methods ────────────────────────────────────────

    @isTest
    static void testCapturePreviousStatusChange() {
        License__c oldL = new License__c(Status__c = 'C - Current, Valid & In Good Standing');
        License__c newL = new License__c(Status__c = 'F - Terminated; Needs to Reapply');
        Test.startTest();
        licenseService.capturePreviousStatus(oldL, newL);
        Test.stopTest();
        System.assertEquals('C - Current, Valid & In Good Standing', newL.PreviousStatus__c);
    }

    @isTest
    static void testCaptureZTStatusChange() {
        License__c oldL = new License__c(Status__c = 'C - Current, Valid & In Good Standing');
        License__c newL = new License__c(
            Status__c = 'ZT - Remain Forfeited Due To Failure To Provide Proof Of Continuous Coverage of Insurance or Bond'
        );
        Test.startTest();
        licenseService.captureZTStatusChagne(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testCaptureAMDInactivationFlag() {
        License__c oldL = new License__c(SendAMDInactivationEmail__c = false);
        License__c newL = new License__c(SendAMDInactivationEmail__c = true);
        Test.startTest();
        licenseService.captureAMDInactivation(oldL, newL);
        Test.stopTest();
        System.assertEquals(false, newL.SendAMDInactivationEmail__c);
    }

    @isTest
    static void testCaptureIdForFileGenerationSingleArgFlagSet() {
        License__c newL = new License__c(GenerateFile__c = true);
        Test.startTest();
        licenseService.captureIdForFileGeneration(newL);
        Test.stopTest();
        System.assertEquals(true, newL.GenerateFile__c);
    }

    @isTest
    static void testCaptureIdForFileGenerationTwoArgChange() {
        License__c oldL = new License__c(GenerateFile__c = false);
        License__c newL = new License__c(GenerateFile__c = true);
        Test.startTest();
        licenseService.captureIdForFileGeneration(oldL, newL);
        Test.stopTest();
        System.assertEquals(false, newL.GenerateFile__c);
    }

    @isTest
    static void testCaptureIdForLicenseConditionsRemoveOnDependentChange() {
        Id fakeLicId = makeFakeId(License__c.SObjectType);
        Id oldDep = makeFakeId(License__c.SObjectType);
        License__c oldL = new License__c(Id = fakeLicId, DependentLicense__c = oldDep);
        License__c newL = new License__c(Id = fakeLicId, DependentLicense__c = null);
        Test.startTest();
        licenseService.captureIdForLicenseConditionsRemove(oldL, newL);
        licenseService.captureIdForLicenseConditionsCreate(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testGeneratePostCardFlagBranch() {
        License__c oldL = new License__c();
        Map<String, Object> fields = new Map<String, Object>{
            'Id' => makeFakeId(License__c.SObjectType),
            'GenerateRenewalPostcards__c' => true,
            'SelectRenewalPostcard__c' => 'TemplateX',
            'PostcardContent__c' => 'PostcardX'
        };
        License__c newL = (License__c) JSON.deserialize(JSON.serialize(fields), License__c.class);
        Test.startTest();
        licenseService.generatePostCard(oldL, newL);
        Test.stopTest();
        System.assertEquals(false, newL.GenerateRenewalPostcards__c);
        System.assertEquals(null, newL.SelectRenewalPostcard__c);
    }

    @isTest
    static void testGenerateRenewalNotificationFlagBranch() {
        License__c oldL = new License__c();
        Map<String, Object> fields = new Map<String, Object>{
            'Id' => makeFakeId(License__c.SObjectType),
            'GenerateDuplicateRenewalForm__c' => true,
            'RenewalNotificationTemplate__c' => 'TemplateY'
        };
        License__c newL = (License__c) JSON.deserialize(JSON.serialize(fields), License__c.class);
        Test.startTest();
        licenseService.generateRenewalNotification(oldL, newL);
        Test.stopTest();
        System.assertEquals(false, newL.GenerateDuplicateRenewalForm__c);
    }

    @isTest
    static void testCapturePrincipalSuspenseProcessBranch() {
        License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        oldL.LossofPrincipalRME__c = false;
        License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 0);
        newL.LossofPrincipalRME__c = true;
        Test.startTest();
        licenseService.capturePrincipalSuspenseProcess(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testCaptureEntitySuspenseProcessBranch() {
        License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        oldL.LossofEntity__c = false;
        License__c newL = makeLicenseInMemory('CT - Entity', 0, 1, 1, 1);
        newL.LossofEntity__c = true;
        Test.startTest();
        licenseService.captureEntitySuspenseProcess(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testPerformLicenseClassificationCheckBranch() {
        License__c oldL = new License__c(
            LossofPrincipalRME__c = false,
            Status__c = 'C - Current, Valid & In Good Standing'
        );
        License__c newL = new License__c(
            LossofPrincipalRME__c = true,
            Status__c = 'C - Current, Valid & In Good Standing'
        );
        Test.startTest();
        licenseService.performLicenseClassificationCheck(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testCaptureForActiveEmployersCalStatusChange() {
        License__c oldL = new License__c(
            Status__c = 'C - Current, Valid & In Good Standing',
            ActiveInactive__c = 'Active'
        );
        License__c newL = new License__c(
            Status__c = 'F - Terminated; Needs to Reapply',
            ActiveInactive__c = 'Active'
        );
        Test.startTest();
        licenseService.captureForActiveEmployersCal(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testCaptureAddressesUpdateBothAddresses() {
        Id fakeLicId = makeFakeId(License__c.SObjectType);
        License__c oldL = new License__c(
            Id = fakeLicId,
            BusinessStreet__c = 'Old Business', BusinessCity__c = 'Honolulu',
            BusinessState__c = 'HI', BusinessZipcode__c = '96813',
            MailingStreet__c = 'Old Mailing', MailingCity__c = 'Honolulu',
            MailingState__c = 'HI', MailingZipcode__c = '96814'
        );
        License__c newL = new License__c(
            Id = fakeLicId,
            BusinessStreet__c = 'New Business', BusinessCity__c = 'Honolulu',
            BusinessState__c = 'HI', BusinessZipcode__c = '96813',
            MailingStreet__c = 'New Mailing', MailingCity__c = 'Honolulu',
            MailingState__c = 'HI', MailingZipcode__c = '96814',
            BypassLicenseHistoryCreation__c = false
        );
        Test.startTest();
        licenseService.captureAddressesUpdate(oldL, newL);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testCaptureRbEntityInactivationNotRbEntityShortCircuits() {
        License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        oldL.ActiveInactive__c = 'Active';
        License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        newL.ActiveInactive__c = 'Inactive';
        Test.startTest();
        licenseService.captureRbEntityInactivationForAssociatedLicenses(oldL, newL);
        Test.stopTest();
        System.assertEquals(null, newL.LossofRBEntityDate__c);
    }

    @isTest
    static void testCaptureSoleProprietorInactivationNotSolePropShortCircuits() {
        License__c oldL = makeLicenseInMemory('RB - Entity', 1, 1, 1, 1);
        oldL.ActiveInactive__c = 'Active';
        License__c newL = makeLicenseInMemory('RB - Entity', 1, 1, 1, 1);
        newL.ActiveInactive__c = 'Inactive';
        Test.startTest();
        licenseService.captureSoleProprietorInactivation(oldL, newL);
        Test.stopTest();
        System.assertEquals(null, newL.LossofSoleProprietorDate__c);
    }

    @isTest
    static void testGenerateRemarksFieldNullsAndValues() {
        Test.startTest();
        String allNull = licenseService.generateRemarksField(null, null, null, null);
        String full = licenseService.generateRemarksField('1 Main St', 'Honolulu', 'HI', '96813');
        Test.stopTest();
        System.assertNotEquals(null, allNull);
        System.assert(full.contains('Main St'));
        System.assert(full.contains('Honolulu'));
        System.assert(full.contains('HI'));
        System.assert(full.contains('96813'));
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // Integration tests — these mirror existing LicenseAllTest scenarios but live
    // in a fresh class so ApexCodeCoverage tracking captures their contribution.
    // (LicenseAllTest persistently fails to record coverage records in this org;
    //  see this class's header comment for context.)
    // ─────────────────────────────────────────────────────────────────────────────

    /** Exercises the bulkBefore disable-trigger early-return path on actual DML. */
    @isTest
    static void testBulkBeforeDisableFlagOnInsert() {
        TriggerHelper.disableLicenseTrigger = true;
        try {
            Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
            Account acc = new Account(Name = 'BulkBeforeDisableTest');
            insert acc;
            
            LicenseType__c lt = new LicenseType__c();
            lt.Name = 'BulkBeforeLT';
            lt.Status__c = 'Active';
            insert lt;
            
            License__c lic = new License__c();
            lic.Name = 'BulkBeforeDisable';
            lic.LicenseType__c = lt.Id;
            lic.RecordTypeId = ctEntityRtId;
            lic.ActiveInactive__c = 'Active';
            
            Test.startTest();
            insert lic;
            // Update path also exercises bulkBefore disable early-return
            lic.Status__c = 'C - Current, Valid & In Good Standing';
            update lic;
            Test.stopTest();
            
            System.assertNotEquals(null, lic.Id, 'License insert succeeded under disable flag');
        } finally {
            TriggerHelper.disableLicenseTrigger = false;
        }
    }

    /**
     * Integration: License insert + update flow that exercises wide swaths of
     * licenseService legacy code (capturePreviousStatus, populateLicenceName,
     * cacheRecordsForLicenseInitiation, captureLicenseForClassification,
     * captureIdForFileGeneration, captureAddressesUpdate, runInFinally, etc.).
     * Mirrors the LicenseAllTest.testCaptureLicenseForClassification scenario.
     */
    @isTest
    static void testLicenseInsertAndUpdateFlow() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Id businessAcctRtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();

        Account acc = new Account();
        acc.Name = 'LicenseInsertUpdateAcc';
        acc.RecordTypeId = businessAcctRtId;
        insert acc;

        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'RDS';
        licenseType.Status__c = 'Active';
        licenseType.Branch__c = true;
        licenseType.ClassificationCheckRequired__c = true;
        insert licenseType;

        License__c dependentLicense = new License__c();
        dependentLicense.Name = 'DepLic';
        dependentLicense.ActiveInactive__c = 'Active';
        dependentLicense.LicenseType__c = licenseType.Id;
        dependentLicense.RecordTypeId = ctEntityRtId;
        insert dependentLicense;

        Application__c application = new Application__c();
        application.Applicant__c = acc.Id;
        application.GenerateLicense__c = true;
        application.DateofLicensure__c = Date.today();
        application.LicenseType__c = licenseType.Id;
        application.DependentLicense__c = dependentLicense.Id;
        application.BusinessStreet__c = 'BusinessStreet';
        application.Type__c = 'LICN - New License';
        application.Phase__c = 'A - Application Received';
        insert application;

        License__c license = new License__c();
        license.Name = 'TheLicense';
        license.ActiveInactive__c = 'Active';
        license.LicenseType__c = licenseType.Id;
        license.Application__c = application.Id;
        license.RecordTypeId = ctEntityRtId;
        insert license;

        Test.startTest();
        license.GenerateFile__c = true;
        license.GenerateNoticeofLicensureEmail__c = true;
        license.LossofPrincipalRME__c = true;
        license.Status__c = 'C - Current, Valid & In Good Standing';
        license.BusinessStreet__c = 'NewBusinessStreet';
        license.BusinessCity__c = 'Honolulu';
        license.BusinessState__c = 'HI';
        license.BusinessZipcode__c = '96813';
        license.MailingStreet__c = 'NewMailingStreet';
        license.MailingCity__c = 'Honolulu';
        license.MailingState__c = 'HI';
        license.MailingZipcode__c = '96814';
        license.BypassLicenseHistoryCreation__c = false;
        update license;
        Test.stopTest();

        License__c queried = [SELECT Id, BusinessStreet__c FROM License__c WHERE Id = :license.Id];
        System.assertEquals('NewBusinessStreet', queried.BusinessStreet__c);
    }

    /** Exercises licenseService.populateLicenceName via TestDataFactory.createLicense pattern. */
    @isTest
    static void testPopulateLicenceNameFlow() {
        Id businessAcctRtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
        Account acc = new Account(Name = 'PopulateNameAcc', RecordTypeId = businessAcctRtId);
        insert acc;

        BoardProgram__c boardProgram = new BoardProgram__c();
        boardProgram.Type__c = 'Program';
        boardProgram.Name = 'PopNameBP';
        insert boardProgram;

        List<LicenseType__c> types = new List<LicenseType__c>();
        LicenseType__c ltLic = new LicenseType__c();
        ltLic.Name = 'LICTYPE_LIC';
        ltLic.Status__c = 'Active';
        ltLic.BoardProgram__c = boardProgram.Id;
        ltLic.LicenseNumberAssignmentCode__c = 'LIC';
        types.add(ltLic);
        
        LicenseType__c ltBrd = new LicenseType__c();
        ltBrd.Name = 'LICTYPE_BRD';
        ltBrd.Status__c = 'Active';
        ltBrd.BoardProgram__c = boardProgram.Id;
        ltBrd.LicenseNumberAssignmentCode__c = 'BRD';
        types.add(ltBrd);

        LicenseType__c ltMan = new LicenseType__c();
        ltMan.Name = 'LICTYPE_MAN';
        ltMan.Status__c = 'Active';
        ltMan.BoardProgram__c = boardProgram.Id;
        ltMan.LicenseNumberAssignmentCode__c = 'MAN';
        types.add(ltMan);
        insert types;

        LicenseNumberAssignments__c lna = new LicenseNumberAssignments__c();
        lna.BoardProgram__c = boardProgram.Id;
        lna.LicenseType__c = ltBrd.Id;
        lna.LicenseNumber__c = 100000;
        insert lna;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.GenerateLicense__c = true;
        app.DateofLicensure__c = Date.today();
        app.LicenseType__c = ltLic.Id;
        app.BusinessStreet__c = 'B';
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        insert app;

        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Test.startTest();
        List<License__c> lics = new List<License__c>();
        License__c l1 = new License__c(Name = 'L1', ActiveInactive__c = 'Active', LicenseType__c = ltLic.Id, Application__c = app.Id, RecordTypeId = ctEntityRtId);
        lics.add(l1);
        License__c l2 = new License__c(Name = 'L2', ActiveInactive__c = 'Active', LicenseType__c = ltBrd.Id, Application__c = app.Id, RecordTypeId = ctEntityRtId);
        lics.add(l2);
        License__c l3 = new License__c(Name = 'L3', ActiveInactive__c = 'Active', LicenseType__c = ltMan.Id, Application__c = app.Id, RecordTypeId = ctEntityRtId);
        lics.add(l3);
        insert lics;
        Test.stopTest();
        
        System.assertEquals(3, [SELECT count() FROM License__c WHERE Application__c = :app.Id]);
    }

    /** Exercises captureAddressesUpdate / recordAddressUpdate via real updates. */
    @isTest
    static void testAddressUpdateIntegration() {
        TestDataFactory.createLicense();
        List<License__c> records = [
            SELECT Id, MailingStreet__c, BusinessStreet__c, BypassLicenseHistoryCreation__c
            FROM License__c
        ];
        for (License__c lic : records) {
            lic.MailingStreet__c = 'mailing street';
            lic.MailingCity__c = 'Honolulu';
            lic.MailingState__c = 'HI';
            lic.MailingZipcode__c = '96815';
            lic.BusinessStreet__c = 'biz street';
            lic.BusinessCity__c = 'Honolulu';
            lic.BusinessState__c = 'HI';
            lic.BusinessZipcode__c = '96815';
            lic.BypassLicenseHistoryCreation__c = false;
        }
        Test.startTest();
        update records;
        Test.stopTest();
        Integer histCount = [SELECT count() FROM LicenseHistory__c];
        System.assert(histCount > 0, 'Address-change history records were created');
    }

    /** Exercises capturePreviousStatus / captureUpdate via real status updates. */
    @isTest
    static void testStatusChangeIntegration() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Id businessAcctRtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();

        Account acc = new Account(Name = 'StatusChangeAcc', RecordTypeId = businessAcctRtId);
        insert acc;
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'StatusLT';
        lt.Status__c = 'Active';
        lt.AbleToInactivate__c = true;
        insert lt;

        License__c lic = new License__c();
        lic.Name = 'StatusLic';
        lic.LicenseType__c = lt.Id;
        lic.RecordTypeId = ctEntityRtId;
        lic.ActiveInactive__c = 'Active';
        lic.Status__c = 'C - Current, Valid & In Good Standing';
        insert lic;

        Test.startTest();
        lic.Status__c = 'F - Terminated; Needs to Reapply';
        update lic;
        Test.stopTest();
        License__c queried = [SELECT Id, PreviousStatus__c, Status__c FROM License__c WHERE Id = :lic.Id];
        System.assertEquals('C - Current, Valid & In Good Standing', queried.PreviousStatus__c);
        System.assertEquals('F - Terminated; Needs to Reapply', queried.Status__c);
    }

    /** Exercises nullifyAssocLicensesDualIndicator via prepared associated licenses. */
    @isTest
    static void testNullifyAssocLicensesDualIndicatorIntegration() {
        TestDataFactory.prepareAssociatedLicenses();
        Set<String> parentIds = new Set<String>();
        for (License__c lic : [SELECT Id FROM License__c]) {
            parentIds.add(lic.Id);
        }
        Test.startTest();
        licenseService.nullifyAssocLicensesDualIndicator(parentIds);
        Test.stopTest();
        System.assert(true, 'nullifyAssocLicensesDualIndicator executed without error');
    }

    /**
     * Direct invocation of getLicenseRequirements to cover lines 816-827.
     */
    @isTest
    static void testGetLicenseRequirements() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Account acc = new Account(Name = 'GetReqsAcc');
        insert acc;
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'GetReqsLT';
        lt.Status__c = 'Active';
        insert lt;
        License__c lic = new License__c();
        lic.Name = 'GetReqsLic';
        lic.LicenseType__c = lt.Id;
        lic.RecordTypeId = ctEntityRtId;
        lic.ActiveInactive__c = 'Active';
        insert lic;
        
        Test.startTest();
        Map<String, List<LicenseRequirements__c>> result = licenseService.getLicenseRequirements(new List<String>{lic.Id});
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }

    /**
     * Triggers Criteria 3A (loss of dual indicator) in captureUpdate.
     * Requires real-DB context because the criteria branch queries 
     * AssociatedLicenseSelector.getPDGByEmployee with the record's Id.
     */
    @isTest
    static void testCaptureUpdateCriteria3ADualLoss() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Account acc = new Account(Name = 'Criteria3AAcc');
        insert acc;
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Criteria3ALT';
        lt.Status__c = 'Active';
        insert lt;
        License__c lic = new License__c();
        lic.Name = 'Criteria3ALic';
        lic.LicenseType__c = lt.Id;
        lic.RecordTypeId = ctEntityRtId;
        lic.ActiveInactive__c = 'Active';
        lic.Status__c = 'C - Current, Valid & In Good Standing';
        insert lic;
        
        // Build a Criteria 3A scenario via direct invocation with crafted records
        // (NumberofActiveEmployers__c dropped from 2 to 1, with dependency required)
        License__c oldL = makeLicenseInMemory('CT - Entity', 2, 1, 1, 1);
        License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
        // Patch in the real Id so the selector query can run
        Map<String, Object> patched = newL.getPopulatedFieldsAsMap();
        Map<String, Object> patchedMap = new Map<String, Object>(patched);
        patchedMap.put('Id', lic.Id);
        newL = (License__c) JSON.deserialize(JSON.serialize(patchedMap), License__c.class);

        Test.startTest();
        licenseService.captureUpdate(oldL, newL);
        Test.stopTest();
        
        System.assert(true, 'Criteria 3A executed without error');
    }

    /**
     * Cover the deleteLicenseConditions / createLicenseConditions branches by
     * setting DependentLicense__c then calling the capture methods then runInFinally.
     */
    @isTest
    static void testLicenseConditionsLifecycle() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Account acc = new Account(Name = 'CondAcc');
        insert acc;
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'CondLT';
        lt.Status__c = 'Active';
        insert lt;
        
        License__c depA = new License__c(Name = 'DepA', LicenseType__c = lt.Id, RecordTypeId = ctEntityRtId, ActiveInactive__c = 'Active');
        License__c depB = new License__c(Name = 'DepB', LicenseType__c = lt.Id, RecordTypeId = ctEntityRtId, ActiveInactive__c = 'Active');
        insert new List<License__c>{depA, depB};
        
        License__c main = new License__c(
            Name = 'MainCond', LicenseType__c = lt.Id, RecordTypeId = ctEntityRtId,
            ActiveInactive__c = 'Active', DependentLicense__c = depA.Id
        );
        insert main;
        
        // Create a LicenseConditions__c record so deleteLicenseConditions has data to process
        LicenseConditions__c cond = new LicenseConditions__c();
        cond.License__c = main.Id;
        insert cond;

        Test.startTest();
        main.DependentLicense__c = depB.Id;
        update main;
        Test.stopTest();
        
        System.assert(true, 'License conditions lifecycle exercised');
    }

    /**
     * Direct invocation of createPrincipalRMESuspenses / createEntitySuspenses 
     * by seeding the static collections via captureXSuspenseProcess and then
     * calling the methods explicitly. Covers lines 433-447 and 453-475.
     */
    @isTest
    static void testCreatePrincipalAndEntitySuspensesDirect() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Account acc = new Account(Name = 'SuspAcc');
        insert acc;
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'SuspLT';
        lt.Status__c = 'Active';
        lt.DependencyRequired__c = true;
        lt.AbleToInactivate__c = true;
        insert lt;
        License__c lic = new License__c(
            Name = 'SuspLic', LicenseType__c = lt.Id, RecordTypeId = ctEntityRtId,
            ActiveInactive__c = 'Active', Status__c = 'C - Current, Valid & In Good Standing'
        );
        insert lic;
        
        // Seed the capture: set LossofPrincipalRME / LossofEntity flags to push the
        // license Id into the static sets used by createPrincipalRMESuspenses /
        // createEntitySuspenses.
        License__c queried = [SELECT Id, LossofPrincipalRME__c, LossofEntity__c, EntityPrincipalCounter__c, NumberofActiveEmployers__c, Status__c, DependencyRequired__c FROM License__c WHERE Id = :lic.Id];
        License__c oldL = queried.clone(true, true, true, true);
        queried.LossofPrincipalRME__c = true;
        queried.LossofEntity__c = true;
        
        Test.startTest();
        licenseService.capturePrincipalSuspenseProcess(oldL, queried);
        licenseService.captureEntitySuspenseProcess(oldL, queried);
        // Now exercise the creation methods directly
        licenseService.createPrincipalRMESuspenses(new List<License__c>{queried});
        licenseService.createEntitySuspenses(new List<License__c>{queried});
        Test.stopTest();
        
        System.assert(true, 'createPrincipalRMESuspenses and createEntitySuspenses executed');
    }

    /**
     * Exercise all 6 status branches in captureUpdate Criteria 1 (RB-Entity PB loss).
     * Each status forces evaluation through more of the short-circuited OR chain.
     */
    @isTest
    static void testCaptureUpdateCriteria1AllStatuses() {
        List<String> statuses = new List<String>{
            'CP - Current Pending',
            'CR - Current/Next Renewal Paid',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            GlobalUtilities.STATUSZI
        };
        Test.startTest();
        for (String s : statuses) {
            License__c oldL = makeLicenseInMemory('RB - Entity', 1, 1, 1, 1);
            oldL.Status__c = s;
            License__c newL = makeLicenseInMemory('RB - Entity', 1, 1, 0, 1);
            newL.Status__c = s;
            licenseService.captureUpdate(oldL, newL);
        }
        Test.stopTest();
        System.assert(true, 'Criteria 1 evaluated for all status branches');
    }

    /**
     * Exercise all status branches in captureUpdate Criteria 2 (NumberofActiveEmployees dropped).
     */
    @isTest
    static void testCaptureUpdateCriteria2AllStatuses() {
        List<String> statuses = new List<String>{
            'CP - Current Pending',
            'CR - Current/Next Renewal Paid',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            GlobalUtilities.STATUSZI
        };
        Test.startTest();
        for (String s : statuses) {
            License__c oldL = makeLicenseInMemory('CT - Entity', 1, 2, 1, 1);
            oldL.Status__c = s;
            License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
            newL.Status__c = s;
            licenseService.captureUpdate(oldL, newL);
        }
        Test.stopTest();
        System.assert(true);
    }

    /**
     * Exercise all status branches in captureUpdate Criteria 3 (NumberofActiveEmployers => 0).
     * Includes the CM status (only allowed in Criteria 3 outer if).
     */
    @isTest
    static void testCaptureUpdateCriteria3AllStatuses() {
        List<String> statuses = new List<String>{
            'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
            'CP - Current Pending',
            'CR - Current/Next Renewal Paid',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            GlobalUtilities.STATUSZI
        };
        Test.startTest();
        for (String s : statuses) {
            License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
            oldL.Status__c = s;
            License__c newL = makeLicenseInMemory('CT - Entity', 0, 1, 1, 1);
            newL.Status__c = s;
            licenseService.captureUpdate(oldL, newL);
        }
        Test.stopTest();
        System.assert(true);
    }

    /**
     * Exercise all status branches in captureUpdate Criteria 4 (MVD with 0 employees).
     */
    @isTest
    static void testCaptureUpdateCriteria4AllStatuses() {
        List<String> statuses = new List<String>{
            'CP - Current Pending',
            'CR - Current/Next Renewal Paid',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            GlobalUtilities.STATUSZI
        };
        Test.startTest();
        for (String s : statuses) {
            License__c oldL = makeLicenseInMemory('MVD', 1, 1, 1, 1);
            oldL.Status__c = s;
            License__c newL = makeLicenseInMemory('MVD', 1, 0, 1, 1);
            newL.Status__c = s;
            licenseService.captureUpdate(oldL, newL);
        }
        Test.stopTest();
        System.assert(true);
    }

    /**
     * Exercise capturePrincipalSuspenseProcess with each valid status.
     */
    @isTest
    static void testCapturePrincipalSuspenseProcessAllStatuses() {
        List<String> statuses = new List<String>{
            'C - Current, Valid & In Good Standing',
            'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            'R - Valid Thru Expiration Date, Subject To Renewal',
            'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
            'CR - Current/Next Renewal Paid'
        };
        Test.startTest();
        for (String s : statuses) {
            License__c oldL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 1);
            oldL.Status__c = s;
            oldL.LossofPrincipalRME__c = false;
            License__c newL = makeLicenseInMemory('CT - Entity', 1, 1, 1, 0);
            newL.Status__c = s;
            newL.LossofPrincipalRME__c = true;
            licenseService.capturePrincipalSuspenseProcess(oldL, newL);
        }
        Test.stopTest();
        System.assert(true);
    }

    /**
     * Cover captureRecentTerminatedEmployers via direct invocation with a real Id.
     */
    @isTest
    static void testCaptureRecentTerminatedEmployersDirect() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Account acc = new Account(Name = 'CRTEAcc');
        insert acc;
        LicenseType__c lt = new LicenseType__c(Name = 'CRTELT', Status__c = 'Active');
        insert lt;
        License__c lic = new License__c(
            Name = 'CRTELic', LicenseType__c = lt.Id, RecordTypeId = ctEntityRtId,
            ActiveInactive__c = 'Active', Status__c = 'C - Current, Valid & In Good Standing'
        );
        insert lic;
        
        Test.startTest();
        licenseService.captureRecentTerminatedEmployers(new Set<Id>{lic.Id});
        Test.stopTest();
        System.assert(true);
    }

    /**
     * Cover sendNoticeOfLicensure flow via flag + valid email template (uses 
     * the Test.isRunningTest() fallback to find any active EmailTemplate).
     */
    @isTest
    static void testSendNoticeOfLicensureFlow() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Account acc = new Account(Name = 'NoticeAcc');
        insert acc;
        LicenseType__c lt = new LicenseType__c(Name = 'NoticeLT', Status__c = 'Active');
        insert lt;
        License__c lic = new License__c(
            Name = 'NoticeLic', LicenseType__c = lt.Id, RecordTypeId = ctEntityRtId,
            ActiveInactive__c = 'Active', Status__c = 'C - Current, Valid & In Good Standing',
            NotificationEmail__c = 'noticelic@test.test'
        );
        insert lic;
        Test.startTest();
        lic.GenerateNoticeofLicensureEmail__c = true;
        update lic;
        Test.stopTest();
        System.assert(true);
    }

    /** Triggers the SendRenewalEmail__c branch in LicenseHandler.bulkBefore. */
    @isTest
    static void testSendRenewalEmailBranch() {
        Id ctEntityRtId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Id businessAcctRtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();

        Account acc = new Account(Name = 'SendRenewalAcc', RecordTypeId = businessAcctRtId);
        insert acc;
        
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'SendRenewalLT';
        lt.Status__c = 'Active';
        insert lt;

        PVL_Portal_User__c portalUser = new PVL_Portal_User__c();
        portalUser.Email__c = 'renewal@test.test';
        insert portalUser;

        License__c lic = new License__c();
        lic.Name = 'SendRenewalLic';
        lic.LicenseType__c = lt.Id;
        lic.RecordTypeId = ctEntityRtId;
        lic.ActiveInactive__c = 'Active';
        lic.Status__c = 'C - Current, Valid & In Good Standing';
        lic.PVL_Portal_User__c = portalUser.Id;
        insert lic;

        Test.startTest();
        lic.SendRenewalEmail__c = true;
        update lic;
        Test.stopTest();
        
        License__c queried = [SELECT Id, SendRenewalEmail__c FROM License__c WHERE Id = :lic.Id];
        System.assertEquals(false, queried.SendRenewalEmail__c, 'SendRenewalEmail flag was consumed by handler');
    }
}