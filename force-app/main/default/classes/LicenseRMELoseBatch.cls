/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* checkLicenseStatus : Find and set the EntityLosesRMENotification__c or RMELosesEntityNotification__c of 
* Licenses with GenerateEntityLosesRMENotification__c or GenerateRMELosesEntity__c 
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @created      PacPoint-AZ032320 - Created for PVL Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* 
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class LicenseRMELoseBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    String query = 'Select Id, GenerateEntityLosesRMENotification__c, GenerateFile__c, FileEngines__c, GenerateRMELosesEntityNotification__c, LicenseType__r.EntityLosesRMENotification__r.Name,'
        +' LicenseType__r.RMELosesEntityNotification__r.Name  from License__c where (GenerateEntityLosesRMENotification__c = true  and LicenseType__r.EntityLosesRMENotification__c != null) '
        +' or (GenerateRMELosesEntityNotification__c = true and LicenseType__r.RMELosesEntityNotification__c != null)';
    
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>) scope;
        for(License__c record: licenses) {
            List<String> fileEngines = new List<String>();
            if(record.GenerateEntityLosesRMENotification__c && record.LicenseType__r.EntityLosesRMENotification__r.Name != null) {
                record.GenerateEntityLosesRMENotification__c = false;
                record.GenerateFile__c = true;
                fileEngines.add(record.LicenseType__r.EntityLosesRMENotification__r.Name);
            }
            if(record.GenerateRMELosesEntityNotification__c && record.LicenseType__r.RMELosesEntityNotification__r.Name != null ) {
                record.GenerateRMELosesEntityNotification__c = false;
                record.GenerateFile__c = true;
                fileEngines.add(record.LicenseType__r.RMELosesEntityNotification__r.Name);
            }

            if(!fileEngines.isEmpty()) {
                record.FileEngines__c = String.join(fileEngines, ',');
            }
        }
        update licenses;
    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new LicenseRMELoseBatch(), 100);
    }
    global void finish(Database.BatchableContext context) {
        
    }
}