@IsTest
private class LicenseTaxClearancerControllerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
        TaxClearanceApi__c settings = new TaxClearanceApi__c();
        settings.EndpointUrl__c = 'https://test.api.test';
        settings.Username__c = 'test';
        settings.Password__c = 'test';
        settings.SetupOwnerId = UserInfo.getOrganizationId();
        insert settings;
    }

    @IsTest
    static void testRunClearanceD() {
        License__c l = [SELECT Id FROM License__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        l.Licensee__c = acc.Id;
        update l;

        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceDResultMockImpl());
        Test.startTest();
        LicenseTaxClearancerController.runClearanceCheck(l.Id);
        Test.stopTest();
    }

    @IsTest
    static void testRunClearanceY() {
        License__c l = [SELECT Id FROM License__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        l.Licensee__c = acc.Id;
        update l;

        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceYResultMockImpl());
        Test.startTest();
        LicenseTaxClearancerController.runClearanceCheck(l.Id);
        Test.stopTest();
    }

    @IsTest
    static void testRunClearanceNoResults() {
        License__c l = [SELECT Id FROM License__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.StateExciseTaxNumber__c = '1';
        update acc;

        l.Licensee__c = acc.Id;
        update l;

        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceNoResultsMockImpl());
        Test.startTest();
        LicenseTaxClearancerController.runClearanceCheck(l.Id);
        Test.stopTest();
    }

    @IsTest
    static void testRunClearanceNoResultsErr() {
        License__c l = [SELECT Id FROM License__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        l.Licensee__c = acc.Id;
        update l;

        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceErr400MockImpl());
        Test.startTest();
        try {
            LicenseTaxClearancerController.runClearanceCheck(l.Id);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
}