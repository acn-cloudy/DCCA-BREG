@isTest
public class BREGHandlerErrorEventHandlerTest {

    @testSetup
    static void setupData() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('BREG_Case')
            .getRecordTypeId();

        Case testCase = new Case(
            Subject = 'Handler Error Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId
        );
        insert testCase;
    }

    // -------------------------------------------------------------------------
    // Happy path: single event with all fields populated
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_SingleEvent_UpdatesCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Datetime ts = Datetime.newInstanceGmt(2024, 6, 15, 12, 0, 0);

        BREG_Handler_Error__e evt = new BREG_Handler_Error__e(
            Case_Id__c       = String.valueOf(testCase.Id),
            User_Id__c       = UserInfo.getUserId(),
            Error_Message__c = 'Something went wrong',
            Stack_Trace__c   = 'Class.Foo.bar: line 10',
            Timestamp__c     = ts
        );

        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(new List<BREG_Handler_Error__e>{ evt });
        Test.stopTest();

        Case updated = [SELECT breg_Handler_Log_Message__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updated.breg_Handler_Log_Message__c, 'Log message should be populated');

        Map<String, Object> log = (Map<String, Object>) JSON.deserializeUntyped(updated.breg_Handler_Log_Message__c);
        System.assertEquals(String.valueOf(testCase.Id), log.get('caseId'),        'caseId mismatch');
        System.assertEquals(UserInfo.getUserId(),        log.get('userId'),         'userId mismatch');
        System.assertEquals('Something went wrong',      log.get('errorMessage'),   'errorMessage mismatch');
        System.assertEquals('Class.Foo.bar: line 10',    log.get('stackTrace'),     'stackTrace mismatch');
        System.assertEquals('2024-06-15T12:00:00Z',      log.get('timestamp'),      'timestamp mismatch');
    }

    // -------------------------------------------------------------------------
    // Null timestamp: timestamp field in JSON should be null (not absent)
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_NullTimestamp_WritesNullInJson() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        BREG_Handler_Error__e evt = new BREG_Handler_Error__e(
            Case_Id__c       = String.valueOf(testCase.Id),
            User_Id__c       = UserInfo.getUserId(),
            Error_Message__c = 'Null ts error',
            Stack_Trace__c   = 'trace',
            Timestamp__c     = null
        );

        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(new List<BREG_Handler_Error__e>{ evt });
        Test.stopTest();

        Case updated = [SELECT breg_Handler_Log_Message__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updated.breg_Handler_Log_Message__c);

        Map<String, Object> log = (Map<String, Object>) JSON.deserializeUntyped(updated.breg_Handler_Log_Message__c);
        System.assert(log.containsKey('timestamp'), 'timestamp key should be present');
        System.assertEquals(null, log.get('timestamp'), 'timestamp should be null');
    }

    // -------------------------------------------------------------------------
    // Blank Case_Id: event is skipped, no DML, no exception
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_BlankCaseId_Skipped() {
        BREG_Handler_Error__e evt = new BREG_Handler_Error__e(
            Case_Id__c       = '',
            User_Id__c       = UserInfo.getUserId(),
            Error_Message__c = 'Should be skipped',
            Stack_Trace__c   = 'trace',
            Timestamp__c     = Datetime.now()
        );

        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(new List<BREG_Handler_Error__e>{ evt });
        Test.stopTest();

        // No exception thrown and no Case was updated (log still null)
        Case testCase = [SELECT breg_Handler_Log_Message__c FROM Case LIMIT 1];
        System.assertEquals(null, testCase.breg_Handler_Log_Message__c, 'Blank Case_Id event should produce no update');
    }

    // -------------------------------------------------------------------------
    // Null Case_Id: event is skipped, no DML, no exception
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_NullCaseId_Skipped() {
        BREG_Handler_Error__e evt = new BREG_Handler_Error__e(
            Case_Id__c       = null,
            User_Id__c       = UserInfo.getUserId(),
            Error_Message__c = 'Should be skipped too',
            Stack_Trace__c   = 'trace',
            Timestamp__c     = Datetime.now()
        );

        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(new List<BREG_Handler_Error__e>{ evt });
        Test.stopTest();

        Case testCase = [SELECT breg_Handler_Log_Message__c FROM Case LIMIT 1];
        System.assertEquals(null, testCase.breg_Handler_Log_Message__c, 'Null Case_Id event should produce no update');
    }

    // -------------------------------------------------------------------------
    // Empty list: no-op, no exception
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_EmptyList_NoOp() {
        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(new List<BREG_Handler_Error__e>());
        Test.stopTest();

        // Simply assert no exception was thrown; no assertions needed beyond test completion
        System.assert(true, 'Empty event list should not throw');
    }

    // -------------------------------------------------------------------------
    // Bulk: multiple events for multiple Cases all get updated
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_BulkEvents_AllCasesUpdated() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('BREG_Case')
            .getRecordTypeId();

        // Create additional cases beyond the one from @testSetup
        List<Case> extraCases = new List<Case>();
        for (Integer i = 0; i < 4; i++) {
            extraCases.add(new Case(
                Subject = 'Bulk Error Case ' + i,
                Status = 'New',
                Origin = 'Web',
                RecordTypeId = bregCaseRecordTypeId
            ));
        }
        insert extraCases;

        List<BREG_Handler_Error__e> events = new List<BREG_Handler_Error__e>();
        for (Case c : extraCases) {
            events.add(new BREG_Handler_Error__e(
                Case_Id__c       = String.valueOf(c.Id),
                User_Id__c       = UserInfo.getUserId(),
                Error_Message__c = 'Bulk error for ' + c.Subject,
                Stack_Trace__c   = 'bulk trace',
                Timestamp__c     = Datetime.now()
            ));
        }

        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(events);
        Test.stopTest();

        List<Case> updated = [
            SELECT Id, breg_Handler_Log_Message__c
            FROM Case
            WHERE Id IN :extraCases
        ];

        for (Case c : updated) {
            System.assertNotEquals(null, c.breg_Handler_Log_Message__c,
                'Every case in the bulk set should have a log message');
            Map<String, Object> log = (Map<String, Object>) JSON.deserializeUntyped(c.breg_Handler_Log_Message__c);
            System.assertEquals(String.valueOf(c.Id), log.get('caseId'), 'caseId should match for ' + c.Id);
        }
    }

    // -------------------------------------------------------------------------
    // Mixed: some events with valid Case_Id, some blank — only valid ones updated
    // -------------------------------------------------------------------------
    @isTest
    static void testHandleEvents_MixedValidity_OnlyValidUpdated() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        List<BREG_Handler_Error__e> events = new List<BREG_Handler_Error__e>{
            new BREG_Handler_Error__e(
                Case_Id__c       = '',
                User_Id__c       = UserInfo.getUserId(),
                Error_Message__c = 'skipped blank',
                Stack_Trace__c   = 'trace',
                Timestamp__c     = Datetime.now()
            ),
            new BREG_Handler_Error__e(
                Case_Id__c       = String.valueOf(testCase.Id),
                User_Id__c       = UserInfo.getUserId(),
                Error_Message__c = 'valid event',
                Stack_Trace__c   = 'trace',
                Timestamp__c     = Datetime.now()
            ),
            new BREG_Handler_Error__e(
                Case_Id__c       = null,
                User_Id__c       = UserInfo.getUserId(),
                Error_Message__c = 'skipped null',
                Stack_Trace__c   = 'trace',
                Timestamp__c     = Datetime.now()
            )
        };

        Test.startTest();
        BREGHandlerErrorEventHandler.handleEvents(events);
        Test.stopTest();

        Case updated = [SELECT breg_Handler_Log_Message__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updated.breg_Handler_Log_Message__c, 'Valid event should update the Case');

        Map<String, Object> log = (Map<String, Object>) JSON.deserializeUntyped(updated.breg_Handler_Log_Message__c);
        System.assertEquals('valid event', log.get('errorMessage'));
    }

    // -------------------------------------------------------------------------
    // Trigger coverage: publish a real BREG_Handler_Error__e event so that
    // BREGHandlerErrorEventTrigger is executed via Test.getEventBus().deliver()
    // -------------------------------------------------------------------------
    @isTest
    static void testTrigger_PublishEvent_FiresTriggerAndUpdatesCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Datetime ts = Datetime.newInstanceGmt(2024, 1, 1, 0, 0, 0);

        BREG_Handler_Error__e evt = new BREG_Handler_Error__e(
            Case_Id__c       = String.valueOf(testCase.Id),
            User_Id__c       = UserInfo.getUserId(),
            Error_Message__c = 'Trigger coverage error',
            Stack_Trace__c   = 'trigger trace',
            Timestamp__c     = ts
        );

        Test.startTest();
        EventBus.publish(evt);
        Test.getEventBus().deliver();
        Test.stopTest();

        Case updated = [SELECT breg_Handler_Log_Message__c FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updated.breg_Handler_Log_Message__c,
            'Trigger should have fired and written the log message');

        Map<String, Object> log = (Map<String, Object>) JSON.deserializeUntyped(updated.breg_Handler_Log_Message__c);
        System.assertEquals('Trigger coverage error', log.get('errorMessage'));
        System.assertEquals('2024-01-01T00:00:00Z', log.get('timestamp'));
    }
}