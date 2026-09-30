@isTest
private class ForfeitureLicenseTest {
    @TestSetup
    static void makeData(){
        Id CTEntityRecordTypeId = Schema.SObjectType.License__c.getRecordTypeInfosByName().get('PVL - CT - Entity').getRecordTypeId();
        Id BusinessAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Business Account').getRecordTypeId();
  
        // Account
		Account acc = new Account();
        acc.Name = 'Test 398624';
        acc.RecordTypeId = BusinessAccountRecordTypeId;
        insert acc;

        //License Type
		LicenseType__c licenseType = new LicenseType__c();
		licenseType.Name = 'RDS';
        licenseType.Status__c = 'Active';
        licenseType.DependencyRequired__c = true;
        licenseType.Branch__c = true;
        licenseType.StatusDueToNonRenewal__c = 'C - Current, Valid & In Good Standing';
        licenseType.StatusDueToLossOfInsurance__c = 'C - Current, Valid & In Good Standing';
        insert licenseType;
      

        License__c dependentLicense = new License__c();
		dependentLicense.Name = 'License A';
        dependentLicense.ActiveInactive__c = 'Active';
        dependentLicense.Status__c = 'C - Current, Valid & In Good Standing';
        // dependentLicense.Status__c = 'D - Forfeited; Needs to Restore';
        dependentLicense.LicenseType__c = licenseType.Id;
        dependentLicense.RecordTypeId = CTEntityRecordTypeId;
        dependentLicense.ForfeitureDate__c = Date.today().addDays(-1);
        insert dependentLicense;
        
        dependentLicense.LossofEntity__c = true;
        dependentLicense.LossofPrincipalRME__c = true;
        dependentLicense.ForfeitureDate__c = Date.today().addDays(-1);
        update dependentLicense;
        List<Suspense__c> suspenses = [Select Id, SuspenseDueDate__c from Suspense__c where License__c =: dependentLicense.Id];
        for(Suspense__c suspense: suspenses) {
            suspense.SuspenseStatus__c = 'C - Current, Valid & In Good Standing';
            suspense.SuspenseDueDate__c = Date.today().addDays(-1);
        }
        update suspenses;
       
    }
    private static testMethod void testForfeitureLicense() {
        Test.startTest();
        Database.executeBatch(new ForfeitureLicense(), 100);
        Test.stopTest();
    }
    
}