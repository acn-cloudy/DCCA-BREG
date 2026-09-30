/**
 * @description Test class for QualIntegrationLogger
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualIntegrationLoggerTest {
  @TestSetup
  static void setupTestData() {
    Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
  }

  private static void deleteExistingLogs() {
    delete [SELECT Id FROM qual_Integration_Log__c];
  }

  @IsTest
  static void testLogSuccess() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    HttpResponse response = new HttpResponse();
    response.setStatusCode(200);
    response.setBody(
      '{"result": {"eventId": "EVT_json_test123"}, "meta": {"httpStatus": "200 - OK", "requestId": "test-req-123"}}'
    );

    Test.startTest();
    Id logId = QualIntegrationLogger.logSuccess(
      testCase.Id,
      '{"test": "payload"}',
      response,
      config
    );
    Test.stopTest();

    System.assertNotEquals(null, logId, 'Log ID should not be null');

    qual_Integration_Log__c log = [
      SELECT
        Id,
        qual_Status__c,
        qual_Status_Code__c,
        qual_Case__c,
        qual_Qualtrics_Event_Id__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertEquals(
      'Success',
      log.qual_Status__c,
      'Status should be Success'
    );
    System.assertEquals(
      200,
      log.qual_Status_Code__c,
      'Status code should be 200'
    );
    System.assertEquals(testCase.Id, log.qual_Case__c, 'Case should match');
    System.assertEquals(
      'EVT_json_test123',
      log.qual_Qualtrics_Event_Id__c,
      'Qualtrics Event ID should be stored'
    );
  }

  @IsTest
  static void testLogSuccess_StoresQualtricsEventId() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    HttpResponse response = new HttpResponse();
    response.setStatusCode(202);
    response.setBody(
      '{"result": {"eventId": "EVT_json_ReconcileMe123"}, "meta": {"httpStatus": "202 - Accepted", "requestId": "req-abc"}}'
    );

    Test.startTest();
    Id logId = QualIntegrationLogger.logSuccess(
      testCase.Id,
      '{"case": "data"}',
      response,
      config
    );
    Test.stopTest();

    qual_Integration_Log__c log = [
      SELECT
        qual_Status__c,
        qual_Qualtrics_Event_Id__c,
        qual_Workflow_Execution_Id__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertEquals(
      'Success',
      log.qual_Status__c,
      'Status should be Success'
    );
    System.assertEquals(
      'EVT_json_ReconcileMe123',
      log.qual_Qualtrics_Event_Id__c,
      'Qualtrics Event ID should be stored for reconciliation'
    );
    System.assertEquals(
      'req-abc',
      log.qual_Workflow_Execution_Id__c,
      'Request ID should also be stored'
    );
  }

  @IsTest
  static void testLogRetry() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    HttpResponse response = new HttpResponse();
    response.setStatusCode(500);
    response.setBody('{"meta": {"error": {"errorMessage": "Server error"}}}');

    Test.startTest();
    Id logId = QualIntegrationLogger.logRetry(
      testCase.Id,
      '{"test": "payload"}',
      response,
      1,
      null,
      null,
      config
    );
    Test.stopTest();

    System.assertNotEquals(null, logId, 'Log ID should not be null');

    qual_Integration_Log__c log = [
      SELECT Id, qual_Status__c, qual_Retry_Count__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertEquals(
      'Retrying',
      log.qual_Status__c,
      'Status should be Retrying'
    );
    System.assertEquals(1, log.qual_Retry_Count__c, 'Retry count should be 1');
    System.assertNotEquals(
      null,
      log.qual_Next_Retry_Date__c,
      'Next retry date should be set'
    );
  }

  @IsTest
  static void testLogRetry_NoResponse_UsesProvidedError() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    Id logId = QualIntegrationLogger.logRetry(
      testCase.Id,
      '{"test": "payload"}',
      null,
      1,
      'Endpoint unreachable',
      'Stack trace here',
      config
    );
    Test.stopTest();

    qual_Integration_Log__c log = [
      SELECT qual_Status__c, qual_Error_Message__c, qual_Stack_Trace__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertEquals(
      'Retrying',
      log.qual_Status__c,
      'Status should be Retrying'
    );
    System.assert(
      log.qual_Error_Message__c.contains('Endpoint unreachable'),
      'Should store provided error message'
    );
    System.assert(
      log.qual_Stack_Trace__c.contains('Stack trace'),
      'Should store provided stack trace'
    );
  }

  @IsTest
  static void testLogDeadLetter() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    HttpResponse response = new HttpResponse();
    response.setStatusCode(400);
    response.setBody('{"meta": {"error": {"errorMessage": "Bad request"}}}');

    Test.startTest();
    Id logId = QualIntegrationLogger.logDeadLetter(
      testCase.Id,
      '{"test": "payload"}',
      response,
      'Max retries exceeded',
      'Stack trace here',
      config
    );
    Test.stopTest();

    System.assertNotEquals(null, logId, 'Log ID should not be null');

    qual_Integration_Log__c log = [
      SELECT Id, qual_Status__c, qual_Error_Message__c, qual_Stack_Trace__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertEquals(
      'Dead Letter',
      log.qual_Status__c,
      'Status should be Dead Letter'
    );
    System.assert(
      log.qual_Error_Message__c.contains('Max retries'),
      'Error message should be set'
    );
    System.assert(
      log.qual_Stack_Trace__c.contains('Stack trace'),
      'Stack trace should be set'
    );
  }

  @IsTest
  static void testLogException() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Exception testException;
    try {
      Integer x = 1 / 0;
    } catch (Exception ex) {
      testException = ex;
    }

    Test.startTest();
    Id logId = QualIntegrationLogger.logException(
      testCase.Id,
      '{"test": "payload"}',
      testException,
      config
    );
    Test.stopTest();

    System.assertNotEquals(null, logId, 'Log ID should not be null');

    qual_Integration_Log__c log = [
      SELECT Id, qual_Status__c, qual_Error_Message__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertEquals(
      'Failed',
      log.qual_Status__c,
      'Status should be Failed'
    );
    System.assertNotEquals(
      null,
      log.qual_Error_Message__c,
      'Error message should be set'
    );
  }

  @IsTest
  static void testUpdateLogStatus() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Integration_Log__c log = QualTestDataFactory.createIntegrationLog(
      testCase.Id,
      'New',
      true
    );

    Test.startTest();
    QualIntegrationLogger.updateLogStatus(log.Id, 'Processing');
    Test.stopTest();

    qual_Integration_Log__c updatedLog = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      'Processing',
      updatedLog.qual_Status__c,
      'Status should be updated'
    );
  }

  @IsTest
  static void testGetLogsForRetry() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create retry log with past next retry date
    qual_Integration_Log__c log = QualTestDataFactory.createRetryLog(
      testCase.Id,
      1,
      true
    );

    Test.startTest();
    List<qual_Integration_Log__c> logsForRetry = QualIntegrationLogger.getLogsForRetry();
    Test.stopTest();

    System.assert(
      logsForRetry.size() >= 1,
      'Should find at least one log for retry'
    );
  }

  @IsTest
  static void testCreateBaseLog_SetsEventType() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Set event type map
    Map<Id, String> eventTypeMap = new Map<Id, String>{
      testCase.Id => 'Opened'
    };
    QualIntegrationLogger.setEventTypeMap(eventTypeMap);

    Test.startTest();
    qual_Integration_Log__c log = QualIntegrationLogger.createSuccessLog(
      testCase.Id,
      '{"test":"payload"}',
      QualCalloutMock.createSuccessMock().respond(new HttpRequest()),
      config
    );
    Test.stopTest();

    System.assertNotEquals(null, log, 'Log should not be null');
    System.assertEquals(
      'Opened',
      log.qual_Event_Type__c,
      'Event type should be set to Opened'
    );
  }

  @IsTest
  static void testCreateBaseLog_NoEventType() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Clear event type map
    QualIntegrationLogger.setEventTypeMap(new Map<Id, String>());

    Test.startTest();
    qual_Integration_Log__c log = QualIntegrationLogger.createSuccessLog(
      testCase.Id,
      '{"test":"payload"}',
      QualCalloutMock.createSuccessMock().respond(new HttpRequest()),
      config
    );
    Test.stopTest();

    System.assertNotEquals(null, log, 'Log should not be null');
    System.assertEquals(
      null,
      log.qual_Event_Type__c,
      'Event type should be null when not set'
    );
  }

  // ========== Deferred Log Tests ==========

  @IsTest
  static void testCreateDeferredLog() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    QualIntegrationLogger.createDeferredLog(testCase.Id, 'Opened', 120, config);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT
        qual_Status__c,
        qual_Event_Type__c,
        qual_Next_Retry_Date__c,
        qual_Retry_Count__c,
        qual_Workflow_Id__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Status__c = 'Deferred'
    ];
    System.assertEquals(1, logs.size(), 'Should create one deferred log');
    System.assertEquals(
      'Opened',
      logs[0].qual_Event_Type__c,
      'Event type should be Opened'
    );
    System.assertEquals(
      0,
      logs[0].qual_Retry_Count__c,
      'Retry count should be 0'
    );
    System.assertNotEquals(
      null,
      logs[0].qual_Next_Retry_Date__c,
      'Next retry date should be set'
    );
    System.assertEquals(
      config.qual_Case_Workflow_Id__c,
      logs[0].qual_Workflow_Id__c,
      'Workflow ID should match Case workflow config'
    );
  }

  @IsTest
  static void testCreateDeferredLogs_Bulk() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    List<Case> moreCases = QualTestDataFactory.createCases(
      acc.Id,
      con.Id,
      3,
      true
    );
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Map<Id, String> caseEventMap = new Map<Id, String>();
    caseEventMap.put(testCase.Id, 'Opened');
    for (Case c : moreCases) {
      caseEventMap.put(c.Id, 'Opened');
    }

    Test.startTest();
    QualIntegrationLogger.createDeferredLogs(caseEventMap, 60, config);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Status__c = 'Deferred'
    ];
    System.assertEquals(
      4,
      logs.size(),
      'Should create deferred log for each case'
    );
  }

  @IsTest
  static void testCreateDeferredLogs_RefreshesExistingCaseDeferredLog() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    QualIntegrationLogger.createDeferredLog(testCase.Id, 'Opened', 120, config);
    qual_Integration_Log__c originalLog = [
      SELECT Id, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Status__c = 'Deferred'
      LIMIT 1
    ];
    originalLog.qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5);
    update originalLog;

    Test.startTest();
    QualIntegrationLogger.createDeferredLogs(
      new Map<Id, String>{ testCase.Id => 'Updated' },
      120,
      config
    );
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Latest Case deferral should refresh the pending row, not insert another'
    );
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Refreshed Case log should remain Deferred'
    );
    System.assertEquals(
      'Updated',
      logs[0].qual_Event_Type__c,
      'Latest Case event should win'
    );
    System.assert(
      logs[0].qual_Next_Retry_Date__c > Datetime.now().addMinutes(119),
      'Refreshed Case log should be rescheduled from the latest event'
    );
  }

  @IsTest
  static void testCreateDeferredLogs_CancelsDuplicateCaseDeferredLogs() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    List<qual_Integration_Log__c> duplicateDeferredLogs = new List<qual_Integration_Log__c>{
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE,
        qual_Status__c = 'Deferred',
        qual_Event_Type__c = 'Opened',
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(10),
        qual_Processed_Date__c = Datetime.now()
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE,
        qual_Status__c = 'Deferred',
        qual_Event_Type__c = 'Opened',
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(20),
        qual_Processed_Date__c = Datetime.now()
      )
    };
    insert duplicateDeferredLogs;

    Test.startTest();
    QualIntegrationLogger.createDeferredLogs(
      new Map<Id, String>{ testCase.Id => 'Updated' },
      120,
      config
    );
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Event_Type__c, qual_Error_Message__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    Integer deferredCount = 0;
    Integer cancelledCount = 0;
    for (qual_Integration_Log__c log : logs) {
      if (log.qual_Status__c == 'Deferred') {
        deferredCount++;
        System.assertEquals(
          'Updated',
          log.qual_Event_Type__c,
          'Remaining Deferred Case log should use latest event'
        );
      } else if (log.qual_Status__c == 'Cancelled') {
        cancelledCount++;
        System.assert(
          log.qual_Error_Message__c.contains('Superseded'),
          'Cancelled duplicate should explain that it was superseded'
        );
      }
    }
    System.assertEquals(
      1,
      deferredCount,
      'Only one Case Deferred log should remain active'
    );
    System.assertEquals(
      1,
      cancelledCount,
      'Duplicate Case Deferred log should be cancelled'
    );
  }

  @IsTest
  static void testCancelDeferredLogs() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    QualIntegrationLogger.createDeferredLog(testCase.Id, 'Opened', 120, config);

    Test.startTest();
    QualIntegrationLogger.cancelDeferredLogs(new Set<Id>{ testCase.Id });
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Error_Message__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(1, logs.size(), 'Should still have one log');
    System.assertEquals(
      'Cancelled',
      logs[0].qual_Status__c,
      'Status should be Cancelled'
    );
    System.assert(
      logs[0].qual_Error_Message__c.contains('Superseded'),
      'Should note superseded'
    );
  }

  @IsTest
  static void testCancelDeferredLogs_EmptySet() {
    Test.startTest();
    QualIntegrationLogger.cancelDeferredLogs(new Set<Id>());
    QualIntegrationLogger.cancelDeferredLogs(null);
    Test.stopTest();
    // No exception means success
    System.assert(true, 'Should handle empty/null gracefully');
  }

  @IsTest
  static void testLogSuccess_ErrorLogLevel_ReturnsNull() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Error';

    HttpResponse response = new HttpResponse();
    response.setStatusCode(200);
    response.setBody(
      '{"meta": {"httpStatus": "200 - OK", "requestId": "test-123"}}'
    );

    Test.startTest();
    Id logId = QualIntegrationLogger.logSuccess(
      testCase.Id,
      '{"test": "payload"}',
      response,
      config
    );
    Test.stopTest();

    System.assertEquals(
      null,
      logId,
      'logSuccess should return null when logLevel is Error'
    );
  }

  @IsTest
  static void testCreateSuccessLog_ErrorLogLevel_ReturnsNull() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Error';

    HttpResponse response = new HttpResponse();
    response.setStatusCode(200);
    response.setBody(
      '{"meta": {"httpStatus": "200 - OK", "requestId": "test-123"}}'
    );

    Test.startTest();
    qual_Integration_Log__c log = QualIntegrationLogger.createSuccessLog(
      testCase.Id,
      '{"test": "payload"}',
      response,
      config
    );
    Test.stopTest();

    System.assertEquals(
      null,
      log,
      'createSuccessLog should return null when logLevel is Error'
    );
  }

  @IsTest
  static void testLogSuccess_DebugLogLevel_IncludesBody() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';

    HttpResponse response = new HttpResponse();
    response.setStatusCode(200);
    response.setBody(
      '{"result": {"eventId": "EVT_debug"}, "meta": {"httpStatus": "200 - OK", "requestId": "req-debug"}}'
    );

    Test.startTest();
    Id logId = QualIntegrationLogger.logSuccess(
      testCase.Id,
      '{"test": "debug-payload"}',
      response,
      config
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      logId,
      'Log ID should not be null for Debug level'
    );

    qual_Integration_Log__c log = [
      SELECT qual_Request_Body__c, qual_Response_Body__c
      FROM qual_Integration_Log__c
      WHERE Id = :logId
    ];
    System.assertNotEquals(
      null,
      log.qual_Request_Body__c,
      'Request body should be preserved at Debug level'
    );
    System.assertNotEquals(
      null,
      log.qual_Response_Body__c,
      'Response body should be preserved at Debug level'
    );
  }

  @IsTest
  static void testCreateDeferredLog_NullConfig() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    Test.startTest();
    QualIntegrationLogger.createDeferredLog(testCase.Id, 'Opened', 60, null);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Workflow_Id__c, qual_Datacenter__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Status__c = 'Deferred'
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Should create deferred log even with null config'
    );
    System.assertEquals(
      null,
      logs[0].qual_Workflow_Id__c,
      'Workflow ID should be null'
    );
    System.assertEquals(
      null,
      logs[0].qual_Datacenter__c,
      'Datacenter should be null'
    );
  }

  @IsTest
  static void testCreateDeferredLogs_EmptyMap() {
    deleteExistingLogs();
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Integer logCountBefore = [SELECT COUNT() FROM qual_Integration_Log__c];

    Test.startTest();
    QualIntegrationLogger.createDeferredLogs(new Map<Id, String>(), 60, config);
    Test.stopTest();

    Integer logCountAfter = [SELECT COUNT() FROM qual_Integration_Log__c];
    System.assertEquals(
      logCountBefore,
      logCountAfter,
      'Should not create logs for empty map'
    );
  }

  @IsTest
  static void testGetLogsForRetry_IncludesDeferredLogs() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Create a deferred log that is past due
    qual_Integration_Log__c log = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Status__c = 'Deferred',
      qual_Event_Type__c = 'Opened',
      qual_Retry_Count__c = 0,
      qual_Next_Retry_Date__c = Datetime.now().addMinutes(-10),
      qual_Processed_Date__c = Datetime.now().addHours(-2),
      qual_Workflow_Id__c = config.qual_Workflow_Id__c
    );
    insert log;

    Test.startTest();
    List<qual_Integration_Log__c> logsForRetry = QualIntegrationLogger.getLogsForRetry();
    Test.stopTest();

    Boolean foundDeferred = false;
    for (qual_Integration_Log__c l : logsForRetry) {
      if (l.Id == log.Id && l.qual_Status__c == 'Deferred') {
        foundDeferred = true;
        break;
      }
    }
    System.assert(
      foundDeferred,
      'Should include deferred logs that are past due'
    );
  }

  @IsTest
  static void testGetLogsForRetry_ExcludesFutureDeferredLogs() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    qual_Integration_Log__c futureDeferredLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Status__c = 'Deferred',
      qual_Event_Type__c = 'Opened',
      qual_Retry_Count__c = 0,
      qual_Next_Retry_Date__c = Datetime.now().addMinutes(30),
      qual_Processed_Date__c = Datetime.now(),
      qual_Workflow_Id__c = config.qual_Workflow_Id__c
    );
    insert futureDeferredLog;

    Test.startTest();
    List<qual_Integration_Log__c> logsForRetry = QualIntegrationLogger.getLogsForRetry();
    Test.stopTest();

    Set<Id> retryLogIds = new Map<Id, qual_Integration_Log__c>(logsForRetry)
      .keySet();
    System.assert(
      !retryLogIds.contains(futureDeferredLog.Id),
      'Future Deferred logs should stay out of scheduler pickup'
    );
  }

  @IsTest
  static void testCreateOrRefreshDeferredCallLogs_CancelsDuplicateDeferredLogs() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      1004,
      true
    );
    String sessionIdString = String.valueOf(session.Id);

    List<qual_Integration_Log__c> duplicateDeferredLogs = new List<qual_Integration_Log__c>{
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Call Survey',
        qual_Status__c = 'Deferred',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
        qual_Ujet_Session_Id__c = sessionIdString,
        qual_Call_Id__c = '1004',
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(5),
        qual_Processed_Date__c = Datetime.now()
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Call Survey',
        qual_Status__c = 'Deferred',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
        qual_Ujet_Session_Id__c = sessionIdString,
        qual_Call_Id__c = '1004',
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(10),
        qual_Processed_Date__c = Datetime.now()
      )
    };
    insert duplicateDeferredLogs;

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCallDelay(
      45
    );

    Test.startTest();
    QualIntegrationLogger.createOrRefreshDeferredCallLogs(
      new List<UJET__UJET_Session__c>{ session },
      45,
      config
    );
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT qual_Status__c, qual_Error_Message__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Ujet_Session_Id__c = :sessionIdString
    ];

    Integer deferredCount = 0;
    Integer cancelledCount = 0;
    for (qual_Integration_Log__c log : logs) {
      if (log.qual_Status__c == 'Deferred') {
        deferredCount++;
        System.assert(
          log.qual_Next_Retry_Date__c > Datetime.now().addMinutes(44),
          'Remaining Deferred Call log should be refreshed from latest update'
        );
      } else if (log.qual_Status__c == 'Cancelled') {
        cancelledCount++;
        System.assert(
          log.qual_Error_Message__c.contains('Superseded'),
          'Cancelled duplicate should explain that it was superseded'
        );
      }
    }

    System.assertEquals(2, logs.size(), 'Should keep log history intact');
    System.assertEquals(
      1,
      deferredCount,
      'Only one Deferred Call log should remain active per session'
    );
    System.assertEquals(
      1,
      cancelledCount,
      'Duplicate Deferred Call logs should be cancelled'
    );
  }

  @IsTest
  static void testRecoverStaleProcessingLogs_ResetsWithoutFollowUp() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Integration_Log__c processingLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE,
      qual_Status__c = 'Processing',
      qual_Event_Type__c = 'Updated',
      qual_Retry_Count__c = 1,
      qual_Processed_Date__c = Datetime.now().addHours(-3)
    );
    insert processingLog;

    Test.startTest();
    Integer recoveredCount = QualIntegrationLogger.recoverStaleProcessingLogs(
      120
    );
    Test.stopTest();

    qual_Integration_Log__c recovered = [
      SELECT qual_Status__c, qual_Next_Retry_Date__c, qual_Error_Message__c
      FROM qual_Integration_Log__c
      WHERE Id = :processingLog.Id
    ];
    System.assertEquals(
      1,
      recoveredCount,
      'Should recover one stale Processing log'
    );
    System.assertEquals(
      'Retrying',
      recovered.qual_Status__c,
      'Stale Processing log should be reset to Retrying'
    );
    System.assert(
      recovered.qual_Next_Retry_Date__c <= Datetime.now(),
      'Recovered log should be immediately eligible for retry'
    );
    System.assert(
      recovered.qual_Error_Message__c.contains('Recovered stale Processing'),
      'Recovered log should explain why it was reset'
    );
  }

  @IsTest
  static void testRecoverStaleProcessingLogs_SkipsWhenNewerFollowUpExists() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Integration_Log__c processingLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE,
      qual_Status__c = 'Processing',
      qual_Event_Type__c = 'Updated',
      qual_Retry_Count__c = 1,
      qual_Processed_Date__c = Datetime.now().addHours(-3)
    );
    insert processingLog;
    insert new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE,
      qual_Status__c = 'Success',
      qual_Event_Type__c = 'Updated',
      qual_Processed_Date__c = Datetime.now()
    );

    Test.startTest();
    Integer recoveredCount = QualIntegrationLogger.recoverStaleProcessingLogs(
      120
    );
    Test.stopTest();

    qual_Integration_Log__c untouched = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :processingLog.Id
    ];
    System.assertEquals(
      0,
      recoveredCount,
      'Should not recover stale Processing when a newer follow-up exists'
    );
    System.assertEquals(
      'Processing',
      untouched.qual_Status__c,
      'Original Processing log should remain untouched'
    );
  }

  @IsTest
  static void testDeleteLogsOlderThan_RemovesOldNonActiveLogsOnly() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    Datetime oldProcessedDate = Datetime.now().addDays(-61);
    Datetime recentProcessedDate = Datetime.now().addDays(-10);

    List<qual_Integration_Log__c> logs = new List<qual_Integration_Log__c>{
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Status__c = 'Success',
        qual_Processed_Date__c = oldProcessedDate
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Status__c = 'Processing',
        qual_Processed_Date__c = oldProcessedDate
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Status__c = 'Deferred',
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(30),
        qual_Processed_Date__c = oldProcessedDate
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Status__c = 'Retrying',
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(30),
        qual_Processed_Date__c = oldProcessedDate
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Integration_Name__c = 'Qualtrics Case Survey',
        qual_Status__c = 'Success',
        qual_Processed_Date__c = recentProcessedDate
      )
    };
    insert logs;

    Test.startTest();
    Integer deletedCount = QualIntegrationLogger.deleteLogsOlderThan(60);
    Test.stopTest();

    System.assertEquals(
      2,
      deletedCount,
      'Should delete old terminal and stale processing logs only'
    );

    Set<Id> logIds = new Set<Id>();
    for (qual_Integration_Log__c log : logs) {
      logIds.add(log.Id);
    }

    Set<Id> remainingLogIds = new Map<Id, qual_Integration_Log__c>(
        [
          SELECT Id
          FROM qual_Integration_Log__c
          WHERE Id IN :logIds
        ]
      )
      .keySet();

    System.assert(
      !remainingLogIds.contains(logs[0].Id),
      'Old Success log should be deleted'
    );
    System.assert(
      !remainingLogIds.contains(logs[1].Id),
      'Old Processing log should be deleted'
    );
    System.assert(
      remainingLogIds.contains(logs[2].Id),
      'Deferred logs should remain because they are pending work'
    );
    System.assert(
      remainingLogIds.contains(logs[3].Id),
      'Retrying logs should remain because they are pending work'
    );
    System.assert(
      remainingLogIds.contains(logs[4].Id),
      'Recent logs should remain inside the retention window'
    );
  }
}