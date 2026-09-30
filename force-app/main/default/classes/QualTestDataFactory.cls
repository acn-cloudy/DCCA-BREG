/**
 * @description Test data factory for Qualtrics integration tests
 * @author Qualtrics Integration Team
 */
@IsTest
public class QualTestDataFactory {
  private static final String TEST_PHONE = '(555) 123-4567';
  private static final String TEST_EMAIL = 'test@example.com';

  /**
   * @description Create test Account
   * @param name Account name
   * @param doInsert Whether to insert the record
   * @return Account record
   */
  public static Account createAccount(String name, Boolean doInsert) {
    Account acc = new Account(Name = name);

    if (doInsert) {
      insert acc;
    }

    return acc;
  }

  /**
   * @description Create test Account with default name
   * @param doInsert Whether to insert the record
   * @return Account record
   */
  public static Account createAccount(Boolean doInsert) {
    return createAccount('Test Account', doInsert);
  }

  /**
   * @description Create test Contact
   * @param accountId Related Account ID
   * @param firstName First name
   * @param lastName Last name
   * @param doInsert Whether to insert the record
   * @return Contact record
   */
  public static Contact createContact(
    Id accountId,
    String firstName,
    String lastName,
    Boolean doInsert
  ) {
    Contact con = new Contact(
      AccountId = accountId,
      FirstName = firstName,
      LastName = lastName,
      Email = TEST_EMAIL,
      Phone = TEST_PHONE
    );

    if (doInsert) {
      insert con;
    }

    return con;
  }

  /**
   * @description Create test Contact with default values
   * @param accountId Related Account ID
   * @param doInsert Whether to insert the record
   * @return Contact record
   */
  public static Contact createContact(Id accountId, Boolean doInsert) {
    return createContact(accountId, 'Test', 'Contact', doInsert);
  }

  /**
   * @description Create test Case
   * @param accountId Related Account ID
   * @param contactId Related Contact ID
   * @param status Case status
   * @param doInsert Whether to insert the record
   * @return Case record
   */
  public static Case createCase(
    Id accountId,
    Id contactId,
    String status,
    Boolean doInsert
  ) {
    Case c = new Case(
      AccountId = accountId,
      ContactId = contactId,
      Status = status,
      Subject = 'Test Case',
      Description = 'Test case description',
      Priority = 'Medium',
      Origin = 'Phone'
    );

    if (doInsert) {
      insert c;
    }

    return c;
  }

  /**
   * @description Create open test Case
   * @param accountId Related Account ID
   * @param contactId Related Contact ID
   * @param doInsert Whether to insert the record
   * @return Case record
   */
  public static Case createOpenCase(
    Id accountId,
    Id contactId,
    Boolean doInsert
  ) {
    return createCase(accountId, contactId, 'New', doInsert);
  }

  /**
   * @description Create closed test Case
   * @param accountId Related Account ID
   * @param contactId Related Contact ID
   * @param doInsert Whether to insert the record
   * @return Case record
   */
  public static Case createClosedCase(
    Id accountId,
    Id contactId,
    Boolean doInsert
  ) {
    return createCase(accountId, contactId, 'Closed', doInsert);
  }

  /**
   * @description Create multiple test Cases
   * @param accountId Related Account ID
   * @param contactId Related Contact ID
   * @param count Number of Cases to create
   * @param doInsert Whether to insert the records
   * @return List of Case records
   */
  public static List<Case> createCases(
    Id accountId,
    Id contactId,
    Integer count,
    Boolean doInsert
  ) {
    List<Case> cases = new List<Case>();

    for (Integer i = 0; i < count; i++) {
      Case c = new Case(
        AccountId = accountId,
        ContactId = contactId,
        Status = 'New',
        Subject = 'Test Case ' + i,
        Description = 'Test case description ' + i,
        Priority = 'Medium',
        Origin = 'Phone'
      );
      cases.add(c);
    }

    if (doInsert) {
      insert cases;
    }

    return cases;
  }

  /**
   * @description Create test configuration Custom Metadata
   * @return qual_Config__mdt record (not insertable, for test context only)
   */
  public static qual_Config__mdt createTestConfig() {
    qual_Config__mdt config = new qual_Config__mdt(
      DeveloperName = 'Test_Config',
      MasterLabel = 'Test Config',
      qual_Workflow_Id__c = 'test-token-uuid-12345',
      qual_Case_Workflow_Id__c = 'test-case-token-uuid-12345',
      qual_Call_Workflow_Id__c = 'test-call-token-uuid-12345',
      qual_Datacenter__c = 'pdx1',
      qual_Named_Credential__c = 'qual_Qualtrics_API',
      qual_Is_Active__c = true,
      qual_Max_Retries__c = 3,
      qual_Retry_Interval_Minutes__c = 15,
      qual_Default_Country_Code__c = '1',
      qual_Environment__c = 'DEV',
      qual_Is_Test_Contact__c = true,
      qual_Alert_Email_Addresses__c = 'test@example.com',
      qual_Payload_Version__c = '2.0',
      qual_Max_Payload_Size_KB__c = 100,
      qual_Timeout_Seconds__c = 30,
      // Case selection filters - default to no restrictions
      qual_Case_Require_Contact__c = false,
      qual_Case_Filter_Statuses__c = null,
      qual_Case_Filter_Origins__c = null,
      qual_Case_Filter_Priorities__c = null,
      qual_Case_Filter_Types__c = null,
      qual_Case_Filter_RecordTypes__c = null,
      qual_Case_Custom_Soql_Filter__c = null,
      qual_Log_Level__c = 'Info',
      // Lifecycle events - default to Closed only (backward compatible)
      qual_Case_Event_Types__c = 'Closed',
      qual_Case_Tracked_Update_Fields__c = 'Status, Priority, OwnerId, ContactId, IsEscalated',
      qual_Case_Opened_Delay_Minutes__c = 0,
      qual_Call_Delay_Minutes__c = 0,
      qual_Log_Retention_Days__c = 60
    );

    return config;
  }

  /**
   * @description Create test config with all lifecycle events enabled
   * @return qual_Config__mdt with Opened, Updated, Closed events enabled
   */
  public static qual_Config__mdt createTestConfigAllEvents() {
    qual_Config__mdt config = createTestConfig();
    config.qual_Case_Event_Types__c = 'Opened, Updated, Closed';
    return config;
  }

  /**
   * @description Create test config with specific event types enabled
   * @param eventTypes Comma-separated event types (e.g., 'Opened, Closed')
   * @return qual_Config__mdt with specified events
   */
  public static qual_Config__mdt createTestConfigWithEvents(String eventTypes) {
    qual_Config__mdt config = createTestConfig();
    config.qual_Case_Event_Types__c = eventTypes;
    return config;
  }

  /**
   * @description Create test config with specific tracked update fields
   * @param trackedFields Comma-separated field API names
   * @return qual_Config__mdt with specified tracked fields
   */
  public static qual_Config__mdt createTestConfigWithTrackedFields(
    String trackedFields
  ) {
    qual_Config__mdt config = createTestConfigAllEvents();
    config.qual_Case_Tracked_Update_Fields__c = trackedFields;
    return config;
  }

  /**
   * @description Create test config with all events and a specific send delay
   * @param delayMinutes Delay in minutes for Opened/Updated events (0 = immediate)
   * @return qual_Config__mdt with all events and specified delay
   */
  public static qual_Config__mdt createTestConfigWithDelay(
    Integer delayMinutes
  ) {
    qual_Config__mdt config = createTestConfigAllEvents();
    config.qual_Case_Opened_Delay_Minutes__c = delayMinutes;
    return config;
  }

  /**
   * @description Create test config with a specific Call/Session send delay
   * @param delayMinutes Delay in minutes for Call events (0 = immediate)
   * @return qual_Config__mdt with specified Call delay
   */
  public static qual_Config__mdt createTestConfigWithCallDelay(
    Integer delayMinutes
  ) {
    qual_Config__mdt config = createTestConfig();
    config.qual_Call_Delay_Minutes__c = delayMinutes;
    return config;
  }

  /**
   * @description Create test config with a specific integration log retention
   * @param retentionDays Number of days to retain completed logs
   * @return qual_Config__mdt with specified log retention
   */
  public static qual_Config__mdt createTestConfigWithLogRetention(
    Integer retentionDays
  ) {
    qual_Config__mdt config = createTestConfig();
    config.qual_Log_Retention_Days__c = retentionDays;
    return config;
  }

  /**
   * @description Create test configuration with case selection filters
   * @param allowedOrigins Comma-separated allowed origins (or null for all)
   * @param requireContact Whether to require ContactId
   * @return qual_Config__mdt record with specified filters
   */
  public static qual_Config__mdt createTestConfigWithFilters(
    String allowedOrigins,
    Boolean requireContact
  ) {
    qual_Config__mdt config = createTestConfig();
    config.qual_Case_Filter_Origins__c = allowedOrigins;
    config.qual_Case_Require_Contact__c = requireContact;
    return config;
  }

  /**
   * @description Create test configuration with custom SOQL filter
   * @param customSoqlFilter Custom SOQL WHERE predicate
   * @return qual_Config__mdt record with custom filter
   */
  public static qual_Config__mdt createTestConfigWithCustomFilter(
    String customSoqlFilter
  ) {
    qual_Config__mdt config = createTestConfig();
    config.qual_Case_Custom_Soql_Filter__c = customSoqlFilter;
    return config;
  }

  /**
   * @description Create test integration settings (Custom Setting)
   * @param environment Environment value (Production, Sandbox, GovCloud)
   * @param apiToken API token value
   * @return qual_Integration_Settings__c record (not inserted, for test injection)
   */
  public static qual_Integration_Settings__c createTestSettings(
    String environment,
    String apiToken
  ) {
    qual_Integration_Settings__c settings = new qual_Integration_Settings__c(
      qual_Environment__c = environment,
      qual_Api_Token__c = apiToken
    );
    return settings;
  }

  /**
   * @description Create test integration settings with default values
   * @return qual_Integration_Settings__c record (not inserted, for test injection)
   */
  public static qual_Integration_Settings__c createTestSettings() {
    return createTestSettings('DEV', 'test-api-token-12345');
  }

  /**
   * @description Insert org-default integration settings for tests
   * @param environment Environment value
   * @param apiToken API token value
   * @return Inserted qual_Integration_Settings__c record
   */
  public static qual_Integration_Settings__c insertOrgDefaultSettings(
    String environment,
    String apiToken
  ) {
    qual_Integration_Settings__c settings = new qual_Integration_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      qual_Environment__c = environment,
      qual_Api_Token__c = apiToken
    );
    insert settings;
    return settings;
  }

  /**
   * @description Insert org-default integration settings with default values
   * @return Inserted qual_Integration_Settings__c record
   */
  public static qual_Integration_Settings__c insertOrgDefaultSettings() {
    return insertOrgDefaultSettings('DEV', 'test-api-token-12345');
  }

  /**
   * @description Create test Integration Log
   * @param caseId Related Case ID
   * @param status Log status
   * @param doInsert Whether to insert the record
   * @return qual_Integration_Log__c record
   */
  public static qual_Integration_Log__c createIntegrationLog(
    Id caseId,
    String status,
    Boolean doInsert
  ) {
    qual_Integration_Log__c log = new qual_Integration_Log__c(
      qual_Case__c = caseId,
      qual_Status__c = status,
      qual_Integration_Name__c = 'Qualtrics Case Survey',
      qual_Request_Body__c = '{"test": "payload"}',
      qual_Workflow_Id__c = 'WF_test123',
      qual_Datacenter__c = 'iad1',
      qual_Processed_Date__c = Datetime.now()
    );

    if (doInsert) {
      insert log;
    }

    return log;
  }

  /**
   * @description Create test Integration Log for retry
   * @param caseId Related Case ID
   * @param retryCount Current retry count
   * @param doInsert Whether to insert the record
   * @return qual_Integration_Log__c record
   */
  public static qual_Integration_Log__c createRetryLog(
    Id caseId,
    Integer retryCount,
    Boolean doInsert
  ) {
    qual_Integration_Log__c log = createIntegrationLog(
      caseId,
      'Retrying',
      false
    );
    log.qual_Retry_Count__c = retryCount;
    log.qual_Next_Retry_Date__c = Datetime.now().addMinutes(-5); // Due for retry

    if (doInsert) {
      insert log;
    }

    return log;
  }

  /**
   * @description Create complete test data set (Account, Contact, Case)
   * @return Map with 'account', 'contact', 'case' keys
   */
  public static Map<String, SObject> createCompleteTestData() {
    Account acc = createAccount(true);
    Contact con = createContact(acc.Id, true);
    Case c = createOpenCase(acc.Id, con.Id, true);

    return new Map<String, SObject>{
      'account' => acc,
      'contact' => con,
      'case' => c
    };
  }

  /**
   * @description Query Case with all related data (mimics production query)
   * @param caseId Case ID to query
   * @return Case with related records
   */
  public static Case queryCaseWithRelations(Id caseId) {
    // Build dynamic query to include custom fields if they exist
    Set<String> fields = new Set<String>{
      'Id',
      'CaseNumber',
      'Status',
      'Priority',
      'Origin',
      'Subject',
      'Description',
      'CreatedDate',
      'ClosedDate',
      'IsClosed',
      'OwnerId',
      'Owner.Name',
      'ContactId',
      'Contact.FirstName',
      'Contact.LastName',
      'Contact.Email',
      'Contact.Phone',
      'AccountId',
      'Account.Name'
    };

    // Add custom fields if they exist
    Map<String, SObjectField> caseFields = Case.SObjectType.getDescribe()
      .fields.getMap();
    if (caseFields.containsKey('Incoming_Division__c'))
      fields.add('Incoming_Division__c');
    if (caseFields.containsKey('INS_Branch_v2__c'))
      fields.add('INS_Branch_v2__c');
    if (caseFields.containsKey('Respondent_Branch__c'))
      fields.add('Respondent_Branch__c');
    if (caseFields.containsKey('Disposition__c'))
      fields.add('Disposition__c');
    if (caseFields.containsKey('qual_Division__c'))
      fields.add('qual_Division__c');
    if (caseFields.containsKey('qual_Branch__c'))
      fields.add('qual_Branch__c');
    if (caseFields.containsKey('qual_Disposition__c'))
      fields.add('qual_Disposition__c');
    if (caseFields.containsKey('qual_Call_Duration__c'))
      fields.add('qual_Call_Duration__c');
    if (caseFields.containsKey('Routed_to_Division__c'))
      fields.add('Routed_to_Division__c');
    if (caseFields.containsKey('qual_Call_Forwarding_Division__c'))
      fields.add('qual_Call_Forwarding_Division__c');
    if (caseFields.containsKey('Auto_Close_Reason__c'))
      fields.add('Auto_Close_Reason__c');

    String query =
      'SELECT ' +
      String.join(new List<String>(fields), ', ') +
      ' FROM Case WHERE Id = :caseId';
    return Database.query(query);
  }

  /**
   * @description Create a test user with Qualtrics Team and Manager for testing agent data
   * @param doInsert Whether to insert the user
   * @return User record with qual_Team__c and Manager set
   */
  public static User createTestUserWithTeam(Boolean doInsert) {
    // Get a profile for the test user
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

    // Create a manager user first
    String uniqueId = String.valueOf(DateTime.now().getTime());
    User manager = new User(
      FirstName = 'Test',
      LastName = 'Manager',
      Email = 'testmanager' + uniqueId + '@example.com',
      Username = 'testmanager' + uniqueId + '@example.com.test',
      Alias = 'tmgr',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      ProfileId = p.Id,
      LanguageLocaleKey = 'en_US',
      IsActive = true
    );
    insert manager;

    // Create the test user with manager and team
    User testUser = new User(
      FirstName = 'Test',
      LastName = 'Agent',
      Email = 'testagent' + uniqueId + '@example.com',
      Username = 'testagent' + uniqueId + '@example.com.test',
      Alias = 'tagt',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      ProfileId = p.Id,
      LanguageLocaleKey = 'en_US',
      IsActive = true,
      ManagerId = manager.Id,
      qual_Team__c = 'DCCA'
    );

    if (doInsert) {
      insert testUser;
    }

    return testUser;
  }

  /**
   * @description Setup User data map for payload builder tests
   * @param userId The user ID to add to the map
   */
  public static void setupUserDataForPayload(Id userId) {
    Map<Id, User> userMap = new Map<Id, User>(
      [
        SELECT Id, Name, qual_Team__c, ManagerId, Manager.Name
        FROM User
        WHERE Id = :userId
      ]
    );
    QualCasePayloadBuilder.setUserDataMap(userMap);
  }

  /**
   * @description Create test UJET Session record
   * @param caseId Related Case ID
   * @param callId UJET Call ID value
   * @param doInsert Whether to insert the record
   * @return UJET__UJET_Session__c record
   */
  public static UJET__UJET_Session__c createUjetSession(
    Id caseId,
    Decimal callId,
    Boolean doInsert
  ) {
    return createUjetSession(caseId, callId, null, doInsert);
  }

  /**
   * @description Create test UJET Session record with a directly-linked Contact.
   * UJET does not populate UJET__Contact__c in practice, so the session-Contact
   * resolution branch of the Call payload can only be exercised by a fixture that
   * sets it explicitly.
   * @param caseId Related Case ID
   * @param callId UJET Call ID value
   * @param contactId Contact to link directly to the session (nullable)
   * @param doInsert Whether to insert the record
   * @return UJET__UJET_Session__c record
   */
  public static UJET__UJET_Session__c createUjetSession(
    Id caseId,
    Decimal callId,
    Id contactId,
    Boolean doInsert
  ) {
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = caseId,
      UJET__Call_Id__c = callId,
      UJET__Contact__c = contactId
    );

    if (doInsert) {
      insert session;
    }

    return session;
  }

  /**
   * @description Create test UJET Session record with duration fields
   * @param caseId Related Case ID
   * @param callId UJET Call ID value
   * @param callDuration Call duration in seconds
   * @param holdDuration Hold duration in seconds
   * @param waitDuration Wait/queue duration in seconds
   * @param doInsert Whether to insert the record
   * @return UJET__UJET_Session__c record
   */
  public static UJET__UJET_Session__c createUjetSessionWithDurations(
    Id caseId,
    Decimal callId,
    Decimal callDuration,
    Decimal holdDuration,
    Decimal waitDuration,
    Boolean doInsert
  ) {
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = caseId,
      UJET__Call_Id__c = callId,
      UJET__Call_Duration__c = callDuration,
      UJET__Hold_Duration__c = holdDuration,
      UJET__Wait_Duration__c = waitDuration
    );

    if (doInsert) {
      insert session;
    }

    return session;
  }

  /**
   * @description Create multiple UJET Session records for a Case
   * @param caseId Related Case ID
   * @param callIds List of Call IDs
   * @param doInsert Whether to insert the records
   * @return List of UJET__UJET_Session__c records
   */
  public static List<UJET__UJET_Session__c> createUjetSessions(
    Id caseId,
    List<Decimal> callIds,
    Boolean doInsert
  ) {
    List<UJET__UJET_Session__c> sessions = new List<UJET__UJET_Session__c>();

    for (Decimal callId : callIds) {
      sessions.add(
        new UJET__UJET_Session__c(
          UJET__Case__c = caseId,
          UJET__Call_Id__c = callId
        )
      );
    }

    if (doInsert) {
      insert sessions;
    }

    return sessions;
  }

  /**
   * @description Setup UJET Call ID map for payload builder tests
   * @param caseId The Case ID
   * @param callIds List of Call IDs
   */
  public static void setupUjetCallIdForPayload(Id caseId, List<Long> callIds) {
    Map<Id, List<Long>> callIdMap = new Map<Id, List<Long>>();
    if (caseId != null && callIds != null && !callIds.isEmpty()) {
      callIdMap.put(caseId, callIds);
    }
    QualCasePayloadBuilder.setUjetCallIdMap(callIdMap);
  }

  /**
   * @description Setup voice call transcript map for payload builder tests
   * @param caseId The Case ID
   * @param transcript The transcript text
   */
  public static void setupVoiceCallTranscriptForPayload(
    Id caseId,
    String transcript
  ) {
    Map<Id, String> transcriptMap = new Map<Id, String>();
    if (caseId != null && String.isNotBlank(transcript)) {
      transcriptMap.put(caseId, transcript);
    }
    QualCasePayloadBuilder.setVoiceCallTranscriptMap(transcriptMap);
  }

  /**
   * @description Setup UJET durations map for payload builder tests
   * @param caseId The Case ID
   * @param callDuration Call duration in seconds
   * @param holdDuration Hold duration in seconds
   * @param waitDuration Wait/queue duration in seconds
   */
  public static void setupUjetDurationsForPayload(
    Id caseId,
    Integer callDuration,
    Integer holdDuration,
    Integer waitDuration
  ) {
    Map<Id, QualCasePayloadBuilder.UjetDurations> durationsMap = new Map<Id, QualCasePayloadBuilder.UjetDurations>();
    if (caseId != null) {
      QualCasePayloadBuilder.UjetDurations durations = new QualCasePayloadBuilder.UjetDurations();
      durations.callDurationSeconds = callDuration;
      durations.holdDurationSeconds = holdDuration;
      durations.waitDurationSeconds = waitDuration;
      durationsMap.put(caseId, durations);
    }
    QualCasePayloadBuilder.setUjetDurationsMap(durationsMap);
  }

  /**
   * @description Create a ContentVersion (file) with text content
   * @param title File title
   * @param content File content (text)
   * @param doInsert Whether to insert the record
   * @return ContentVersion record
   */
  public static ContentVersion createContentVersion(
    String title,
    String content,
    Boolean doInsert
  ) {
    ContentVersion cv = new ContentVersion(
      Title = title,
      PathOnClient = title,
      VersionData = Blob.valueOf(content)
    );

    if (doInsert) {
      insert cv;
    }

    return cv;
  }

  /**
   * @description Create a ContentDocumentLink to attach a file to a record
   * @param contentDocumentId The ContentDocument ID (from ContentVersion)
   * @param linkedEntityId The record to link to (e.g., UJET Session)
   * @param doInsert Whether to insert the record
   * @return ContentDocumentLink record
   */
  public static ContentDocumentLink createContentDocumentLink(
    Id contentDocumentId,
    Id linkedEntityId,
    Boolean doInsert
  ) {
    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = contentDocumentId,
      LinkedEntityId = linkedEntityId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );

    if (doInsert) {
      insert cdl;
    }

    return cdl;
  }

  /**
   * @description Create a transcript file attached to a UJET Session
   * Creates ContentVersion and ContentDocumentLink in one call
   * @param sessionId The UJET Session ID to attach to
   * @param title File title (e.g., 'rt_transcript_737_abc123.txt')
   * @param content Transcript text content
   * @return The ContentVersion record
   */
  public static ContentVersion createTranscriptAttachment(
    Id sessionId,
    String title,
    String content
  ) {
    // Create ContentVersion
    ContentVersion cv = createContentVersion(title, content, true);

    // Query to get the ContentDocumentId
    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

    // Create ContentDocumentLink
    createContentDocumentLink(cv.ContentDocumentId, sessionId, true);

    return cv;
  }

  /**
   * @description Get sample real-time (rt) transcript text
   * Representative of actual UJET transcript format from dcca-migration
   * @param callId The call ID number for the transcript header
   * @return Sample transcript text
   */
  public static String getSampleRtTranscript(Integer callId) {
    return 'Call ID: ' +
      callId +
      '   |   2025-11-12     HST   |   54 sec\n' +
      '--------------------------------------------------\n\n' +
      '[10:13:52     DCCA Virtual Agent]     Aloha! Thank you for calling the Hawaii Department of Commerce and Consumer Affairs. For more detailed information about our services, please visit our website at cca.hawaii.gov.\n' +
      '                                      \n' +
      '                                      How may I help you?\n' +
      '                                      You can say things such as,\n' +
      '                                      "Professional and Vocational Licensing", "Business Registration", or "Regulated Industries Complaints".\n' +
      '                                      \n' +
      '                                      For Professional and Vocational Licensing, say "Licensing", or press 1. \n' +
      '                                      "Business Registration", or press 2.\n' +
      '                                      "Regulated Industries Complaints", or press 3.\n' +
      '                                      "Insurance", or press 4.\n' +
      '                                      "Consumer Protection", or press 5.\n' +
      '                                      "Financial Institutions", or press 6.\n' +
      '                                      "Consumer Advocacy", or press 7.\n' +
      '                                      "Cable Television", or press 8.\n' +
      '                                      "Administrative Hearings", or press 9.\n' +
      '                                      \n' +
      '                                      At any point during the call, press 0 to speak to a representative, or press star to repeat the menu. \n' +
      '                                      \n' +
      '                                      For more information regarding each of the divisions, say "more information", or press #.\n' +
      '[10:14:28     DCCA Virtual Agent]     Hello, thanks for calling Professional and Vocational Licensing. Our working hours are 7:45 AM to 4:15 PM Monday through Friday. We are closed on state holidays. Please call back during our hours of operation. Have a nice day.\n';
  }

  /**
   * @description Get sample virtual agent (va) transcript text
   * Representative of actual UJET transcript format from dcca-migration
   * @param callId The call ID number for the transcript header
   * @return Sample transcript text
   */
  public static String getSampleVaTranscript(Integer callId) {
    return 'Call ID: ' +
      callId +
      '   |   2025-11-12     HST   |   35 sec\n' +
      '--------------------------------------------------\n\n' +
      '[10:13:52     Virtual Agent: DCCA Virtual Agent]     Aloha! Thank you for calling the Hawaii Department of Commerce and Consumer Affairs. For more detailed information about our services, please visit our website at cca.hawaii.gov.\n' +
      '                                                     \n' +
      '                                                     How may I help you?\n' +
      '                                                     You can say things such as,\n' +
      '                                                     "Professional and Vocational Licensing", "Business Registration", or "Regulated Industries Complaints".\n' +
      '                                                     \n' +
      '                                                     For Professional and Vocational Licensing, say "Licensing", or press 1. \n' +
      '                                                     "Business Registration", or press 2.\n' +
      '                                                     "Regulated Industries Complaints", or press 3.\n' +
      '                                                     "Insurance", or press 4.\n' +
      '                                                     "Consumer Protection", or press 5.\n' +
      '                                                     "Financial Institutions", or press 6.\n' +
      '                                                     "Consumer Advocacy", or press 7.\n' +
      '                                                     "Cable Television", or press 8.\n' +
      '                                                     "Administrative Hearings", or press 9.\n' +
      '                                                     \n' +
      '                                                     At any point during the call, press 0 to speak to a representative, or press star to repeat the menu. \n' +
      '                                                     \n' +
      '                                                     For more information regarding each of the divisions, say "more information", or press #.\n' +
      '[10:14:28     Virtual Agent: DCCA Virtual Agent]     Hello, thanks for calling Professional and Vocational Licensing. Our working hours are 7:45 AM to 4:15 PM Monday through Friday. We are closed on state holidays. Please call back during our hours of operation. Have a nice day.\n';
  }

  /**
   * @description Get sample combined transcript (both rt and va)
   * @param callId The call ID number
   * @return Combined transcript with separator
   */
  public static String getSampleCombinedTranscript(Integer callId) {
    return getSampleRtTranscript(callId) +
      '\n\n---\n\n' +
      getSampleVaTranscript(callId);
  }

  /**
   * @description Create a JSON file attachment on a UJET Session
   * @param sessionId The UJET Session ID to attach to
   * @param title File title (e.g., 'call-71817.json')
   * @param jsonContent JSON string content
   * @return The ContentVersion record
   */
  public static ContentVersion createJsonAttachment(
    Id sessionId,
    String title,
    String jsonContent
  ) {
    ContentVersion cv = createContentVersion(title, jsonContent, true);
    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
    createContentDocumentLink(cv.ContentDocumentId, sessionId, true);
    return cv;
  }

  /**
   * @description Get sample UJET call JSON for testing
   * @param callId The UJET call ID
   * @return Sample JSON string matching UJET API export format
   */
  public static String getSampleCallJson(Integer callId) {
    return '{' +
      '"id":' +
      callId +
      ',' +
      '"call_type":"Voice Inbound (IVR)",' +
      '"status":"finished",' +
      '"call_duration":284,' +
      '"hold_duration":0,' +
      '"wait_duration":47,' +
      '"disconnected_by":"disconnected_by_end_user",' +
      '"fail_reason":"nothing",' +
      '"agent_info":{"id":6,"name":"Test Agent"},' +
      '"participants":[],' +
      '"transfers":[],' +
      '"handle_durations":[{"acw_duration":12},{"acw_duration":3}],' +
      '"recordings":[]' +
      '}';
  }

  /**
   * @description Setup abandoned call map for payload builder tests
   * @param caseId The Case ID
   * @param abandoned Whether the call was abandoned
   */
  public static void setupAbandonedCallForPayload(
    Id caseId,
    Boolean abandoned
  ) {
    Map<Id, Boolean> abandonedMap = new Map<Id, Boolean>();
    if (caseId != null) {
      abandonedMap.put(caseId, abandoned);
    }
    QualCasePayloadBuilder.setAbandonedCallMap(abandonedMap);
  }

  /**
   * @description Setup speed to answer map for payload builder tests
   * @param caseId The Case ID
   * @param seconds Wait duration in seconds for the first answered session (ASA)
   */
  public static void setupSpeedToAnswerForPayload(Id caseId, Integer seconds) {
    Map<Id, Integer> speedMap = new Map<Id, Integer>();
    if (caseId != null) {
      speedMap.put(caseId, seconds);
    }
    QualCasePayloadBuilder.setSpeedToAnswerMap(speedMap);
  }

  /**
   * @description Create a UJET Session with fail reason for abandoned call testing
   * @param caseId Related Case ID
   * @param callId UJET Call ID value
   * @param failReason Fail reason (e.g., 'eu_abandoned')
   * @param status Session status (e.g., 'failed', 'finished')
   * @param waitDuration Wait/queue duration in seconds
   * @param doInsert Whether to insert the record
   * @return UJET__UJET_Session__c record
   */
  public static UJET__UJET_Session__c createUjetSessionWithStatus(
    Id caseId,
    Decimal callId,
    String failReason,
    String status,
    Decimal waitDuration,
    Boolean doInsert
  ) {
    UJET__UJET_Session__c session = new UJET__UJET_Session__c(
      UJET__Case__c = caseId,
      UJET__Call_Id__c = callId,
      UJET__Fail_Reason__c = failReason,
      UJET__Status__c = status,
      UJET__Wait_Duration__c = waitDuration
    );

    if (doInsert) {
      insert session;
    }

    return session;
  }
}