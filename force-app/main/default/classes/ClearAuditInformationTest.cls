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
private class ClearAuditInformationTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        List<License__c> licenses =  [Select Id, FlaggedforAudit__c from License__c] ;
        for(License__c license: licenses) {
            license.FlaggedforAudit__c = true;
        }
        update licenses;
    }

    @isTest
    static void test_clearAuditInformationList() {
        test.startTest();
        List<Id> ltIds = new List<Id>();
        List<LicenseType__c> licenseTypes = [Select Id, ResetAudit__c from LicenseType__c];        
        for (LicenseType__c record : licenseTypes) {
            ltIds.add(record.Id);
        }
        Database.executeBatch(new ClearAuditInformation(ltIds), 200);
        test.stopTest();
    }

    @isTest
    static void test_clearAuditInformation() {
        test.startTest();
        LicenseType__c licenseType = [Select Id, ResetAudit__c from LicenseType__c LIMIT 1];  
        Database.executeBatch(new ClearAuditInformation(licenseType.Id), 200);
        test.stopTest();
    }
}