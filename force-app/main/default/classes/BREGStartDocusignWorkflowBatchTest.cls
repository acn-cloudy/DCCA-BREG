@isTest
private class BREGStartDocusignWorkflowBatchTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    @isTest
    static void testStartWithNullRecordIds() {
        BREGStartDocusignWorkflowBatch batch = new BREGStartDocusignWorkflowBatch('WF-Null', null);

        Iterable<Id> iterableIds = batch.start(null);
        List<Id> ids = new List<Id>();
        for (Id nextId : iterableIds) {
            ids.add(nextId);
        }

        System.assertEquals(0, ids.size(), 'start should return empty iterable when recordIds is null');
    }

    @isTest
    static void testBatchExecuteSuccessPath() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        List<Id> recordIds = new List<Id>{ UserInfo.getUserId(), UserInfo.getProfileId() };

        Test.startTest();
        Id jobId = Database.executeBatch(new BREGStartDocusignWorkflowBatch('WF-Success', recordIds), 200);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned');
        AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        System.assertEquals('Completed', job.Status, 'Batch job should complete for success path');
    }

    @isTest
    static void testBatchExecuteErrorPathIsHandled() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());

        List<Id> recordIds = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        Id jobId = Database.executeBatch(new BREGStartDocusignWorkflowBatch('WF-Error', recordIds), 1);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch should complete even when callout throws and is caught');

        AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        System.assertEquals('Completed', job.Status, 'Batch job should still complete because exception is handled in execute');
    }
}