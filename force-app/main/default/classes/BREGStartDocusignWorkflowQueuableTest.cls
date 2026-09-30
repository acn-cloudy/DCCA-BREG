@isTest
private class BREGStartDocusignWorkflowQueuableTest {
    private static Integer calloutCount = 0;

    private static Id getBregCaseRecordTypeId() {
        return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            calloutCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Name":"Test Workflow","Status":"Executing","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/d187e6c3-1c81-f111-9798-9440c983dcd5"}'
            );
            return res;
        }
    }

    @isTest
    static void testExecuteEnqueuesBatchWithRecordIds() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        List<Id> recordIds = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        new BREGStartDocusignWorkflowQueuable('WF-Queueable', recordIds).execute(null);
        Test.stopTest();

        AsyncApexJob batchJob = [
            SELECT Id, Status, JobType
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Completed', batchJob.Status, 'Batch should complete');
        System.assertEquals('BatchApex', batchJob.JobType, 'Job type should be BatchApex');
    }

    @isTest
    static void testExecuteWithNullRecordIds() {
        Test.startTest();
        new BREGStartDocusignWorkflowQueuable('WF-Queueable-Null', null).execute(null);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'BatchApex' AND Status = 'Holding'],
            'Null recordIds should not queue a batch job'
        );
    }

    @isTest
    static void testExecuteCalloutModeUpdatesLogWithoutRecursing() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        calloutCount = 0;

        Case testCase = new Case(
            Subject = 'Queueable Callout Test',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        TriggerUtils.disableTrigger = true;
        Id logId = BREGUtils.createWorkflowLog(testCase.Id, 'BREGStartDocusignWorkflowQueuableTest');
        TriggerUtils.disableTrigger = false;

        Test.startTest();
        new BREGStartDocusignWorkflowQueuable('WF-Queueable-Callout', testCase.Id, null, logId).execute(null);
        Test.stopTest();

        breg_Log__c updatedLog = [
            SELECT breg_Workflow_Name__c, breg_Workflow_Status__c, breg_Workflow_Instance_Id__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        System.assertEquals('Test Workflow', updatedLog.breg_Workflow_Name__c, 'Callout mode should update the log from the response');
        System.assertEquals('Executing', updatedLog.breg_Workflow_Status__c, 'Callout mode should update the workflow status');
        System.assertEquals('d187e6c3-1c81-f111-9798-9440c983dcd5', updatedLog.breg_Workflow_Instance_Id__c, 'Callout mode should parse the workflow instance id');
        System.assertEquals(1, calloutCount, 'Single-record callout mode should perform one callout.');
    }

    @isTest
    static void testExecuteCalloutModeForRecordListHandlesNullIdsAndNullLogIds() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        calloutCount = 0;

        Id recordTypeId = getBregCaseRecordTypeId();
        Case caseOne = new Case(Subject = 'Queueable List One', Status = 'New', Origin = 'Web', RecordTypeId = recordTypeId, breg_Form_Code__c = 'DC-1');
        Case caseTwo = new Case(Subject = 'Queueable List Two', Status = 'New', Origin = 'Web', RecordTypeId = recordTypeId, breg_Form_Code__c = 'DC-1');
        insert new List<Case>{ caseOne, caseTwo };

        TriggerUtils.disableTrigger = true;
        Id logId = BREGUtils.createWorkflowLog(caseOne.Id, 'BREGStartDocusignWorkflowQueuableTest');
        TriggerUtils.disableTrigger = false;

        List<Id> recordIds = new List<Id>{ caseOne.Id, caseTwo.Id, null };
        List<Id> logIds = new List<Id>{ logId, null, null };

        Test.startTest();
        new BREGStartDocusignWorkflowQueuable('WF-Queueable-Callout-List', recordIds, logIds).execute(null);
        Test.stopTest();

        breg_Log__c updatedLog = [
            SELECT breg_Workflow_Name__c, breg_Workflow_Status__c, breg_Workflow_Instance_Id__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        System.assertEquals('Test Workflow', updatedLog.breg_Workflow_Name__c, 'List callout mode should update log when logId exists.');
        System.assertEquals('Executing', updatedLog.breg_Workflow_Status__c, 'List callout mode should update workflow status.');
        System.assertEquals('d187e6c3-1c81-f111-9798-9440c983dcd5', updatedLog.breg_Workflow_Instance_Id__c, 'List callout mode should parse workflow instance id.');
        System.assertEquals(2, calloutCount, 'List mode should call out for logged and non-logged records, while skipping null record ids.');
    }

    @isTest
    static void testExecuteCalloutModeSingleRecordWithParamsAndLogId() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        calloutCount = 0;

        Case testCase = new Case(
            Subject = 'Queueable Params Callout Test',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        TriggerUtils.disableTrigger = true;
        Id logId = BREGUtils.createWorkflowLog(testCase.Id, 'BREGStartDocusignWorkflowQueuableTest');
        TriggerUtils.disableTrigger = false;

        String params = '<recordId>' + testCase.Id + '</recordId><templateName>Template A</templateName>';

        Test.startTest();
        new BREGStartDocusignWorkflowQueuable('WF-Queueable-Callout-Params', testCase.Id, params, logId).execute(null);
        Test.stopTest();

        breg_Log__c updatedLog = [
            SELECT breg_Workflow_Name__c, breg_Workflow_Status__c, breg_Workflow_Instance_Id__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        System.assertEquals('Test Workflow', updatedLog.breg_Workflow_Name__c, 'Params callout mode should update log from response.');
        System.assertEquals('Executing', updatedLog.breg_Workflow_Status__c, 'Params callout mode should update workflow status.');
        System.assertEquals('d187e6c3-1c81-f111-9798-9440c983dcd5', updatedLog.breg_Workflow_Instance_Id__c, 'Params callout mode should parse workflow instance id.');
        System.assertEquals(1, calloutCount, 'Params callout mode should do one callout.');
    }
}