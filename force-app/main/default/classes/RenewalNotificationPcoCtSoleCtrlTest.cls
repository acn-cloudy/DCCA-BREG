/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04202022 - Created for PVL Case 00021212
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 04/20/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class RenewalNotificationPcoCtSoleCtrlTest {
    @TestSetup
    static void makeData() {
        TestDataFactory.insertInsuranceBonds();
    }

    @IsTest
    static void testController() {
        List<License__c> records = [
                SELECT
                        Id,
                        LicenseType__r.OtherRenewalRequirements2__c,
                        LicenseType__r.OtherRenewalRequirements1__c
                FROM License__c
        ];

        LicenseType__c licenseType = records.get(0).LicenseType__r;
        licenseType.OtherRenewalRequirements1__c =
            '<p>RENEW ONLINE AT: <span style="font-size: 14px;">https://mypvl.example.com</span></p>';
        licenseType.OtherRenewalRequirements2__c = 'test';
        licenseType.RenewalFormTemplateBulkRenewals__c = 'RenewalNotificationPCOCTSOLE';
        update licenseType;

        List<String> idList = (List<String>)(new LicenseDomain(records)).getFieldValues('Id');
        String queryIds = String.join(idList, ',');
        Notification__c notification = NotificationService.generateNotificationForIdContain(queryIds, '');

        ApexPages.currentPage().getParameters().put('notificationIds', notification.Id);
        RenewalNotificationPcoCtSoleController cont = new RenewalNotificationPcoCtSoleController();

        String req1 = cont.displayRecords[0].license.LicenseType__r.OtherRenewalRequirements1__c;
        System.assert(req1.contains('<div>'), 'p tags should convert to div');
        System.assert(!req1.containsIgnoreCase('font-size'), 'font-size should be stripped');
    }
}