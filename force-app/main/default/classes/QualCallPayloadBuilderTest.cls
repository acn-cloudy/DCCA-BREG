@IsTest
private class QualCallPayloadBuilderTest {
  @TestSetup
  static void setupTestData() {
    QualTestDataFactory.createCompleteTestData();
  }

  @IsTest
  static void testBuildCallPayload_UsesHistoricalCallShapeAndAcw() {
    Case testCase = [SELECT Id, CaseNumber FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      801,
      284,
      7,
      47,
      true
    );
    session.UJET__Status__c = 'finished';
    update session;

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

    Object callJson = JSON.deserializeUntyped(
      '{"id":801,"call_type":"Voice Inbound (IVR)","status":"finished",' +
        '"call_duration":284,"hold_duration":0,"wait_duration":47,' +
        '"agent_info":{"id":6,"name":"Test Agent","email":"agent@example.com"},' +
        '"participants":[{"id":1}],"handle_durations":[{"acw_duration":12},{"acw_duration":3}]}'
    );

    String payload = QualCallPayloadBuilder.buildCallPayload(
      session,
      callJson,
      QualTestDataFactory.createTestConfig()
    );
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> callData = (Map<String, Object>) payloadMap.get('call');
    Map<String, Object> caseData = (Map<String, Object>) payloadMap.get('case');
    Map<String, Object> metadata = (Map<String, Object>) payloadMap.get(
      'metadata'
    );
    Map<String, Object> sessionData = (Map<String, Object>) callData.get(
      'session'
    );
    Map<String, Object> agentInfo = (Map<String, Object>) callData.get(
      'agent_info'
    );

    System.assertEquals(
      testCase.CaseNumber,
      caseData.get('caseNumber'),
      'Case number should be linked'
    );
    System.assertEquals(
      '801',
      String.valueOf(callData.get('id')),
      'Call ID should match'
    );
    System.assertEquals(
      'Voice Inbound (IVR)',
      callData.get('call_type'),
      'Call type should be copied'
    );
    System.assertEquals(
      '15',
      String.valueOf(callData.get('acw_duration')),
      'ACW should sum handle durations'
    );
    System.assertEquals(
      '284',
      String.valueOf(sessionData.get('callDurationSeconds')),
      'Session call duration should be set'
    );
    System.assertEquals(
      '47',
      String.valueOf(sessionData.get('speedToAnswerSeconds')),
      'Speed to answer should use finished wait duration'
    );
    System.assertEquals(
      'Test Agent',
      agentInfo.get('name'),
      'Nested scalar objects should be preserved'
    );
    System.assert(
      !callData.containsKey('participants'),
      'Array fields should be excluded from simplified payload'
    );
    System.assert(
      !callData.containsKey('handle_durations'),
      'Handle duration array should be excluded after ACW extraction'
    );
    System.assertEquals(
      UserInfo.getOrganizationId(),
      metadata.get('salesforceOrgId'),
      'Metadata should include the Salesforce org identifier'
    );
    System.assertEquals(
      '2.0',
      metadata.get('payloadVersion'),
      'Metadata should use configured payload version'
    );
    System.assertEquals(
      true,
      metadata.get('isTestContact'),
      'Test factory config should mark Call payloads as test contacts'
    );
    System.assertNotEquals(
      null,
      metadata.get('integrationTimestamp'),
      'Metadata should include an integration timestamp'
    );
  }

  @IsTest
  static void testBuildCallPayload_SessionOnlyFallback() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSessionWithStatus(
      testCase.Id,
      902,
      'eu_abandoned',
      'failed',
      10,
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

    String payload = QualCallPayloadBuilder.buildCallPayload(
      session,
      null,
      QualTestDataFactory.createTestConfig()
    );
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Map<String, Object> callData = (Map<String, Object>) payloadMap.get('call');
    Map<String, Object> sessionData = (Map<String, Object>) callData.get(
      'session'
    );

    System.assertEquals(
      '902',
      String.valueOf(callData.get('id')),
      'Call ID should fall back to session field'
    );
    System.assertEquals(
      true,
      sessionData.get('abandonedCall'),
      'Abandoned call should come from fail reason'
    );
    System.assertEquals(
      null,
      sessionData.get('speedToAnswerSeconds'),
      'Failed calls should not set speed to answer'
    );
  }

  @IsTest
  static void testBuildCallPayload_MetadataFalseAndNullConfigDefaults() {
    qual_Config__mdt falseConfig = QualTestDataFactory.createTestConfig();
    falseConfig.qual_Is_Test_Contact__c = false;

    String configuredPayload = QualCallPayloadBuilder.buildCallPayload(
      null,
      null,
      falseConfig
    );
    Map<String, Object> configuredPayloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      configuredPayload
    );
    Map<String, Object> configuredMetadata = (Map<String, Object>) configuredPayloadMap.get(
      'metadata'
    );

    System.assertEquals(
      false,
      configuredMetadata.get('isTestContact'),
      'Configured false should send metadata.isTestContact as false'
    );
    System.assertEquals(
      UserInfo.getOrganizationId(),
      configuredMetadata.get('salesforceOrgId'),
      'Configured payload should include the Salesforce org identifier'
    );

    String nullConfigPayload = QualCallPayloadBuilder.buildCallPayload(
      null,
      null,
      null
    );
    Map<String, Object> nullConfigPayloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      nullConfigPayload
    );
    Map<String, Object> nullConfigMetadata = (Map<String, Object>) nullConfigPayloadMap.get(
      'metadata'
    );

    System.assertEquals(
      false,
      nullConfigMetadata.get('isTestContact'),
      'Null config should default metadata.isTestContact to false'
    );
    System.assertEquals(
      '1.0',
      nullConfigMetadata.get('payloadVersion'),
      'Null config should preserve payload version fallback'
    );
    System.assertEquals(
      UserInfo.getOrganizationId(),
      nullConfigMetadata.get('salesforceOrgId'),
      'Null config payload should still include the Salesforce org identifier'
    );
  }

  @IsTest
  static void testBuildCallPayload_OversizedPayload_ThrowsException() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSessionWithDurations(
      testCase.Id,
      903,
      20,
      0,
      3,
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
      '{"id":903,"call_type":"' + largeValue + '"}'
    );
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Max_Payload_Size_KB__c = 1;

    Boolean threwException = false;
    Test.startTest();
    try {
      QualCallPayloadBuilder.buildCallPayload(session, callJson, config);
    } catch (QualCalloutService.QualCalloutException ex) {
      threwException = true;
      System.assert(
        ex.getMessage().contains('Call payload size'),
        'Exception should identify Call payload size enforcement'
      );
    }
    Test.stopTest();

    System.assert(
      threwException,
      'Oversized Call payloads should fail before callout'
    );
  }

  // ---------------------------------------------------------------------------
  // CALL-719 — contact.salesforceContactId on the Call payload
  // ---------------------------------------------------------------------------

  /**
   * @description Payload-shaped session query. Mirrors the field list in
   * QualCallSessionQueueable.querySessions so the builder sees exactly what
   * production hands it — any field the builder reads must be selected here too,
   * or it throws SObjectException at run time rather than failing to compile.
   */
  private static UJET__UJET_Session__c querySessionForPayload(Id sessionId) {
    return [
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
      WHERE Id = :sessionId
    ];
  }

  /**
   * @description Builds a Call payload and returns its contact root, asserting
   * the root exists at all.
   */
  private static Map<String, Object> contactRootOf(
    UJET__UJET_Session__c session
  ) {
    String payload = QualCallPayloadBuilder.buildCallPayload(
      session,
      null,
      QualTestDataFactory.createTestConfig()
    );
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );
    Assert.isTrue(
      payloadMap.containsKey('contact'),
      'Call payload must carry a top-level contact root'
    );
    return (Map<String, Object>) payloadMap.get('contact');
  }

  @IsTest
  static void testBuildCallPayload_ContactFallsBackToCaseContact() {
    Case testCase = [SELECT Id, ContactId FROM Case LIMIT 1];
    Assert.isNotNull(
      testCase.ContactId,
      'Test setup must give the Case a Contact for the fallback branch to mean anything'
    );

    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      901,
      true
    );

    Map<String, Object> contactRoot = contactRootOf(
      querySessionForPayload(session.Id)
    );
    String contactId = (String) contactRoot.get('salesforceContactId');

    Assert.areEqual(
      String.valueOf(testCase.ContactId),
      contactId,
      'A session with no Contact of its own must fall back to the Case Contact'
    );
    Assert.areEqual(
      18,
      contactId.length(),
      'salesforceContactId must be the 18-character Contact Id'
    );
  }

  @IsTest
  static void testBuildCallPayload_SessionContactWinsOverCaseContact() {
    Case testCase = [SELECT Id, AccountId, ContactId FROM Case LIMIT 1];
    Contact sessionContact = QualTestDataFactory.createContact(
      testCase.AccountId,
      'Session',
      'Contact',
      true
    );
    Assert.areNotEqual(
      testCase.ContactId,
      sessionContact.Id,
      'The session Contact and the Case Contact must differ, or precedence proves nothing'
    );

    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      902,
      sessionContact.Id,
      true
    );

    Map<String, Object> contactRoot = contactRootOf(
      querySessionForPayload(session.Id)
    );

    Assert.areEqual(
      String.valueOf(sessionContact.Id),
      (String) contactRoot.get('salesforceContactId'),
      'The session Contact must take precedence over the Case Contact'
    );
  }

  @IsTest
  static void testBuildCallPayload_ContactNullWhenCaseHasNoContact() {
    Case testCase = [SELECT Id, AccountId FROM Case LIMIT 1];
    Case caseWithoutContact = QualTestDataFactory.createOpenCase(
      testCase.AccountId,
      null,
      true
    );

    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      caseWithoutContact.Id,
      903,
      true
    );

    Map<String, Object> contactRoot = contactRootOf(
      querySessionForPayload(session.Id)
    );

    Assert.isTrue(
      contactRoot.containsKey('salesforceContactId'),
      'The key must be present even with no Contact — an omitted key breaks the nullable contract'
    );
    Assert.isNull(
      contactRoot.get('salesforceContactId'),
      'salesforceContactId must be an explicit null when neither source has a Contact'
    );
  }

  @IsTest
  static void testBuildCallPayload_ContactNullWhenSessionHasNoCase() {
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      null,
      904,
      true
    );

    Map<String, Object> contactRoot = contactRootOf(
      querySessionForPayload(session.Id)
    );

    Assert.isTrue(
      contactRoot.containsKey('salesforceContactId'),
      'The key must be present even when the session has no Case'
    );
    Assert.isNull(
      contactRoot.get('salesforceContactId'),
      'salesforceContactId must be null when the session has no Case to fall back to'
    );
  }

  @IsTest
  static void testBuildCallPayload_ContactNullWhenSessionIsNull() {
    Map<String, Object> contactRoot = contactRootOf(null);

    Assert.isNull(
      contactRoot.get('salesforceContactId'),
      'salesforceContactId must be null when there is no session at all'
    );
  }

  @IsTest
  static void testBuildCallPayload_RootsRemainBackwardCompatible() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    UJET__UJET_Session__c session = QualTestDataFactory.createUjetSession(
      testCase.Id,
      905,
      true
    );

    String payload = QualCallPayloadBuilder.buildCallPayload(
      querySessionForPayload(session.Id),
      null,
      QualTestDataFactory.createTestConfig()
    );
    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
      payload
    );

    Assert.areEqual(
      new Set<String>{ 'call', 'case', 'contact', 'metadata' },
      payloadMap.keySet(),
      'Adding contact must not add, drop, or rename any other payload root'
    );
  }

  @IsTest
  static void testExtractAcwDuration_SkipsMalformedEntries() {
    Object callJson = JSON.deserializeUntyped(
      '{"handle_durations":[' +
        '"not-an-object",' +
        '{"other_field":5},' +
        '{"acw_duration":null},' +
        '{"acw_duration":"not-a-number"},' +
        '{"acw_duration":9}' +
        ']}'
    );

    Decimal acw = QualCallPayloadBuilder.extractAcwDuration(callJson);

    Assert.isNotNull(
      acw,
      'A single well-formed entry must still yield an ACW total'
    );
    Assert.areEqual(
      9,
      acw.intValue(),
      'Non-object entries, missing and null acw_duration, and unparseable values must all be skipped rather than aborting the sum'
    );
  }

  @IsTest
  static void testGetCallIdAsString_NullWhenNeitherSourceSuppliesOne() {
    Assert.isNull(
      QualCallPayloadBuilder.getCallIdAsString(null, null),
      'Call Id must be null when neither the call JSON nor the session supplies one'
    );
  }

  @IsTest
  static void testGetPayloadSizeBytes_ZeroForBlankPayload() {
    Assert.areEqual(
      0,
      QualCallPayloadBuilder.getPayloadSizeBytes(''),
      'A blank payload must measure zero bytes rather than throwing'
    );
  }
}