/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for ExamAll / StatusHistoryAux
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
public class ExamAllTest {

    public static testmethod void TestHistory() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        Exam__c ex = new Exam__c();
        ex.Account__c = acct.Id;
        ex.ExamStatus__c = 'Assigned for Examination';
        insert ex;
        
        Test.startTest();
        ex.ExamStatus__c = 'Exam in Progress';
        update ex;
        ex.ExamStatus__c = 'Deficiency Letter Sent';
        update ex;
        Test.stopTest();
        
        System.assertEquals(3, [SELECT COUNT() FROM StatusHistory__c], 'At this point, we should have at least 3 history records');
    }
    
}