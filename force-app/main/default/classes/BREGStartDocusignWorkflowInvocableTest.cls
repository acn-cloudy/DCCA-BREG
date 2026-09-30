@isTest
private class BREGStartDocusignWorkflowInvocableTest {
    private class WorkflowCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"Name":"Test Workflow","Status":"Executing","Href":"https://apiuatna11.springcm.com/v2/d8615adc-fdbe-433a-93fc-2b9975a641cd/workflows/d187e6c3-1c81-f111-9798-9440c983dcd5"}'
            );
            return res;
        }
    }

    private static Id getBregCaseRecordTypeId() {
        return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case')?.getRecordTypeId();
    }

    @isTest
    static void testStartDocusignWorkflowInvocableProcessesFlowInput() {
        Test.setMock(HttpCalloutMock.class, new WorkflowCalloutMock());

        Id recordTypeId = getBregCaseRecordTypeId();
        Case caseOne = new Case(
            Subject = 'Invocable Flow Input One',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = recordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        Case caseTwo = new Case(
            Subject = 'Invocable Flow Input Two',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = recordTypeId,
            breg_Form_Code__c = 'DC-1'
        );
        insert new List<Case>{ caseOne, caseTwo };

        String startedBy = 'Invocable Test';
        List<Id> caseIds = new List<Id>{ caseOne.Id, caseTwo.Id };
        List<Id> logIds = BREGStartDocusignWorkflow.createWorkflowLogsSafely(caseIds, startedBy);

        BREGStartDocusignWorkflowInvocable.StartDocusignWorkflowInput flowInput =
            new BREGStartDocusignWorkflowInvocable.StartDocusignWorkflowInput();
        flowInput.ids = caseIds;
        flowInput.startedBy = startedBy;
        flowInput.workflowName = BREGStartDocusignWorkflow.ANNUAL_ROBOT_WORKFLOW;
        flowInput.logIds = logIds;

        Test.startTest();
        BREGStartDocusignWorkflowInvocable.startDocusignWorkflow(
            new List<BREGStartDocusignWorkflowInvocable.StartDocusignWorkflowInput>{ flowInput }
        );
        Test.stopTest();

        List<breg_Log__c> updatedLogs = [
            SELECT breg_Case__c, breg_Workflow_Name__c, breg_Workflow_Status__c, breg_Started_From__c
            FROM breg_Log__c
            WHERE Id IN :new Set<Id>(logIds)
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(2, updatedLogs.size(), 'Invocable should update all provided workflow logs.');
        System.assertEquals('Test Workflow', updatedLogs[0].breg_Workflow_Name__c, 'Invocable should update workflow name from callout response.');
        System.assertEquals('Executing', updatedLogs[0].breg_Workflow_Status__c, 'Invocable should update workflow status from callout response.');
        System.assertEquals(startedBy, updatedLogs[0].breg_Started_From__c, 'Invocable should preserve startedBy value in the workflow log.');
    }

    @isTest
    static void testStartDocusignWorkflowInvocableSkipsNullInputList() {
        Test.startTest();
        BREGStartDocusignWorkflowInvocable.startDocusignWorkflow(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'Null input list should not enqueue queueable jobs.');
    }

    @isTest
    static void testStartDocusignWorkflowInvocableSkipsEmptyInputList() {
        Test.startTest();
        BREGStartDocusignWorkflowInvocable.startDocusignWorkflow(new List<BREGStartDocusignWorkflowInvocable.StartDocusignWorkflowInput>());
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'Empty input list should not enqueue queueable jobs.');
    }
}