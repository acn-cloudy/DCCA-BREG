/********************************************************************************************************
*    Name:  PaymentAll.trigger
*    Date:  10/1/2018
*    
*    Handler class: PaymentAllHandler.cls
*    Test class: PaymentAllHandlerTest.cls
********************************************************************************************************/

trigger PaymentAll on pymt__PaymentX__c (before insert, before update, after insert, after update, before delete, after delete) {
   OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();

   if(orgSetting.DisableTriggers__c || UserInfo.getProfileId() == GlobalUtilities.getIntegrationProfileId()) {
      return;
   }

    if (PaymentDeduplicator.disableTrigger) {
        return;
    }

    PaymentAllHandler handler = new PaymentAllHandler();
    
    if (Trigger.isInsert) {
        if (Trigger.isBefore)
            handler.onBeforeInsert(Trigger.New, Trigger.NewMap ) ;
            
        if (Trigger.isAfter) 
            handler.onAfterInsert(Trigger.New, Trigger.NewMap);
    }
    
    if (Trigger.isUpdate) {
        if (Trigger.isBefore)
            handler.onBeforeUpdate(Trigger.New, Trigger.NewMap, Trigger.oldMap);
        
        if (Trigger.isAfter)
            handler.onAfterUpdate(Trigger.New, Trigger.NewMap , Trigger.oldMap);
    }

    /*if (Trigger.isDelete) {
        if (Trigger.isBefore)
            handler.onBeforeDelete(Trigger.Old, Trigger.oldMap);
        
        if (Trigger.isAfter)
            handler.onAfterDelete(Trigger.Old, Trigger.oldMap );
    }*/

}