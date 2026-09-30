public without sharing class ApplicationLicenseValidatorController {
    private static Set<String> activeStatuses 
        = new Set<String> {'C - Current, Valid & In Good Standing', 
        'CM - Current, Valid & In Good Standing/Maint. Requirement Due', 
        'CP - Current Pending', 'CR - Current/Next Renewal Paid', 'R - Valid Thru Expiration Date, Subject To Renewal', 
        'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due', 'Z - Current & Valid, But Subject To Disciplinary Requirement', 
        'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'};

    @AuraEnabled
    public static String validateLicense(String licenseNumber, String licenseType){
        String message = '';
        try {
            LicenseType__c ltRecord = [Select Id, Name from LicenseType__c where LicenseType__c =: licenseType];
            String licenseName = ltRecord.Name + '-' + licenseNumber + '-0';
            List<License__c> licenses = [Select Id, Status__c from License__c where Name =: licenseName ];
            if(licenses.isEmpty()) {
                return message;
            }
            if(activeStatuses.contains(licenses.get(0).Status__c)) {
                message = 'Use the My Licenses tab to access your linked license and print your pocket ID. You may also verify the status of your license at: https://mypvl.dcca.hawaii.gov/public-license-search/';
            } else if(licenses.get(0).Status__c == 'D - Forfeited; Needs to Restore') {
                message = 'Please contact the Professional and Vocational Licensing Branch at (808) 586-3000 to request a hardcopy restoration form.';
            } else {
                message = 'The license entered requires a submittal of a Please submit an application for LICF – New License After Forfeiture application. Use the My Licenses tab to access your linked license Apply button.';
            }
            return message;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
}