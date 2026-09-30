global class AMDRenewalPushThru extends ApplicationRenewalPushThru {
    global Set<String> processedLicenseIds = new Set<String>();

    global AMDRenewalPushThru() {
        super(new List<String> {'AMD'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getAMDEntityAssociatedLicenses(licenseIds);
        List<String> employeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        Set<String> employeeLicenseIdsSet = new Set<String>(employeeLicenseIds);
        List<Application__c> recordsWithEntityLicenses = (new ApplicationDomain(records)).filterApplicationByLicenseIds(employeeLicenseIdsSet);
        this.appMap = new Map<Id, Application__c> (recordsWithEntityLicenses);
        Set<String> appIds = new Set<String>();
        for(Id rId: appMap.KeySet()) {
            appIds.add(rId);
        }

        List<Application__c> recordsWithoutEntityLicenses = (new ApplicationDomain(records)).filterRecordsByIds(appIds);
        for(Application__c app: recordsWithoutEntityLicenses) {
            app.CurrentLIcense__r.DependentLicense__c = null;
            app.CurrentLIcense__r.ExcludeFromInactivationProcess__c = true;
            app.CurrentLIcense__r.ActiveInactive__c = 'Inactive';
            app.CurrentLIcense__r.InactivationDate__c = app.CurrentLIcense__r.LicenseType__r.LicenseTypeEffectiveDate__c;
            this.appMap.put(app.Id, app);
        }
        if(!recordsWithoutEntityLicenses.isEmpty()) {
            // check if need to create the application 
            List<String> renewLicenseIds = (List<String>) (new ApplicationDomain(recordsWithoutEntityLicenses)).getFieldValues('CurrentLicense__c');
            List<LicenseHistory__c> histories 
                    = LicenseHistorySelector.getHistories(new List<String>{'RNEW - RENEWED', 'RSTR - Restoration'}, renewLicenseIds);
                
            // Create INAC history
            List<LicenseHistory__c> newINACHistories = new List<LicenseHistory__c>(); 
            for(Application__c record: recordsWithoutEntityLicenses) {
                LicenseHistory__c history = new LicenseHistory__c();
                history.TransactionType__c = 'I - INACTIVE';
                history.EffectiveDate__c = record.CurrentLicense__r.LicenseType__r.LicenseTypeEffectiveDate__c;
                history.License__c = record.CurrentLicense__c;
                history.LicensePeriod__c = record.LicensePeriodRNEW__c;
                history.Remarks__c = 'Inactive due to no associated MD/DOS';
                newINACHistories.add(history);
            }
            if(!newINACHistories.isEmpty()) insert newINACHistories;
            
            List<License__c> currentLicenses 
                = (new ApplicationDomain(recordsWithoutEntityLicenses)).getRenewLicenses();
            List<Notification__c> notifications 
                = (new LicenseDomain(currentLicenses)).generateAMDInactivationNotifications(true);

            if(!notifications.isEmpty()) insert notifications;
            
        }
    }

    global override void finish(Database.BatchableContext context) {
        //00033729
        Database.executeBatch(new AMDInactivationBatch(), 10);
    }
}