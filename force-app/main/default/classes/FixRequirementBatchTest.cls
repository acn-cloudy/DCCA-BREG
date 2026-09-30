@isTest
private class FixRequirementBatchTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        
    }

    @isTest
    static void testBatch() {
        List<Application__c> applications = [Select Id, name from Application__c];
        List<String> appNames = (List<String>)(new ApplicationDomain(applications)).getFieldValues('Name');
        Database.executeBatch(new FixRequirementBatch(appNames));
    }

}