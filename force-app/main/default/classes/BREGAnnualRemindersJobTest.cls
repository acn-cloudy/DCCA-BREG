@isTest
public class BREGAnnualRemindersJobTest {
    @testSetup
    static void setupData() {
        TriggerHelper.disableAccountTrigger = true;
        BREGTestDataFactory.createFileNumberSequences();
        List<breg_Form_Configuration__c> forms = BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createRegistrationCases(forms);

        Case testCase = [
            SELECT
                Id,
                breg_New_Entity_Name__c,
                breg_File__c,
                breg_File_Suffix__c,
                breg_Company_Address__City__s,
                breg_Company_Address__StateCode__s,
                breg_Company_Address__PostalCode__s,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address_Street2__c,
                breg_Company_Address__Street__s,
                breg_Company_Address_State__c,
                breg_Entity_Type__c,
                breg_Formation_State__c,
                breg_Reg_Agent_Type__c,
                breg_Mailing_Address__CountryCode__s,
                breg_Mailing_Address__StateCode__s,
                breg_Mailing_Address_State__c,
                breg_Mailing_Address__City__s,
                breg_Mailing_Address__PostalCode__s,
                breg_Mailing_Address__Street__s,
                breg_subscribe_owner_free_email_alerts__c,
                breg_Number_Of_members__c,
                breg_Purposes__c,
                breg_New_Registrant_First_Name__c,
                breg_New_Registrant_Last_Name__c,
                breg_New_Registrant_Name__c,
                breg_New_Entity_Jurisdiction__c,
                breg_New_Entity_Type__c,
                breg_Effective_Date_Time__c,
                breg_Effective_Date__c,
                breg_Name_of_the_Entity__c,
                CreatedById
            FROM Case
            LIMIT 1
        ];

        testCase.breg_New_Entity_Type__c = 'L5';

        Map<Id, Id> caseToNewEntity = BREGCaseStatusHandlerConversion.createNewEntities(new List<Case>{ testCase });

        Test.startTest();
        Date today = Date.today();
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        insert new List<Account>{
            new Account(
                Name = 'Account Upcoming',
                RecordTypeId = bregAccRecordType,
                breg_Annuals_Due_Date__c = today.addMonths(1),
                breg_Subscribe_Owner_Free_Email_Alerts__c = true
            ),
            new Account(
                Name = 'Account Today',
                RecordTypeId = bregAccRecordType,
                breg_Annuals_Due_Date__c = today,
                breg_Subscribe_Owner_Free_Email_Alerts__c = true
            ),
            new Account(
                Name = 'Account Expired',
                RecordTypeId = bregAccRecordType,
                breg_Annuals_Due_Date__c = today.addDays(-13),
                breg_Subscribe_Owner_Free_Email_Alerts__c = true
            ),
            new Account(
                Name = 'Account No Reminder',
                RecordTypeId = bregAccRecordType,
                breg_Annuals_Due_Date__c = today.addDays(50), // Should not trigger
                breg_Subscribe_Owner_Free_Email_Alerts__c = true
            )
        };
    }

    @isTest
    static void testCreateTasks() {
        List<Account> accounts = [SELECT Id, Name, breg_Annuals_Due_Date__c, breg_Subscribe_Owner_Free_Email_Alerts__c FROM Account];

        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        for (Account acc : accounts) {
            recordsMap.put(acc.Id, acc);
        }

        Test.startTest();
        BREGAnnualRemindersJob job = new BREGAnnualRemindersJob();
        BREGBatchInterface.BatchProcessingResult result = job.processRecords(recordsMap, 'Account');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.tasksToUpsert, 'tasksToUpsert should not be null');
        System.assertEquals(3, result.tasksToUpsert.size(), 'Should create exactly 3 tasks (Upcoming, Today, Expired)');

        // Validate each expected task
        Set<String> subjects = new Set<String>();
        for (Task t : result.tasksToUpsert) {
            subjects.add(t.Subject);
            System.assertEquals('Email', t.TaskSubtype, 'Task subtype should be Email');
            System.assertNotEquals(null, t.WhatId, 'WhatId should be populated with Account Id');
            System.assertEquals(Date.today(), t.ActivityDate, 'ActivityDate should be today');
            System.assertNotEquals(null, t.Description, 'Task should have a description');
        }

        System.assert(subjects.contains('Annual Renewal Upcoming Alert'), 'Missing Upcoming Alert');
        System.assert(subjects.contains('Annual Renewal Alert'), 'Missing Today Alert');
        System.assert(subjects.contains('Annual Renewal Expired Alert'), 'Missing Expired Alert');
    }

    @isTest
    static void testNoTasksWhenNoMatches() {
        TriggerHelper.disableAccountTrigger = true;
        Test.startTest();
        Account acc = new Account(
            Name = 'Future Account',
            breg_Annuals_Due_Date__c = Date.today().addDays(100),
            breg_Subscribe_Owner_Free_Email_Alerts__c = true
        );
        insert acc;

        Map<Id, SObject> recordsMap = new Map<Id, SObject>{ acc.Id => acc };

        BREGAnnualRemindersJob job = new BREGAnnualRemindersJob();
        BREGBatchInterface.BatchProcessingResult result = job.processRecords(recordsMap, 'Account');
        Test.stopTest();

        System.assertEquals(0, result.tasksToUpsert.size(), 'No tasks should be created for non-matching due date');
    }

    @isTest
    static void testNoTasksWhenFreeEmailAlertsDisabled() {
        TriggerHelper.disableAccountTrigger = true;
        Test.startTest();
        Account acc = new Account(
            Name = 'Today But Not Subscribed',
            breg_Annuals_Due_Date__c = Date.today(),
            breg_Subscribe_Owner_Free_Email_Alerts__c = false
        );
        insert acc;

        Map<Id, SObject> recordsMap = new Map<Id, SObject>{ acc.Id => acc };

        BREGAnnualRemindersJob job = new BREGAnnualRemindersJob();
        BREGBatchInterface.BatchProcessingResult result = job.processRecords(recordsMap, 'Account');
        Test.stopTest();

        System.assertEquals(0, result.tasksToUpsert.size(), 'No tasks should be created when free email alerts are disabled');
    }
}