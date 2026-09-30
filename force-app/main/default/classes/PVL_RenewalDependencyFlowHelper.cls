public with sharing class PVL_RenewalDependencyFlowHelper {
    @InvocableMethod(
        label='Get Related Multidependency Application' 
        description='Returns a list of applications declared as 2nd Dependency Required for this application' 
        category='License'
    )
    public static List<Result> getRelatedMultidependentApplications(List<License__c> licenses){
        Map<Id, Result> applicationsToReturn = new Map<Id, Result>();
        Set<Application__c> uniqueApplicationsToReturn = new Set<Application__c>();
        Set<Id> licenseTypeIds = new Set<Id>();
        for(License__c thisLicense : licenses){
            applicationsToReturn.put(thisLicense.Id, new Result(thisLicense));
            licenseTypeIds.add(thisLicense.LicenseType__c);
        }
        Map<Id, LicenseType__c> licenseTypes = new Map<Id, LicenseType__c>([SELECT Id, DependentLicenseType__c, X2ndDependentLicenseType__c FROM LicenseType__c WHERE X2ndDependencyRequired__c = true AND (DependentLicenseType__c IN :licenseTypeIds OR X2ndDependentLicenseType__c IN :licenseTypeIds)]);
        if(licenseTypes.isEmpty()){
            return applicationsToReturn.values();
        }
        for(License__c dependentLicenses : [SELECT (SELECT Id, CurrentLicense__c, RNEWRSTRDate__c, ActiveInactive__c, RenewingPermittoPractice__c, Type__c, ApplicationReceivedDate__c, Status__c, LicenseType__c, Phase__c FROM Applications1__r WHERE Status__c = 'D1 - Awaiting Dependency Review'), (SELECT EmployeeLicense__c FROM AssociatedEmployee__r WHERE EmployeeLicense__c IN :applicationsToReturn.keySet()) FROM License__c WHERE LicenseType__c IN :licenseTypes.keySet() AND Id IN (SELECT EntityLicense__c FROM AssociatedLicense__c WHERE EmployeeLicense__c IN :applicationsToReturn.keySet())]){
            for(AssociatedLicense__c associatedLicense : dependentLicenses.AssociatedEmployee__r){
                applicationsToReturn.get(associatedLicense.EmployeeLicense__c)?.dependentApplications.addAll(dependentLicenses.Applications1__r);
            }
        }
        return applicationsToReturn.values();
    }

    public class Result{
        @InvocableVariable (label='License' description='The license that associated to this result')
        public License__c ivokingLicense;

        @InvocableVariable (label='Dependent Applications' description='The dependent applications related to this license')
        public List<Application__c> dependentApplications;

        public Result(){
            
        }
        public Result(License__c license){
            this.ivokingLicense = license;
            this.dependentApplications = new List<Application__c>();
        }
    }
}