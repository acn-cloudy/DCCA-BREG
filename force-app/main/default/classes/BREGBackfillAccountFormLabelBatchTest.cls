@isTest
private class BREGBackfillAccountFormLabelBatchTest {
    @isTest
    static void executeBatchPopulatesMissingFormLabels() {
        Id accountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        Account needsBackfill = new Account(
            Name = 'Account Label Backfill Needed',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Status__c = 'Active (A)',
            breg_Formation_Country__c = 'US',
            breg_Formation_State__c = 'CO',
            breg_Formation_Country_Label__c = null,
            breg_Formation_State_Label__c = null
        );

        Account alreadyPopulated = new Account(
            Name = 'Account Label Already Populated',
            RecordTypeId = accountRecordTypeId,
            breg_Entity_Status__c = 'Active (A)',
            breg_Formation_Country__c = 'US',
            breg_Formation_State__c = 'HI',
            breg_Formation_Country_Label__c = 'United States',
            breg_Formation_State_Label__c = 'Hawaii'
        );

        BREGBaseTriggerHandler.disableTrigger(BREGAccountTriggerHandler.class);
        try {
            insert new List<Account>{ needsBackfill, alreadyPopulated };
        } finally {
            BREGBaseTriggerHandler.enableTrigger(BREGAccountTriggerHandler.class);
        }

        Test.startTest();
        Database.executeBatch(new BREGBackfillAccountFormLabelBatch(), 200);
        Test.stopTest();

        Map<String, Account> accountsByName = new Map<String, Account>();
        List<Account> accounts = [
            SELECT Name, breg_Formation_Country__c, breg_Formation_Country_Label__c, breg_Formation_State__c, breg_Formation_State_Label__c
            FROM Account
            WHERE Name IN ('Account Label Backfill Needed', 'Account Label Already Populated')
        ];

        for (Account acc : accounts) {
            accountsByName.put(acc.Name, acc);
        }

        Account updatedNeedsBackfill = accountsByName.get('Account Label Backfill Needed');
        Account unchangedAlreadyPopulated = accountsByName.get('Account Label Already Populated');

        System.assertEquals(
            'United States',
            updatedNeedsBackfill.breg_Formation_Country_Label__c,
            'Formation country label should be populated from picklist label map or fallback value'
        );
        System.assertEquals(
            'Colorado',
            updatedNeedsBackfill.breg_Formation_State_Label__c,
            'Formation state label should be populated from picklist label map or fallback value'
        );

        System.assertEquals(
            'United States',
            unchangedAlreadyPopulated.breg_Formation_Country_Label__c,
            'Formation country label should be populated from picklist label map or fallback value'
        );
        System.assertEquals(
            'Hawaii',
            unchangedAlreadyPopulated.breg_Formation_State_Label__c,
            'Formation state label should be populated from picklist label map or fallback value'
        );
    }
}