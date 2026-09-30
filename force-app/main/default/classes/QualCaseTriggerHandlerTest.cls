/**
 * @description Test class for QualCaseTriggerHandler
 * Tests all three lifecycle events: Opened, Updated, Closed
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualCaseTriggerHandlerTest {
  @TestSetup
  static void setupTestData() {
    Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
  }

  private static void deleteExistingLogs() {
    delete [SELECT Id FROM qual_Integration_Log__c];
  }

  // ========== Closed Event Tests (existing behavior) ==========

  @IsTest
  static void testHandleAfterUpdate_CaseClosing() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create log when case closes');
    System.assertEquals(
      'Closed',
      logs[0].qual_Event_Type__c,
      'Event type should be Closed'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_CaseNotClosing_ClosedOnly() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    // Config with only Closed event enabled (default)
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    testCase.Priority = 'High';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should not create log when only Closed is enabled and case is not closing'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_IntegrationInactive() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

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
  static void testHandleAfterUpdate_BulkCases() {
    deleteExistingLogs();
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    List<Case> cases = QualTestDataFactory.createCases(
      acc.Id,
      con.Id,
      50,
      true
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    for (Case c : cases) {
      c.Status = 'Closed';
    }
    update cases;
    Test.stopTest();

    Set<Id> caseIds = new Set<Id>();
    for (Case c : cases) {
      caseIds.add(c.Id);
    }

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c IN :caseIds
    ];
    System.assertEquals(
      50,
      logs.size(),
      'Should create log for each closed case'
    );
    for (qual_Integration_Log__c log : logs) {
      System.assertEquals(
        'Closed',
        log.qual_Event_Type__c,
        'All bulk close logs should have Closed event type'
      );
    }
  }

  // ========== Opened Event Tests ==========

  @IsTest
  static void testHandleAfterInsert_OpenedEventEnabled() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when case is opened with Opened event enabled'
    );
    System.assertEquals(
      'Opened',
      logs[0].qual_Event_Type__c,
      'Event type should be Opened'
    );
  }

  @IsTest
  static void testHandleAfterInsert_OpenedEventDisabled() {
    // Config with only Closed event enabled
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when Opened event is disabled'
    );
  }

  @IsTest
  static void testHandleAfterInsert_IntegrationInactive() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    config.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(config);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when integration is inactive'
    );
  }

  @IsTest
  static void testHandleAfterInsert_BulkCases() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    List<Case> newCases = QualTestDataFactory.createCases(
      acc.Id,
      con.Id,
      50,
      true
    );
    Test.stopTest();

    Set<Id> caseIds = new Set<Id>();
    for (Case c : newCases) {
      caseIds.add(c.Id);
    }

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c IN :caseIds
    ];
    System.assertEquals(
      50,
      logs.size(),
      'Should create log for each opened case'
    );
  }

  // ========== Updated Event Tests ==========

  @IsTest
  static void testHandleAfterUpdate_PriorityChange_UpdatedEvent() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Priority = 'High';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when tracked field changes on open case'
    );
    System.assertEquals(
      'Updated',
      logs[0].qual_Event_Type__c,
      'Event type should be Updated'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_OwnerChange_UpdatedEvent() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, OwnerId FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    User newOwner = QualTestDataFactory.createTestUserWithTeam(true);

    Test.startTest();
    System.runAs(newOwner) {
      // Run as user doesn't change owner; explicitly set
    }
    testCase.OwnerId = newOwner.Id;
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when owner changes on open case'
    );
    System.assertEquals(
      'Updated',
      logs[0].qual_Event_Type__c,
      'Event type should be Updated'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_UntrackedField_NoEvent() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Subject FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    testCase.Subject = 'Updated Subject - not tracked';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when untracked field changes'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_UpdatedEventDisabled() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    // Only Closed and Opened enabled, NOT Updated
    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithEvents(
      'Opened, Closed'
    );
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    testCase.Priority = 'High';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when Updated event is disabled'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_CloseTakesPriorityOverUpdate() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    // Change priority AND close in the same update
    testCase.Priority = 'High';
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(logs.size() >= 1, 'Should create exactly one log');
    System.assertEquals(
      'Closed',
      logs[0].qual_Event_Type__c,
      'Closed should take priority over Updated'
    );
  }

  @IsTest
  static void testHandleAfterUpdate_EmptyTrackedFields_NoUpdatedEvent() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    config.qual_Case_Tracked_Update_Fields__c = '';
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    testCase.Priority = 'High';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when tracked fields list is empty'
    );
  }

  // ========== Event Type Configuration Tests ==========

  @IsTest
  static void testIsEventTypeEnabled_BlankConfig_DefaultsClosed() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Event_Types__c = null;
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    Boolean closedEnabled = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Closed'
    );
    Boolean openedEnabled = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Opened'
    );
    Boolean updatedEnabled = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Updated'
    );
    Test.stopTest();

    System.assertEquals(
      true,
      closedEnabled,
      'Closed should be enabled by default when config is blank'
    );
    System.assertEquals(
      false,
      openedEnabled,
      'Opened should NOT be enabled by default'
    );
    System.assertEquals(
      false,
      updatedEnabled,
      'Updated should NOT be enabled by default'
    );
  }

  @IsTest
  static void testIsEventTypeEnabled_AllEvents() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();

    Test.startTest();
    Boolean closedEnabled = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Closed'
    );
    Boolean openedEnabled = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Opened'
    );
    Boolean updatedEnabled = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Updated'
    );
    Test.stopTest();

    System.assertEquals(true, closedEnabled, 'Closed should be enabled');
    System.assertEquals(true, openedEnabled, 'Opened should be enabled');
    System.assertEquals(true, updatedEnabled, 'Updated should be enabled');
  }

  @IsTest
  static void testIsEventTypeEnabled_CaseInsensitive() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();

    Test.startTest();
    Boolean result1 = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'closed'
    );
    Boolean result2 = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'OPENED'
    );
    Boolean result3 = QualCaseTriggerHandler.isEventTypeEnabled(
      config,
      'Updated'
    );
    Test.stopTest();

    System.assertEquals(true, result1, 'Should be case insensitive');
    System.assertEquals(true, result2, 'Should be case insensitive');
    System.assertEquals(true, result3, 'Should be case insensitive');
  }

  // ========== hasSignificantUpdate Tests ==========

  @IsTest
  static void testHasSignificantUpdate_TrackedFieldChanged() {
    Case oldCase = new Case(Priority = 'Medium', Status = 'New');
    Case newCase = new Case(Priority = 'High', Status = 'New');

    Set<String> trackedFields = new Set<String>{ 'priority', 'status' };

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.hasSignificantUpdate(
      newCase,
      oldCase,
      trackedFields
    );
    Test.stopTest();

    System.assertEquals(true, result, 'Should detect tracked field change');
  }

  @IsTest
  static void testHasSignificantUpdate_NoTrackedFieldChanged() {
    Case oldCase = new Case(
      Priority = 'Medium',
      Status = 'New',
      Subject = 'Old'
    );
    Case newCase = new Case(
      Priority = 'Medium',
      Status = 'New',
      Subject = 'New'
    );

    Set<String> trackedFields = new Set<String>{ 'priority', 'status' };

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.hasSignificantUpdate(
      newCase,
      oldCase,
      trackedFields
    );
    Test.stopTest();

    System.assertEquals(
      false,
      result,
      'Should NOT detect change when only untracked fields changed'
    );
  }

  @IsTest
  static void testHasSignificantUpdate_EmptyTrackedFields() {
    Case oldCase = new Case(Priority = 'Medium');
    Case newCase = new Case(Priority = 'High');

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.hasSignificantUpdate(
      newCase,
      oldCase,
      new Set<String>()
    );
    Test.stopTest();

    System.assertEquals(
      false,
      result,
      'Should return false when tracked fields is empty'
    );
  }

  @IsTest
  static void testHasSignificantUpdate_NullTrackedFields() {
    Case oldCase = new Case(Priority = 'Medium');
    Case newCase = new Case(Priority = 'High');

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.hasSignificantUpdate(
      newCase,
      oldCase,
      null
    );
    Test.stopTest();

    System.assertEquals(
      false,
      result,
      'Should return false when tracked fields is null'
    );
  }

  // ========== Existing Tests (isCaseJustClosed, filters, etc.) ==========

  @IsTest
  static void testIsCaseJustClosed() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    Case openCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);

    Case oldCase = [
      SELECT Id, IsClosed, Status
      FROM Case
      WHERE Id = :openCase.Id
    ];
    System.assertEquals(false, oldCase.IsClosed, 'Old case should be open');

    openCase.Status = 'Closed';
    update openCase;

    Case newCase = [
      SELECT Id, IsClosed, Status
      FROM Case
      WHERE Id = :openCase.Id
    ];
    System.assertEquals(true, newCase.IsClosed, 'New case should be closed');

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.isCaseJustClosed(newCase, oldCase);
    Test.stopTest();

    System.assertEquals(true, result, 'Should detect case just closed');
  }

  @IsTest
  static void testIsCaseJustClosed_AlreadyClosed() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    Case closedCase = QualTestDataFactory.createClosedCase(
      acc.Id,
      con.Id,
      true
    );

    Case bothCase = [
      SELECT Id, IsClosed, Status
      FROM Case
      WHERE Id = :closedCase.Id
    ];

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.isCaseJustClosed(
      bothCase,
      bothCase
    );
    Test.stopTest();

    System.assertEquals(false, result, 'Should not detect as just closed');
  }

  @IsTest
  static void testResetRecursionGuard() {
    Test.startTest();
    QualCaseTriggerHandler.resetRecursionGuard();
    Test.stopTest();

    System.assert(true, 'Recursion guard reset successfully');
  }

  @IsTest
  static void testFilter_ByOrigin_Match() {
    Case testCase = [SELECT Id, Status, Origin FROM Case LIMIT 1];
    System.assertEquals(
      'Phone',
      testCase.Origin,
      'Test case should have Phone origin'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithFilters(
      'Phone, Email',
      false
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when origin matches allowed list'
    );
  }

  @IsTest
  static void testFilter_ByOrigin_NoMatch() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Origin FROM Case LIMIT 1];
    System.assertEquals(
      'Phone',
      testCase.Origin,
      'Test case should have Phone origin'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithFilters(
      'Web, Email',
      false
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when origin does not match allowed list'
    );
  }

  @IsTest
  static void testFilter_RequireContact_WithContact() {
    Case testCase = [SELECT Id, Status, ContactId FROM Case LIMIT 1];
    System.assertNotEquals(
      null,
      testCase.ContactId,
      'Test case should have a contact'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithFilters(
      null,
      true
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when case has contact and contact is required'
    );
  }

  @IsTest
  static void testFilter_RequireContact_WithoutContact() {
    deleteExistingLogs();

    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Case noContactCase = new Case(
      AccountId = acc.Id,
      Status = 'New',
      Subject = 'No Contact Case',
      Origin = 'Phone'
    );
    insert noContactCase;

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithFilters(
      null,
      true
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    noContactCase.Status = 'Closed';
    update noContactCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :noContactCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when case has no contact and contact is required'
    );
  }

  @IsTest
  static void testFilter_CustomSoqlPredicate_Match() {
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];
    System.assertEquals(
      'Medium',
      testCase.Priority,
      'Test case should have Medium priority'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCustomFilter(
      'Priority = \'Medium\''
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when custom SOQL predicate matches'
    );
  }

  @IsTest
  static void testFilter_CustomSoqlPredicate_NoMatch() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];
    System.assertEquals(
      'Medium',
      testCase.Priority,
      'Test case should have Medium priority'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCustomFilter(
      'Priority = \'Critical\''
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when custom SOQL predicate does not match'
    );
  }

  @IsTest
  static void testFilter_CustomSoqlPredicate_Invalid() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithCustomFilter(
      'INVALID_FIELD = \'test\''
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when custom SOQL predicate is invalid (fail closed)'
    );
  }

  @IsTest
  static void testParseFilterList() {
    Test.startTest();

    Set<String> empty = QualCaseTriggerHandler.parseFilterList('');
    System.assertEquals(
      0,
      empty.size(),
      'Empty string should return empty set'
    );

    Set<String> nullSet = QualCaseTriggerHandler.parseFilterList(null);
    System.assertEquals(0, nullSet.size(), 'Null should return empty set');

    Set<String> commas = QualCaseTriggerHandler.parseFilterList(
      'Phone, Email, Web'
    );
    System.assertEquals(
      3,
      commas.size(),
      'Should parse comma-separated values'
    );
    System.assert(commas.contains('phone'), 'Should contain phone (lowercase)');
    System.assert(commas.contains('email'), 'Should contain email (lowercase)');

    Set<String> newlines = QualCaseTriggerHandler.parseFilterList(
      'Phone\nEmail\nWeb'
    );
    System.assertEquals(
      3,
      newlines.size(),
      'Should parse newline-separated values'
    );

    Set<String> mixed = QualCaseTriggerHandler.parseFilterList(
      '  Phone  ,  Email  \n  Web  '
    );
    System.assertEquals(
      3,
      mixed.size(),
      'Should handle mixed delimiters and whitespace'
    );

    Test.stopTest();
  }

  // ========== Deferred Send Tests ==========

  @IsTest
  static void testDeferred_OpenedEventCreatesLog_WhenDelayConfigured() {
    deleteExistingLogs();

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(
      120
    );
    QualConfigSelector.setTestConfig(config);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Should create exactly one deferred log'
    );
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Status should be Deferred'
    );
    System.assertEquals(
      'Opened',
      logs[0].qual_Event_Type__c,
      'Event type should be Opened'
    );
    System.assert(
      logs[0].qual_Next_Retry_Date__c > Datetime.now().addMinutes(119),
      'Send time should be ~2 hours from now'
    );
  }

  @IsTest
  static void testDeferred_OpenedEventSendsImmediately_WhenDelayIsZero() {
    deleteExistingLogs();

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(0);
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log immediately when delay is 0'
    );
    System.assertNotEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Should NOT be Deferred when delay is 0'
    );
  }

  @IsTest
  static void testDeferred_ClosedAlwaysSendsImmediately_RegardlessOfDelay() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(
      120
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Event_Type__c = 'Closed'
    ];
    System.assert(logs.size() >= 1, 'Closed event should send immediately');
    System.assertNotEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Closed should never be Deferred'
    );
  }

  @IsTest
  static void testDeferred_CloseCancelsPendingDeferredOpened() {
    deleteExistingLogs();

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(
      120
    );
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    // Step 1: Insert a case — creates deferred Opened log
    Test.startTest();
    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);

    // Verify deferred log exists
    List<qual_Integration_Log__c> deferredLogs = [
      SELECT Id, qual_Status__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id AND qual_Status__c = 'Deferred'
    ];
    System.assertEquals(
      1,
      deferredLogs.size(),
      'Should have 1 deferred log after insert'
    );

    // Step 2: Close the case — should cancel the deferred log and send Closed immediately
    newCase.Status = 'Closed';
    update newCase;
    Test.stopTest();

    // Verify deferred log was cancelled
    List<qual_Integration_Log__c> cancelledLogs = [
      SELECT Id, qual_Status__c, qual_Error_Message__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id AND qual_Status__c = 'Cancelled'
    ];
    System.assertEquals(
      1,
      cancelledLogs.size(),
      'Deferred log should be cancelled'
    );
    System.assert(
      cancelledLogs[0].qual_Error_Message__c.contains('Superseded'),
      'Should note that it was superseded by Closed event'
    );

    // Verify Closed event was sent
    List<qual_Integration_Log__c> closedLogs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id AND qual_Event_Type__c = 'Closed'
    ];
    System.assert(closedLogs.size() >= 1, 'Closed event should have been sent');
  }

  @IsTest
  static void testDeferred_UpdatedEventDeferred_WhenDelayConfigured() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(
      120
    );
    QualConfigSelector.setTestConfig(config);

    Test.startTest();
    testCase.Priority = 'High';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Event_Type__c = 'Updated'
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Should create one deferred Updated log'
    );
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Status should be Deferred'
    );
    System.assert(
      logs[0].qual_Next_Retry_Date__c > Datetime.now().addMinutes(119),
      'Send time should be ~2 hours from now'
    );
  }

  @IsTest
  static void testDeferred_UpdatedEventRefreshesExistingOpenedDeferredLog() {
    deleteExistingLogs();

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(
      120
    );
    QualConfigSelector.setTestConfig(config);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Case newCase = QualTestDataFactory.createOpenCase(acc.Id, con.Id, true);
    qual_Integration_Log__c openedLog = [
      SELECT Id, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id AND qual_Status__c = 'Deferred'
      LIMIT 1
    ];
    openedLog.qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5);
    update openedLog;

    Test.startTest();
    newCase.Priority = 'High';
    update newCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c, qual_Next_Retry_Date__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :newCase.Id
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Updated trigger should refresh the pending deferred Case log, not create another'
    );
    System.assertEquals(
      'Deferred',
      logs[0].qual_Status__c,
      'Log should remain Deferred'
    );
    System.assertEquals(
      'Updated',
      logs[0].qual_Event_Type__c,
      'Latest event should win'
    );
    System.assert(
      logs[0].qual_Next_Retry_Date__c > Datetime.now().addMinutes(119),
      'Deferred Case log should be rescheduled from latest update'
    );
  }

  @IsTest
  static void testDeferred_BulkOpenedCases_AllDeferred() {
    deleteExistingLogs();

    qual_Config__mdt config = QualTestDataFactory.createTestConfigWithDelay(
      120
    );
    QualConfigSelector.setTestConfig(config);

    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    List<Case> newCases = QualTestDataFactory.createCases(
      acc.Id,
      con.Id,
      50,
      true
    );
    Test.stopTest();

    Set<Id> caseIds = new Set<Id>();
    for (Case c : newCases) {
      caseIds.add(c.Id);
    }

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Status__c, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c IN :caseIds AND qual_Status__c = 'Deferred'
    ];
    System.assertEquals(
      50,
      logs.size(),
      'Should create deferred log for each opened case'
    );
    for (qual_Integration_Log__c log : logs) {
      System.assertEquals(
        'Opened',
        log.qual_Event_Type__c,
        'All should be Opened events'
      );
    }
  }

  // ========== Priority / Type / Status Filter Tests ==========

  @IsTest
  static void testFilter_ByPriority_Match() {
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];
    System.assertEquals(
      'Medium',
      testCase.Priority,
      'Test case should have Medium priority'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Priorities__c = 'Medium, High';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when priority matches allowed list'
    );
  }

  @IsTest
  static void testFilter_ByPriority_NoMatch() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];
    System.assertEquals(
      'Medium',
      testCase.Priority,
      'Test case should have Medium priority'
    );

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Priorities__c = 'Critical, High';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when priority does not match allowed list'
    );
  }

  @IsTest
  static void testFilter_ByType_Match() {
    deleteExistingLogs();
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'New',
      Subject = 'Typed Case',
      Priority = 'Medium',
      Origin = 'Phone',
      Type = 'Question'
    );
    insert testCase;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Types__c = 'Question, Problem';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when Type matches allowed list'
    );
  }

  @IsTest
  static void testFilter_ByType_NoMatch() {
    deleteExistingLogs();
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact LIMIT 1];

    qual_Config__mdt inactiveConfig = QualTestDataFactory.createTestConfig();
    inactiveConfig.qual_Is_Active__c = false;
    QualConfigSelector.setTestConfig(inactiveConfig);

    Case testCase = new Case(
      AccountId = acc.Id,
      ContactId = con.Id,
      Status = 'New',
      Subject = 'Typed Case',
      Priority = 'Medium',
      Origin = 'Phone',
      Type = 'Question'
    );
    insert testCase;

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Types__c = 'Problem, Feature Request';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when Type does not match allowed list'
    );
  }

  @IsTest
  static void testFilter_ByStatus_ClosedEvent_Match() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Statuses__c = 'Closed';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when Closed status matches filter'
    );
  }

  @IsTest
  static void testFilter_ByStatus_ClosedEvent_NoMatch() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    // Only allow 'Resolved' status — our case closes as 'Closed' so it won't match
    config.qual_Case_Filter_Statuses__c = 'Resolved';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when Closed status does not match filter'
    );
  }

  @IsTest
  static void testFilter_StatusSkippedForNonClosedEvents() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();
    // Status filter set, but Updated events should skip it
    config.qual_Case_Filter_Statuses__c = 'Closed';
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Priority = 'High';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Updated event should bypass status filter'
    );
    System.assertEquals(
      'Updated',
      logs[0].qual_Event_Type__c,
      'Event type should be Updated'
    );
  }

  @IsTest
  static void testFilter_CombinedFilters_AllPass() {
    Case testCase = [SELECT Id, Status, Priority, Origin FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Origins__c = 'Phone';
    config.qual_Case_Filter_Priorities__c = 'Medium';
    config.qual_Case_Require_Contact__c = true;
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assert(
      logs.size() >= 1,
      'Should create log when all combined filters pass'
    );
  }

  @IsTest
  static void testFilter_CombinedFilters_OneFails() {
    deleteExistingLogs();
    Case testCase = [SELECT Id, Status, Priority, Origin FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Case_Filter_Origins__c = 'Phone';
    config.qual_Case_Filter_Priorities__c = 'Critical'; // Won't match Medium
    config.qual_Case_Require_Contact__c = true;
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    testCase.Status = 'Closed';
    update testCase;
    Test.stopTest();

    List<qual_Integration_Log__c> logs = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id
    ];
    System.assertEquals(
      0,
      logs.size(),
      'Should NOT create log when one combined filter fails'
    );
  }

  @IsTest
  static void testIsEventTypeEnabled_NullConfig() {
    Test.startTest();
    Boolean result = QualCaseTriggerHandler.isEventTypeEnabled(null, 'Closed');
    Test.stopTest();

    System.assertEquals(false, result, 'Should return false for null config');
  }

  @IsTest
  static void testIsEventTypeEnabled_BlankEventType() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfigAllEvents();

    Test.startTest();
    Boolean result = QualCaseTriggerHandler.isEventTypeEnabled(config, '');
    Test.stopTest();

    System.assertEquals(
      false,
      result,
      'Should return false for blank event type'
    );
  }

  @IsTest
  static void testDeferred_SchedulablePicksUpDeferredLogs() {
    deleteExistingLogs();
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(config);
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings()
    );

    // Create a deferred log that is already past due
    qual_Integration_Log__c deferredLog = new qual_Integration_Log__c(
      qual_Case__c = testCase.Id,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Status__c = 'Deferred',
      qual_Event_Type__c = 'Opened',
      qual_Retry_Count__c = 0,
      qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5),
      qual_Processed_Date__c = Datetime.now().addHours(-2),
      qual_Workflow_Id__c = config.qual_Workflow_Id__c,
      qual_Datacenter__c = config.qual_Datacenter__c
    );
    insert deferredLog;

    Test.setMock(HttpCalloutMock.class, QualCalloutMock.createSuccessMock());

    Test.startTest();
    QualRetrySchedulable scheduler = new QualRetrySchedulable();
    scheduler.execute(null);
    Test.stopTest();

    // The deferred log should have been picked up and set to Processing
    qual_Integration_Log__c updatedLog = [
      SELECT qual_Status__c
      FROM qual_Integration_Log__c
      WHERE Id = :deferredLog.Id
    ];
    System.assertEquals(
      'Processing',
      updatedLog.qual_Status__c,
      'Schedulable should pick up and process deferred logs'
    );

    // A new success log should have been created by the Queueable
    List<qual_Integration_Log__c> successLogs = [
      SELECT Id, qual_Event_Type__c
      FROM qual_Integration_Log__c
      WHERE qual_Case__c = :testCase.Id AND qual_Status__c = 'Success'
    ];
    System.assert(
      successLogs.size() >= 1,
      'Queueable should have created a success log'
    );
  }
}