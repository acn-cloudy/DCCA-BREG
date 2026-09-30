/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04222022 - Created for PVL Case 00021111
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@outlook.ph
 *
 * @created 04/22/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class LicenseTypeRenewalEmailSenderTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
        PVL_Portal_User__c testUser = new PVL_Portal_User__c();
        testUser.Email__c = 'test@test.test';
        insert testUser;
        List<License__c> licenses = [SELECT Id FROM License__c];
        for (License__c l : licenses) {
            l.PVL_Portal_User__c = testUser.Id;
            l.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        }

        update licenses;
    }

    @IsTest
    static void testBatch() {
        LicenseType__c l = [SELECT Id FROM LicenseType__c LIMIT 1];
        Test.startTest();
        l.SendRenewalEmailforallLicenses__c = true;
        update l;
        Test.stopTest();
    }
}