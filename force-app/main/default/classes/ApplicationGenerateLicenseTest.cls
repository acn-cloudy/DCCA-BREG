/*
 * Created by Devtac-Irene on 7/31/2019.
 */
@IsTest
private class ApplicationGenerateLicenseTest {
	// @isTest
	// static void testApplicationGenerateLicense(){
	// 	Account acctRecord = new Account();
	// 	acctRecord.Name = 'Dummy';
	// 	insert acctRecord;

	// 	Date todaysDate = Date.today();
	// 	Date twoMonths = todaysDate.addMonths(2);

	// 	LicenseType__c licenseTypeRecord = new LicenseType__c();
	// 	licenseTypeRecord.Name = 'Test LT';
	// 	insert licenseTypeRecord;

	// 	List<Application__c> applicationList = new List<Application__c>();

	// 	Application__c applicationRecord = new Application__c();
	// 	applicationRecord.Applicant__c = acctRecord.Id;
	// 	applicationRecord.LicenseType__c = licenseTypeRecord.Id;
	// 	applicationRecord.Type__c = 'LICN - New License';
	// 	applicationRecord.Phase__c = 'A - Application Received';
	// 	applicationList.add(applicationRecord);

	// 	insert applicationList;

	// 	Classification__c classificationRecord = new Classification__c();
	// 	classificationRecord.Status__c = 'Active';
	// 	classificationRecord.Name = 'Classification Record';
	// 	classificationRecord.LicenseType__c = licenseTypeRecord.Id;
	// 	insert classificationRecord;

	// 	List<ApplicationClassifications__c> acList = new List<ApplicationClassifications__c>();

	// 	ApplicationClassifications__c applicationClassificationsRecord = new ApplicationClassifications__c();
	// 	applicationClassificationsRecord.Classification__c = classificationRecord.Id;
	// 	applicationClassificationsRecord.Status__c = 'W - Awaiting Approval/Exam';
	// 	applicationClassificationsRecord.Application__c = applicationRecord.Id;
	// 	acList.add(applicationClassificationsRecord);

	// 	ApplicationClassifications__c acPassed = new ApplicationClassifications__c();
	// 	acPassed.Classification__c = classificationRecord.Id;
	// 	acPassed.Status__c = 'P - Passed Exam--Class to be Licensed';
	// 	acPassed.Application__c = applicationRecord.Id;
	// 	acList.add(acPassed);
	// 	insert acList;

	// 	Test.startTest();
	// 	applicationRecord.Phase__c  = 'H - License Generation';
	// 	applicationRecord.Status__c = '';
	// 	update applicationRecord;

	// 	applicationRecord.Phase__c  = 'A - Application Received';
	// 	applicationRecord.Status__c = '';
	// 	update applicationRecord;

	// 	applicationRecord.Phase__c  = 'H - License Generation';
	// 	applicationRecord.Status__c = '';
	// 	applicationRecord.Type__c = 'ADDC - Additional Class';
	// 	update applicationRecord;

	// 	Test.stopTest();

		

	// 	List<License__c> licenseList = [SELECT Id FROM License__c WHERE Application__c =: applicationRecord.Id];
	// 	System.assertEquals(1, licenseList.size());

	// }
}