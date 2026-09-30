trigger TravelApprovalTrigger on TravelApproval__c (before insert, before update) {
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        for(TravelApproval__c record: trigger.new) {
            record.TotalAllowanceValue__c = record.TotalAllowance__c;
            record.TotalCompletedTravelCostValue__c = record.TotalCompletedTravelCost__c;
        }
    }
    

}