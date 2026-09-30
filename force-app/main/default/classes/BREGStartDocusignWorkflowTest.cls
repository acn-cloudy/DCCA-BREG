@isTest
private class BREGStartDocusignWorkflowTest {
    private static Integer calloutCount = 0;

    private static Id getBregCaseRecordTypeId() {
        return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
    }

    private class WorkflowCalloutMock implements HttpCalloutMock {
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
    static void testExecuteWithoutParams() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());
        calloutCount = 0;

        Test.startTest();
        new BREGStartDocusignWorkflow('Test Workflow', UserInfo.getUserId(), 'Test User', false).execute(null);
        Test.stopTest();

        System.assertEquals(1, calloutCount, 'Workflow should make one callout for the no-params path');
    }

    @isTest
    static void testExecuteWithParams() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());
        calloutCount = 0;

        Test.startTest();
        new BREGStartDocusignWorkflow('Test Workflow With Params', UserInfo.getUserId(), '<recordId>001000000000001AAA</recordId>', false).execute(null);
        Test.stopTest();

        System.assertEquals(1, calloutCount, 'Workflow should make one callout for the params path');
    }

    @isTest
    static void testExecuteWithParamsAndStartedByUsesFiveArgConstructor() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());
        calloutCount = 0;

        Case testCase = new Case(
            Subject = 'Workflow Params Constructor Test',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        Test.startTest();
        new BREGStartDocusignWorkflow(
            'Test Workflow Params Constructor',
            testCase.Id,
            '<recordId>' + testCase.Id + '</recordId>',
            'Started By Test',
            false
        ).execute(null);
        Test.stopTest();

        System.assertEquals(1, calloutCount, 'Workflow should make one callout for the params constructor path');
    }

    @isTest
    static void testExecuteWithRecordIds() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());
        calloutCount = 0;

        List<Id> recordIds = new List<Id>{'001000000000001AAA', '001000000000002AAA'};
        Test.startTest();
        new BREGStartDocusignWorkflow('Test Workflow With RecordIds', recordIds, null, false).execute(null);
        Test.stopTest();

        System.assertEquals(2, calloutCount, 'Workflow should make one callout per record id');
    }

    @isTest
    static void testExecuteWithGenerateLogCreatesPendingLog() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());

        Case testCase = new Case(
            Subject = 'Workflow Queueable Test',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DC-1'
        );
        insert testCase;

        Id logId = BREGStartDocusignWorkflow.createWorkflowLogSafely(testCase.Id, 'Workflow Test');
        BREGStartDocusignWorkflow workflow = new BREGStartDocusignWorkflow('Test Workflow', testCase.Id, null, 'Workflow Test', logId);

        breg_Log__c createdLog = [
            SELECT breg_Case__c, breg_Workflow_Name__c, breg_Workflow_Status__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        System.assertEquals(testCase.Id, createdLog.breg_Case__c, 'Workflow log should be created before execute runs.');
        System.assertEquals(null, createdLog.breg_Workflow_Name__c, 'Constructor should create a pending log without response data.');
        System.assertEquals('Pending', createdLog.breg_Workflow_Status__c, 'Constructor should create a pending log.');

        Test.startTest();
        System.enqueueJob(workflow);
        Test.stopTest();

        breg_Log__c updatedLog = [
            SELECT breg_Case__c, breg_Workflow_Name__c, breg_Workflow_Status__c, breg_Workflow_Instance_Id__c
            FROM breg_Log__c
            WHERE Id = :logId
            LIMIT 1
        ];

        System.assertEquals('Test Workflow', updatedLog.breg_Workflow_Name__c, 'Execute should update the log from callout response.');
        System.assertEquals('Executing', updatedLog.breg_Workflow_Status__c, 'Execute should update the workflow status.');
        System.assertEquals('d187e6c3-1c81-f111-9798-9440c983dcd5', updatedLog.breg_Workflow_Instance_Id__c, 'Execute should parse the workflow instance id.');
    }

    @isTest
    static void testStartDocuSignAnnualRobotCreatesAndUpdatesLogs() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());

        Id recordTypeId = getBregCaseRecordTypeId();
        Case caseOne = new Case(Subject = 'Generate Log One', Status = 'New', Origin = 'Web', RecordTypeId = recordTypeId, breg_Form_Code__c = 'DC-1');
        Case caseTwo = new Case(Subject = 'Generate Log Two', Status = 'New', Origin = 'Web', RecordTypeId = recordTypeId, breg_Form_Code__c = 'DC-1');
        insert new List<Case>{ caseOne, caseTwo };

        Test.startTest();
        BREGStartDocusignWorkflow.startDocuSignAnnualRobot(new List<Id>{ caseOne.Id, caseTwo.Id });
        Test.stopTest();

        List<breg_Log__c> createdLogs = [
            SELECT breg_Case__c, breg_Workflow_Name__c, breg_Workflow_Status__c, breg_Workflow_Instance_Id__c, breg_Started_From__c
            FROM breg_Log__c
            WHERE breg_Case__c IN :new Set<Id>{ caseOne.Id, caseTwo.Id }
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(2, createdLogs.size(), 'Both record ids should create workflow logs');
        System.assertEquals('Test Workflow', createdLogs[0].breg_Workflow_Name__c, 'Annual robot should update workflow logs from callout response');
        System.assertEquals('Executing', createdLogs[0].breg_Workflow_Status__c, 'Annual robot should update the workflow status');
        System.assertEquals('Annual Robot Process', createdLogs[0].breg_Started_From__c, 'Started by should be persisted to the workflow log');
    }
}