/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: TaxClearanceCheckBatchTestTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL08092022 - Created for case 00023037
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 08/09/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class TaxClearanceCheckBatchTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
        TaxClearanceApi__c settings = new TaxClearanceApi__c();
        settings.EndpointUrl__c = 'https://test.api.test';
        settings.Username__c = 'test';
        settings.Password__c = 'test';
        settings.SetupOwnerId = UserInfo.getOrganizationId();
        insert settings;
        Account a = [SELECT Id FROM Account LIMIT 1];
        List<License__c> licenses = [SELECT Id FROM License__c];
        for (License__c l : licenses) {
            l.Status__c = 'C - Current, Valid & In Good Standing';
            l.ActiveInactive__c = 'Active';
            l.Licensee__c = a.Id;
        }
        update licenses;
    }

    @IsTest
    static void dFoundTest() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceYResultMockImpl());
        Test.startTest();
        Database.executeBatch(new TaxClearanceCheckBatch(lt.Id), 50);
        Test.stopTest();
    }

    @IsTest
    static void yFoundTest() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceDResultMockImpl());
        Test.startTest();
        Database.executeBatch(new TaxClearanceCheckBatch(lt.Id), 50);
        Test.stopTest();
    }

    @IsTest
    static void notFoundTest() {
        LicenseType__c lt = [SELECT Id FROM LicenseType__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new TaxClearanceApiHelperTest.RunClearanceNoResultsMockImpl());
        Test.startTest();
        Database.executeBatch(new TaxClearanceCheckBatch(lt.Id), 50);
        Test.stopTest();
    }
}