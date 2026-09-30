@isTest
private class SEBCasePenaltyBatchTest {
    @TestSetup
    static void makeData(){
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        acc.SEBSEC__c = true;
        insert acc;
        
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        SEBCase__c sebCase = new SEBCase__c(
            Account__c = acc.Id
            
        );
        insert sebCase;
        List<Sanction__c> sanctions= new List<Sanction__c>();
        for(Integer i = 0;i<100; i++) {
            Sanction__c sa = new Sanction__c();
            sa.SEBCaseID__c = sebCase.Id;
            sa.Total_Amount_Due__c = i + 100;
            if(math.mod(i, 2) == 0) {
                sa.Sanction__c = 'Restitution/Rescission';
            } else {
                sa.Sanction__c = 'Penalty';
            }
            
            sa.Total_Sanction_Amount__c = i + 300;
            sanctions.add(sa);
        }
		
        insert sanctions;
    }
    @isTest
    static void testTransactionBatch() {
        Test.startTest();
        Database.executeBatch(new SEBCasePenaltyBatch(), 100);
        Test.stopTest();
    }
    @isTest
    static void testTransactionSchedule() {
        Test.startTest();
        SEBCasePenaltyBatch scheduler = new SEBCasePenaltyBatch();
        String sch = '0 0 23 * * ?';
        System.schedule('testSEBCasePenaltyBatch', sch, scheduler);
        Test.stopTest();
    }

}