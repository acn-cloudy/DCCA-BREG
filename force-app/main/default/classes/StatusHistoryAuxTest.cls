@isTest
private class StatusHistoryAuxTest {
    public static testMethod void testStatusLog() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        
        SEBCase__c SEBCase = new SEBCase__c(
            Account__c = acct.Id,
            Status__c = 'Intake'
            
        );
        insert SEBCase;
        List<SEBCase__c> caseRecords = new List<SEBCase__c>();
        caseRecords.add(SEBCase);


        SEBCase__c oldRecord = SEBCase.clone();
        oldRecord.Status__c = 'Investigation';
        oldRecord.Id = SEBCase.Id;
        
        Map<Id, SEBCase__c> oldMap = new Map<Id, SEBCase__c>();
        oldMap.put(oldRecord.Id, oldRecord);
        StatusHistoryAux.LogStatus(caseRecords, oldMap, 'Status__c', 'SEBCase__c', 'SEBCase__c');
        SEBCase.Status__c = 'Closed';
        SEBCase.Disposition__c = 'No action';
        update SEBCase;
        List<SEBCase__c> records = new List<SEBCase__c>();
        records.add(SEBCase);
        StatusHistoryAux.LogStatus(records, oldMap, 'Status__c', 'SEBCase__c', 'SEBCase__c');
    }
    
}