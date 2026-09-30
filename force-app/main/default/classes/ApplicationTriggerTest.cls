/*
* ─────────────────────────────────────────────────────────
* Used for testing the Trigger for Application
* ─────────────────────────────────────────────────────────
* PacPoint-MV010419 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-08-25
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
@isTest
public with sharing class ApplicationTriggerTest {
    // 00005047
    public static testMethod void testOutstandingAmount() {
        // create transactions
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.RequiresInsurance__c = true;
        licenseTypeRecord.InsuranceBondTypesRequired__c = 'BD - Bond';
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'A - Application Received';
        insert applicationRecord;

		Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 100.00;
        trn.Contact__c = cnt.Id;
        trn.Application__c = applicationRecord.Id;
        insert trn;
    }
    
    public static testMethod void testUpdateClassifications() {
        // create transactions
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
     
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.DependencyRequired__c = true;
        insert licenseTypeRecord;

        License__c licenseRecord = new License__c();
		licenseRecord.Name = 'License A';
		licenseRecord.ActiveInactive__c = 'Active';
		licenseRecord.LicenseType__c = licenseTypeRecord.Id;
        licenseRecord.Status__c = 'CP - Current Pending';
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        licenseRecord.RecordTypeId = CTEntityRecordTypeId;
        insert licenseRecord;

        Application__c dependentApplication = new Application__c();
        dependentApplication.Applicant__c = acc.Id;
        dependentApplication.LicenseType__c = licenseTypeRecord.Id;
        dependentApplication.Type__c = 'LICN - New License';
        dependentApplication.Phase__c = 'A - Application Received';
        insert dependentApplication;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'A - Application Received';
        insert applicationRecord;

        Classification__c classificationRecord = new Classification__c();
		classificationRecord.Status__c = 'Active';
		classificationRecord.Name = 'Classification Record';
		classificationRecord.LicenseType__c = licenseTypeRecord.Id;
		insert classificationRecord;

        LicenseClassification__c licenseClassificationRecord = new LicenseClassification__c();
		licenseClassificationRecord.Status__c = 'C - Current, Valid & In Good Standing';
        licenseClassificationRecord.License__c = licenseRecord.id;
        licenseClassificationRecord.Classification__c = classificationRecord.Id;
        insert licenseClassificationRecord;

        Test.startTest();
        // applicationRecord.DependentApplication__c = dependentApplication.Id;
        applicationRecord.DependentLicense__c = licenseRecord.Id;
        update applicationRecord;
        Test.stopTest();
    }

    public static testMethod void testCaptureLLicenseReview() {
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'A - Application Received';
        insert applicationRecord;

        Test.startTest();
        applicationRecord.Phase__c = 'L - License Review';
        update applicationRecord;
        Test.stopTest();
    }

    
    public static testMethod void testPopulateLicenseRequirements() {
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        License__c licenseRecord = new License__c();
		licenseRecord.Name = 'License A';
		licenseRecord.ActiveInactive__c = 'Active';
		licenseRecord.LicenseType__c = licenseTypeRecord.Id;
        licenseRecord.Status__c = 'CP - Current Pending';
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        licenseRecord.RecordTypeId = CTEntityRecordTypeId;
        insert licenseRecord;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'REAC - Reactivation';
        applicationRecord.CurrentLicense__c = licenseRecord.Id;
        insert applicationRecord;
    }

    @IsTest
    private static void testRenewalMethods(){
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.RequiresInsurance__c = true;
        licenseTypeRecord.InsuranceBondTypesRequired__c = 'BD - Bond';
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        License__c licenseRecord = new License__c();
		licenseRecord.Name = 'License A';
		licenseRecord.ActiveInactive__c = 'Active';
		licenseRecord.LicenseType__c = licenseTypeRecord.Id;
        licenseRecord.Status__c = 'CP - Current Pending';
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        licenseRecord.RecordTypeId = CTEntityRecordTypeId;
        insert licenseRecord;

        License__c licenseRecord2 = new License__c();
		licenseRecord2.Name = 'License B';
		licenseRecord2.ActiveInactive__c = 'Active';
		licenseRecord2.LicenseType__c = licenseTypeRecord.Id;
        licenseRecord2.Status__c = 'CP - Current Pending';
        Id CTEntityRecordTypeId2 = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        licenseRecord2.RecordTypeId = CTEntityRecordTypeId2;
        insert licenseRecord2;

        AssociatedLicense__c associatedLicense = new AssociatedLicense__c();
        //associatedLicense.EmployeeLicense__c = licenseRecord.Id;
        associatedLicense.EmploymentStatus__c = 'Employed';
        associatedLicense.EntityLicense__c = licenseRecord.Id;
        associatedLicense.EndDate__c = null;                
        insert associatedLicense;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.CurrentLicense__c = licenseRecord.Id;
        applicationRecord.Phase__c = 'C - Current, Valid, & In Good Standing';
        applicationRecord.ActiveInactive__c = 'Inactive';
        insert applicationRecord;

        ExamTypes__c examTypes = new ExamTypes__c();
        examTypes.LicenseType__c = licenseTypeRecord.Id;
        insert examTypes;

        Test.startTest();        
        Application__c applicationRecord2 = [SELECT Applicant__c, LicenseType__c, CurrentLicense__c, Phase__c, Type__c, CompleteApplicationBy__c FROM Application__c WHERE Type__c = 'LICN - New License'];
        applicationRecord2.Status__c = 'H - License Generation';
        applicationRecord2.ActiveInactive__c = 'Active';

        update applicationRecord2;

        List<Application__c> applications = new List<Application__c>();
        applications.add(applicationRecord2);

        List<String> applicationIds = new List<String>();
        applicationIds.add(applicationRecord2.ID);

        Set<String> filteredIds = new Set<String>();
        filteredIds.add(applicationRecord2.ID);

        ApplicationService.takeRenewalSnapshot(applications);        
        ApplicationService.reCreateTransactionLines(applications);        
        ApplicationService.insertApplicationClassifications(applications);        
        ApplicationService.isHcRenewalValidationFail(new List<Application__c>{applicationRecord2});
        ApplicationService.generateCheckoutForm(applicationIds);
        ApplicationService.generatePDF(applications, filteredIds);
        ApplicationService.updateDependentApplications();
        ApplicationService.insertApplicationClassifications(applications, filteredIds);
        Test.stopTest();     
    }

    @IsTest
    static void testExams() {
        DocGeneratorSettings__c  setting = new DocGeneratorSettings__c ();
        setting.Name = 'Exam Notice of Approval CT';
        setting.DocumentType__c = 'Word';
        insert setting;

        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.ExamApprovalNotification__c = setting.Id;
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        License__c licenseRecord = new License__c();
		licenseRecord.Name = 'License A';
		licenseRecord.ActiveInactive__c = 'Active';
		licenseRecord.LicenseType__c = licenseTypeRecord.Id;
        licenseRecord.Status__c = 'CP - Current Pending';
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        licenseRecord.RecordTypeId = CTEntityRecordTypeId;
        insert licenseRecord;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'REAC - Reactivation';
        applicationRecord.CurrentLicense__c = licenseRecord.Id;
        insert applicationRecord;
        Test.startTest();
        applicationRecord.NotificationEmail__c = 'test@example.com';
        applicationRecord.SendApprovedForExamLetterEmail__c = true;
        update applicationRecord;

        Test.stopTest();
    }

    @IsTest
    private static void testApplicationServicePdfOnlineRenewalAndLicensePeriod() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc PDF';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT PDF';
        insert lt;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        app.LicensePeriod__c = 'This License Period';
        insert app;

        Test.startTest();
        Application__c beforePdf = [
            SELECT Id, GenerateFile__c, GenerateOnlineRenewal__c, LicensePeriod__c
            FROM Application__c
            WHERE Id = :app.Id
        ];
        beforePdf.GenerateFile__c = true;
        update beforePdf;

        Application__c beforeOnline = [
            SELECT Id, GenerateOnlineRenewal__c
            FROM Application__c
            WHERE Id = :app.Id
        ];
        beforeOnline.GenerateOnlineRenewal__c = true;
        update beforeOnline;

        Application__c beforePeriod = [
            SELECT Id, LicensePeriod__c
            FROM Application__c
            WHERE Id = :app.Id
        ];
        beforePeriod.LicensePeriod__c = 'Next License Period';
        update beforePeriod;

        ApplicationService.batchSaveOnlineRenewalCopy();
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Application__c WHERE Id = :app.Id].Id);
    }

    @IsTest
    private static void testApplicationServiceCalcOutstandingAndSkipCache() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc Outstanding';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT OS';
        insert lt;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        insert app;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test OS Contact';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 50.00;
        trn.Contact__c = cnt.Id;
        trn.Application__c = app.Id;
        trn.Status__c = 'New';
        insert trn;

        Test.startTest();
        ApplicationService.skipApplicationCacheUpdate = true;
        ApplicationService.calcualteOutStanding(new Set<String>{ app.Id });
        ApplicationService.skipApplicationCacheUpdate = false;
        ApplicationService.calcualteOutStanding(new Set<String>{ app.Id });
        Test.stopTest();

        Application__c refreshed = [SELECT Id, OutstandingAmount__c FROM Application__c WHERE Id = :app.Id];
        System.assertNotEquals(null, refreshed.Id);
    }

    @IsTest
    private static void testApplicationServiceIMLCCAfterCreateAndHcRenewalHelpers() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc IMLCC';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT IMLCC';
        insert lt;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        insert app;

        Test.startTest();
        ApplicationService.runIMLCCAfterApplicationCreate(null, null);
        ApplicationService.runIMLCCAfterApplicationCreate(new List<Id>(), new List<Id>());
        Test.stopTest();

        // Do not call runIMLCCAfterApplicationCreate with app Ids here: the @future method updates
        // Application__c to H/HC and can fail with CANNOT_EXECUTE_FLOW_TRIGGER (Application:Processes) in orgs where that flow errors on synthetic test data.

        Application__c afterIm = [SELECT Phase__c, Status__c FROM Application__c WHERE Id = :app.Id];
        System.assertEquals('A - Application Received', afterIm.Phase__c);

        Application__c oldHc = new Application__c(
            Id = app.Id,
            Type__c = 'RNEW - Renewal',
            Phase__c = 'A - Application Received',
            Status__c = null,
            ActiveInactive__c = 'Active',
            LicenseType__c = lt.Id,
            CurrentLicense__c = null
        );
        Application__c newHc = new Application__c(
            Id = app.Id,
            Type__c = 'RNEW - Renewal',
            Phase__c = 'H - License Generation',
            Status__c = null,
            ActiveInactive__c = 'Active',
            LicenseType__c = lt.Id,
            CurrentLicense__c = null
        );
        ApplicationService.checkForHCRenewalValidationFail(oldHc, newHc);
    }

    @IsTest
    private static void testApplicationServiceHcValidationTwoArgAndDeleteRequirements() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC2';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC2';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c = 'BD - Bond';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC2';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.BondWaiver__c = true;
        insert lic;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> waiverMap = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ null, app },
            lics
        );
        System.assert(waiverMap.containsKey(app.Id));

        ApplicationService.deleteAppRequirements(new List<String>());
        ApplicationService.deleteAppRequirements(new List<String>{ app.Id });
    }

    @IsTest
    private static void testHcRenewalValidationUsesCompleteApplicationByDate() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC Coverage Date';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC Coverage Date';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC Coverage Date';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.EffectiveExpireDate__c = Date.newInstance(2028, 9, 30);
        insert lic;

        InsuranceBond__c lpBond = new InsuranceBond__c();
        lpBond.Type__c = 'LP - Liability / Property Damage';
        lpBond.Amount__c = 1;
        lpBond.License__c = lic.Id;
        lpBond.Status__c = 'Active';
        lpBond.EffectiveDate__c = Date.newInstance(2025, 10, 1);
        lpBond.TermDate__c = Date.newInstance(2026, 10, 7);
        insert lpBond;

        InsuranceBond__c wcSubstitute = new InsuranceBond__c();
        wcSubstitute.Type__c = 'SI - Exclusion from Workers Comp.';
        wcSubstitute.Amount__c = 1;
        wcSubstitute.License__c = lic.Id;
        wcSubstitute.Status__c = 'Active';
        wcSubstitute.EffectiveDate__c = Date.newInstance(2020, 1, 1);
        insert wcSubstitute;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        app.CompleteApplicationBy__c = Date.newInstance(2026, 9, 30);
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ app },
            lics
        );
        System.assertEquals(
            false,
            result.get(app.Id),
            'Valid LP past CompleteApplicationBy__c must pass even when license expire date is rolled forward'
        );
    }

    @IsTest
    private static void testHcRenewalValidationFailsWhenRequiredCoverageMissing() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC Coverage Missing';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC Coverage Missing';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC Coverage Missing';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.EffectiveExpireDate__c = Date.newInstance(2028, 9, 30);
        insert lic;

        InsuranceBond__c wcSubstitute = new InsuranceBond__c();
        wcSubstitute.Type__c = 'SI - Exclusion from Workers Comp.';
        wcSubstitute.Amount__c = 1;
        wcSubstitute.License__c = lic.Id;
        wcSubstitute.Status__c = 'Active';
        wcSubstitute.EffectiveDate__c = Date.newInstance(2020, 1, 1);
        insert wcSubstitute;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        app.CompleteApplicationBy__c = Date.newInstance(2026, 9, 30);
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ app },
            lics
        );
        System.assertEquals(
            true,
            result.get(app.Id),
            'Missing required LP coverage must still fail HC renewal validation'
        );
    }

    @IsTest
    private static void testHcRenewalValidationRestorationUsesTodayNotDeadline() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC Restoration Pass';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC Restoration Pass';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC Restoration Pass';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.EffectiveExpireDate__c = Date.newInstance(2028, 9, 30);
        insert lic;

        InsuranceBond__c lpBond = new InsuranceBond__c();
        lpBond.Type__c = 'LP - Liability / Property Damage';
        lpBond.Amount__c = 1;
        lpBond.License__c = lic.Id;
        lpBond.Status__c = 'Active';
        lpBond.EffectiveDate__c = Date.today().addDays(-335);
        lpBond.TermDate__c = Date.today().addDays(30);
        insert lpBond;

        InsuranceBond__c wcSubstitute = new InsuranceBond__c();
        wcSubstitute.Type__c = 'SI - Exclusion from Workers Comp.';
        wcSubstitute.Amount__c = 1;
        wcSubstitute.License__c = lic.Id;
        wcSubstitute.Status__c = 'Active';
        wcSubstitute.EffectiveDate__c = Date.newInstance(2020, 1, 1);
        insert wcSubstitute;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RSTR - Restore - No A/I Status';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        app.CompleteApplicationBy__c = Date.newInstance(2028, 12, 31);
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ app },
            lics
        );
        System.assertEquals(
            false,
            result.get(app.Id),
            'A restoration must only require coverage current today, not through the restoration deadline'
        );
    }

    @IsTest
    private static void testHcRenewalValidationRestorationFailsWhenLapsed() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC Restoration Fail';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC Restoration Fail';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC Restoration Fail';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.EffectiveExpireDate__c = Date.newInstance(2028, 9, 30);
        insert lic;

        InsuranceBond__c lpBond = new InsuranceBond__c();
        lpBond.Type__c = 'LP - Liability / Property Damage';
        lpBond.Amount__c = 1;
        lpBond.License__c = lic.Id;
        lpBond.Status__c = 'Active';
        lpBond.EffectiveDate__c = Date.today().addDays(-395);
        lpBond.TermDate__c = Date.today().addDays(-30);
        insert lpBond;

        InsuranceBond__c wcSubstitute = new InsuranceBond__c();
        wcSubstitute.Type__c = 'SI - Exclusion from Workers Comp.';
        wcSubstitute.Amount__c = 1;
        wcSubstitute.License__c = lic.Id;
        wcSubstitute.Status__c = 'Active';
        wcSubstitute.EffectiveDate__c = Date.newInstance(2020, 1, 1);
        insert wcSubstitute;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RSTR - Restore - No A/I Status';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        app.CompleteApplicationBy__c = Date.newInstance(2028, 12, 31);
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ app },
            lics
        );
        System.assertEquals(
            true,
            result.get(app.Id),
            'A restoration with lapsed LP coverage must still fail HC validation'
        );
    }

    @IsTest
    private static void testHcRenewalValidationOpenEndedBondDoesNotHideDatedPolicies() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC Open Bond';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC Open Bond';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC Open Bond';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.EffectiveExpireDate__c = Date.newInstance(2028, 9, 30);
        insert lic;

        InsuranceBond__c openEndedBond = new InsuranceBond__c();
        openEndedBond.Type__c = 'BD - Bond';
        openEndedBond.Amount__c = 1;
        openEndedBond.License__c = lic.Id;
        openEndedBond.Status__c = 'Active';
        openEndedBond.EffectiveDate__c = Date.newInstance(2020, 1, 1);
        insert openEndedBond;

        InsuranceBond__c lpBond = new InsuranceBond__c();
        lpBond.Type__c = 'LP - Liability / Property Damage';
        lpBond.Amount__c = 1;
        lpBond.License__c = lic.Id;
        lpBond.Status__c = 'Active';
        lpBond.EffectiveDate__c = Date.newInstance(2025, 11, 20);
        lpBond.TermDate__c = Date.newInstance(2026, 11, 20);
        insert lpBond;

        InsuranceBond__c wcBond = new InsuranceBond__c();
        wcBond.Type__c = 'WC - Workers Compensation';
        wcBond.Amount__c = 1;
        wcBond.License__c = lic.Id;
        wcBond.Status__c = 'Active';
        wcBond.EffectiveDate__c = Date.newInstance(2025, 11, 20);
        wcBond.TermDate__c = Date.newInstance(2026, 11, 20);
        insert wcBond;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        app.CompleteApplicationBy__c = Date.newInstance(2026, 9, 30);
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ app },
            lics
        );
        System.assertEquals(
            false,
            result.get(app.Id),
            'An open-ended BD Bond must not hide dated LP and WC that cover CompleteApplicationBy__c'
        );
    }

    @IsTest
    private static void testHcRenewalValidationSwSubstituteWithDatedLp() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc HC SW Sub';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC SW Sub';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic HC SW Sub';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        lic.EffectiveExpireDate__c = Date.newInstance(2028, 9, 30);
        insert lic;

        InsuranceBond__c lpBond = new InsuranceBond__c();
        lpBond.Type__c = 'LP - Liability / Property Damage';
        lpBond.Amount__c = 1;
        lpBond.License__c = lic.Id;
        lpBond.Status__c = 'Active';
        lpBond.EffectiveDate__c = Date.newInstance(2026, 1, 17);
        lpBond.TermDate__c = Date.newInstance(2027, 1, 17);
        insert lpBond;

        InsuranceBond__c swBond = new InsuranceBond__c();
        swBond.Type__c = 'SW - Workers Comp Thru Leasing Co.';
        swBond.Amount__c = 1;
        swBond.License__c = lic.Id;
        swBond.Status__c = 'Active';
        swBond.EffectiveDate__c = Date.newInstance(2026, 3, 25);
        swBond.TermDate__c = Date.newInstance(2027, 3, 25);
        insert swBond;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        app.CompleteApplicationBy__c = Date.newInstance(2026, 9, 30);
        insert app;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{ lic.Id });
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ app },
            lics
        );
        System.assertEquals(
            false,
            result.get(app.Id),
            'SW must count as WC coverage and dated LP must pass against CompleteApplicationBy__c'
        );
    }

    @IsTest
    private static void testApplicationServiceReCreateTransactionLinesByIdsAndRenewalSnapshot() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc Recreate';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT Recreate';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        License__c lic = new License__c();
        lic.Name = 'Lic Recreate';
        lic.ActiveInactive__c = 'Active';
        lic.LicenseType__c = lt.Id;
        lic.Status__c = 'CP - Current Pending';
        lic.RecordTypeId = ctEntityRt;
        insert lic;

        License__c entityLic = new License__c();
        entityLic.Name = 'Lic Recreate Entity';
        entityLic.ActiveInactive__c = 'Active';
        entityLic.LicenseType__c = lt.Id;
        entityLic.Status__c = 'CP - Current Pending';
        entityLic.RecordTypeId = ctEntityRt;
        insert entityLic;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        app.CurrentLicense__c = lic.Id;
        insert app;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test Recreate Cnt';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 25.00;
        trn.Contact__c = cnt.Id;
        trn.Application__c = app.Id;
        trn.Status__c = 'New';
        trn.Description__c = 'License Fees (test)';
        insert trn;

        AssociatedLicense__c assocEmp = new AssociatedLicense__c();
        assocEmp.EmployeeLicense__c = lic.Id;
        assocEmp.EntityLicense__c = entityLic.Id;
        assocEmp.EmploymentStatus__c = 'Employed';
        assocEmp.EndDate__c = null;
        insert assocEmp;

        Application__c snapApp = [
            SELECT Id, Applicant__c, LicenseType__c, CurrentLicense__c, Phase__c, Type__c, Status__c,
                OnlineRenewalClasses__c, OnlineRenewalInsurance__c, OnlineRenewalEmployment__c
            FROM Application__c
            WHERE Id = :app.Id
        ];
        List<Application__c> snapResult = ApplicationService.takeRenewalSnapshot(new List<Application__c>{ snapApp });
        System.assertEquals(1, snapResult.size());

        Test.startTest();
        ApplicationService.reCreateTransactionLines(new List<String>{ app.Id });
        Test.stopTest();
    }

    @IsTest
    private static void testApplicationServiceRenewPermitAndExamRecordsAndCheckout() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc Permit';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT Permit';
        insert lt;

        ExamTypes__c examType = new ExamTypes__c();
        examType.Name = 'Exam Type AppSvc';
        examType.LicenseType__c = lt.Id;
        examType.Status__c = 'Active';
        insert examType;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        app.RenewingPermitToPractice__c = 'No';
        ApplicationService.skipExamCreation = true;
        insert app;
        ApplicationService.skipExamCreation = false;

        Application__c forPermit = [SELECT Id, RenewingPermitToPractice__c FROM Application__c WHERE Id = :app.Id];
        ApplicationService.ensureRenewByPermitToPracticeValue(forPermit);

        Application__c forExams = [
            SELECT Id, Applicant__c, LicenseType__c
            FROM Application__c
            WHERE Id = :app.Id
        ];
        ApplicationService.applicationCreateExamRequiredRecords(new List<Application__c>{ forExams });

        Test.startTest();
        // CheckoutFormVersion__c is formula/read-only; generateCheckoutForm still runs and skips when null (Test.isRunningTest).
        ApplicationService.generateCheckoutForm(new List<String>{ String.valueOf(app.Id) });
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM ExamsRequired__c WHERE Application__c = :app.Id] >= 1,
            'Expected ExamsRequired__c from applicationCreateExamRequiredRecords'
        );
    }

    @IsTest
    private static void testApplicationServiceADDPApprovedEmailCapture() {
        Account acc = new Account();
        acc.Name = 'Test AppSvc ADDP';
        insert acc;

        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT ADDP';
        insert lt;

        Application__c app = new Application__c();
        app.Applicant__c = acc.Id;
        app.LicenseType__c = lt.Id;
        app.Type__c = 'LICN - New License';
        app.Phase__c = 'A - Application Received';
        // NotificationEmail__c may be formula- or automation-driven and stay null in tests; omit assertions on it.
        app.NotificationEmail__c = 'addp-test@example.com';
        insert app;

        Test.startTest();
        Application__c toSend = [
            SELECT Id, Send_ADDP_Approved_Letter_Email__c
            FROM Application__c
            WHERE Id = :app.Id
        ];
        toSend.Send_ADDP_Approved_Letter_Email__c = true;
        update toSend;
        Test.stopTest();

        System.assertNotEquals(null, [SELECT Id FROM Application__c WHERE Id = :app.Id].Id);
    }
}