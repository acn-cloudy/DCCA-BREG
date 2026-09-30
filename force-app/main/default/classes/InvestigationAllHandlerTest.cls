/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for the InvestigationAll trigger and the InvestigationAllHandler class
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC010919 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-09
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
public class InvestigationAllHandlerTest{
    
    private static testmethod void testHandler1(){
        
       
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        
        SEBCase__c SEBCase = new SEBCase__c(
            Account__c = acct.Id
            
        );
        insert SEBCase;
        
        Investigation__c Investigation1 = new Investigation__c(
            SEBCase__c = SEBCase.Id,
            Name = 'Test Investigation'
        );
        insert Investigation1;
        
        Investigation__c Investigation2 = new Investigation__c(
            SEBCase__c = SEBCase.Id,
            Name = 'Test Investigation'
        );
        insert Investigation2;
        
        TimeandExpenseHeader__c Header1 = new TimeandExpenseHeader__c(
            Investigation__c = Investigation1.Id,
            Name = 'Test Assignment'
          //  AssignedTo__c = UserInfo.getUserId()
        );
        insert Header1;
        
            
        List<TimeandExpenseDetails__c> TimeExpenseList = new List<TimeandExpenseDetails__c>();    
        
        TimeandExpenseDetails__c TimeandExpense11 = new TimeandExpenseDetails__c(
            TimeandExpenseHeader__c = Header1.Id,
            ExpenseAmount__c = 20,
            Hours__c = 2
        );
        TimeExpenseList.add(TimeandExpense11);
        
        TimeandExpenseDetails__c TimeandExpense12 = new TimeandExpenseDetails__c(
            TimeandExpenseHeader__c = Header1.Id,
            ExpenseAmount__c = 30,
            Hours__c = 3
        );
        TimeExpenseList.add(TimeandExpense12);
        
        TimeandExpenseDetails__c TimeandExpense13 = new TimeandExpenseDetails__c(
            TimeandExpenseHeader__c = Header1.Id,
            ExpenseAmount__c = 40,
            Hours__c = 4
        );
        TimeExpenseList.add(TimeandExpense13);
        
        TimeandExpenseHeader__c Header2 = new TimeandExpenseHeader__c(
            Investigation__c = Investigation1.Id,
            Name = 'Test Assignment'
           // AssignedTo__c = UserInfo.getUserId()
        );
        insert Header2;
        
        TimeandExpenseDetails__c TimeandExpense21 = new TimeandExpenseDetails__c(
            TimeandExpenseHeader__c = Header2.Id,
            ExpenseAmount__c = 10,
            Hours__c = 1
        );
        TimeExpenseList.add(TimeandExpense21);
        
        TimeandExpenseDetails__c TimeandExpense22 = new TimeandExpenseDetails__c(
            TimeandExpenseHeader__c = Header2.Id,
            ExpenseAmount__c = 10,
            Hours__c = 1
        );
        TimeExpenseList.add(TimeandExpense22);
        
        TimeandExpenseDetails__c TimeandExpense23 = new TimeandExpenseDetails__c(
            TimeandExpenseHeader__c = Header2.Id,
            ExpenseAmount__c = 10,
            Hours__c = 1
        );
        TimeExpenseList.add(TimeandExpense23);

        Test.startTest();
            insert TimeExpenseList;
            
            SEBCase__c SEBCaseCheck = [SELECT Id, TotalSEBCaseExpenses__c, TotalSEBCaseHours__c FROM SEBCase__c WHERE Id =: SEBCase.Id LIMIT 1];
            System.assertEquals(120, SEBCaseCheck.TotalSEBCaseExpenses__c);
            System.assertEquals(12, SEBCaseCheck.TotalSEBCaseHours__c);
        Test.stopTest();     
    }
    
    public static testmethod void TestHistory() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        
        SEBCase__c cs = new SEBCase__c();
        cs.Status__c = 'Intake';
        cs.Account__c = acct.Id;
        insert cs;
        
        Investigation__c ex = new Investigation__c();
        ex.SEBCase__c = cs.Id;
        ex.Status__c = 'Investigation in Progress';
        insert ex;
        
        Test.startTest();
        ex.Status__c = 'Ready for Supervisor Review';
        update ex;
        ex.Status__c = 'Ready for Supervising Attorney Review';
        update ex;
        Test.stopTest();
        
        System.assert([SELECT COUNT() FROM StatusHistory__c] >= 3, 'At this point, we should have at least 3 history records');
    }
    
}