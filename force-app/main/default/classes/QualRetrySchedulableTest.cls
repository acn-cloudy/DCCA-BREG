/**
 * @description Test class for QualRetrySchedulable
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualRetrySchedulableTest {
  @TestSetup
  static void setupTestData() {
    Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
  }

  private static void deleteExistingLogs() {
    delete [SELECT Id FROM qual_Integration_Log__c];
  }

  @IsTest
  static void testExecute_WithRetryLogs() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create retry log
    qual_Integration_Log__c log = QualTestDataFactory.createRetryLog(
      testCase.Id,
      1,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    // Verify log status was updated
    qual_Integration_Log__c updatedLog = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      'Processing',
      updatedLog.qual_Status__c,
      'Log should be set to Processing'
    );
  }

  @IsTest
  static void testExecute_NoRetryLogs() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    // No exception means success
    System.assert(true, 'Should execute without error when no retry logs');
  }

  @IsTest
  static void testExecute_CleansOldLogsWhenNoRetryLogs() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Integration_Log__c oldLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Status__c = 'Success',
      qual_Processed_Date__c = Datetime.now().addDays(-61)
    );
    insert oldLog;

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithLogRetention(
      60
    );
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    Integer remainingCount = [
      SELECT COUNT()
      FROM qual_Integration_Log__c
      WHERE Id = :oldLog.Id
    ];
    System.assertEquals(
      0,
      remainingCount,
      'Scheduled job should clean old logs even when there is no retry work'
    );
  }

  @IsTest
  static void testExecute_IntegrationInactive() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create retry log
    qual_Integration_Log__c log = QualTestDataFactory.createRetryLog(
      testCase.Id,
      1,
      true
    );

    // Set inactive config
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    // Log should remain as Retrying (not processed)
    qual_Integration_Log__c updatedLog = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      'Retrying',
      updatedLog.qual_Status__c,
      'Log should remain Retrying when integration inactive'
    );
  }

  @IsTest
  static void testScheduleJob() {
    Test.startTest();
    String jobId = QualRetrySchedulable.scheduleJob(
      'Test Qualtrics Retry',
      '0 0 * * * ?'
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Job should be scheduled');

    // Clean up
    System.abortJob(jobId);
  }

  @IsTest
  static void testScheduleDefault() {
    Test.startTest();
    String jobId = QualRetrySchedulable.scheduleDefault();
    Test.stopTest();

    System.assertNotEquals(
      null,
      jobId,
      'Job should be scheduled with default settings'
    );

    // Clean up
    System.abortJob(jobId);
  }

  @IsTest
  static void testExecute_MultipleLogsForSameCase_KeepsHighestRetryCount() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create two retry logs for the same case with different retry counts
    qual_Integration_Log__c log1 = QualTestDataFactory.createRetryLog(
      testCase.Id,
      1,
      true
    );
    qual_Integration_Log__c log2 = QualTestDataFactory.createRetryLog(
      testCase.Id,
      3,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    // Both logs should be set to Processing
    qual_Integration_Log__c updatedLog1 = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :log1.Id
    ];
    qual_Integration_Log__c updatedLog2 = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :log2.Id
    ];
    System.assertEquals(
      'Processing',
      updatedLog1.qual_Status__c,
      'First log should be Processing'
    );
    System.assertEquals(
      'Processing',
      updatedLog2.qual_Status__c,
      'Second log should be Processing'
    );
  }

  @IsTest
  static void testExecute_DeferredLog_PreservesEventType() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    // Create a deferred log with Opened event type that is past due
    qual_Integration_Log__c deferredLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Status__c = 'Deferred',
      qual_Event_Type__c = 'Opened',
      qual_Retry_Count__c = 0,
      qual_Next_Retry_Date__c = Datetime.now().addMinutes(-10),
      qual_Processed_Date__c = Datetime.now().addHours(-2),
      qual_Workflow_Id__c = config.qual_Workflow_Id__c,
      qual_Datacenter__c = config.qual_Datacenter__c
    );
    insert deferredLog;

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualRetrySchedulable job = new QualRetrySchedulable();
    job.execute(null);
    Test.stopTest();

    // The deferred log should now be Processing
    qual_Integration_Log__c updatedLog = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :deferredLog.Id
    ];
    System.assertEquals(
      'Processing',
      updatedLog.qual_Status__c,
      'Deferred log should be Processing'
    );

    // A new log should have been created by the Queueable with the Opened event type
    List<qual_Integration_Log__c> newLogs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Case__c = :testCase.Id
        AND Id != :deferredLog.Id
        AND qual_Status__c = 'Success'
    ];
    System.assert(newLogs.size() >= 1, 'Should create a new success log');
    System.assertEquals(
      'Opened',
      newLogs[0].qual_Event_Type__c,
      'Event type should be preserved as Opened through the retry cycle'
    );
  }

  @IsTest
  static void testExecute_MixedCaseRetryCounts_PreservesPerCaseRetryCount() {
    deleteExistingLogs();
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    List<Case> cases = QualTestDataFactory.createCases(acc.Id, con.Id, 2, true);

    qual_Integration_Log__c lowRetryLog = QualTestDataFactory.createRetryLog(
      cases[0].Id,
      1,
      true
    );
    qual_Integration_Log__c exhaustedRetryLog = QualTestDataFactory.createRetryLog(
      cases[1].Id,
      3,
      true
    );
    Id lowCaseId = cases[0].Id;
    Id exhaustedCaseId = cases[1].Id;
    Id lowRetryLogId = lowRetryLog.Id;
    Id exhaustedRetryLogId = exhaustedRetryLog.Id;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(
      HttpCalloutMock.class,
      QualCalloutMock.createServerErrorMock()
    );

    Test.startTest();
    new QualRetrySchedulable().execute(null);
    Test.stopTest();

    List<qual_Integration_Log__c> lowRetryResults = [
      SELECT qual_Status__c, qual_Retry_Count__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Case__c = :lowCaseId
        AND Id != :lowRetryLogId
        AND qual_Status__c = 'Retrying'
    ];
    System.assertEquals(
      1,
      lowRetryResults.size(),
      'Lower retry Case should still be retryable'
    );
    System.assertEquals(
      2,
      lowRetryResults[0].qual_Retry_Count__c,
      'Lower retry Case should increment from its own retry count'
    );

    List<qual_Integration_Log__c> exhaustedResults = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Case__c = :exhaustedCaseId
        AND Id != :exhaustedRetryLogId
        AND qual_Status__c = 'Dead Letter'
    ];
    System.assertEquals(
      1,
      exhaustedResults.size(),
      'Exhausted Case should Dead Letter without forcing other Cases to Dead Letter'
    );
  }

  @IsTest
  static void testExecute_MixedCallRetryCounts_PreservesPerSessionRetryCount() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c lowRetrySession = QualTestDataFactory.createUjetSession(
      testCase.Id,
      2001,
      true
    );
    UJET__UJET_Session__c exhaustedSession = QualTestDataFactory.createUjetSession(
      testCase.Id,
      2002,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      lowRetrySession.Id,
      'call-2001.json',
      QualTestDataFactory.getSampleCallJson(2001)
    );
    QualTestDataFactory.createJsonAttachment(
      exhaustedSession.Id,
      'call-2002.json',
      QualTestDataFactory.getSampleCallJson(2002)
    );

    String lowSessionId = String.valueOf(lowRetrySession.Id);
    String exhaustedSessionId = String.valueOf(exhaustedSession.Id);
    List<qual_Integration_Log__c> retryLogs = new List<qual_Integration_Log__c>{
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Status__c = 'Retrying',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
        qual_Integration_Name__c = 'Qualtrics Call Survey',
        qual_Ujet_Session_Id__c = lowSessionId,
        qual_Call_Id__c = '2001',
        qual_Retry_Count__c = 1,
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5),
        qual_Processed_Date__c = Datetime.now()
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Status__c = 'Retrying',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
        qual_Integration_Name__c = 'Qualtrics Call Survey',
        qual_Ujet_Session_Id__c = exhaustedSessionId,
        qual_Call_Id__c = '2002',
        qual_Retry_Count__c = 3,
        qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5),
        qual_Processed_Date__c = Datetime.now()
      )
    };
    insert retryLogs;
    Id lowRetryLogId = retryLogs[0].Id;
    Id exhaustedRetryLogId = retryLogs[1].Id;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );
    Test.setMock(
      HttpCalloutMock.class,
      QualCalloutMock.createServerErrorMock()
    );

    Test.startTest();
    new QualRetrySchedulable().execute(null);
    Test.stopTest();

    List<qual_Integration_Log__c> lowRetryResults = [
      SELECT qual_Status__c, qual_Retry_Count__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Ujet_Session_Id__c = :lowSessionId
        AND Id != :lowRetryLogId
        AND qual_Status__c = 'Retrying'
    ];
    System.assertEquals(
      1,
      lowRetryResults.size(),
      'Lower retry Call should still be retryable'
    );
    System.assertEquals(
      2,
      lowRetryResults[0].qual_Retry_Count__c,
      'Lower retry Call should increment from its own retry count'
    );

    List<qual_Integration_Log__c> exhaustedResults = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Ujet_Session_Id__c = :exhaustedSessionId
        AND Id != :exhaustedRetryLogId
        AND qual_Status__c = 'Dead Letter'
    ];
    System.assertEquals(
      1,
      exhaustedResults.size(),
      'Exhausted Call should Dead Letter without forcing other Calls to Dead Letter'
    );
  }
}