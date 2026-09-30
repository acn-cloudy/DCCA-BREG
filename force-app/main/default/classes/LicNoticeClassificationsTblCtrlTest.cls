/*
 * ___________________________________________________________________________________
 * LicNoticeClassificationsTblController Test
 * __________________________________________________________________________________
 * PacPoint-CL02142022 - Created for Case 00013106
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 02/14/2022
 * __________________________________________________________________________________
 */
@IsTest
private class LicNoticeClassificationsTblCtrlTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
    }

    @IsTest
    static void testGetClassifications() {
        License__c l = [SELECT Id FROM License__c LIMIT 1];
        LicNoticeClassificationsTblController ctrl = new LicNoticeClassificationsTblController();
        ctrl.lic = l;
        ctrl.getClassifications();
    }
}