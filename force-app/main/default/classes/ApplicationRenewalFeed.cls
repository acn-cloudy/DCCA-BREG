public class ApplicationRenewalFeed {
    public Application__c app {set;get;}
    public List<Transaction__c> trans {set;get;}
    public List<pymt__PaymentX__c> payments {set;get;}
    public List<AssociatedLicense__c> associatedLicenses {set;get;}
    public List<AssociatedLicense__c> associatedEmployeeLicenses {set;get;}
    public List<InsuranceBond__c> insuranceBonds {set;get;}
    public List<LicenseClassification__c> licenseClassifications {set;get;}
}