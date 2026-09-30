/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class InvestigationCallsControllerTest {

    @TestSetup
    static void makeData(){
        SEBCase__c scase = new SEBCase__c(Type__c = 'Agent', Subtype__c = 'Mail');
        insert scase;

        String recordTypeId = Investigation__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('Investigation').getRecordTypeId();
        Investigation__c inv = new Investigation__c(RecordTypeId = recordTypeId, Status__c = 'New', SEBCase__c = scase.Id);
        insert inv;

        Task tsk = new Task(Subject = 'Test', Description = 'Test', TaskSubtype = 'Call', WhatId = inv.Id);
        insert tsk;
    }

    @isTest
    static void testInvestigationCallsController() {
        Investigation__c inv = [SELECT Id FROM Investigation__c LIMIT 1];
        PageReference pageRef = Page.InvestigationCallsTemplate;
        Test.setCurrentPage(pageRef);

        pageRef.getParameters().put('id', String.valueOf(inv.Id));
        InvestigationCallsController ctr = new InvestigationCallsController();
        ctr.generateInvestigationCalls();
    }

    @isTest
    static void testInvestigationCallsStandardController() {
        Investigation__c inv = [SELECT Id FROM Investigation__c LIMIT 1];
        PageReference pageRef = Page.InvestigationCallsAction;
        Test.setCurrentPage(pageRef);

        pageRef.getParameters().put('id', String.valueOf(inv.Id));
        ApexPages.StandardController sc = new ApexPages.StandardController(inv);
        InvestigationCallsController ctr = new InvestigationCallsController(sc);
        ctr.generateInvestigationCalls();
    }
}