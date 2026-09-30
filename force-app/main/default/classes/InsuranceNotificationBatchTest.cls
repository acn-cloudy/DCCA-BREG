@IsTest
private class InsuranceNotificationBatchTest {
    @TestSetup
    static void setup() {
        TestDataFactory.prepareInsuranceBonds();
        List<LicenseType__c> licenseTypes = [
                SELECT
                        Id,
                        RequiresInsurance__c
                FROM LicenseType__c
        ];

        for (LicenseType__c licenseType : licenseTypes) {
            licenseType.RequiresInsurance__c = true;
        }

        update licenseTypes;
    }

    @IsTest
    static void testBatch() {
        List<InsuranceBond__c> results = [SELECT Id, License__c FROM InsuranceBond__c];

        Test.startTest();
        (new InsuranceNotificationBatch()).execute(null, results);
        Test.stopTest();
    }

    @IsTest
    static void testBatch2() {
        Test.startTest();
        Database.executeBatch(new InsuranceNotificationBatch());
        Test.stopTest();
    }
}