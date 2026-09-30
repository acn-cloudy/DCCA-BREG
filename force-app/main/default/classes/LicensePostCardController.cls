public with sharing class LicensePostCardController {
    // public List<License__c> records {set;get;}
    public List<List<License__c>> allRecords {set;get;}
    
    public LicensePostCardController() {
        String notificationIds = System.currentPageReference().getParameters().get('notificationIds');

        generateLicenses(notificationIds);
    }
    public void generateLicenses(String notificationIds) {
        List<String> licenseIds = new List<String>();
        if(notificationIds != null) {
            List<String> notificationIdList = notificationIds.split(',');
            List<Notification__c> notifications = NotificationSelector.getNotifications(notificationIdList);
            for(Notification__c notification: notifications) {
                if(notification.Content__c != null) {
                    licenseIds.addAll(notification.Content__c.split(','));
                }
            }
        }
        
        List<License__c> records = LicenseSelector.getLicenses(licenseIds);
        allRecords = new List<List<License__c>>();
        Integer index = 0;
        List<License__c> units = new List<License__c>();
        for(License__c record: records) {
            units.add(record);
            if(index == 3) {
                index = 0;
                allRecords.add(units);
                units = new List<License__c>();
            } else {
                index ++;
            }
        }
        System.debug(units.size());
        System.debug(allRecords.size());
        if(!units.isEmpty() && units.size() < 4) {
            Integer size = 4 - units.size();
            for(Integer i=0; i<size; i++ ) {
                units.add(new License__c());
            }
            allRecords.add(units);
        }
        System.debug(allRecords.size());
        
        System.debug(allRecords);
    }
}