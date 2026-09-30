/*
 * ─────────────────────────────────────────────────────────────
 * Test class for PVL_MassEmailController and PVL_MassEmailBatch.
 * ─────────────────────────────────────────────────────────────
 * VPVL-37 - Mass Email from License Type
 * ─────────────────────────────────────────────────────────────
 * @author  VPVL-37
 * @created 2026-02-06
 * ─────────────────────────────────────────────────────────────
 */
@IsTest
private class PVL_MassEmailTest {

    // ── Test data setup ─────────────────────────────────────

    @TestSetup
    static void setup() {
        // Business Account Counter setting (required by some triggers)
        BusinessAccountCounter__c counter = new BusinessAccountCounter__c();
        counter.ResetDate__c = Date.today();
        counter.Counter__c = 1;
        insert counter;

        // Board Program
        BoardProgram__c bp = new BoardProgram__c();
        bp.Type__c = 'Program';
        bp.Name = 'Test Board';
        insert bp;

        // License Type
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'TEST-ME';
        lt.RollingLicensePeriod__c = false;
        lt.LicenseTypeEffectiveDate__c = Date.today().addDays(1);
        lt.DurationofLicenseInMonths__c = 0;
        lt.DurationofRestorationInMonths__c = 0;
        lt.StatusDuetoNonRestore__c = 'F - Terminated; Needs to Reapply';
        lt.Status__c = 'Active';
        lt.AbleToInactivate__c = true;
        lt.BoardProgram__c = bp.Id;
        lt.GenerateLicenseStatus__c = 'D - Forfeited; Needs to Restore';
        lt.RenewalWindowInDays__c = 5;
        insert lt;

        // Account (Licensee / Applicant)
        Account acc = new Account();
        acc.Name = 'Mass Email Test Account';
        insert acc;

        // Portal User
        PVL_Portal_User__c portalUser = new PVL_Portal_User__c();
        portalUser.Email__c = 'massemailtest@example.com';
        insert portalUser;

        // Record Type
        Id licenseRtId = License__c.getSObjectType()
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PVLCTEntity')
            .getRecordTypeId();

        // Application
        Application__c app = new Application__c();
        app.Name = 'mass-email-app';
        app.LicenseType__c = lt.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Status__c = 'D1 - Awaiting Dependency Review';
        app.PVLPortalUser__c = portalUser.Id;
        insert app;

        // License
        License__c lic = new License__c();
        lic.Name = 'mass-email-lic';
        lic.Application__c = app.Id;
        lic.LicenseType__c = lt.Id;
        lic.Licensee__c = acc.Id;
        lic.RecordTypeId = licenseRtId;
        lic.ActiveInactive__c = 'Active';
        lic.Status__c = 'C - Current, Valid & In Good Standing';
        lic.PVL_Portal_User__c = portalUser.Id;
        insert lic;
    }

    // ── Controller tests ────────────────────────────────────

    @IsTest
    static void testRunMassEmail_Licenses_FreeText() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];

        Test.startTest();
        String result = PVL_MassEmailController.runMassEmail(
            lt.Id,
            'Licenses',
            'FreeText',
            null,                      // no template
            'Test Subject',
            'Hello {!Name}, your license {!LicenseNumber} is being updated.',
            new List<String>{ 'C - Current, Valid & In Good Standing' },
            new List<String>(),
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assert(result.contains('queued'), 'Expected success message');
        // Verify Task was created on License
        List<Task> tasks = [
            SELECT Id, Subject, WhatId
            FROM Task
            WHERE Subject LIKE 'Mass Email:%'
        ];
        System.assert(tasks.size() > 0, 'Expected at least one Task created');
    }

    @IsTest
    static void testRunMassEmail_Applications_FreeText() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];

        Test.startTest();
        String result = PVL_MassEmailController.runMassEmail(
            lt.Id,
            'Applications',
            'FreeText',
            null,
            'App Subject',
            'Hello {!Name}, your application {!LicenseNumber} for {!LicenseType}.',
            new List<String>(),
            new List<String>(),
            new List<String>(),
            new List<String>()
        );
        Test.stopTest();

        System.assert(result.contains('queued'), 'Expected success message');
    }

    @IsTest
    static void testRunMassEmail_ValidationErrors() {
        // AuraHandledException.getMessage() returns "Script-thrown exception"
        // in Apex test context, so we only verify the exception is thrown.

        // Missing licenseTypeId
        Boolean threwMissing = false;
        try {
            PVL_MassEmailController.runMassEmail(
                null, 'Licenses', 'FreeText', null, 'Subj', 'Body',
                null, null, null, null
            );
        } catch (AuraHandledException e) {
            threwMissing = true;
        }
        System.assert(threwMissing, 'Expected AuraHandledException for missing licenseTypeId');

        // Invalid target
        Boolean threwTarget = false;
        try {
            PVL_MassEmailController.runMassEmail(
                'fakeId', 'InvalidTarget', 'FreeText', null, 'Subj', 'Body',
                null, null, null, null
            );
        } catch (AuraHandledException e) {
            threwTarget = true;
        }
        System.assert(threwTarget, 'Expected AuraHandledException for invalid target');

        // Template mode without templateId
        Boolean threwTemplate = false;
        try {
            PVL_MassEmailController.runMassEmail(
                'fakeId', 'Licenses', 'Template', null, null, null,
                null, null, null, null
            );
        } catch (AuraHandledException e) {
            threwTemplate = true;
        }
        System.assert(threwTemplate, 'Expected AuraHandledException for missing template');

        // FreeText mode without subject
        Boolean threwSubject = false;
        try {
            PVL_MassEmailController.runMassEmail(
                'fakeId', 'Licenses', 'FreeText', null, null, 'Body',
                null, null, null, null
            );
        } catch (AuraHandledException e) {
            threwSubject = true;
        }
        System.assert(threwSubject, 'Expected AuraHandledException for missing subject');
    }

    @IsTest
    static void testGetEmailTemplates() {
        List<PVL_MassEmailController.EmailTemplateWrapper> templates =
            PVL_MassEmailController.getEmailTemplates();
        System.assertNotEquals(null, templates, 'Templates list should not be null');
    }

    @IsTest
    static void testRunMassEmail_WithNullFilters() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];
        Test.startTest();
        String result = PVL_MassEmailController.runMassEmail(
            lt.Id, 'Licenses', 'FreeText', null, 'Subj', 'Body',
            null, null, null, null
        );
        Test.stopTest();
        System.assert(result.contains('queued'), 'Expected success when filters are null');
    }

    @IsTest
    static void testGetStatusPicklistValues_Licenses() {
        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getStatusPicklistValues('Licenses');
        System.assertNotEquals(null, options, 'Status options should not be null');
        System.assert(options.size() > 0, 'Expected at least one License status');
        System.assertNotEquals(null, options[0].label, 'Label should be set');
        System.assertNotEquals(null, options[0].value, 'Value should be set');
    }

    @IsTest
    static void testGetStatusPicklistValues_Applications() {
        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getStatusPicklistValues('Applications');
        System.assertNotEquals(null, options, 'Status options should not be null');
        System.assert(options.size() > 0, 'Expected at least one Application status');
    }

    @IsTest
    static void testGetMolPicklistValues_Licenses() {
        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getMolPicklistValues('Licenses');
        System.assertNotEquals(null, options, 'MOL options should not be null');
    }

    @IsTest
    static void testGetMolPicklistValues_Applications() {
        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getMolPicklistValues('Applications');
        System.assertNotEquals(null, options, 'MOL options should not be null');
    }

    @IsTest
    static void testGetPrivilegePicklistValues() {
        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getPrivilegePicklistValues();
        System.assertNotEquals(null, options, 'Privilege options should not be null');
    }

    @IsTest
    static void testGetClassificationValues_Empty() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];
        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getClassificationValues(lt.Id);
        System.assertNotEquals(null, options, 'Classification options should not be null');
        System.assertEquals(0, options.size(), 'No classifications in setup');
    }

    @IsTest
    static void testGetClassificationValues_WithData() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];
        Classification__c cls = new Classification__c();
        cls.Name = 'Test Classification';
        cls.LicenseType__c = lt.Id;
        cls.Status__c = 'Active';
        insert cls;

        List<PVL_MassEmailController.PicklistOption> options =
            PVL_MassEmailController.getClassificationValues(lt.Id);
        System.assertEquals(1, options.size(), 'Expected one classification');
        System.assertEquals('Test Classification', options[0].label, 'Label should match');
        System.assertEquals('Test Classification', options[0].value, 'Value should match');
    }

    // ── Batch tests ─────────────────────────────────────────

    @IsTest
    static void testBatch_Licenses_WithFilters() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];

        PVL_MassEmailBatch batch = new PVL_MassEmailBatch(
            lt.Id,
            'Licenses',
            'FreeText',
            null,
            'Filtered Subject',
            'Hello {!Name}',
            new List<String>{ 'C - Current, Valid & In Good Standing' },
            new List<String>(),
            new List<String>(),
            new List<String>()
        );

        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        // Verify at least one task was created
        List<Task> tasks = [
            SELECT Id, Subject FROM Task WHERE Subject LIKE 'Mass Email:%'
        ];
        System.assert(tasks.size() > 0, 'Expected task(s) from license batch');
    }

    @IsTest
    static void testBatch_Applications_NoFilters() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];

        PVL_MassEmailBatch batch = new PVL_MassEmailBatch(
            lt.Id,
            'Applications',
            'FreeText',
            null,
            'App Announcement',
            'Dear {!Name}, regarding {!LicenseType}.',
            new List<String>(),
            new List<String>(),
            new List<String>(),
            new List<String>()
        );

        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id, Subject FROM Task WHERE Subject LIKE 'Mass Email:%'
        ];
        System.assert(tasks.size() > 0, 'Expected task(s) from application batch');
    }

    @IsTest
    static void testBatch_Licenses_NoMatchingRecords() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c WHERE Name = 'TEST-ME' LIMIT 1];

        // Use a status that no license has
        PVL_MassEmailBatch batch = new PVL_MassEmailBatch(
            lt.Id,
            'Licenses',
            'FreeText',
            null,
            'No Match Subject',
            'No match body',
            new List<String>{ 'X - Nonexistent Status' },
            new List<String>(),
            new List<String>(),
            new List<String>()
        );

        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        // No tasks should be created
        List<Task> tasks = [
            SELECT Id FROM Task WHERE Subject LIKE 'Mass Email: No Match%'
        ];
        System.assertEquals(0, tasks.size(), 'No tasks expected for zero matching records');
    }
}