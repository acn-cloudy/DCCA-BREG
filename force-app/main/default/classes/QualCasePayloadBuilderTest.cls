/**
 * @description Test class for QualCasePayloadBuilder
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualCasePayloadBuilderTest {
  @TestSetup
  static void setupTestData() {
    Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
  }

  @IsTest
  static void testBuildPayload() {
    // Get test case with relations
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    System.assertNotEquals(null, payload, 'Payload should not be null');
    System.assert(
      payload.contains('"case"'),
      'Payload should contain case element'
    );
    System.assert(
      payload.contains('"contact"'),
      'Payload should contain contact element'
    );
    System.assert(
      payload.contains('"agent"'),
      'Payload should contain agent element'
    );
    System.assert(
      payload.contains('"metadata"'),
      'Payload should contain metadata element'
    );
    System.assert(
      !payload.contains('"call"'),
      'Case payload should not contain a call element'
    );
  }

  @IsTest
  static void testBuildPayload_CaseNumber() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify case number
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      testCase.CaseNumber,
      caseData.get('caseNumber'),
      'Case number should match'
    );
  }

  @IsTest
  static void testBuildPayload_ContactPhone() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify phone is formatted
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> contactData = (Map<String, Object>) payloadMap.get(
      'contact'
    );

    String phone = (String) contactData.get('phone');
    System.assert(phone.startsWith('+'), 'Phone should be in E.164 format');
  }

  @IsTest
  static void testBuildPayload_Metadata() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify metadata
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );

    System.assertEquals(
      testCase.Id,
      metadata.get('salesforceCaseId'),
      'Case ID should match'
    );
    System.assertEquals(
      '2.0',
      metadata.get('payloadVersion'),
      'Payload version should match'
    );
    System.assertNotEquals(
      null,
      metadata.get('integrationTimestamp'),
      'Timestamp should be set'
    );
    System.assertNotEquals(
      null,
      metadata.get('eventType'),
      'Event type should be set'
    );
    System.assertEquals(
      true,
      metadata.get('isTestContact'),
      'Test factory config should mark payloads as test contacts'
    );
  }

  @IsTest
  static void testBuildPayload_IsTestContactFalseFromConfig() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Is_Test_Contact__c = false;

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );

    System.assertEquals(
      false,
      metadata.get('isTestContact'),
      'Config false should send metadata.isTestContact as false'
    );
  }

  @IsTest
  static void testBuildPayload_NullContact() {
    // Create case without contact
    Account acc = QualTestDataFactory.createAccount(true);
    Case testCase = new Case(
      AccountId = acc.Id,
      Status = 'New',
      Subject = 'Test Case No Contact'
    );
    insert testCase;

    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    System.assertNotEquals(null, payload, 'Should handle null contact');
  }

  @IsTest
  static void testGetPayloadSizeBytes() {
    String testPayload = '{"test": "data"}';

    Test.startTest();
    Integer size = QualCasePayloadBuilder.getPayloadSizeBytes(testPayload);
    Test.stopTest();

    System.assert(size > 0, 'Size should be greater than 0');
  }

  @IsTest
  static void testGetPayloadSizeBytes_Null() {
    Test.startTest();
    Integer size = QualCasePayloadBuilder.getPayloadSizeBytes(null);
    Test.stopTest();

    System.assertEquals(0, size, 'Size should be 0 for null');
  }

  @IsTest
  static void testBuildPayload_AgentTeamAndSupervisor() {
    // Create test user with team and manager
    User testUser = QualTestDataFactory.createTestUserWithTeam(true);

    // Use existing account and contact from test setup
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Case testCase;
    System.runAs(testUser) {
      testCase = new Case(
        AccountId = acc.Id,
        ContactId = con.Id,
        Status = 'New',
        Subject = 'Test Case with Team',
        OwnerId = testUser.Id
      );
      insert testCase;
    }

    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Setup user data map for payload builder
    QualTestDataFactory.setupUserDataForPayload(testUser.Id);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify agent data
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> agentData = (Map<String, Object>) payloadMap.get(
      'agent'
    );

    System.assertEquals(
      'DCCA',
      agentData.get('teamId'),
      'Team ID should be DCCA from qual_Team__c'
    );
    System.assertEquals(
      'Test Manager',
      agentData.get('supervisorName'),
      'Supervisor name should come from Manager'
    );
    System.assertEquals(
      'Test Agent',
      agentData.get('agentName'),
      'Agent name should match'
    );
  }

  @IsTest
  static void testBuildPayload_AgentNoTeamData() {
    // Get test case with default owner (no team data set)
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Clear any existing user data map
    QualCasePayloadBuilder.setUserDataMap(new Map<Id, User>());

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify agent data handles missing team/supervisor gracefully
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> agentData = (Map<String, Object>) payloadMap.get(
      'agent'
    );

    System.assertNotEquals(
      null,
      agentData.get('agentId'),
      'Agent ID should be set'
    );
    // teamId and supervisorName may be null when no user data is available
  }

  @IsTest
  static void testBuildPayload_SingleCallId() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Setup single Call ID as list
    QualTestDataFactory.setupUjetCallIdForPayload(
      testCase.Id,
      new List<Long>{ 123456789 }
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify callIds is an array
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    List<Object> callIds = (List<Object>) caseData.get('callIds');
    System.assertNotEquals(null, callIds, 'Call IDs should not be null');
    System.assertEquals(1, callIds.size(), 'Should have 1 Call ID');
    System.assertEquals(123456789, callIds[0], 'Call ID should match');
  }

  @IsTest
  static void testBuildPayload_MultipleCallIds() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Setup multiple Call IDs as list
    QualTestDataFactory.setupUjetCallIdForPayload(
      testCase.Id,
      new List<Long>{ 123456789, 987654321, 555555555 }
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify callIds is an array with multiple values
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    List<Object> callIds = (List<Object>) caseData.get('callIds');
    System.assertNotEquals(null, callIds, 'Call IDs should not be null');
    System.assertEquals(3, callIds.size(), 'Should have 3 Call IDs');
    System.assertEquals(123456789, callIds[0], 'First Call ID should match');
    System.assertEquals(987654321, callIds[1], 'Second Call ID should match');
    System.assertEquals(555555555, callIds[2], 'Third Call ID should match');
  }

  @IsTest
  static void testBuildPayload_NoCallIds() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Clear Call ID map
    QualCasePayloadBuilder.setUjetCallIdMap(new Map<Id, List<Long>>());

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify callIds is null when no data
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      null,
      caseData.get('callIds'),
      'Call IDs should be null when no sessions'
    );
  }

  @IsTest
  static void testSetUjetCallIdMap_Null() {
    // Test that setUjetCallIdMap handles null gracefully
    Test.startTest();
    QualCasePayloadBuilder.setUjetCallIdMap(null);
    Test.stopTest();

    // Should not throw exception - test passes if we reach here
    System.assert(true, 'Should handle null Call ID map');
  }

  @IsTest
  static void testBuildPayload_WithVoiceCallTranscript() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Setup transcript using sample rt_transcript data
    String sampleTranscript = QualTestDataFactory.getSampleRtTranscript(737);
    QualTestDataFactory.setupVoiceCallTranscriptForPayload(
      testCase.Id,
      sampleTranscript
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify voiceCallTranscript is not present on Case payloads
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assert(
      !caseData.containsKey('voiceCallTranscript'),
      'Case payload should not include transcript fields'
    );
  }

  @IsTest
  static void testBuildPayload_WithCombinedTranscripts() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Setup combined transcript (rt + va)
    String combinedTranscript = QualTestDataFactory.getSampleCombinedTranscript(
      800
    );
    QualTestDataFactory.setupVoiceCallTranscriptForPayload(
      testCase.Id,
      combinedTranscript
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify combined transcript
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assert(
      !caseData.containsKey('voiceCallTranscript'),
      'Case payload should not include transcript fields'
    );
  }

  @IsTest
  static void testBuildPayload_NoVoiceCallTranscript() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Clear transcript map
    QualCasePayloadBuilder.setVoiceCallTranscriptMap(new Map<Id, String>());

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify voiceCallTranscript is not present when no data
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assert(
      !caseData.containsKey('voiceCallTranscript'),
      'Case payload should not include transcript fields'
    );
  }

  @IsTest
  static void testSetVoiceCallTranscriptMap_Null() {
    // Test that setVoiceCallTranscriptMap handles null gracefully
    Test.startTest();
    QualCasePayloadBuilder.setVoiceCallTranscriptMap(null);
    Test.stopTest();

    // Should not throw exception - test passes if we reach here
    System.assert(true, 'Should handle null transcript map');
  }

  @IsTest
  static void testSetUjetDurationsMap_Null() {
    // Test that setUjetDurationsMap handles null gracefully
    Test.startTest();
    QualCasePayloadBuilder.setUjetDurationsMap(null);
    Test.stopTest();

    // Should not throw exception - test passes if we reach here
    System.assert(true, 'Should handle null durations map');
  }

  @IsTest
  static void testBuildPayload_WithUjetDurations() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Setup UJET durations (callDuration, holdDuration, waitDuration)
    QualTestDataFactory.setupUjetDurationsForPayload(testCase.Id, 300, 45, 15);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify duration fields
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      300,
      caseData.get('callDurationSeconds'),
      'Call duration should be 300'
    );
    System.assertEquals(
      45,
      caseData.get('holdDurationSeconds'),
      'Hold duration should be 45'
    );
    System.assertEquals(
      15,
      caseData.get('waitDurationSeconds'),
      'Wait duration should be 15'
    );
  }

  @IsTest
  static void testBuildPayload_NoDurations() {
    // Get test case
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Clear durations map
    QualCasePayloadBuilder.setUjetDurationsMap(
      new Map<Id, QualCasePayloadBuilder.UjetDurations>()
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify duration fields are null when no data
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      null,
      caseData.get('callDurationSeconds'),
      'Call duration should be null when no sessions'
    );
    System.assertEquals(
      null,
      caseData.get('holdDurationSeconds'),
      'Hold duration should be null when no sessions'
    );
    System.assertEquals(
      null,
      caseData.get('waitDurationSeconds'),
      'Wait duration should be null when no sessions'
    );
  }

  @IsTest
  static void testBuildPayload_CaseTimeSeconds() {
    // Create a closed case to test caseTimeSeconds calculation
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'Closed',
      Subject = 'Test Case Time Calc'
    );
    insert testCase;

    // Update to set ClosedDate (need to close the case properly)
    testCase = [
      SELECT Id, CreatedDate, ClosedDate
      FROM Case
      WHERE Id = :testCase.Id
    ];

    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Parse JSON and verify caseTimeSeconds field exists
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    // caseTimeSeconds should be present (may be 0 if dates are close or null if case not closed)
    System.assert(
      caseData.containsKey('caseTimeSeconds'),
      'Payload should contain caseTimeSeconds field'
    );
  }

  @IsTest
  static void testBuildPayload_TranscriptWithSpecialCharacters() {
    // Test that special characters in transcript are properly escaped for JSON
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Create transcript with special characters that need JSON escaping
    String transcriptWithSpecials =
      'Call ID: 999   |   2025-11-12     HST   |   30 sec\n' +
      '--------------------------------------------------\n\n' +
      '[10:00:00     Agent]     Customer said: "Hello, I need help!"\n' +
      '[10:00:10     Agent]     Special chars test: \\ / \t \n' +
      '[10:00:20     Agent]     Unicode: Mahalo nui loa!';
    QualTestDataFactory.setupVoiceCallTranscriptForPayload(
      testCase.Id,
      transcriptWithSpecials
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    // Verify payload is valid JSON (deserialization should succeed)
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assert(
      !caseData.containsKey('voiceCallTranscript'),
      'Case payload should not include transcript fields'
    );
  }

  @IsTest
  static void testBuildPayload_TranscriptWithDivisionOptions() {
    // Test transcript containing all DCCA division menu options
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Use the full sample transcript which contains all division options
    String fullTranscript = QualTestDataFactory.getSampleRtTranscript(737);
    QualTestDataFactory.setupVoiceCallTranscriptForPayload(
      testCase.Id,
      fullTranscript
    );

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assert(
      !caseData.containsKey('voiceCallTranscript'),
      'Case payload should not include transcript fields'
    );
  }

  // ========== Event Type Tests ==========

  @IsTest
  static void testBuildPayload_EventType_Closed() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Set event type to Closed
    Map<Id, String> eventTypeMap = new Map<Id, String>{
      testCase.Id => 'Closed'
    };
    QualCasePayloadBuilder.setEventTypeMap(eventTypeMap);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );

    System.assertEquals(
      'Closed',
      metadata.get('eventType'),
      'Event type should be Closed'
    );
  }

  @IsTest
  static void testBuildPayload_EventType_Opened() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Map<Id, String> eventTypeMap = new Map<Id, String>{
      testCase.Id => 'Opened'
    };
    QualCasePayloadBuilder.setEventTypeMap(eventTypeMap);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );

    System.assertEquals(
      'Opened',
      metadata.get('eventType'),
      'Event type should be Opened'
    );
  }

  @IsTest
  static void testBuildPayload_EventType_Updated() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Map<Id, String> eventTypeMap = new Map<Id, String>{
      testCase.Id => 'Updated'
    };
    QualCasePayloadBuilder.setEventTypeMap(eventTypeMap);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );

    System.assertEquals(
      'Updated',
      metadata.get('eventType'),
      'Event type should be Updated'
    );
  }

  @IsTest
  static void testBuildPayload_EventType_DefaultToClosed() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    // Don't set any event type map — should default to Closed
    QualCasePayloadBuilder.setEventTypeMap(new Map<Id, String>());

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );

    System.assertEquals(
      'Closed',
      metadata.get('eventType'),
      'Event type should default to Closed'
    );
  }

  // ========== Abandoned Call Tests ==========

  @IsTest
  static void testBuildPayload_WithAbandonedCall() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    QualTestDataFactory.setupAbandonedCallForPayload(testCase.Id, true);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      true,
      caseData.get('abandonedCall'),
      'Abandoned call should be true'
    );
  }

  @IsTest
  static void testBuildPayload_WithNoAbandonedCall() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    QualTestDataFactory.setupAbandonedCallForPayload(testCase.Id, false);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      false,
      caseData.get('abandonedCall'),
      'Abandoned call should be false'
    );
  }

  @IsTest
  static void testSetAbandonedCallMap_Null() {
    Test.startTest();
    QualCasePayloadBuilder.setAbandonedCallMap(null);
    Test.stopTest();

    System.assert(true, 'Should handle null abandoned call map');
  }

  // ========== Speed to Answer Tests ==========

  @IsTest
  static void testBuildPayload_WithSpeedToAnswer() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    QualTestDataFactory.setupSpeedToAnswerForPayload(testCase.Id, 22);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      22,
      caseData.get('speedToAnswerSeconds'),
      'Speed to answer should be 22'
    );
  }

  @IsTest
  static void testBuildPayload_NoSpeedToAnswer() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    QualCasePayloadBuilder.setSpeedToAnswerMap(new Map<Id, Integer>());

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      null,
      caseData.get('speedToAnswerSeconds'),
      'Speed to answer should be null when no data'
    );
  }

  @IsTest
  static void testSetSpeedToAnswerMap_Null() {
    Test.startTest();
    QualCasePayloadBuilder.setSpeedToAnswerMap(null);
    Test.stopTest();

    System.assert(true, 'Should handle null speed to answer map');
  }

  // ========== Call Forwarding Division Tests ==========

  // ========== Call JSON Tests ==========

  @IsTest
  static void testBuildPayload_WithCallJson() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    String sampleJson = '{"id":71817,"call_type":"Voice Outbound","status":"finished","call_duration":67}';
    Object parsed = JSON.deserializeUntyped(sampleJson);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(
      testCase,
      config,
      parsed
    );
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    System.assert(
      !payloadMap.containsKey('call'),
      'Case payload should ignore legacy embedded call data'
    );
  }

  @IsTest
  static void testBuildPayload_GetCallJsonList() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    Object call1 = JSON.deserializeUntyped(
      '{"id":92707,"status":"finished","call_duration":284}'
    );
    Object call2 = JSON.deserializeUntyped(
      '{"id":92712,"status":"finished","call_duration":5}'
    );
    Object call3 = JSON.deserializeUntyped(
      '{"id":92714,"status":"finished","call_duration":86}'
    );
    Map<Id, List<Object>> callJsonMap = new Map<Id, List<Object>>{
      testCase.Id => new List<Object>{ call1, call2, call3 }
    };
    QualCasePayloadBuilder.setCallJsonMap(callJsonMap);

    Test.startTest();
    List<Object> callList = QualCasePayloadBuilder.getCallJsonList(testCase.Id);
    Test.stopTest();

    System.assertEquals(
      3,
      callList.size(),
      'Should have 3 call entries in list'
    );
  }

  @IsTest
  static void testBuildPayload_NoCallJson() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    System.assert(
      !payloadMap.containsKey('call'),
      'Case payload should not contain call data'
    );
  }

  @IsTest
  static void testSetCallJsonMap_Null() {
    Test.startTest();
    QualCasePayloadBuilder.setCallJsonMap(null);
    Test.stopTest();

    System.assert(true, 'Should handle null call JSON map');
  }

  // ========== Call Forwarding Division Tests ==========

  @IsTest
  static void testBuildPayload_WithCallForwardingDivision() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    // Dynamically set the call forwarding field that exists in this org
    // Routed_to_Division__c takes priority; qual_Call_Forwarding_Division__c is the fallback
    Map<String, SObjectField> caseFields = Case.SObjectType.getDescribe()
      .fields.getMap();
    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'New',
      Subject = 'Test Call Forwarding'
    );
    if (caseFields.containsKey('Routed_to_Division__c')) {
      testCase.put('Routed_to_Division__c', 'PVL');
    } else {
      testCase.put('qual_Call_Forwarding_Division__c', 'PVL');
    }
    insert testCase;

    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      'PVL',
      caseData.get('callForwardingDivision'),
      'Call forwarding division should be PVL'
    );
  }

  @IsTest
  static void testBuildPayload_NoCallForwardingDivision() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      null,
      caseData.get('callForwardingDivision'),
      'Call forwarding division should be null when not set'
    );
  }

  // ========== Branch Mapping Tests ==========

  @IsTest
  static void testBuildPayload_BranchPrefersInsBranch() {
    Map<String, SObjectField> caseFields = Case.SObjectType.getDescribe()
      .fields.getMap();
    if (
      !caseFields.containsKey('INS_Branch_v2__c') ||
      !caseFields.containsKey('Respondent_Branch__c')
    ) {
      return; // precedence only observable when both org fields exist
    }

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'New',
      Subject = 'Test INS Branch Precedence'
    );
    // INS branch picklist values are record-type-scoped
    List<RecordType> insRecordTypes = [
      SELECT Id
      FROM RecordType
      WHERE
        SObjectType = 'Case'
        AND DeveloperName = 'INS_Complaint'
        AND IsActive = true
      LIMIT 1
    ];
    if (!insRecordTypes.isEmpty()) {
      testCase.RecordTypeId = insRecordTypes[0].Id;
    }
    // INS_Branch_v2__c is a dependent picklist controlled by Final_Division__c
    if (caseFields.containsKey('Final_Division__c')) {
      testCase.put('Final_Division__c', 'INS');
    }
    testCase.put('INS_Branch_v2__c', 'Licensing');
    testCase.put('Respondent_Branch__c', 'Legacy Respondent Branch');
    insert testCase;

    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      'Licensing',
      caseData.get('branch'),
      'Branch should come from INS_Branch_v2__c when both branch fields are populated'
    );
  }

  @IsTest
  static void testBuildPayload_BranchBlankInsFallsBack() {
    Map<String, SObjectField> caseFields = Case.SObjectType.getDescribe()
      .fields.getMap();
    if (
      !caseFields.containsKey('INS_Branch_v2__c') ||
      !caseFields.containsKey('Respondent_Branch__c')
    ) {
      return; // fall-through only observable when both org fields exist
    }

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'New',
      Subject = 'Test Blank INS Branch Fallback'
    );
    testCase.put('Respondent_Branch__c', 'Legacy Respondent Branch');
    insert testCase;

    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      'Legacy Respondent Branch',
      caseData.get('branch'),
      'Blank INS_Branch_v2__c should fall through to Respondent_Branch__c'
    );
  }

  @IsTest
  static void testBuildPayload_MinimallyQueriedCaseDegradesToNulls() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'New',
      Subject = 'Test Minimal Query Resilience'
    );
    insert testCase;

    // Re-query WITHOUT the optional custom fields so every optional read
    // hits the SObjectException guard instead of a populated value
    Case minimalCase = [
      SELECT
        Id,
        CaseNumber,
        Status,
        Origin,
        Priority,
        CreatedDate,
        ClosedDate,
        ContactId,
        OwnerId,
        Contact.FirstName,
        Contact.LastName,
        Contact.Email,
        Contact.Phone,
        Owner.Name
      FROM Case
      WHERE Id = :testCase.Id
    ];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(minimalCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      null,
      caseData.get('branch'),
      'Unqueried optional fields should degrade to null, not throw'
    );
  }

  @IsTest
  static void testGetCallJsonList_DefaultsToEmpty() {
    Test.startTest();
    List<Object> result = QualCasePayloadBuilder.getCallJsonList(null);
    Test.stopTest();

    System.assertEquals(
      0,
      result.size(),
      'Unknown Case Id should return an empty call list'
    );
  }

  // ========== Null Setter Coverage ==========

  @IsTest
  static void testSetUserDataMap_Null() {
    Test.startTest();
    QualCasePayloadBuilder.setUserDataMap(null);
    Test.stopTest();

    System.assert(true, 'Should handle null user data map');
  }

  @IsTest
  static void testSetEventTypeMap_Null() {
    Test.startTest();
    QualCasePayloadBuilder.setEventTypeMap(null);
    Test.stopTest();

    System.assert(true, 'Should handle null event type map');
  }

  // ========== calculateCaseTime for Open Case ==========

  @IsTest
  static void testBuildPayload_CaseTimeSeconds_OpenCase_ReturnsZero() {
    // Open case has no ClosedDate, so caseTimeSeconds should be 0
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, config);
    Test.stopTest();

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');

    System.assertEquals(
      0,
      caseData.get('caseTimeSeconds'),
      'caseTimeSeconds should be 0 for an open case with no ClosedDate'
    );
  }

  // ========== Oversized Payload Path ==========

  @IsTest
  static void testBuildPayload_OversizedPayload_ThrowsException() {
    // Set max payload to 1 KB so the normal payload exceeds it
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Max_Payload_Size_KB__c = 1; // 1 KB = 1024 bytes

    // Add enough included Case-side scalar data to guarantee > 1 KB now that
    // Call transcript content is owned by the independent Call/Session payload.
    List<Long> largeCallIds = new List<Long>();
    for (Integer i = 0; i < 150; i++) {
      largeCallIds.add(900000000L + i);
    }
    QualCasePayloadBuilder.setUjetCallIdMap(
      new Map<Id, List<Long>>{ testCase.Id => largeCallIds }
    );

    Boolean threwException = false;
    Test.startTest();
    try {
      QualCasePayloadBuilder.buildPayload(testCase, config);
    } catch (QualCalloutService.QualCalloutException ex) {
      threwException = true;
      System.assert(
        ex.getMessage().contains('Case payload size'),
        'Exception should identify Case payload size enforcement'
      );
    }
    Test.stopTest();

    System.assert(
      threwException,
      'Oversized Case payloads should fail before callout'
    );
  }

  // ========== Null Config in buildPayload ==========

  @IsTest
  static void testBuildPayload_NullConfig() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase = QualTestDataFactory.queryCaseWithRelations(testCase.Id);

    Test.startTest();
    String payload = QualCasePayloadBuilder.buildPayload(testCase, null);
    Test.stopTest();

    System.assertNotEquals(
      null,
      payload,
      'Should handle null config gracefully'
    );

    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );
    System.assertEquals(
      '1.0',
      metadata.get('payloadVersion'),
      'Should default to version 1.0'
    );
    System.assertEquals(
      false,
      metadata.get('isTestContact'),
      'Null config should default metadata.isTestContact to false'
    );
  }
}