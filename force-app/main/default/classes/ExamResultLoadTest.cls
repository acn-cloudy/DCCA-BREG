/*
 * ___________________________________________________________________________________
 * Code coverage for ExamResultLoad classes
 * __________________________________________________________________________________
 * PacPoint-CL12132019 - Created for PVL PHASE 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 12/13/2019
 * __________________________________________________________________________________
 */
@IsTest
private class ExamResultLoadTest {
    @TestSetup
    static void setup() {
        BusinessAccountCounter__c accountCounterSetting = new BusinessAccountCounter__c();
        accountCounterSetting.ResetDate__c = Date.today();
        accountCounterSetting.Counter__c = 1;
        insert accountCounterSetting;

        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');

        Account acc = new Account();
        acc.Name = 'acc';
        acc.BPID__c = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;

        ExamTypes__c examType = new ExamTypes__c();
        examType.Name = 'examType';
        insert examType;

        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'lct';
        licenseType.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        insert licenseType;

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'A - Application Received';
        insert app;

        ExamsRequired__c examsRequired = new ExamsRequired__c();
        examsRequired.ExamType__c = examType.Id;
        examsRequired.Applicant__c = acc.Id;
        examsRequired.Date__c = Date.today();
        examsRequired.Application__c = app.Id;
        insert examsRequired;
    }

    @IsTest
    static void testExamResultsLoadPopulateExamResults() {
        Account accWithSsn = [SELECT Id, BPID__c FROM Account LIMIT 1];
        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today();
        load.PassorFail__c = 'Pass';
        load.SSN__c = accWithSsn.BPID__c;
        insert load;
    }

    @IsTest
    static void testExamResultsLoadPopulateExamResultsNoSsn() {
        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today();
        load.PassorFail__c = 'Pass';
        load.SSN__c = 'non';
        insert load;
    }

    @IsTest
    static void testExamResultsLoadPopulateExamResultsSameStatus() {
        ExamsRequired__c req = [SELECT Id FROM ExamsRequired__c LIMIT 1];
        Account accWithSsn = [SELECT Id, BPID__c FROM Account LIMIT 1];

        ExamResults__c examResults = new ExamResults__c();
        examResults.ExamsRequired__c = req.Id;
        examResults.ExamDate__c = Date.today();
        examResults.Status__c = 'Passed';
        insert examResults;

        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today();
        load.PassorFail__c = 'Pass';
        load.SSN__c = accWithSsn.BPID__c;
        insert load;
    }

    @IsTest
    static void testExamResultsLoadPopulateExamResultsUpdateStatus() {
        ExamsRequired__c req = [SELECT Id FROM ExamsRequired__c LIMIT 1];
        Account accWithSsn = [SELECT Id, BPID__c FROM Account LIMIT 1];

        ExamResults__c examResults = new ExamResults__c();
        examResults.ExamsRequired__c = req.Id;
        examResults.ExamDate__c = Date.today();
        examResults.Status__c = 'Failed';
        insert examResults;

        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today();
        load.PassorFail__c = 'Pass';
        load.SSN__c = accWithSsn.BPID__c;
        insert load;
    }

    @IsTest
    static void testExamResultsLoadPopulateExamResultsDifferentDate() {
        ExamsRequired__c req = [SELECT Id FROM ExamsRequired__c LIMIT 1];
        Account accWithSsn = [SELECT Id, BPID__c FROM Account LIMIT 1];

        ExamResults__c examResults = new ExamResults__c();
        examResults.ExamsRequired__c = req.Id;
        examResults.ExamDate__c = Date.today();
        examResults.Status__c = 'Failed';
        insert examResults;

        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today().addDays(-1);
        load.PassorFail__c = 'Pass';
        load.SSN__c = accWithSsn.BPID__c;
        insert load;
    }

    @IsTest
    static void testNoApplicationFound() {
        RecordTypeInfo businessAccountRti =
                Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('BusinessAccount');

        Account acc = new Account();
        acc.Name = 'acc';
        acc.BPID__c = 'acc';
        acc.RecordTypeId = businessAccountRti.getRecordTypeId();
        insert acc;

        ExamTypes__c examType = new ExamTypes__c();
        examType.Name = 'examType';
        insert examType;

        LicenseType__c licenseType = new LicenseType__c();
        licenseType.Name = 'lct';
        licenseType.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        insert licenseType;

        Application__c app = new Application__c();
        app.Name = 'app';
        app.LicenseType__c = licenseType.Id;
        app.Applicant__c = acc.Id;
        app.Type__c = 'RNEW - Renewal';
        app.Phase__c = 'H - License Generation';
        app.Status__c = 'H1 - Awaiting Licensing';
        insert app;

        ExamsRequired__c examsRequired = new ExamsRequired__c();
        examsRequired.ExamType__c = examType.Id;
        examsRequired.Applicant__c = acc.Id;
        examsRequired.Date__c = Date.today();
        examsRequired.Application__c = app.Id;
        insert examsRequired;

        Account accWithSsn = [SELECT Id, BPID__c FROM Account WHERE Id = :acc.Id];

        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today();
        load.PassorFail__c = 'Pass';
        load.SSN__c = accWithSsn.BPID__c;
        insert load;
    }

    @IsTest
    static void testNoExamTypeFound() {
        ExamsRequired__c req = [SELECT Id FROM ExamsRequired__c LIMIT 1];
        Account accWithSsn = [SELECT Id, BPID__c FROM Account LIMIT 1];

        ExamResults__c examResults = new ExamResults__c();
        examResults.ExamsRequired__c = req.Id;
        examResults.ExamDate__c = Date.today();
        examResults.Status__c = 'Failed';
        insert examResults;

        ExamResultsLoad__c load = new ExamResultsLoad__c();
        load.ExamType__c = 'examType1';
        load.ExamScore__c = 1;
        load.DateofExam__c = Date.today().addDays(-1);
        load.PassorFail__c = 'Pass';
        load.SSN__c = accWithSsn.BPID__c;
        insert load;
    }
}