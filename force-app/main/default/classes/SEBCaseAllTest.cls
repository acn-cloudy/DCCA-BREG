/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for SEBCaseAll / StatusHistoryAux
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
public class SEBCaseAllTest {

    public static testmethod void TestHistory() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        SEBCase__c ex = new SEBCase__c();
        ex.Status__c = 'Intake';
        ex.Account__c = acct.Id;
        insert ex;
        
        Test.startTest();
        ex.Status__c = 'Investigation';
        update ex;
        ex.Status__c = 'Legal';
        update ex;
        Test.stopTest();
        
        System.assertEquals(3, [SELECT COUNT() FROM StatusHistory__c], 'At this point, we should have at least 3 history records');
    }
    

}