@IsTest
private class QualCallSessionQueueableTest {
  @TestSetup
  static void setupTestData() {
    QualTestDataFactory.createCompleteTestData();
  }

  @IsTest
  static void testExecute_SendsCallPayloadToCallWorkflow() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      801,
      284,
      0,
      47,
      true
    );
    session.UJET__Status__c = 'finished';
    update session;
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-801.json',
      QualTestDataFactory.getSampleCallJson(801)
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT
        Id,
        qual_Payload_Type__c,
        qual_Ujet_Session_Id__c,
        qual_Call_Id__c,
        qual_Workflow_Id__c,
        qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(1, logs.size(), 'Should create one Call log');
    System.assertEquals(
      QualCalloutService.PAYLOAD_TYPE_CALL,
      logs[0].qual_Payload_Type__c,
      'Log should be a Call payload'
    );
    System.assertEquals(
      '801',
      logs[0].qual_Call_Id__c,
      'Log should capture call ID'
    );
    System.assertEquals(
      config.qual_Call_Workflow_Id__c,
      logs[0].qual_Workflow_Id__c,
      'Log should use Call workflow ID'
    );

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      logs[0].qual_Request_Body__c
    );
    Map<String, Object> callData = (Map<String, Object>) payloadMap.get('call');
    System.assertEquals(
      '15',
      String.valueOf(callData.get('acw_duration')),
      'Call payload should include computed ACW'
    );
  }

  @IsTest
  static void testExecute_UsesJsonFileMatchingCurrentCallId() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      1234,
      284,
      0,
      47,
      true
    );
    session.UJET__Status__c = 'finished';
    update session;

    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-9999.json',
      QualTestDataFactory.getSampleCallJson(9999)
    );
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-12345.json',
      QualTestDataFactory.getSampleCallJson(12345)
    );
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-1234.json',
      QualTestDataFactory.getSampleCallJson(1234)
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Call_Id__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(1, logs.size(), 'Should create one Call log');
    System.assertEquals(
      'Success',
      logs[0].qual_Status__c,
      'Matching JSON should send'
    );
    System.assertEquals(
      '1234',
      logs[0].qual_Call_Id__c,
      'Log should use current session Call ID'
    );

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      logs[0].qual_Request_Body__c
    );
    Map<String, Object> callData = (Map<String, Object>) payloadMap.get('call');
    System.assertEquals(
      '1234',
      String.valueOf(callData.get('id')),
      'Payload should use the JSON file whose filename matches Call ID 1234'
    );
  }

  @IsTest
  static void testFileNameContainsCallId_AvoidsPartialNumericMatches() {
    System.assertEquals(
      true,
      QualCallSessionQueueable.fileNameContainsCallId('call-1234.json', '1234'),
      'Exact token should match'
    );
    System.assertEquals(
      false,
      QualCallSessionQueueable.fileNameContainsCallId(
        'call-12345.json',
        '1234'
      ),
      'Longer numeric token should not match'
    );
    System.assertEquals(
      false,
      QualCallSessionQueueable.fileNameContainsCallId(
        'call-91234.json',
        '1234'
      ),
      'Numeric prefix should not match'
    );
  }

  @IsTest
  static void testExecute_MissingJsonCreatesDeadLetter() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      1236,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Error_Message__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(1, logs.size(), 'Should create one Call log');
    System.assertEquals(
      'Dead Letter',
      logs[0].qual_Status__c,
      'Missing required JSON should dead-letter'
    );
    System.assert(
      logs[0].qual_Error_Message__c.contains('Required call JSON attachment'),
      'Dead Letter should explain that required JSON is missing'
    );
    System.assertEquals(
      null,
      logs[0].qual_Request_Body__c,
      'Missing JSON should not send a session-only payload'
    );
  }

  @IsTest
  static void testExecute_InvalidJsonCreatesDeadLetterWithFileContext() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      1237,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-1237.json',
      'not valid json'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Error_Message__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(1, logs.size(), 'Should create one Call log');
    System.assertEquals(
      'Dead Letter',
      logs[0].qual_Status__c,
      'Invalid required JSON should dead-letter'
    );
    System.assert(
      logs[0].qual_Error_Message__c.contains('call-1237.json'),
      'Parse error should include the JSON filename'
    );
  }

  @IsTest
  static void testUjetSessionTrigger_EnqueuesCallPayload() {
    QualUjetSessionTriggerHandler.bypassInTests = false;
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 991,
      UJET__Call_Duration__c = 10,
      UJET__Status__c = 'finished'
    );
    insert session;
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Payload_Type__c, qual_Ujet_Session_Id__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Trigger should enqueue one Call payload'
    );
    System.assertEquals(
      QualCalloutService.PAYLOAD_TYPE_CALL,
      logs[0].qual_Payload_Type__c,
      'Log should be a Call payload'
    );
  }

  @IsTest
  static void testUjetSessionTrigger_DefersCallPayload_WhenDelayConfigured() {
    QualUjetSessionTriggerHandler.bypassInTests = false;
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCallDelay(
      45
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.startTest();
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 1001,
      UJET__Call_Duration__c = 10,
      UJET__Status__c = 'finished'
    );
    insert session;
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT
        Id,
        qual_Status__c,
        qual_Payload_Type__c,
        qual_Ujet_Session_Id__c,
        qual_Call_Id__c,
        qual_Event_Type__c,
        qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(1, logs.size(), 'Trigger should create one log');
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Call payload should be deferred'
    );
    System.assertEquals(
      QualCalloutService.PAYLOAD_TYPE_CALL,
      logs[0].qual_Payload_Type__c,
      'Deferred log should be a Call payload'
    );
    System.assertEquals(
      '1001',
      logs[0].qual_Call_Id__c,
      'Call ID should be set'
    );
    System.assertEquals(
      'Call',
      logs[0].qual_Event_Type__c,
      'Event type should be Call'
    );
    System.assert(
      logs[0].qual_Next_Retry_Date__c > Datetime.now().addMinutes(44),
      'Next retry date should be based on configured Call delay'
    );
  }

  @IsTest
  static void testExecute_SkipsAlreadySentSession() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      811,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-811.json',
      QualTestDataFactory.getSampleCallJson(811)
    );

    String sessionIdString = String.valueOf(session.Id);
    insert new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Status__c = 'Success',
      qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
      qual_Integration_Name__c = 'Qualtrics Call Survey',
      qual_Ujet_Session_Id__c = sessionIdString,
      qual_Call_Id__c = '811',
      qual_Processed_Date__c = Datetime.now()
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(
      new QualCallSessionQueueable(new List<Id>{ session.Id }, 1)
    );
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Already successful sessions should not be resent'
    );
  }

  @IsTest
  static void testExecute_SkipsSessionHeldByFutureDeferredLog() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      813,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-813.json',
      QualTestDataFactory.getSampleCallJson(813)
    );

    String sessionIdString = String.valueOf(session.Id);
    insert new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Status__c = 'Deferred',
      qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
      qual_Integration_Name__c = 'Qualtrics Call Survey',
      qual_Ujet_Session_Id__c = sessionIdString,
      qual_Call_Id__c = '813',
      qual_Next_Retry_Date__c = Datetime.now().addMinutes(30),
      qual_Processed_Date__c = Datetime.now()
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(
      new QualCallSessionQueueable(new List<Id>{ session.Id }, 1)
    );
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Future Deferred log should prevent the in-flight queueable from sending'
    );
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'The waiting Deferred log should remain queued for the scheduled job'
    );
  }

  @IsTest
  static void testExecute_MissingCallWorkflowDoesNotSend() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      812,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Call_Workflow_Id__c = null;
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Call payload should not send without a Call workflow ID'
    );
  }

  @IsTest
  static void testUjetSessionTrigger_UpdateEnqueuesCallPayload() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 992,
      UJET__Status__c = 'queued'
    );
    insert session;

    QualUjetSessionTriggerHandler.bypassInTests = false;
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    session.UJET__Status__c = 'finished';
    session.UJET__Call_Duration__c = 21;
    update session;
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Payload_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Updated UJET Session should enqueue one Call payload'
    );
    System.assertEquals(
      QualCalloutService.PAYLOAD_TYPE_CALL,
      logs[0].qual_Payload_Type__c,
      'Log should be a Call payload'
    );
  }

  @IsTest
  static void testUjetSessionTrigger_UpdateRefreshesExistingDeferredCallLog() {
    QualUjetSessionTriggerHandler.bypassInTests = false;
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCallDelay(
      45
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 1002,
      UJET__Status__c = 'queued'
    );
    insert session;

    String sessionIdString = String.valueOf(session.Id);
    qual_Integration_Log__c staleDeferredLog = [
      SELECT Id, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
      LIMIT 1
    ];
    staleDeferredLog.qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5);
    update staleDeferredLog;

    Test.startTest();
    session.UJET__Status__c = 'finished';
    session.UJET__Call_Duration__c = 25;
    update session;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Next_Retry_Date__c, qual_Call_Id__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Session update should refresh the pending deferred Call log, not create another'
    );
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Existing pending Call log should remain Deferred'
    );
    System.assertEquals(
      '1002',
      logs[0].qual_Call_Id__c,
      'Call ID should be preserved'
    );
    System.assert(
      logs[0].qual_Next_Retry_Date__c > Datetime.now().addMinutes(44),
      'Deferred Call log should be rescheduled from the latest qualifying update'
    );
  }

  @IsTest
  static void testUjetSessionTrigger_BlankWorkflowDoesNotEnqueue() {
    QualUjetSessionTriggerHandler.bypassInTests = false;
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Call_Workflow_Id__c = null;
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 993,
      UJET__Status__c = 'finished'
    );
    insert session;
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Trigger should not enqueue without a Call workflow ID'
    );
  }

  @IsTest
  static void testUjetSessionHandler_NoopsForEmptyAndUnchangedSessions() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Case testCase = [SELECT Id FROM Case LIMIT 1];
    QualUjetSessionTriggerHandler.bypassInTests = true;
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 994,
      UJET__Status__c = 'finished'
    );
    insert session;
    QualUjetSessionTriggerHandler.bypassInTests = false;
    QualUjetSessionTriggerHandler.resetRecursionGuard();

    Test.startTest();
    QualUjetSessionTriggerHandler.handleAfterInsert(
      new List<UJET__UJET_Session__c>()
    );
    QualUjetSessionTriggerHandler.handleAfterInsert(
      new List<UJET__UJET_Session__c>{
        new UJET__UJET_Session__c(UJET__Call_Id__c = 995)
      }
    );
    QualUjetSessionTriggerHandler.handleAfterUpdate(
      new List<UJET__UJET_Session__c>{ session },
      new Map<Id, UJET__UJET_Session__c>{ session.Id => session }
    );
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Call_Id__c IN ('994', '995')
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Empty, case-less, and unchanged sessions should not enqueue payloads'
    );
  }

  @IsTest
  static void testDeferredCallLog_IsPickedUpBySchedulable() {
    QualUjetSessionTriggerHandler.bypassInTests = false;
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCallDelay(
      45
    );
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 1003,
      UJET__Call_Duration__c = 55,
      UJET__Status__c = 'finished'
    );
    insert session;
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-1003.json',
      QualTestDataFactory.getSampleCallJson(1003)
    );

    String sessionIdString = String.valueOf(session.Id);
    qual_Integration_Log__c deferredLog = [
      SELECT Id, qual_Status__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
      LIMIT 1
    ];
    System.assertEquals(
      'Deferred',
      deferredLog.qual_Status__c,
      'Trigger should mark the Call log as Deferred before scheduler pickup'
    );
    deferredLog.qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5);
    update deferredLog;

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    qual_Integration_Log__c processedDeferredLog = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :deferredLog.Id
    ];
    System.assertEquals(
      'Processing',
      processedDeferredLog.qual_Status__c,
      'Schedulable should pick up due Deferred Call logs'
    );

    List<qual_Integration_Log__c> successLogs = [
      SELECT Id, qual_Status__c, qual_Payload_Type__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Ujet_Session_Id__c = :sessionIdString
        AND Id != :deferredLog.Id
        AND qual_Status__c = 'Success'
    ];
    System.assertEquals(
      1,
      successLogs.size(),
      'Schedulable should enqueue the Call queueable and create a Success log'
    );
    System.assertEquals(
      QualCalloutService.PAYLOAD_TYPE_CALL,
      successLogs[0].qual_Payload_Type__c,
      'Success log should be for the Call payload'
    );
    System.assert(
      successLogs[0].qual_Request_Body__c.contains('acw_duration'),
      'Deferred send should build payload after JSON attachment is available'
    );
  }

  @IsTest
  static void testExecute_BulkDeadLettersDoNotExhaustEmailInvocations() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    List<UJET__UJET_Session__c> sessions = new List<UJET__UJET_Session__c>();

    for (Integer i = 0; i < 12; i++) {
      sessions.add(
        new UJET__UJET_Session__c(
          UJET__Case__c = testCase.Id,
          UJET__Call_Id__c = 2000 + i,
          UJET__Call_Duration__c = 10,
          UJET__Status__c = 'finished'
        )
      );
    }
    insert sessions;

    List<Id> sessionIds = new List<Id>();
    Set<String> sessionIdStrings = new Set<String>();
    for (UJET__UJET_Session__c session : sessions) {
      sessionIds.add(session.Id);
      sessionIdStrings.add(String.valueOf(session.Id));
    }

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(sessionIds));
    Test.stopTest();

    Integer deadLetterCount = [
      SELECT COUNT()
      FROM qual_Integration_Log__c
      WHERE
        qual_Ujet_Session_Id__c IN :sessionIdStrings
        AND qual_Status__c = 'Dead Letter'
    ];
    System.assertEquals(
      12,
      deadLetterCount,
      'All missing-JSON sessions should become Dead Letter logs without failing the queueable'
    );
  }

  // ---------------------------------------------------------------------------
  // CALL-719 — contact.salesforceContactId survives the full queueable path
  // ---------------------------------------------------------------------------

  /**
   * @description End-to-end through the queueable: proves querySessions selects
   * the contact sources and that the resolved Id reaches the outbound body. A
   * missing field in that SELECT surfaces here as SObjectException, not at compile
   * time, which is why this test exercises the real queueable rather than calling
   * the builder directly.
   */
  @IsTest
  static void testExecute_CallPayloadCarriesCaseContactId() {
    Case testCase = [SELECT Id, ContactId FROM Case LIMIT 1];
    Assert.isNotNull(
      testCase.ContactId,
      'Test setup must give the Case a Contact for the fallback branch'
    );

    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      802,
      120,
      0,
      15,
      true
    );
    session.UJET__Status__c = 'finished';
    update session;
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-802.json',
      QualTestDataFactory.getSampleCallJson(802)
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    Assert.areEqual(1, logs.size(), 'Should create one Call log');

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      logs[0].qual_Request_Body__c
    );
    Assert.areEqual(
      new Set<String>{ 'call', 'case', 'contact', 'metadata' },
      payloadMap.keySet(),
      'Outbound Call payload roots must be call, case, contact and metadata'
    );

    Map<String, Object> contactData = (Map<String, Object>) payloadMap.get(
      'contact'
    );
    Assert.areEqual(
      String.valueOf(testCase.ContactId),
      (String) contactData.get('salesforceContactId'),
      'Outbound Call payload must carry the Case Contact Id'
    );
  }

  /**
   * @description A session with no Call Id cannot have its call JSON located, so
   * it must dead-letter with a message naming that cause rather than failing
   * opaquely or sending a partial payload.
   */
  @IsTest
  static void testExecute_SessionWithoutCallIdDeadLetters() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      null,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    String sessionIdString = String.valueOf(session.Id);
    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Error_Message__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];
    Assert.areEqual(1, logs.size(), 'Should create one Call log');
    Assert.areEqual(
      'Dead Letter',
      logs[0].qual_Status__c,
      'A session with no Call Id should dead-letter'
    );
    Assert.isTrue(
      logs[0].qual_Error_Message__c.contains('has no Call ID'),
      'Dead Letter should name the missing Call Id as the cause'
    );
    Assert.isNull(
      logs[0].qual_Request_Body__c,
      'No payload should be sent for a session that cannot be resolved'
    );
  }

  /**
   * @description An empty batch must no-op cleanly rather than querying or
   * logging. Guards the early returns that keep an empty enqueue from doing work.
   */
  @IsTest
  static void testExecute_EmptySessionListDoesNothing() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(
      new QualCallSessionQueueable(new List<Id>(), new Map<Id, Integer>())
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM qual_Integration_Log__c],
      'An empty batch must not create any integration log'
    );
  }

  /**
   * @description With the integration switched off, the queueable must return
   * before doing any work — no callout, no log.
   */
  @IsTest
  static void testExecute_InactiveConfigSkipsAllWork() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      1240,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    System.enqueueJob(new QualCallSessionQueueable(new List<Id>{ session.Id }));
    Test.stopTest();

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM qual_Integration_Log__c],
      'An inactive integration must not log or send anything'
    );
  }

  /**
   * @description A blank file name or a blank Call Id must never be treated as a
   * match — matching on blank input would attach an arbitrary file to a call.
   */
  @IsTest
  static void testFileNameContainsCallId_BlankInputsNeverMatch() {
    Assert.isFalse(
      QualCallSessionQueueable.fileNameContainsCallId(null, '801'),
      'A null file name must not match any Call Id'
    );
    Assert.isFalse(
      QualCallSessionQueueable.fileNameContainsCallId('', '801'),
      'An empty file name must not match any Call Id'
    );
    Assert.isFalse(
      QualCallSessionQueueable.fileNameContainsCallId('call-801.json', null),
      'A null Call Id must not match any file name'
    );
    Assert.isFalse(
      QualCallSessionQueueable.fileNameContainsCallId('call-801.json', '   '),
      'A blank Call Id must not match any file name'
    );
  }
}