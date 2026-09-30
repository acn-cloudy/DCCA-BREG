public with sharing class BREGTransactionTriggerHandler extends BREGBaseTriggerHandler {
    public override void beforeInsert() {
        for (breg_Transaction__c record : (List<breg_Transaction__c>) this.newList) {
            if (String.isNotBlank(record.breg_Business_Name__c) && record.breg_Business_Name__c.length() > 255) {
                record.breg_Search_Name__c = BREGUtils.cleanBusinessName(record.breg_Business_Name__c).substring(0, 255);
            } else {
                record.breg_Search_Name__c = BREGUtils.cleanBusinessName(record.breg_Business_Name__c);
            }
        }
    }

    public override void beforeUpdate() {
        for (breg_Transaction__c record : (List<breg_Transaction__c>) this.newList) {
            breg_Transaction__c oldRecord = (breg_Transaction__c) this.oldMap.get(record.Id);
            if (oldRecord == null) {
                continue;
            }

            if (record.breg_Business_Name__c != oldRecord.breg_Business_Name__c) {
                if (String.isNotBlank(record.breg_Business_Name__c) && record.breg_Business_Name__c.length() > 255) {
                    record.breg_Search_Name__c = BREGUtils.cleanBusinessName(record.breg_Business_Name__c).substring(0, 255);
                } else {
                    record.breg_Search_Name__c = BREGUtils.cleanBusinessName(record.breg_Business_Name__c);
                }
            }
        }
    }
}