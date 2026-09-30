/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class ExamResultsServiceTest {

    @TestSetup
    static void makeData(){
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.RequiresInsurance__c = true;
        licenseTypeRecord.InsuranceBondTypesRequired__c = 'BD - Bond';
        insert licenseTypeRecord;

        Application__c applicationRecord = new Application__c();
        applicationRecord.Applicant__c = acc.Id;
        applicationRecord.LicenseType__c = licenseTypeRecord.Id;
        applicationRecord.Type__c = 'LICN - New License';
        applicationRecord.Phase__c = 'A - Application Received';
        insert applicationRecord;

        ExamTypes__c exType = new ExamTypes__c();
        exType.name = 'TEST';
        exType.WaitingPeriodUponFailedExam__c = 3;
        insert exType;

        ExamsRequired__c exReq = new ExamsRequired__c();
        exReq.Application__c = applicationRecord.Id;
        exReq.Applicant__c = acc.Id;
        exReq.ExamType__c = exType.Id;
        insert exReq;

        ExamResults__c exRes1 = new ExamResults__c();
        exRes1.ExamsRequired__c = exReq.Id;
        exRes1.ExamDate__c = Date.today();
        exRes1.Status__c = 'Failed';

        ExamResults__c exRes2 = new ExamResults__c();
        exRes2.ExamsRequired__c = exReq.Id;
        exRes2.ExamDate__c = Date.today().addMonths(1);
        exRes2.Status__c = 'Passed';

        insert new List<ExamResults__c>{exRes1, exRes2};
    }

    @isTest
    static void testUpdate() {
        List<ExamResults__c> exResults = [SELECT Id, Status__c FROM ExamResults__c];
        for(ExamResults__c exResult:exResults){
            exResult.Status__c = exResult.Status__c == 'Failed' ? 'Passed':'Failed';
        }

        update exResults;
    }

    @isTest
    static void testDelete() {
        List<ExamResults__c> exResults = [SELECT Id, Status__c FROM ExamResults__c];
        for(ExamResults__c exResult:exResults){
            delete exResult;
        }
    }
}