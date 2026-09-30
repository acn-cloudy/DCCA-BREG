public class FixRequirementBatch implements Database.Batchable<SObject>, Database.Stateful{
    private String query = 'Select Id from Application__c where Name in: appNames';
    public List<String> appNames = new List<String>();
    public FixRequirementBatch(List<String> appNames) {
        this.appNames = appNames;
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Application__c> records = (List<Application__c>) scope;
        List<String> appIds = (new ApplicationDomain(records)).getIds();
        List<ApplicationRequirement__c> requirements = [Select Id, Requirement__c, Application__c from ApplicationRequirement__c where Application__c in: appIds and CreatedBy.name like '%Guest%' ];
        ApplicationRequirementService.createChildrenApplicationRequirements(requirements);
        
    }

    public void finish(Database.BatchableContext bc) {}
   
}