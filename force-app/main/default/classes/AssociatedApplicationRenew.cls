public class AssociatedApplicationRenew {
    @InvocableMethod(
        label='Associated Licenses Renewal'
        description='Renew application with Associated Licenses'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<String> licenseIds = new List<String>();
        Set<String> licenseTypeNames = new Set<String>();
        for(Input i: inputs) {
            licenseIds.add(i.license.Id);
            licenseTypeNames.addAll(i.associatedLicenseType.split(','));
        }
        List<AssociatedLicense__c> associatedLicenses 
            = AssociatedLicenseSelector.getActiveAssociatedLicenses(licenseIds, licenseTypeNames);
        
        List<String> employeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> records = ApplicationSelector.getRenewalApplicationsByLicenseIds(employeeLicenseIds);
        ApplicationService.renewApplicationLicenses(records);
        return new List<Results>();
    }
    public class Input {
        @InvocableVariable(label='License Record for Input' description='Input License' required=true)
        public License__c license;
        @InvocableVariable(label='License Type Names' description='License Type' required=true)
        public String associatedLicenseType;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output' required=true)
        public String operationOutcome;
    }
}