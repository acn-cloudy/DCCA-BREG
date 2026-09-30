@isTest
private class RenewalNotificationControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
        
    }
    @isTest private static void testController() {
        List<License__c> records = [Select Id, LicenseType__r.OtherRenewalRequirements2__c, LicenseType__r.OtherRenewalRequirements1__c from License__c];
        LicenseType__c ltype = records.get(0).LicenseType__r;
        ltype.OtherRenewalRequirements1__c = 'test';
        ltype.OtherRenewalRequirements2__c = 'test';
        update ltype;
        List<String> idList = (List<String>)(new LicenseDomain(records)).getFieldValues('Id');
        String queryIds = String.join(idList, ',');
        Notification__c notification = NotificationService.generateNotificationForIdContain(queryIds, '');
        
        ApexPages.currentPage().getParameters().put('notificationIds', notification.Id);
        ApexPages.currentPage().getParameters().put('sortby', 'address');
        RenewalNotificationController cont = new RenewalNotificationController();

    }

    @isTest
    private static void testFormatAndNormalizeHelpers() {
        String input =
            '<p>RENEW ONLINE AT: <span style="font-size: 14px;">https://mypvl.example.com</span></p>' +
            '<font size="4">text</font><h2>Title</h2>INACTIVE STATUS?';

        String formatted = RenewalNotificationController.formatOtherRenewalRequirementsHtml(input);
        System.assert(formatted.contains('<div>'), 'p tags should convert to div');
        System.assert(!formatted.containsIgnoreCase('font-size'), 'font-size should be stripped');
        System.assert(!formatted.containsIgnoreCase('size="4"'), 'font size attr should be stripped');
        System.assert(formatted.contains('<div>Title</div>'), 'heading tags should convert to div');
        System.assert(formatted.contains('<strong>INACTIVE STATUS?</strong>'), 'bold phrase should wrap');

        System.assertEquals(null, RenewalNotificationController.normalizeRenewalRequirementsFontSize(null));
        System.assertEquals(
            '<span style=" color: red;">x</span>',
            RenewalNotificationController.normalizeRenewalRequirementsFontSize(
                '<span style="font-size: 13px; color: red;">x</span>'
            )
        );
    }
}