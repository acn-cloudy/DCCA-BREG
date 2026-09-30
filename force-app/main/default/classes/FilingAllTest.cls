/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for FilingAll / StatusHistoryAux
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@istest
public class FilingAllTest {

    public static testmethod void TestHistory() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        Filing__c ex = new Filing__c();
        ex.Status__c = 'In Progress';
        ex.FiscalYearEnd__c = date.today();
        ex.Account__c = acct.Id;
        insert ex;
        
        Test.startTest();
        ex.Status__c = 'Filing Received';
        update ex;
        ex.Status__c = 'Assigned for Review';
        ex.FilingDate__c = Date.today();
        update ex;
        Test.stopTest();
        
        System.assertEquals(3, [SELECT COUNT() FROM StatusHistory__c], 'At this point, we should have at least 3 history records');
    }
    
}