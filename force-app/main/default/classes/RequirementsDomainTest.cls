@isTest
private class RequirementsDomainTest {
    @TestSetup
    static void setup() {
        Application__c app = new Application__c();
        insert app;

        ApplicationRequirement__c requirement = new ApplicationRequirement__c();
        requirement.Application__c = app.Id;
        requirement.IsDeficient__c = true;
        insert requirement;
        Requirements__c req = new Requirements__c();
        req.ALIASRequirementNumber__c = 24234234;
        req.Verified__c = true;
        insert req;
    }
    public static testMethod void testGetChildrenApplicationRequirements () {
        List<Requirements__c> reqs = [Select Id, RequirementLongDescription__c, 
            RequirementShortDescription__c from Requirements__c];
        ApplicationRequirement__c appReq = [Select Id, Application__c from ApplicationRequirement__c limit 1];
       (new RequirementsDomain(reqs)).getChildrenApplicationRequirements(appReq);

        Requirements__c req1 = new Requirements__c();
        req1.ALIASRequirementNumber__c = 24234234;
        req1.Verified__c = true;
        req1.ParentRequirement__c = reqs.get(0).Id;
        insert req1;
        reqs = [Select Id, RequirementLongDescription__c, ParentRequirement__c,
            RequirementShortDescription__c from Requirements__c];
        (new RequirementsDomain(reqs)).getChildren();
    }
}