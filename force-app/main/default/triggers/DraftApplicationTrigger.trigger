trigger DraftApplicationTrigger on Application_Cache__c (after update, after insert, before update, before insert) {

    List<Application_Cache__c> records = Trigger.new;
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        List<Application_Cache__c> recordsForUpdate = new List<Application_Cache__c>();
        for(Application_Cache__c record: records) {
            if(record.Name != record.Draft_App_No__c) {
                Application_Cache__c newRecord = new Application_Cache__c();
                newRecord.Id = record.Id;
                newRecord.Name = record.Draft_App_No__c;
                recordsForUpdate.add(newRecord);
            }
        }
        if(!recordsForUpdate.isEmpty()) {
            update recordsForUpdate;
        }
    }
    if(Trigger.isBefore && (Trigger.isUpdate || Trigger.isInsert)) {
        for(Application_Cache__c record: records) {
            if(!String.isBlank(record.FormData__c)) {
                Map<String, Object> formData = (Map<String, Object>)JSON.deserializeUntyped(record.FormData__c);
                if(formData.containsKey('user_id')) {
                    record.PVLPortalUser__c = String.valueOf(formData.get('user_id'));
                    
                }
                if(formData.containsKey('board_program')) {
                    record.BoardProgram__c = String.valueOf(formData.get('board_program'));
                    
                }
                if(formData.containsKey('license_type')) {
                    record.LicenseType__c = String.valueOf(formData.get('license_type'));
                    
                }
            }
        }
    }
}