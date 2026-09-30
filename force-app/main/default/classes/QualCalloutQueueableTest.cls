/**
 * @description Test class for QualCalloutQueueable
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualCalloutQueueableTest {
  @TestSetup
  static void setupTestData() {
    Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
  }

  private static void deleteExistingLogs() {
    delete [SELECT Id FROM qual_Integration_Log__c];
  }

  @IsTest
  static void testExecute_Success() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create at least one log');
  }

  @IsTest
  static void testExecute_IntegrationInactive() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Set inactive config
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify no log was created (integration inactive)
    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should not create log when integration is inactive'
    );
  }

  @IsTest
  static void testExecute_WithRetryCount() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id },
      2
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');
  }

  @IsTest
  static void testExecute_Failure() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Max_Retries__c = 0; // No retries
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(
      HttpCalloutMock.class,
      QualCalloutMock.createServerErrorMock()
    );

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id },
      0
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify dead letter log was created
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');
  }

  @IsTest
  static void testExecute_MultipleCases() {
    deleteExistingLogs();
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    List<Case> cases = QualTestDataFactory.createCases(acc.Id, con.Id, 5, true);
    List<Id> caseIds = new List<Id>();
    for (Case c : cases) {
      caseIds.add(c.Id);
    }

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(caseIds);
    System.enqueueJob(job);
    Test.stopTest();

    // Verify logs were created for all cases
    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c IN :caseIds
    ];
    System.assertEquals(5, logs.size(), 'Should create log for each case');
  }

  @IsTest
  static void testExecute_WithUserTeamAndManager() {
    // Create test user with team and manager
    User testUser = QualTestDataFactory.createTestUserWithTeam(true);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    // Create case owned by user with team data
    Case testCase;
    System.runAs(testUser) {
      testCase = new Case(
        AccountId = acc.Id,
        ContactId = con.Id,
        Status = 'New',
        Subject = 'Test Case with Team Owner',
        OwnerId = testUser.Id
      );
      insert testCase;
    }

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created with enriched user data
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    // Verify the payload contains team info (if request body is not null)
    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        requestBody.contains('"teamId"'),
        'Payload should contain teamId'
      );
      System.assert(
        requestBody.contains('DCCA'),
        'Payload should contain DCCA team'
      );
    }
  }

  @IsTest
  static void testExecute_WithSingleUjetSession() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session with Call ID
    QualTestDataFactory.createUjetSession(testCase.Id, 123456789, true);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created with Call ID in payload
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    // Verify the payload contains callIds array (if request body is not null)
    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        requestBody.contains('"callIds"'),
        'Payload should contain callIds field'
      );
      System.assert(
        requestBody.contains('123456789'),
        'Payload should contain the Call ID'
      );
    }
  }

  @IsTest
  static void testExecute_WithMultipleUjetSessions() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create multiple UJET Sessions with different Call IDs
    QualTestDataFactory.createUjetSessions(
      testCase.Id,
      new List<Decimal>{ 111111111, 222222222, 333333333 },
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created with Call IDs in payload
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    // Verify the payload contains callIds array with multiple values
    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        requestBody.contains('"callIds"'),
        'Payload should contain callIds field'
      );
      // Verify at least one call ID is present
      System.assert(
        requestBody.contains('111111111') ||
          requestBody.contains('222222222') ||
          requestBody.contains('333333333'),
        'Payload should contain at least one Call ID'
      );
    }
  }

  @IsTest
  static void testExecute_WithUjetSessionNoCallId() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session without Call ID
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id
      // UJET__Call_Id__c is null
    );
    insert session;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created - should not have callIds since session has no Call ID
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');
  }

  @IsTest
  static void testExecute_WithNoUjetSessions() {
    // Use default test case (no UJET sessions)
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created - callIds should be null/absent
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log without Call ID data');
  }

  @IsTest
  static void testExecute_WithSingleTranscriptFile() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      737,
      true
    );

    // Create transcript file attached to session
    String transcriptContent = QualTestDataFactory.getSampleRtTranscript(737);
    QualTestDataFactory.createTranscriptAttachment(
      session.Id,
      'rt_transcript_737_abc123.txt',
      transcriptContent
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created and Case payload ignores transcript attachments
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        !requestBody.contains('"voiceCallTranscript"'),
        'Case payload should not contain transcript fields'
      );
      System.assert(
        !requestBody.contains('DCCA Virtual Agent') &&
        !requestBody.contains('Aloha'),
        'Case payload should not contain transcript content'
      );
    }
  }

  @IsTest
  static void testExecute_WithMultipleTranscriptFiles() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      800,
      true
    );

    // Create both rt and va transcript files attached to session
    String rtTranscript = QualTestDataFactory.getSampleRtTranscript(800);
    String vaTranscript = QualTestDataFactory.getSampleVaTranscript(800);
    QualTestDataFactory.createTranscriptAttachment(
      session.Id,
      'rt_transcript_800_abc123.txt',
      rtTranscript
    );
    QualTestDataFactory.createTranscriptAttachment(
      session.Id,
      'va_transcript_800_xyz789.txt',
      vaTranscript
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created and combined transcripts are not embedded in Case payload
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        !requestBody.contains('"voiceCallTranscript"'),
        'Case payload should not contain transcript fields'
      );
    }
  }

  @IsTest
  static void testExecute_WithSessionButNoTranscriptFiles() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session without any transcript files
    QualTestDataFactory.createUjetSession(testCase.Id, 999, true);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created - voiceCallTranscript should be null/absent
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log without transcript data'
    );
  }

  @IsTest
  static void testExecute_WithJsonFileOnSession() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      801,
      true
    );

    String callJson = QualTestDataFactory.getSampleCallJson(801);
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-801.json',
      callJson
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      System.assert(
        !payloadMap.containsKey('call'),
        'Case payload should not embed call JSON'
      );
    }
  }

  @IsTest
  static void testExecute_WithMultipleJsonFilesOnMultipleSessions() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    UJET__UJET_Session__c session1 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      92707,
      true
    );
    UJET__UJET_Session__c session2 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      92712,
      true
    );

    QualTestDataFactory.createJsonAttachment(
      session1.Id,
      'call-92707.json',
      QualTestDataFactory.getSampleCallJson(92707)
    );
    QualTestDataFactory.createJsonAttachment(
      session2.Id,
      'call-92712.json',
      QualTestDataFactory.getSampleCallJson(92712)
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Case queueable should create one case log'
    );

    for (qual_Integration_Log__c log : logs) {
      String requestBody = log.qual_Request_Body__c;
      if (String.isNotBlank(requestBody)) {
        Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
          requestBody
        );
        System.assert(
          !payloadMap.containsKey('call'),
          'Case payload should not embed call JSON'
        );
      }
    }
  }

  @IsTest
  static void testExecute_WithSessionButNoJsonFile() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    QualTestDataFactory.createUjetSession(testCase.Id, 999, true);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      System.assert(
        !payloadMap.containsKey('call'),
        'Case payload should not contain call data'
      );
    }
  }

  @IsTest
  static void testExecute_CallJsonAndTranscriptTogether() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      737,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      session.Id,
      'call-737.json',
      QualTestDataFactory.getSampleCallJson(737)
    );
    QualTestDataFactory.createTranscriptAttachment(
      session.Id,
      'rt_transcript_737_abc.txt',
      QualTestDataFactory.getSampleRtTranscript(737)
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );

      Map<String, Object> caseData = (Map<String, Object>) payloadMap.get(
        'case'
      );
      System.assert(
        !payloadMap.containsKey('call'),
        'Case payload should not embed call JSON'
      );
      System.assert(
        !caseData.containsKey('voiceCallTranscript'),
        'Case payload should not embed transcript fields'
      );
    }
  }

  @IsTest
  static void testExecute_WithMultipleSessionsMultipleTranscripts() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create two UJET Sessions for the same Case
    UJET__UJET_Session__c session1 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      850,
      true
    );
    UJET__UJET_Session__c session2 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      851,
      true
    );

    // Create transcript files for both sessions
    String transcript1 = QualTestDataFactory.getSampleRtTranscript(850);
    String transcript2 = QualTestDataFactory.getSampleRtTranscript(851);
    QualTestDataFactory.createTranscriptAttachment(
      session1.Id,
      'rt_transcript_850_aaa.txt',
      transcript1
    );
    QualTestDataFactory.createTranscriptAttachment(
      session2.Id,
      'rt_transcript_851_bbb.txt',
      transcript2
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created without embedding transcripts from sessions
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log with multiple sessions');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        !requestBody.contains('"voiceCallTranscript"'),
        'Case payload should not contain transcript fields'
      );
    }
  }

  @IsTest
  static void testExecute_TranscriptWithCallIdAndMetadata() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session with Call ID
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      737,
      true
    );

    // Create transcript file
    String transcriptContent = QualTestDataFactory.getSampleRtTranscript(737);
    QualTestDataFactory.createTranscriptAttachment(
      session.Id,
      'rt_transcript_737_test.txt',
      transcriptContent
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created with callIds but without transcript content
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        requestBody.contains('"callIds"'),
        'Payload should contain callIds field'
      );
      System.assert(
        requestBody.contains('737'),
        'Payload should contain the Call ID'
      );
      System.assert(
        !requestBody.contains('"voiceCallTranscript"'),
        'Case payload should not contain transcript fields'
      );
    }
  }

  @IsTest
  static void testExecute_WithUjetSessionDurations() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create UJET Session with Call ID and duration fields
    QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      123456789, // callId
      300, // callDuration (5 min)
      45, // holdDuration
      15, // waitDuration
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created with duration fields in payload
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        requestBody.contains('"callDurationSeconds"'),
        'Payload should contain callDurationSeconds field'
      );
      System.assert(
        requestBody.contains('"holdDurationSeconds"'),
        'Payload should contain holdDurationSeconds field'
      );
      System.assert(
        requestBody.contains('"waitDurationSeconds"'),
        'Payload should contain waitDurationSeconds field'
      );
    }
  }

  @IsTest
  static void testExecute_WithMultipleSessionsAggregatedDurations() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create multiple UJET Sessions with durations - should aggregate
    QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      111,
      120,
      10,
      10,
      true
    );
    QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      222,
      180,
      20,
      10,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log with aggregated durations'
    );

    // Verify aggregated values in payload (120+180=300, 10+20=30, 10+10=20)
    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      Map<String, Object> caseData = (Map<String, Object>) payloadMap.get(
        'case'
      );

      System.assertEquals(
        300,
        caseData.get('callDurationSeconds'),
        'Call duration should be aggregated (120+180)'
      );
      System.assertEquals(
        30,
        caseData.get('holdDurationSeconds'),
        'Hold duration should be aggregated (10+20)'
      );
      System.assertEquals(
        20,
        caseData.get('waitDurationSeconds'),
        'Wait duration should be aggregated (10+10)'
      );
    }
  }

  @IsTest
  static void testExecute_WithPartialDurations() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create session with only call duration (hold and wait null)
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = testCase.Id,
      UJET__Call_Id__c = 555,
      UJET__Call_Duration__c = 200
      // UJET__Hold_Duration__c and UJET__Wait_Duration__c are null
    );
    insert session;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    // Verify log was created - partial durations should work
    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log with partial duration data'
    );

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      Map<String, Object> caseData = (Map<String, Object>) payloadMap.get(
        'case'
      );

      System.assertEquals(
        200,
        caseData.get('callDurationSeconds'),
        'Call duration should be 200'
      );
      System.assertEquals(
        0,
        caseData.get('holdDurationSeconds'),
        'Hold duration should be 0 (null in source)'
      );
      System.assertEquals(
        0,
        caseData.get('waitDurationSeconds'),
        'Wait duration should be 0 (null in source)'
      );
    }
  }

  @IsTest
  static void testExecute_CaseTimeSecondsField() {
    // Test that caseTimeSeconds field is present in payload
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      System.assert(
        requestBody.contains('"caseTimeSeconds"'),
        'Payload should contain caseTimeSeconds field'
      );
      // Should NOT contain the old field name
      System.assert(
        !requestBody.contains('"callHandleTimeSeconds"'),
        'Payload should not contain old callHandleTimeSeconds field'
      );
    }
  }

  @IsTest
  static void testExecute_WithAbandonedUjetSession() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create an abandoned UJET Session
    QualTestDataFactory.createUjetSessionWithStatus(
      testCase.Id,
      444555666,
      'eu_abandoned',
      'failed',
      8,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      Map<String, Object> caseData = (Map<String, Object>) payloadMap.get(
        'case'
      );

      System.assertEquals(
        true,
        caseData.get('abandonedCall'),
        'Abandoned call should be true for eu_abandoned session'
      );
    }
  }

  @IsTest
  static void testExecute_WithFinishedUjetSession_SpeedToAnswer() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create a finished UJET Session with wait duration (ASA)
    QualTestDataFactory.createUjetSessionWithStatus(
      testCase.Id,
      777888999,
      null,
      'finished',
      12,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      Map<String, Object> caseData = (Map<String, Object>) payloadMap.get(
        'case'
      );

      System.assertEquals(
        12,
        caseData.get('speedToAnswerSeconds'),
        'Speed to answer should be 12 seconds'
      );
      System.assertEquals(
        false,
        caseData.get('abandonedCall'),
        'Abandoned call should be false for finished session'
      );
    }
  }

  @IsTest
  static void testExecute_WithMixedUjetSessions_AbandonedAndFinished() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create an abandoned session and then a finished session
    QualTestDataFactory.createUjetSessionWithStatus(
      testCase.Id,
      111222333,
      'eu_abandoned',
      'failed',
      5,
      true
    );
    QualTestDataFactory.createUjetSessionWithStatus(
      testCase.Id,
      444555666,
      null,
      'finished',
      18,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id }
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');

    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      Map<String, Object> caseData = (Map<String, Object>) payloadMap.get(
        'case'
      );

      System.assertEquals(
        true,
        caseData.get('abandonedCall'),
        'Abandoned call should be true when any session is abandoned'
      );
      System.assertNotEquals(
        null,
        caseData.get('speedToAnswerSeconds'),
        'Speed to answer should be populated from finished session'
      );
    }
  }

  @IsTest
  static void testExecute_DynamicCalloutBudget() {
    deleteExistingLogs();
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    // Disable integration before creating cases to prevent trigger callouts
    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    List<Case> cases = QualTestDataFactory.createCases(acc.Id, con.Id, 3, true);
    List<Id> caseIds = new List<Id>();
    for (Case c : cases) {
      caseIds.add(c.Id);
    }
    deleteExistingLogs();

    // Re-enable for the explicit Queueable run
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(caseIds);
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c IN :caseIds
    ];
    System.assertEquals(
      3,
      logs.size(),
      'Should process all cases within callout budget'
    );
  }

  @IsTest
  static void testExecute_RetryCreatesCasePayloadIndependentlyOfCallLogs() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create two sessions with JSON attachments
    UJET__UJET_Session__c session1 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      5001,
      true
    );
    UJET__UJET_Session__c session2 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      5002,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      session1.Id,
      'call-5001.json',
      QualTestDataFactory.getSampleCallJson(5001)
    );
    QualTestDataFactory.createJsonAttachment(
      session2.Id,
      'call-5002.json',
      QualTestDataFactory.getSampleCallJson(5002)
    );

    // Pre-insert success logs for BOTH calls (simulating independent Call endpoint success)
    List<qual_Integration_Log__c> preLogs = new List<qual_Integration_Log__c>{
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Status__c = 'Success',
        qual_Request_Body__c = '{"case":{},"call":{"id":5001,"status":"finished"}}',
        qual_Integration_Name__c = 'Qualtrics Call Survey',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
        qual_Ujet_Session_Id__c = String.valueOf(session1.Id),
        qual_Call_Id__c = '5001',
        qual_Processed_Date__c = Datetime.now()
      ),
      new qual_Integration_Log__c(
        qual_Case__c = testCase.Id,
        qual_Status__c = 'Success',
        qual_Request_Body__c = '{"case":{},"call":{"id":5002,"status":"finished"}}',
        qual_Integration_Name__c = 'Qualtrics Call Survey',
        qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
        qual_Ujet_Session_Id__c = String.valueOf(session2.Id),
        qual_Call_Id__c = '5002',
        qual_Processed_Date__c = Datetime.now()
      )
    };
    insert preLogs;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    // retryCount=1 triggers the duplicate-skip logic
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id },
      1
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> allLogs = [
      SELECT Id, qual_Status__c, qual_Payload_Type__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Status__c = 'Success'
    ];
    System.assertEquals(
      3,
      allLogs.size(),
      'Case retry should create one Case success log without resending Call payloads'
    );

    Boolean foundCasePayload = false;
    for (qual_Integration_Log__c log : allLogs) {
      if (log.qual_Payload_Type__c == QualCalloutService.PAYLOAD_TYPE_CASE) {
        foundCasePayload = true;
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
          log.qual_Request_Body__c
        );
        System.assert(
          !payload.containsKey('call'),
          'Case payload should not contain Call JSON'
        );
      }
    }
    System.assert(foundCasePayload, 'Should create a Case payload success log');
  }

  @IsTest
  static void testExecute_RetryDoesNotUseCallJsonAsCasePayload() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    // Create one session with JSON attachment and simulate a pre-existing
    // success log (as if call 5001 already succeeded in a prior attempt)
    UJET__UJET_Session__c session1 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      5001,
      true
    );
    UJET__UJET_Session__c session2 = QualTestDataFactory.createUjetSession(
      testCase.Id,
      5002,
      true
    );
    QualTestDataFactory.createJsonAttachment(
      session1.Id,
      'call-5001.json',
      QualTestDataFactory.getSampleCallJson(5001)
    );
    QualTestDataFactory.createJsonAttachment(
      session2.Id,
      'call-5002.json',
      QualTestDataFactory.getSampleCallJson(5002)
    );

    // Manually insert a success log for call 5001 with request body containing call.id
    qual_Integration_Log__c existingLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Status__c = 'Success',
      qual_Request_Body__c = '{"case":{},"call":{"id":5001,"status":"finished"}}',
      qual_Integration_Name__c = 'Qualtrics Call Survey',
      qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL,
      qual_Ujet_Session_Id__c = String.valueOf(session1.Id),
      qual_Call_Id__c = '5001',
      qual_Processed_Date__c = Datetime.now()
    );
    insert existingLog;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Log_Level__c = 'Debug';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    // retryCount=1 triggers the duplicate-skip logic
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id },
      1
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> successLogs = [
      SELECT Id, qual_Payload_Type__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Status__c = 'Success'
    ];
    System.assertEquals(
      2,
      successLogs.size(),
      'Retry should create one new Case log beside the existing Call log'
    );

    Boolean foundCasePayload = false;
    for (qual_Integration_Log__c log : successLogs) {
      if (
        log.Id != existingLog.Id &&
        log.qual_Payload_Type__c == QualCalloutService.PAYLOAD_TYPE_CASE
      ) {
        foundCasePayload = true;
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
          log.qual_Request_Body__c
        );
        System.assert(
          !payload.containsKey('call'),
          'Case retry payload should not include Call data'
        );
      }
    }
    System.assert(
      foundCasePayload,
      'The new success log should be a Case payload'
    );
  }

  @IsTest
  static void testConstructors_NullMapsDefaultToEmpty() {
    List<Id> caseIds = new List<Id>();

    Test.startTest();
    QualCalloutQueueable retryVariant = new QualCalloutQueueable(
      caseIds,
      1,
      null
    );
    QualCalloutQueueable perCaseVariant = new QualCalloutQueueable(
      caseIds,
      (Map<Id, Integer>) null,
      (Map<Id, String>) null
    );
    QualCalloutQueueable eventVariant = new QualCalloutQueueable(
      caseIds,
      (Map<Id, String>) null
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      retryVariant,
      'Retry constructor should tolerate a null event type map'
    );
    System.assertNotEquals(
      null,
      perCaseVariant,
      'Per-case retry constructor should tolerate null maps'
    );
    System.assertNotEquals(
      null,
      eventVariant,
      'Event type constructor should tolerate a null event type map'
    );
  }

  @IsTest
  static void testExecute_EventTypePreservedThroughRetry() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    // Simulate retry with event type map (as QualRetrySchedulable would pass)
    Map<Id, String> eventTypeMap = new Map<Id, String>{
      testCase.Id => 'Opened'
    };

    Test.startTest();
    QualCalloutQueueable job = new QualCalloutQueueable(
      new List<Id>{ testCase.Id },
      1,
      eventTypeMap
    );
    System.enqueueJob(job);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c, qual_Request_Body__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log');
    System.assertEquals(
      'Opened',
      logs[0].qual_Event_Type__c,
      'Event type should be preserved as Opened during retry'
    );

    // Also verify the payload metadata contains the event type
    String requestBody = logs[0].qual_Request_Body__c;
    if (String.isNotBlank(requestBody)) {
      Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
        requestBody
      );
      Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
        'metadata'
      );
      System.assertEquals(
        'Opened',
        metadata.get('eventType'),
        'Payload metadata eventType should be Opened'
      );
    }
  }
}