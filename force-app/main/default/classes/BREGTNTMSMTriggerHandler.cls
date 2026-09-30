public with sharing class BREGTNTMSMTriggerHandler extends BREGBaseTriggerHandler {
    public static final Set<String> closedStatuses = new Set<String> {'C', 'E', 'R'}; //Cancelled, Expired, Revoked
    public override void beforeInsert() {
        for (breg_TN_TM_SM__c record : (List<breg_TN_TM_SM__c>) this.newList) {
            record.breg_Search_Name__c = BREGUtils.cleanBusinessName(record.Name);
            record.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(record.Name);
            record.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(record.breg_XREF_Name1__c);
            record.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(record.breg_XREF_Name2__c);
        }
    }

    public override void beforeUpdate() {
        for (breg_TN_TM_SM__c record : (List<breg_TN_TM_SM__c>) this.newList) {
            breg_TN_TM_SM__c oldRecord = (breg_TN_TM_SM__c) this.oldMap.get(record.Id);
            if (oldRecord == null) {
                continue;
            }

            if (record.Name != oldRecord.Name) {
                record.breg_Search_Name__c = BREGUtils.cleanBusinessName(record.Name);
                record.breg_Search_Name_NS__c = BREGUtils.cleanBusinessName(record.Name);
            }

            if (record.breg_XREF_Name1__c != oldRecord.breg_XREF_Name1__c) {
                record.breg_Search_Xref_Name_1_NS__c = BREGUtils.cleanBusinessName(record.breg_XREF_Name1__c);
            }

            if (record.breg_XREF_Name2__c != oldRecord.breg_XREF_Name2__c) {
                record.breg_Search_Xref_Name_2_NS__c = BREGUtils.cleanBusinessName(record.breg_XREF_Name2__c);
            }
        }
    }

    public override void afterUpdate() {
       updateRelatedAccountsAfterClosing((List<breg_TN_TM_SM__c>) this.newList, (Map<Id,breg_TN_TM_SM__c>) this.oldMap); 
       
    }

    public static void updateRelatedAccountsAfterClosing(List<breg_TN_TM_SM__c> newList, Map<Id, breg_TN_TM_SM__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        Map<Id, breg_TN_TM_SM__c> accountIdToTntmsmRecord = new Map<Id, breg_TN_TM_SM__c>();
        for (breg_TN_TM_SM__c record : newList) {
            breg_TN_TM_SM__c oldRecord = oldMap.get(record.Id);
            if (
                oldRecord != null &&
                oldRecord.breg_Status__c != record.breg_Status__c &&
                closedStatuses.contains(record.breg_Status__c) &&
                record.breg_Account__c != null
            ) {
                accountIdToTntmsmRecord.put(record.breg_Account__c, record);
            }
        }

        if (accountIdToTntmsmRecord.isEmpty()) {
            return;
        }

        List<Account> tntmsmAccountsToUpdate = new List<Account>();
        for (Account accountRecord : [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIdToTntmsmRecord.keySet() AND breg_Entity_Type__c = 'ZZ'
        ]) {
            breg_TN_TM_SM__c relatedTntmsmRecord = accountIdToTntmsmRecord.get(accountRecord.Id);
            String entityStatus;
            switch on relatedTntmsmRecord.breg_Status__c {
                when 'E' {
                    entityStatus = 'Expired (E)';
                }
                when 'C' {
                    entityStatus = 'Cancelled (C)';
                }
                when 'R' {
                    entityStatus = 'Inv. Revoked (R)';
                }
                when else {
                    entityStatus = 'Inactive';
                }
            }

            tntmsmAccountsToUpdate.add(new Account(Id = accountRecord.Id, breg_Entity_Status__c = entityStatus));
        }

        if (!tntmsmAccountsToUpdate.isEmpty()) {
            update tntmsmAccountsToUpdate;
        }
    }
}