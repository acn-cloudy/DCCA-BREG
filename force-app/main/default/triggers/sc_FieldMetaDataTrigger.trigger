trigger sc_FieldMetaDataTrigger on Field_Meta_Data__c (before insert, before update) {
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        List<Field_Meta_Data__c> records = Trigger.new;
        Map<Id, Field_Meta_Data__c> oldRecords = Trigger.oldMap;
        for(Field_Meta_Data__c record: records) {
            if(oldRecords != null && oldRecords.containsKey(record.Id)) {
                Field_Meta_Data__c oldRecord = oldRecords.get(record.Id);
                if(record.Use_Picklist_Values_From_SF__c != oldRecord.Use_Picklist_Values_From_SF__c 
                    && record.Use_Picklist_Values_From_SF__c && !String.isBlank(record.Object__c) 
                    && !String.isBlank(record.ObjectField__c) ) {
                        record.PicklistValues__c 
                            = FieldUtils.getPicklistValues(record.Object__c, record.ObjectField__c);
                }

            }
        }
    }

}