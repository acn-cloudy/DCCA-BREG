public with sharing class BREGTxnBusInfoTriggerHandler extends BREGBaseTriggerHandler {
    public override void beforeInsert() {
        for (breg_Transaction_Business_Info__c record : (List<breg_Transaction_Business_Info__c>) this.newList) {
            record.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(record.breg_Master_Name__c);
            record.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(record.breg_Xref_Name_1__c);
            record.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(record.breg_Xref_Name_2__c);
        }
    }

    public override void beforeUpdate() {
        for (breg_Transaction_Business_Info__c record : (List<breg_Transaction_Business_Info__c>) this.newList) {
            breg_Transaction_Business_Info__c oldRecord = (breg_Transaction_Business_Info__c) this.oldMap.get(record.Id);
            if (oldRecord == null) {
                continue;
            }

            if (record.breg_Master_Name__c != oldRecord.breg_Master_Name__c) {
                record.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(record.breg_Master_Name__c);
            }

            if (record.breg_Xref_Name_1__c != oldRecord.breg_Xref_Name_1__c) {
                record.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(record.breg_Xref_Name_1__c);
            }

            if (record.breg_Xref_Name_2__c != oldRecord.breg_Xref_Name_2__c) {
                record.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(record.breg_Xref_Name_2__c);
            }
        }
    }
}