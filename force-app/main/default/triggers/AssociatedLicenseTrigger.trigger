trigger AssociatedLicenseTrigger on AssociatedLicense__c (before insert, before update, after insert, after update, after delete) {
    
     OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
    
   if(orgSetting.DisableTriggers__c || orgSetting.DisableLicenseTriggers__c ) {
      return;
   }
    TriggerFactory.createAndExecuteHandler(AssociatedLicense__c.SObjectType);

}