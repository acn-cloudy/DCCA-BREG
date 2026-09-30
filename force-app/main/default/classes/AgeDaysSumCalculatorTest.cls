/*
 * ___________________________________________________________________________________
 * Test Class for AgeDaysSumCalculator
 * __________________________________________________________________________________
 * PacPoint-CL041019 - Created for BREG phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 4/10/2019
 * __________________________________________________________________________________
 */
@IsTest
private class AgeDaysSumCalculatorTest {
    
    @TestSetup
    static void setup() {
        Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;
        RecordTypeInfo filingBrokerDealerRti =
                Filing__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('BrokerDealer');
        Filing__c filing = new Filing__c();
        filing.Status__c = 'In Progress';
        filing.RecordTypeId = filingBrokerDealerRti.getRecordTypeId();
        filing.Account__c = acct.Id;
        insert filing;

        Exam__c exam = new Exam__c();
        exam.Account__c = acct.Id;
        exam.Name = 'dummyExam';
        exam.ExamStatus__c = 'Assigned for Examination';
        insert exam;

        SEBCase__c sbCase = new SEBCase__c();
        sbCase.Account__c = acct.Id;
        // sbCase.Name = 'dummySebCase';
        sbCase.Status__c = 'Intake';
        insert sbCase;

        RecordTypeInfo investigationRti =
                Investigation__c.sObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Investigation');
        Investigation__c investigation = new Investigation__c();
        investigation.RecordTypeId = investigationRti.getRecordTypeId();
        investigation.Name = 'dummyInvestigation';
        investigation.SEBCase__c = sbCase.Id;
        investigation.Status__c = 'Corrections Required';
        insert investigation;
    }

    @IsTest
    static void testFiling() {
        AgeDaysSumCalculator ageDays = new AgeDaysSumCalculator();
        
        Filing__c filing = [SELECT Id FROM Filing__c LIMIT 1];

        Test.startTest();
        StatusHistory__c statusHistory = new StatusHistory__c();
        statusHistory.Filing__c = filing.Id;
        statusHistory.StartDate__c = Datetime.now().addDays(-2);
        statusHistory.EndDate__c = Datetime.now().addDays(-1);
        insert statusHistory;
        Test.stopTest();
    }
}