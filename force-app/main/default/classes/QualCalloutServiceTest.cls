/**
 * @description Test class for QualCalloutService
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualCalloutServiceTest {
    
    @TestSetup
    static void setupTestData() {
        Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
    }
    
    @IsTest
    static void testProcessCaseCallout_Success() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
        
        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());
        
        Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());
        
        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();
        
        System.assertEquals(true, result.isSuccess, 'Should be successful');
        System.assertEquals(testCase.Id, result.caseId, 'Case ID should match');
        System.assertNotEquals(null, result.requestBody, 'Request body should not be null');
        System.assert(result.payloadSize > 0, 'Payload size should be greater than 0');
    }
    
    @IsTest
    static void testProcessCaseCallout_RateLimit() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
        
        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());
        
        Test.setMock(HttpCalloutMock.class, QualCalloutMock.createRateLimitMock());
        
        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assertEquals(true, result.isRetryable, 'Should be retryable');
        System.assertEquals('Rate limit exceeded', result.errorMessage, 'Error message should match');
    }
    
    @IsTest
    static void testProcessCaseCallout_ServerError() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
        
        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());
        
        Test.setMock(HttpCalloutMock.class, QualCalloutMock.createServerErrorMock());
        
        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assertEquals(true, result.isRetryable, 'Server error should be retryable');
    }
    
    @IsTest
    static void testProcessCaseCallout_BadRequest() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
        
        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());
        
        Test.setMock(HttpCalloutMock.class, QualCalloutMock.createBadRequestMock());
        
        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assertEquals(false, result.isRetryable, 'Client error should not be retryable');
    }
    
    @IsTest
    static void testProcessCaseCallout_NullConfig() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
        
        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, null);
        Test.stopTest();
        
        System.assertEquals(false, result.isSuccess, 'Should not be successful without config');
        System.assertNotEquals(null, result.errorMessage, 'Should have error message');
    }
    
    @IsTest
    static void testProcessCaseCallout_MissingApiToken() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
        
        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        // API token is optional for inbound-event endpoints, so null settings should still work
        QualConfigSelector.setTestSettings(null);
        
        Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());
        
        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();
        
        // API token is optional, so callout should proceed and succeed with mock
        System.assertEquals(true, result.isSuccess, 'Should be successful even without API token (optional)');
        System.assertEquals(testCase.Id, result.caseId, 'Case ID should match');
    }

    @IsTest
    static void testProcessCaseCallout_NotFound404() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());

        Test.setMock(HttpCalloutMock.class, QualCalloutMock.createNotFoundMock());

        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Should not be successful');
        System.assertEquals(false, result.isRetryable, '404 client error should not be retryable');
        System.assertEquals('Workflow not found', result.errorMessage, 'Error message should match');
    }

    @IsTest
    static void testProcessCaseCallout_OversizedPayload_NonRetryable() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

        List<Long> largeCallIds = new List<Long>();
        for (Integer i = 0; i < 150; i++) {
            largeCallIds.add(900000000L + i);
        }
        QualCasePayloadBuilder.setUjetCallIdMap(
            new Map<Id, List<Long>>{ testCase.Id => largeCallIds }
        );

        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        config.qual_Max_Payload_Size_KB__c = 1;
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());

        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(testCase, config);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Oversized Case payload should fail');
        System.assertEquals(false, result.isRetryable, 'Oversized Case payload should not retry');
        System.assert(
            result.errorMessage.contains('Case payload size'),
            'Error should identify payload size enforcement'
        );
    }

    @IsTest
    static void testProcessCallCallout_MissingJson_NonRetryable() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
            testCase.Id,
            1234,
            true
        );
        session = [
            SELECT
                Id,
                UJET__Case__c,
                UJET__Case__r.CaseNumber,
                UJET__Case__r.ContactId,
                UJET__Contact__c,
                UJET__Call_Id__c,
                UJET__Call_Duration__c,
                UJET__Hold_Duration__c,
                UJET__Wait_Duration__c,
                UJET__Fail_Reason__c,
                UJET__Status__c
            FROM UJET__UJET_Session__c
            WHERE Id = :session.Id
        ];

        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());

        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCallCallout(
            session,
            config,
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Missing JSON should fail');
        System.assertEquals(false, result.isRetryable, 'Missing JSON should not retry');
        System.assertEquals('1234', result.callId, 'Call ID should come from the session');
        System.assert(
            result.errorMessage.contains('Required call JSON attachment not found'),
            'Error should identify missing required JSON'
        );
    }

    @IsTest
    static void testProcessCallCallout_OversizedPayload_NonRetryable() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
            testCase.Id,
            1235,
            true
        );
        session = [
            SELECT
                Id,
                UJET__Case__c,
                UJET__Case__r.CaseNumber,
                UJET__Case__r.ContactId,
                UJET__Contact__c,
                UJET__Call_Id__c,
                UJET__Call_Duration__c,
                UJET__Hold_Duration__c,
                UJET__Wait_Duration__c,
                UJET__Fail_Reason__c,
                UJET__Status__c
            FROM UJET__UJET_Session__c
            WHERE Id = :session.Id
        ];

        String largeValue = '';
        for (Integer i = 0; i < 1200; i++) {
            largeValue += 'x';
        }
        Object callJson = JSON.deserializeUntyped(
            '{"id":1235,"call_type":"' + largeValue + '"}'
        );
        qual_Config__mdt config = QualTestDataFactory.createTestConfig();
        config.qual_Max_Payload_Size_KB__c = 1;
        QualConfigSelector.setTestConfig(config);
        QualConfigSelector.setTestSettings(QualTestDataFactory.createTestSettings());

        Test.startTest();
        QualCalloutService.CalloutResult result = QualCalloutService.processCallCallout(
            session,
            config,
            callJson
        );
        Test.stopTest();

        System.assertEquals(false, result.isSuccess, 'Oversized Call payload should fail');
        System.assertEquals(false, result.isRetryable, 'Oversized Call payload should not retry');
        System.assert(
            result.errorMessage.contains('Call payload size'),
            'Error should identify payload size enforcement'
        );
    }
}