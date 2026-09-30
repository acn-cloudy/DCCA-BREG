@isTest
public with sharing class TestDataFactory {
    public static User createDummyUser() {
        String orgId = UserInfo.getOrganizationId();
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
        String uniqueName = orgId + dateString + randomInt;

        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User dummyUser = new User(
                Alias = 'standu',
                Email = uniqueName + '@test' + orgId + '.org',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                Division__c = 'BREG',
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueName + '@test' + orgId + '.org');
        insert dummyUser;
        return dummyUser;
    }

    public static void createSuspenses() {
        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.RequiresInsurance__c = TRUE;
        insert licenseTypeRecord;

        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'H - License Generation';
        applicationRecord.Status__c = 'H1 - Awaiting Licensing';
        applicationRecord.IsApplicationTerminated__c = false;
        insert applicationRecord;

        applicationRecord.CompleteApplicationBy__c = System.today() - 1;
        update applicationRecord;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.TotalAmount__c = 100.00;
        trn.Contact__c = cnt.Id;
        trn.Application__c = applicationRecord.Id;

        insert trn;

        Id licenseRtId = License__c.getSObjectType()
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PVLCTEntity')
                .getRecordTypeId();

        License__c license = new License__c();
        license.Name = 'acc';
        license.Application__c = applicationRecord.Id;
        license.Licensee__c = acc.Id;
        license.LicenseType__c = licenseTypeRecord.Id;
        license.ActiveInactive__c  = 'Active';
        license.Status__c = 'C - Current, Valid & In Good Standing';
        insert license;

        license.Status__c = 'CR - Current/Next Renewal Paid';
        update license;

        Suspense__c suspense = new Suspense__c();
        suspense.License__c = license.Id;
        suspense.InsuranceType__c = 'BD - Bond';
        suspense.SuspenseDueDate__c = System.today() + 10;
        insert suspense;

    }
    
    public static void createExams() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        System.runAs(createDummyUser()) {
            RecordTypeInfo filingBrokerDealerRti =
                Filing__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('BrokerDealer');
            Filing__c filing = new Filing__c();
            filing.Status__c = 'In Progress';
            filing.RecordTypeId = filingBrokerDealerRti.getRecordTypeId();
            filing.Account__c = acct.Id;
            insert filing;

            Exam__c exam = new Exam__c();
            exam.Account__c = acct.Id;
            exam.Name = 'dummyExam';
            exam.ExamStatus__c = 'Assigned for Examination';
            insert exam;
            
            RecordTypeInfo fdSeb = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfosByName().get('SEB');
            FileDetails__c fd = new FileDetails__c();
            fd.RecordTypeId = fdSeb.getRecordTypeId();
            fd.Exam__c = exam.Id;
            fd.Filing__c = filing.Id;
            fd.Category__c = 'SEB Clerical';
            fd.Type__c = 'Memorandum';
            insert fd;

            String docName = 'test.pdf';
            ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.VersionData = Blob.valueOf('Test Data');
            cv.Title = docName;
            cv.PathOnClient = '/'+docName;
            
            insert cv;
            
            // First get the content document Id from ContentVersion
            Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;

            //Create ContentDocumentLink
            ContentDocumentLink cDe = new ContentDocumentLink();
            cDe.ContentDocumentId = conDoc;
            cDe.LinkedEntityId = fd.Id;
            cDe.ShareType = 'I';
            cDe.Visibility = 'AllUsers';
            insert cDe;
            
        }
    }

    public static void insertInsuranceBonds(List<License__c> licenseData) {
        List<InsuranceBond__c> insuranceBonds = new List<InsuranceBond__c>();
        for(Integer i = 0;i< licenseData.size();i ++ ) {
            License__c record =licenseData.get(i);
            InsuranceBond__c i2 = new InsuranceBond__c();
            if(math.mod(i, 4) == 0) {
                i2.Type__c = 'LP - Liability / Property Damage';
            } else if(math.mod(i, 4) == 1) {
                i2.Type__c = 'LI - Liability';
            } else if (math.mod(i, 4) == 2) {
                i2.Type__c = 'BD - Bond';
            } else {
                i2.Type__c = 'WC - Workers Compensation';
            }
            
            i2.Amount__c = 1;
            i2.License__c = record.Id;
            i2.Status__c = 'Active';
            i2.EffectiveDate__c = Date.newInstance(2020, 3, 31);
            insuranceBonds.add(i2);
        }
        
        insert insuranceBonds;
    }

    public static void createDummyEarnedCERecords() {
        TestDataFactory.createLicense();

        List<LicenseType__c> licenseTypes = [Select Id, LicenseTypeEffectiveDate__c from LicenseType__c];
        for(licenseType__c licenseType: licenseTypes) {
            licenseType.LicenseTypeEffectiveDate__c = Date.today();
        }
        update licenseTypes;
        List<License__c> lics = [SELECT Id, EffectiveExpireDate__c FROM License__c ];
        for(License__c lic: lics) {
            lic.EffectiveExpireDate__c = Date.today();
        }

        
        update lics;
        List<Earned_Continuing_Education__c> educations = new List<Earned_Continuing_Education__c>();
        for(License__c lic: lics) {
            Earned_Continuing_Education__c ece = new Earned_Continuing_Education__c();
            ece.CourseType__c = 'Core';
            ece.Biennium__c = String.valueOf(Date.today().year());
            ece.License__c = lic.Id;
            ece.Credits__c = 1;
            educations.add(ece);
        }
        
        insert educations;
    }

    public static void insertInsuranceBonds() {
        createLicense();
        List<License__c> licenseData = [Select Id, Name from License__c ];
        insertInsuranceBonds(licenseData);
    }
    public static void insertSubjects() {
        Subject__c ceSubject = new Subject__c();
        ceSubject.Name = 'test';
        ceSubject.Type__c = 'Core';
        ceSubject.CreditsForCESubjects__c = 1;

        Subject__c electiveSubject = new Subject__c();
        electiveSubject.Name = 'test';
        electiveSubject.Type__c = 'Elective';
        electiveSubject.CreditsForCESubjects__c = 1;
        insert new List<Subject__c>{ceSubject, electiveSubject};
    }

    public static void insertCourses() {
        insertSubjects();
        List<Subject__c> subjects = [Select Id, Type__c, CreditsForCESubjects__c from Subject__c ];
        List<Course__c> courses = new List<Course__c>();
        for(Subject__c subject: subjects) {
            Course__c course = new Course__c();
            course.Subject__c = subject.Id;
            course.StartTime__c = Time.newInstance(1, 0, 0, 0);
            course.Island__c = 'Hawaii';
            course.StartDate__c = Date.today().addDays(1);
            courses.add(course);
        }
        insert courses;
    }
    public static void insertPrelicenseCEEnrollments() {
        insertCourses();
        List<Course__c> courses = [Select Id from Course__c ];
        List<PrelicenseCEEnrollment__c> prelicenseCEEnrollments = new List<PrelicenseCEEnrollment__c>();
        Integer credit = 2;
        for(Course__c course: courses) {
            PrelicenseCEEnrollment__c enrollment = new PrelicenseCEEnrollment__c();
            enrollment.Course__c = course.Id;
            enrollment.Credits__c = credit;
            enrollment.PassDate__c = Date.today();
            prelicenseCEEnrollments.add(enrollment);
            credit ++;
        }
        insert prelicenseCEEnrollments;
    }
    

    public static void insertInsurancePortalSubmissions() {
        createLicense();
        List<License__c> licenseData = [Select Id, Name from License__c ];
        List<InsurancePortalSubmission__c> records = new List<InsurancePortalSubmission__c>();
        for(Integer i = 0;i< licenseData.size(); i++) {
            License__c license = licenseData.get(i);
            InsurancePortalSubmission__c record = new InsurancePortalSubmission__c();
            record.LimitEachOccurrence__c = 2;
            record.Email__c = 'testaa12@Sample.com';
            record.PolicyCancellationDateYear__c = Date.today().addDays(100).year()+'';
            record.PolicyCancellationDateMonth__c = Date.today().addDays(100).month()+'';
            record.PolicyCancellationDateDay__c = Date.today().addDays(100).day()+'';
            record.AuthorizedRepresentative__c = 'Test representative';
            record.License__c = license.Id;
            record.Status__c = 'Submitted';
            record.SubmitterType__c = 'Licensed Insurance Agent';
            record.PolicyNumber__c = 'Test Policy Number' + i;
            record.AdditionalComments__c= 'test' +i;
            record.InsurerAffordingCoverage__c = 'test affording coverage';
            record.PolicyExpirationDateYear__c = Date.today().addDays(300).year()+'';
            record.PolicyExpirationDateMonth__c = Date.today().addDays(300).month()+'';
            record.PolicyExpirationDateDay__c = Date.today().addDays(300).day()+'';
            if(math.mod(i, 3) == 0) {
                record.TransactionType__c = InsurancePortalSubmissionDomain.NEWINSURANCE;
                record.InsuranceType__c = 'General Liability';    
            } else if(math.mod(i, 3) == 1) {
                record.TransactionType__c = InsurancePortalSubmissionDomain.CONTINUATION;
                record.InsuranceType__c = 'Liability';
            } else {
                record.TransactionType__c = InsurancePortalSubmissionDomain.REINSTATEMENT;
                record.InsuranceType__c = 'Workers Comp';
            }
            records.add(record);
        }
        insert records;
    }
    public static void prepareInsuranceBonds() {
        createLicense();
        List<License__c> licenseRecords = [SELECT Id, Status__c, EffectiveExpireDate__c FROM License__c ];
        for(License__c lc: licenseRecords) {
            lc.EffectiveExpireDate__c = Date.today().addDays(1);
            lc.Status__c = 'C - Current, Valid & In Good Standing';
        }
        licenseRecords.get(0).Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        update licenseRecords;

        InsuranceBond__c bond1 = new InsuranceBond__c();
        bond1.Type__c = 'BD - Bond';
        bond1.Amount__c = 1;
        bond1.EffectiveDate__c = Date.today();
        bond1.TermDate__c = Date.today().addDays(1);
        bond1.CancelDate__c = Date.today().addDays(1);
        bond1.Status__c = 'Active';
        bond1.License__c = licenseRecords.get(0).Id;

        InsuranceBond__c bond2 = new InsuranceBond__c();
        bond2.Type__c = 'BD - Bond';
        bond2.Amount__c = 1;
        bond2.EffectiveDate__c = Date.today();
        bond2.TermDate__c = Date.today().addDays(1);
        bond2.CancelDate__c = Date.today().addDays(1);
        bond2.Status__c = 'Active';
        bond2.License__c = licenseRecords.get(1).Id;
        insert new List<InsuranceBond__c>{bond1, bond2};

        
    }
    public static void prepareAssociatedLicenses() {
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();

        //License Type
        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'RDS';
        licenseType.Status__c = 'Active';
        insert licenseType;

        //Classifications
        List<Classification__c> classificationList = new List<Classification__c>();
        Classification__c classA = new Classification__c();
        classA.Name = 'A';
        classA.LicenseType__c = licenseType.Id;
        classificationList.add(classA);

        Classification__c classM = new Classification__c();
        classM.Name = 'Motorcycle & Motor Scooter';
        classM.LicenseType__c = licenseType.Id;
        classificationList.add(classM);

        Classification__c classT = new Classification__c();
        classT.Name = 'T4 Brakes';
        classT.LicenseType__c = licenseType.Id;
        classificationList.add(classT);

        insert classificationList;

        //Licenses
        List<License__c> licenseListToCreate = new List<License__c>();

        //Group for Active A
        License__c licenseMainA = new License__c();
        licenseMainA.Name = 'License A';
        licenseMainA.ActiveInactive__c = 'Active';
        licenseMainA.LicenseType__c = licenseType.Id;
        licenseMainA.Status__c = 'CP - Current Pending';
        licenseMainA.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseMainA);

        License__c licenseEmployeeMainA = new License__c();
        licenseEmployeeMainA.Name = 'Employee License A';
        licenseEmployeeMainA.Status__c = 'C - Current, Valid & In Good Standing';
        licenseEmployeeMainA.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseEmployeeMainA);

        //Group for Active M
        License__c licenseMainM = new License__c();
        licenseMainM.Name = 'License M';
        licenseMainM.ActiveInactive__c = 'Active';
        licenseMainM.LicenseType__c = licenseType.Id;
        licenseMainM.Status__c = 'CP - Current Pending';
        licenseMainM.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseMainM);

        License__c licenseEmployeeMainM = new License__c();
        licenseEmployeeMainM.Name = 'Employee License M';
        licenseEmployeeMainM.Status__c = 'C - Current, Valid & In Good Standing';
        licenseEmployeeMainM.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseEmployeeMainM);

        //Group for Active T
        License__c licenseMainT = new License__c();
        licenseMainT.Name = 'License T';
        licenseMainT.ActiveInactive__c = 'Active';
        licenseMainT.LicenseType__c = licenseType.Id;
        licenseMainT.Status__c = 'CP - Current Pending';
        licenseMainT.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseMainT);

        License__c licenseEmployeeMainT = new License__c();
        licenseEmployeeMainT.Name = 'Employee License T';
        licenseEmployeeMainT.Status__c = 'C - Current, Valid & In Good Standing';
        licenseEmployeeMainT.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseEmployeeMainT);

        //Group to Trigger Error
        License__c licenseMainInvalid = new License__c();
        licenseMainInvalid.Name = 'License Invalid';
        licenseMainInvalid.ActiveInactive__c = 'Active';
        licenseMainInvalid.LicenseType__c = licenseType.Id;
        licenseMainInvalid.Status__c = 'CP - Current Pending';
        licenseMainInvalid.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseMainInvalid);

        License__c licenseEmployeeMainInvalid = new License__c();
        licenseEmployeeMainInvalid.Name = 'Employee License Invalid';
        licenseEmployeeMainInvalid.Status__c = 'C - Current, Valid & In Good Standing';
        licenseEmployeeMainInvalid.RecordTypeId = CTEntityRecordTypeId;
        licenseListToCreate.add(licenseEmployeeMainInvalid);

        insert licenseListToCreate;

        //Update the status of the created licenses
        List<License__c> licenseListToUpdate = new List<License__c>();

        //Group for Active A
        licenseMainA.Status__c = 'CP - Current Pending';
        licenseListToUpdate.add(licenseMainA);
        licenseEmployeeMainA.Status__c = 'C - Current, Valid & In Good Standing';
        licenseListToUpdate.add(licenseEmployeeMainA);
        //Group for Active M
        licenseMainM.Status__c = 'CP - Current Pending';
        licenseListToUpdate.add(licenseMainM);
        licenseEmployeeMainM.Status__c = 'C - Current, Valid & In Good Standing';
        licenseListToUpdate.add(licenseEmployeeMainM);
        //Group for Active T
        licenseMainT.Status__c = 'CP - Current Pending';
        licenseListToUpdate.add(licenseMainT);
        licenseEmployeeMainT.Status__c = 'C - Current, Valid & In Good Standing';
        licenseListToUpdate.add(licenseEmployeeMainT);
        //Group for Active Invalid
        licenseMainInvalid.Status__c = 'CP - Current Pending';
        licenseListToUpdate.add(licenseMainInvalid);
        licenseEmployeeMainInvalid.Status__c = 'C - Current, Valid & In Good Standing';
        licenseListToUpdate.add(licenseEmployeeMainInvalid);

        update licenseListToUpdate;

        //Associated Licenses
        List<AssociatedLicense__c> associatedLicenseList = new List<AssociatedLicense__c>();

        //Group for Active A
        AssociatedLicense__c associatedLicenseA = new AssociatedLicense__c();
        associatedLicenseA.EntityLicense__c = licenseMainA.Id;
        associatedLicenseA.EmployeeLicense__c = licenseEmployeeMainA.Id;
        associatedLicenseList.add(associatedLicenseA);
        //Group for Active M
        AssociatedLicense__c associatedLicenseM = new AssociatedLicense__c();
        associatedLicenseM.EntityLicense__c = licenseMainM.Id;
        associatedLicenseM.EmployeeLicense__c = licenseEmployeeMainM.Id;
        associatedLicenseList.add(associatedLicenseM);
        //Group for Active T
        AssociatedLicense__c associatedLicenseT = new AssociatedLicense__c();
        associatedLicenseT.EmploymentStatus__c = 'Employed';
        associatedLicenseT.EntityLicense__c = licenseMainT.Id;
        associatedLicenseT.EmployeeLicense__c = licenseEmployeeMainT.Id;
        associatedLicenseList.add(associatedLicenseT);
        //Group for Invalid
        AssociatedLicense__c associatedLicenseInvalid = new AssociatedLicense__c();
        associatedLicenseInvalid.EntityLicense__c = licenseMainInvalid.Id;
        associatedLicenseInvalid.EmployeeLicense__c = licenseEmployeeMainInvalid.Id;
        associatedLicenseList.add(associatedLicenseInvalid);

        insert associatedLicenseList;

        //License Classifications
        List<LicenseClassification__c> licenseClassificationList = new List<LicenseClassification__c>();

        //License Classifications for Main License
        //Active A Main License
        LicenseClassification__c lcA = new LicenseClassification__c();
        lcA.Status__c = 'C - Current, Valid & In Good Standing';
        lcA.License__c = licenseMainA.Id;
        lcA.Classification__c = classA.Id;
        licenseClassificationList.add(lcA);

        //Active M Main License
        LicenseClassification__c lcM = new LicenseClassification__c();
        lcM.Status__c = 'C - Current, Valid & In Good Standing';
        lcM.License__c = licenseMainM.Id;
        lcM.Classification__c = classM.Id;
        licenseClassificationList.add(lcM);

        //Active T Main License
        LicenseClassification__c lcT = new LicenseClassification__c();
        lcT.Status__c = 'C - Current, Valid & In Good Standing';
        lcT.License__c = licenseMainT.Id;
        lcT.Classification__c = classT.Id;
        licenseClassificationList.add(lcT);

        //License Classifications for Employee Licenses

        //Active A Employee License
        for(Integer activaAs = 0; activaAs <= 9; activaAs++){
            LicenseClassification__c elcA1 = new LicenseClassification__c();
            elcA1.Status__c = 'C - Current, Valid & In Good Standing';
            elcA1.License__c = licenseEmployeeMainA.Id;
            elcA1.Classification__c = classA.Id;
            licenseClassificationList.add(elcA1);
        }


        //Active M Employee License
        LicenseClassification__c elcM1 = new LicenseClassification__c();
        elcM1.Status__c = 'C - Current, Valid & In Good Standing';
        elcM1.License__c = licenseEmployeeMainM.Id;
        elcM1.Classification__c = classM.Id;
        licenseClassificationList.add(elcM1);

        LicenseClassification__c elcM2 = new LicenseClassification__c();
        elcM2.Status__c = 'C - Current, Valid & In Good Standing';
        elcM2.License__c = licenseEmployeeMainM.Id;
        elcM2.Classification__c = classM.Id;
        licenseClassificationList.add(elcM2);

        //Active T Employee License
        for(Integer activaTs = 0; activaTs <= 9; activaTs++) {
            LicenseClassification__c elcT = new LicenseClassification__c();
            elcT.Status__c = 'C - Current, Valid & In Good Standing';
            elcT.License__c = licenseEmployeeMainT.Id;
            elcT.Classification__c = classT.Id;
            licenseClassificationList.add(elcT);
        }

        insert licenseClassificationList;
    }
    public static List<EligibleCandidateLoad__c> createEligibleCandidateLoad() {
        Integer testSize = 10;
        // Data setup
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        List<Account> accounts = new List<Account>();
        accounts.add(createAccountUnit('Test Account 1', '222222'));
        accounts.add(createAccountUnit('AA Account 1', '333'));
        accounts.add(createAccountUnit('BB Account 1', '2222134'));
        accounts.add(createAccountUnit('CC Account 1', '43323'));
        accounts.add(createAccountUnit('DD Account 1', '554544'));
        accounts.add(createAccountUnit('EE Account 1', '66554'));
        accounts.add(createAccountUnit('FF Account 1', '334565'));
        accounts.add(createAccountUnit('GG Account 1', '44332'));
        accounts.add(createAccountUnit('HH Account 1', '55664'));
        accounts.add(createAccountUnit('AAII Account 1', '434333'));
        
        
        insert accounts;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        insert licenseTypeRecord;
        List<Application__c> applications = new List<Application__c>();
        for(Integer i=0;i< testSize; i++ ) {
            Application__c applicationRecord = new Application__c();
            applicationRecord.Applicant__c = accounts.get(i).Id;
            applicationRecord.LicenseType__c = licenseTypeRecord.Id;
            applicationRecord.Type__c = 'LICN - New License';
            applicationRecord.Phase__c = 'A - Application Received';
            applications.add(applicationRecord);
        }
        
        insert applications;
        List<EligibleCandidateLoad__c> eligibleCandiates = new List<EligibleCandidateLoad__c>();
        for(Integer i = 0; i< testSize; i++) {
            EligibleCandidateLoad__c candidateLoad = new EligibleCandidateLoad__c();
            candidateLoad.SSN__c = accounts.get(i).BPID__c;
            eligibleCandiates.add(candidateLoad);
        }
        insert eligibleCandiates;
        return eligibleCandiates;
        
    }
    public static Account createAccountUnit(String name, String feinNumber) {
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        Account acc = new Account();
        acc.Name = name;
        acc.FEIN__c = feinNumber;
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        
        return acc;
    }
    public static Account createBusinessAccount() {
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');
        Account acc = new Account();
        acc.Name = 'acc';
        acc.FEIN__c = '1233435';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        
        return acc;
    }
    public static void createNotification() {
        Date todaysDate = Date.today();

        Account dummyAccount = new Account();
        dummyAccount.Name = 'Account Name';
        insert dummyAccount;
        
        DocGeneratorSettings__c  setting = new DocGeneratorSettings__c ();
        setting.Name = 'test';
        setting.DocumentType__c = 'Word';
        insert setting;
        LicenseType__c dummyLT = new LicenseType__c();
        dummyLT.StartofRenewalPeriod__c = todaysDate;
        dummyLT.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        dummyLT.StatusDuetoLossofDependent__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
         dummyLT.Entity__c = true;
         dummyLT.RMELosesEntityNotification__c  = setting.Id;
         dummyLt.EntityLosesRMENotification__c  = setting.Id;
        dummyLT.Status__c = 'Active';
        dummyLT.Name = 'Dummy License Type';
        insert dummyLT;
        
        
        License__c dummyEmployeeLicense = new License__c();
        dummyEmployeeLicense.Status__c = 'C - Current, Valid & In Good Standing';
        dummyEmployeeLicense.GenerateRMELosesEntityNotification__c = true;
        dummyEmployeeLicense.LicenseType__c = dummyLT.Id;
        dummyEmployeeLicense.Licensee__c = dummyAccount.Id;
        insert dummyEmployeeLicense;
        License__c dummyEmployeeLicense2 = new License__c();
        dummyEmployeeLicense2.Status__c = 'C - Current, Valid & In Good Standing';
        dummyEmployeeLicense2.GenerateEntityLosesRMENotification__c = true;
        dummyEmployeeLicense2.LicenseType__c = dummyLT.Id;
        dummyEmployeeLicense2.Licensee__c = dummyAccount.Id;
        insert dummyEmployeeLicense2;
        Notification__c record = new Notification__c();
        record.RecordId__c = dummyLT.Id;
        insert record;
    }
    public static pymt__PaymentX__c createDummyChargebackPayment() {
        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;
        
        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        insert trn;
        
        FeeSchedule__c fs = new FeeSchedule__c();
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 110;
        pymt.pymt__Payment_Type__c = 'Credit Card';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'Completed';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        pymt.PPIFeeAmount__c = 100;
        pymt.pymt__Status__c = 'Completed';
        return pymt;
    }
    public static void createTransactionAndPayment(Account acc, Application__c app) {
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        Transaction__c trn = new Transaction__c();
        trn.Account__c = acc.Id;
        trn.Contact__c = cnt.Id;
        trn.Application__c = app.Id;
        trn.TotalAmount__c = 100;
        insert trn;

        FeeSchedule__c fs = new FeeSchedule__c();
        insert fs;

        pymt__PaymentX__c pymt = new pymt__PaymentX__c();
        pymt.Transaction__c = trn.Id;
        pymt.pymt__Account__c = acc.Id;
        pymt.pymt__Contact__c = cnt.Id;
        pymt.pymt__Amount__c = 100;
        pymt.pymt__Payment_Type__c = 'Credit Card';
        pymt.pymt__Date__c = Date.today();
        pymt.pymt__Currency_ISO_Code__c = 'USD';
        pymt.pymt__Transaction_Type__c = 'Payment';
        pymt.pymt__Status__c = 'New';
        pymt.Name = 'test';
        pymt.FeeSchedule__c = fs.Id;
        insert pymt;
    }

    public static Transaction__c createTransaction() {
        Account account = createBusinessAccount();
        insert account;

        CashierCode__c cashierCode = new CashierCode__c();
        cashierCode.Amount__c = 10;
        cashierCode.Description__c = 'test Description';
        insert cashierCode;

        Transaction__c transactionGroupParent = new Transaction__c();
        transactionGroupParent.Account__c = account.Id;
        transactionGroupParent.TotalAmount__c = 0;
        transactionGroupParent.TransactionType__c = 'Group';
        transactionGroupParent.Status__c = 'New';
        insert transactionGroupParent;
        return transactionGroupParent;
    }
    
    public static void createLicense() {
        List<License__c> licenses = [Select Id from License__c where Name = 'acc'];
        if(!licenses.isEmpty()) {
            return ;
        }
        BusinessAccountCounter__c accountCounterSetting = new BusinessAccountCounter__c();
        accountCounterSetting.ResetDate__c = Date.today();
        accountCounterSetting.Counter__c = 1;
        insert accountCounterSetting;

        

        Id licenseRtId = License__c.getSObjectType()
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PVLCTEntity')
                .getRecordTypeId();

        
        Account acc = createBusinessAccount();
        insert acc;

        BoardProgram__c boardProgram = new BoardProgram__c();
        boardProgram.Type__c = 'Program';
        boardProgram.Name = 'Test';
        insert boardProgram;

        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'lct';
        licenseType.RollingLicensePeriod__c = false;
        licenseType.LicenseTypeEffectiveDate__c = Date.today().addDays(1);
        licenseType.DurationofLicenseInMonths__c = 0;
        licenseType.DurationofRestorationInMonths__c = 0;
        licenseType.StatusDuetoNonRestore__c = 'F - Terminated; Needs to Reapply';
        licenseType.Status__c = 'Active';
        licenseType.AbleToInactivate__c = true;
        licenseType.BoardProgram__c = boardProgram.Id;
        licenseType.GenerateLicenseStatus__c = 'D - Forfeited; Needs to Restore';
        licenseType.RenewalWindowInDays__c = 5;
        insert licenseType;

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';

        insert new List<Application__c>{app};

        License__c license = new License__c();
        license.Name = 'acc';
        license.Application__c = app.Id;
        license.LicenseType__c = licenseType.Id;
        license.RecordTypeId = licenseRtId;
        license.ActiveInactive__c = 'Active';
        license.Status__c = 'D - Forfeited; Needs to Restore';
        insert license;
        List<License__c> licenseRecords = new List<License__c>();
        License__c license2 = new License__c();
        license2.Name = 'acc2';
        license2.Application__c = app.Id;
        license2.LicenseType__c = licenseType.Id;
        license2.DependentLicense__c = license.Id;
        license2.RecordTypeId = licenseRtId;
        license2.ActiveInactive__c = 'Active';
        license2.Status__c = 'D - Forfeited; Needs to Restore';
        licenseRecords.add(license2);
        License__c license3 = new License__c();
        license3.Name = 'acc3';
        license3.Application__c = app.Id;
        license3.LicenseType__c = licenseType.Id;
        license3.DependentLicense__c = license.Id;
        license3.RecordTypeId = licenseRtId;
        license3.ActiveInactive__c = 'Active';
        license3.Status__c = 'D - Forfeited; Needs to Restore';
        licenseRecords.add(license3);
        License__c license4= new License__c();
        license4.Name = 'acc4';
        license4.Application__c = app.Id;
        license4.LicenseType__c = licenseType.Id;
        license4.DependentLicense__c = license.Id;
        license4.RecordTypeId = licenseRtId;
        license4.ActiveInactive__c = 'Active';
        license4.Status__c = 'D - Forfeited; Needs to Restore';
        licenseRecords.add(license4);
        insert licenseRecords;
    }
    public static LicenseType__c prepareLicenseType(String name, BoardProgram__c bp) {
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = name;
        licenseTypeRecord.BoardProgram__c = bp.Id;
        licenseTypeRecord.LicenseTypeEffectiveDate__c = Date.today().addDays(365);
        
        return licenseTypeRecord;
    }
    public static List<LicenseType__c> createLicenseTypes(List<String> names) {
        BoardProgram__c bp = createBoardProgram();
        insert bp;
        List<LicenseType__c> lts = new List<LicenseType__c>();
        for(String name: names) {
            lts.add(prepareLicenseType(name, bp));
        }
        insert lts;
        return lts;
    }
    public static BoardProgram__c createBoardProgram() {
        BoardProgram__c bp = new BoardProgram__c();
        bp.Name = 'MOTOR VEHICLE REPAIR INDUSTRY BOARD';
        bp.BoardProgramNumber__c = 'MOTOR VEHICLE REPAIR INDUSTRY';
        bp.Type__c = 'Board';
        bp.BoardProgramNumber__c = '680';
        return bp;
    }
    public static LicenseType__c createLicenseTypes(String name) {
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = name;
        licenseTypeRecord.DependencyRequired__c = true;
        insert licenseTypeRecord;
        return licenseTypeRecord;
    }
    public static Application__c createDummyApplication() {
        // create transactions
        // Data setup
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
     
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        LicenseType__c licenseTypeRecord = createLicenseTypes( 'Test LT');

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
        

        
        return applicationRecord;
    }
    public static Classification__c createClasifications() {
        LicenseType__c licenseTypeRecord = createLicenseTypes('Test classification');
        Classification__c classificationRecord = new Classification__c();
        classificationRecord.Status__c = 'Active';
        classificationRecord.Name = 'Classification Record';
        classificationRecord.LicenseType__c = licenseTypeRecord.Id;
        insert classificationRecord;

        return classificationRecord;
    }
}