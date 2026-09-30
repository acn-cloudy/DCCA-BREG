@isTest
public with sharing class LicensePostCardControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createLicense();
        
    }
    public static testMethod void testGenerateLicenses() {
        
        List<License__c> records = [Select Id from License__c];
        List<String> idList = (List<String>)(new LicenseDomain(records)).getFieldValues('Id');
        String queryIds = String.join(idList, ',');
        Notification__c notification = NotificationService.generateNotificationForIdContain(queryIds, '');
        
        ApexPages.currentPage().getParameters().put('notificationIds', notification.Id);
        LicensePostCardController cont = new LicensePostCardController();

    }
}