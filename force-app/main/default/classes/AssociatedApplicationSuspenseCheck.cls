/* UPDATES *
*
* PacPoint EA02072024: 00033888 
*
*/

public class AssociatedApplicationSuspenseCheck {
    @InvocableMethod(
        label='Associated Licenses Suspense Udpate'
        description='Renew application with Associated Licenses and Suspenses'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<Id> licenseIds = new List<Id>();
        //00033888
        List<Results> results = new List<Results>();
        for(Input i: inputs) {
            licenseIds.add(i.license.Id);

            //00033888
            Results res = new Results();
            res.operationOutcome = i.license.Id;
            results.add(res);
        }
        List<AssociatedLicense__c> associatedLicenses 
            = AssociatedLicenseSelector.getEmployedAssociatedLicensesForCheck(licenseIds);
        
        
        List<String> employeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Suspense__c> suspenses = SuspenseSelector.getSuspenseByLicenseIds(employeeLicenseIds);
        Map<String, List<Suspense__c>> suspenseMap = (new SuspenseDomain(suspenses)).getLicenseId2Suspenses();
        System.debug('###suspenseMap####'+suspenseMap);
        List<License__c> employeeLicenses = LicenseSelector.getLicenses(employeeLicenseIds);
        List<Suspense__c> suspensesForUpdate = new List<Suspense__c>();
        List<License__c> licenseRecords = new List<License__c>();
        for(License__c record: employeeLicenses) {
            List<Suspense__c> suspenseUnits = suspenseMap.get(record.Id);
            if(suspenseUnits != null && suspenseUnits.size() == 1) {
                Suspense__c suspense = suspenseUnits.get(0);
                if(suspense.MaintenanceType__c == 'NFRM - RME WITHOUT EMPLOYMENT' 
                    && suspense.SuspenseStatus__c == record.LicenseType__r.AutoForfeitureStatus__c) {
                    suspense.Historical__c = true;
                    suspensesForUpdate.add(suspense);
                    if(record.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due' ) {
                        record.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
                    } else if(record.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due') {
                        record.Status__c = 'C - Current, Valid & In Good Standing';
                    }
                    licenseRecords.add(record);
                }
            }
        }
        update licenseRecords;
        update suspensesForUpdate;
        
        //00033888
        return results;
    }
    public class Input {
        @InvocableVariable(label='License Record for Input' description='Input License' required=true)
        public License__c license;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output' required=true)
        public String operationOutcome;
    }
}