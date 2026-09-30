/*
 * -----------------------------------------------------------------------------------
 * Description
 * test for RenewalNotificationwInsClassesController
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04222022 - Created for PVL case 00021252
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 04/22/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class RenewalNotificationwInsClassesCtrlTest {
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
            '<p style="font-size: 14px;">INACTIVE STATUS?</p>';
        licenseType.OtherRenewalRequirements2__c = 'test';
        licenseType.RenewalFormTemplateBulkRenewals__c = 'RenewalNotificationwInsClasses';
        update licenseType;

        List<String> idList = (List<String>)(new LicenseDomain(records)).getFieldValues('Id');
        String queryIds = String.join(idList, ',');
        Notification__c notification = NotificationService.generateNotificationForIdContain(queryIds, '');

        ApexPages.currentPage().getParameters().put('notificationIds', notification.Id);
        ApexPages.currentPage().getParameters().put('sortby', 'address');
        RenewalNotificationwInsClassesController cont = new RenewalNotificationwInsClassesController();

        String req1 = cont.records[0].LicenseType__r.OtherRenewalRequirements1__c;
        System.assert(!req1.containsIgnoreCase('font-size'), 'font-size should be stripped');
        System.assert(req1.contains('<strong>INACTIVE STATUS?</strong>'), 'bold phrase should wrap');
    }
}