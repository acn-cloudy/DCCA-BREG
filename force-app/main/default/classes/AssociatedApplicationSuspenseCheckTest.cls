@isTest
private class AssociatedApplicationSuspenseCheckTest {
    @TestSetup
    static void makeData(){
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'AMD', 'MD'});
        for(LicenseType__c lt: licenseTypes) {
            lt.AutoForfeitureStatus__c = 'C - Current, Valid & In Good Standing';
        }
        update licenseTypes;
        List<License__c> licenses = new List<License__c>();
        Set<String> entityTypes = new Set<String>{'MD'};
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1';
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            lic.LicenseType__r = licenseType;
            if(entityTypes.contains(licenseType.Name) ) {
                lic.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
            } else {
                lic.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
            }
            lic.ThisLicenseRenewed__c = true;
            if(!entityTypes.contains(licenseType.Name)) {
                License__c clonedRecord = lic.clone();
                licenses.add(clonedRecord);
            }
            licenses.add(lic);
        }
        
        insert licenses;
        for(License__c record: licenses) {
            if(entityTypes.contains(record.LicenseType__r.Name) ) {
                record.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
            } else {
                record.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
            }
        }
        update licenses;
        String recordId;
        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();
        List<License__c> entityLicenses = [Select Id from License__c where LicenseType__r.Name in: entityTypes];
        for(License__c license: licenses) {
            if(license.LicenseType__r.Name =='AMD') {
                for(License__c entityLicense: entityLicenses) {
                    AssociatedLicense__c al = new AssociatedLicense__c();
                    al.EmployeeLicense__c = license.Id;
                    al.EntityLicense__c = entityLicense.Id;
                    al.EmploymentStatus__c = 'Employed';
                    assLicenses.add(al);
                    recordId = license.Id;
                }
                break;
            }
        }
        if(assLicenses.size() > 0){
            insert assLicenses;
        }
        Suspense__c suspense = new Suspense__c();
        suspense.License__c = recordId;
        suspense.InsuranceType__c = 'BD - Bond';
        suspense.SuspenseDueDate__c = System.today() + 10;
        suspense.Historical__c = false;
        suspense.SuspenseStatus__c = 'C - Current, Valid & In Good Standing';
        suspense.MaintenanceType__c = 'NFRM - RME WITHOUT EMPLOYMENT' ;
        insert suspense;
    }

    @isTest
    static void testExecute() {
        Set<String> entityTypes = new Set<String>{'MD'};
        List<AssociatedApplicationSuspenseCheck.Input> inputs = new List<AssociatedApplicationSuspenseCheck.Input>();
        License__c license = [Select Id from License__c where LicenseType__r.Name in: entityTypes limit 1];
        
        AssociatedApplicationSuspenseCheck.Input i = new AssociatedApplicationSuspenseCheck.Input();
        i.license = license;
        inputs.add(i);
        
        Test.startTest();
        AssociatedApplicationSuspenseCheck.execute(inputs);
        Test.stopTest();
    }

}