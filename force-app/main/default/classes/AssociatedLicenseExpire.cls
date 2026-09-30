public class AssociatedLicenseExpire implements Database.Batchable<SObject>, Database.Stateful {
    private Map<Id, Date> associateLicense2ExpireDate = new Map<Id, Date>();
    private Set<Id> associateLicenseIds = new Set<Id>();
    private String query = ' Select Id, EmploymentStatus__c, EndDate__c from AssociatedLicense__c ';
    public AssociatedLicenseExpire(Map<Id, Date> associateLicense2ExpireDate) {
        this.associateLicense2ExpireDate = associateLicense2ExpireDate;
        this.associateLicenseIds = this.associateLicense2ExpireDate.keySet();
        query += ' Where Id in: associateLicenseIds';
    }
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        List<AssociatedLicense__c> records = (List<AssociatedLicense__c>) scope;
        for (AssociatedLicense__c associateLicense : records) {
            associateLicense.EmploymentStatus__c = 'Terminated';
            associateLicense.EndDate__c = associateLicense2ExpireDate.get(associateLicense.Id);
        }
        update records;
    }
    public void finish(Database.BatchableContext context) {}
}