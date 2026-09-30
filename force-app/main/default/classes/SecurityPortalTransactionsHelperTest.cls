@isTest
private class SecurityPortalTransactionsHelperTest {
    @TestSetup
    static void makeData(){
        Account acc = new Account();
        acc.Name = 'Test 02282023';
        acc.SEBSEC__c = true;
        insert acc;

        Contact contct = new Contact();
        contct.FirstName = 'Test 02282023';
        contct.LastName = 'Test 02282023';
        contct.AccountId = acc.Id;
        insert contct;

        for(Integer x=0; x<3; x++){
            Filing__c filingApp = new Filing__c();
            filingApp.Name = 'Test Filing ' + x;
            filingApp.Account__c = acc.Id;
            insert filingApp;

            Transaction__c transactApp = new Transaction__c();
            transactApp.Description__c = 'Test Transaction ' + x;
            transactApp.Account__c = acc.Id;
            transactApp.Filing__c = filingApp.Id;
            transactApp.TotalAmount__c = 100;
            insert transactApp;
        }

        pymt__Settings__c ps = new pymt__Settings__c();
        ps.Name = 'Test Payment Connect Settings';
        insert ps;

        pymt__Processor_Connection__c pc = new pymt__Processor_Connection__c();
        pc.Name = 'Credit Card (Authorize.Net)';
        pc.pymt__PaymentConnect_Setup__c = ps.Id;
        insert pc;
    }

    @isTest
    private static void testUserAccount() {
        Test.startTest();
        User usr =  [Select Id, Name FROM User WHERE Profile.Name = 'DCCA BREG - CustomerCommunityLogin' limit 1];
        Id accId = SecurityPortalTransactionsHelper.getUserAccountId(usr.Id);
        Test.stopTest();
    }

    @isTest
    private static void testAccountFilings() {
        Test.startTest();
        User usr =  [Select Id, Name FROM User WHERE Profile.Name = 'DCCA BREG - CustomerCommunityLogin' limit 1];
        Id accId = SecurityPortalTransactionsHelper.getUserAccountId(usr.Id);
        List <Transaction__c> trans = [
            SELECT Id 
            FROM Transaction__c 
            WHERE (Filing__r.Account__c =: accId OR Filing__r.CreatedById =: usr.Id)
            AND Status__c != 'Completed'
            AND Filing__r.Status__c != 'Filing Withdrawn'
            AND TransactionGroup__r.Status__c != 'Completed'
            AND TransactionType__c != 'Group'
            AND AmountOutstanding__c > 0
        ];

        List<Transaction__c> accTransactions = SecurityPortalTransactionsHelper.getUserTransactions(usr.Id, accId, 'Name', 'ASC');
        Test.stopTest();

        System.assertEquals(trans.size(), accTransactions.size(), 'The same amount of outputs should have been returned as the amount of inputs');
    }

    @isTest
    private static void testGroupPayments() {
        Test.startTest();
        Account acc =  [Select Id, Name from Account WHERE Name = 'Test 02282023' limit 1];
        List <Transaction__c> trans = [Select Id, TotalAmount__c from Transaction__c WHERE Account__c =: acc.Id];

        List<Id> transactIds = new List<Id>();
        Decimal totalAmount = 0.00;
        for(Transaction__c tran: trans){
            transactIds.add(tran.Id);
            totalAmount += tran.TotalAmount__c;
        }

        sObject groupTrans = SecurityPortalTransactionsHelper.groupTransactions(transactIds, acc.Id, totalAmount);
        Test.stopTest();
    }
}