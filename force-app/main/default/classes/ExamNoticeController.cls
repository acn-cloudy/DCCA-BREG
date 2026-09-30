public class ExamNoticeController {
    public List<ApplicationRequirement__c> getApplicationRequirements () {
        return [ Select Id, RequirementLongDescription__c, 
            Remarks__c, RemarksTag__c, (Select Id, RequirementLongDescription__c, ParentApplicationRequirement__c, RemarksTag__c from ApplicationRequirements__r
            where IsDeficient__c = true) 
            from ApplicationRequirement__c where IsDeficient__c = true and ParentApplicationRequirement__c = null and Application__c =: recordId
            order by REQMT__c, SUB__c];
    }

    public List<ApplicationClassifications__c> getApplicationClassifications() {
        return [Select Id, Name, ClassificationName__c from ApplicationClassifications__c 
            where Application__c =: recordId and Status__c = 'W - Awaiting Approval/Exam'];

    }
    public String recordId {get; set;}
}