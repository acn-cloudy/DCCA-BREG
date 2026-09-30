/********************************************************************************************************
*    Name:  GroupTransactionControllerTest.cls
*    Author: PacPoint-MC082818 - Created for phase(???) 
*    Date:  8/28/2018
*    
*    Class: GroupTransactionController.cls
********************************************************************************************************/
@isTest
public class GroupTransactionControllerTest {
    
    private static testmethod void testGroupTransaction(){
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
        insert cnt;
        
        date sd = Date.Today();
        
        Transaction__c trans1 = new Transaction__c();
        trans1.Account__c = acc.Id;
        trans1.Contact__c = cnt.Id;
        trans1.Date__c = sd.addDays(-2);
        trans1.Status__c = 'New';
        trans1.Division__c = 'BREG';
        trans1.TransactionType__c = 'Payment';
        insert trans1;
        
        CashierCode__c cc1 = new CashierCode__c();
        cc1.Name = 'Cashier Code 1';
        cc1.Amount__c = 30;
        cc1.CashierCode__c = '000011';
        cc1.Category__c = 'Categ1';
        cc1.Division__c = 'BREG';
        insert cc1;
        
        TransactionLine__c tl1 = new TransactionLine__c();
        tl1.Transaction__c = trans1.Id;
        tl1.Amount__c = 30;
        tl1.CashierCode__c = cc1.Id;
        tl1.Description__c = 'aaa';
        insert tl1;
        
        Transaction__c trans2 = new Transaction__c();
        trans2.Account__c = acc.Id;
        trans2.Contact__c = cnt.Id;
        trans2.Date__c = sd.addDays(-2);
        trans2.Status__c = 'New';
        trans2.Division__c = 'BREG';
        trans2.TransactionType__c = 'Payment';
        insert trans2;
        
        CashierCode__c cc2 = new CashierCode__c();
        cc2.Name = 'Cashier Code 1';
        cc2.Amount__c = 70;
        cc2.CashierCode__c = '000011';
        cc2.Category__c = 'Categ1';
        cc2.Division__c = 'BREG';
        insert cc2;
        
        TransactionLine__c tl2 = new TransactionLine__c();
        tl2.Transaction__c = trans2.Id;
        tl2.CashierCode__c = cc2.Id;
        tl2.Amount__c = 70;
        tl2.Description__c = 'bbb';
        insert tl2;
        
        Test.startTest();
            
            Transaction__c t = GroupTransactionController.initTransaction();
            List<Transaction__c> allTrans = GroupTransactionController.getTransactions();
            List<GroupTransactionController.TransactionWrapper> newList = new List<GroupTransactionController.TransactionWrapper>();
            String sfields = JSON.serialize(allTrans);
            system.debug('====>' + allTrans);
            Id transId = GroupTransactionController.saveTransaction(t, sfields);
            newList.add(new GroupTransactionController.TransactionWrapper());

        Test.stopTest();    
        Transaction__c parentTrans = [SELECT Id, ParentTotalAmount__c FROM Transaction__c WHERE Id =: transId];
        System.assertEquals(100.0, parentTrans.ParentTotalAmount__c);
        List<Transaction__c> UpdatedTrans = [SELECT Id, TransactionGroup__c FROM Transaction__c WHERE TransactionGroup__c != NULL];
        for( Transaction__c tr: UpdatedTrans )
            System.assertEquals(tr.TransactionGroup__c, transId);
    }
}