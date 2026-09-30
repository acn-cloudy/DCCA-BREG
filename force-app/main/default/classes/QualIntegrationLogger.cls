/**
 * @description Logger for Qualtrics integration events
 * @author Qualtrics Integration Team
 */
public with sharing class QualIntegrationLogger {
  private static final String CASE_INTEGRATION_NAME = 'Qualtrics Case Survey';
  private static final String CALL_INTEGRATION_NAME = 'Qualtrics Call Survey';

  // Static map to hold event type per Case - populated by QualCalloutQueueable
  private static Map<Id, String> eventTypeMap = new Map<Id, String>();

  /**
   * @description Set event type map for tagging log records with lifecycle event type
   * @param eventTypes Map of Case Id to event type string (Opened, Updated, Closed)
   */
  public static void setEventTypeMap(Map<Id, String> eventTypes) {
    eventTypeMap = eventTypes != null ? eventTypes : new Map<Id, String>();
  }

  /**
   * @description Log a successful callout
   * @param caseId Related Case ID
   * @param requestBody JSON payload sent
   * @param response HTTP response
   * @param config Configuration used
   * @return Created log record ID
   */
  public static Id logSuccess(
    Id caseId,
    String requestBody,
    HttpResponse response,
    qual_Config__mdt config
  ) {
    String logLevel = config != null ? config.qual_Log_Level__c : 'Info';
    if (logLevel == 'Error') {
      return null;
    }

    QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
      response
    );

    qual_Integration_Log__c log = createBaseLog(caseId, requestBody, config);
    log.qual_Status__c = 'Success';
    log.qual_Status_Code__c = parsed.statusCode;
    log.qual_Workflow_Execution_Id__c = parsed.requestId;
    log.qual_Qualtrics_Event_Id__c = parsed.eventId;
    log.qual_Processed_Date__c = Datetime.now();

    if (logLevel == 'Info') {
      log.qual_Request_Body__c = null;
      log.qual_Response_Body__c = null;
    } else {
      log.qual_Response_Body__c = truncateField(response.getBody(), 131072);
    }

    insert log;
    return log.Id;
  }

  /**
   * @description Log a failed callout that will be retried
   * @param caseId Related Case ID
   * @param requestBody JSON payload sent
   * @param response HTTP response (may be null)
   * @param retryCount Current retry attempt
   * @param errorMessage Error message (used when response is null or parser has no message)
   * @param stackTrace Stack trace (optional; typically set when response is null)
   * @param config Configuration used
   * @return Created log record ID
   */
  public static Id logRetry(
    Id caseId,
    String requestBody,
    HttpResponse response,
    Integer retryCount,
    String errorMessage,
    String stackTrace,
    qual_Config__mdt config
  ) {
    QualResponseParser.ParsedResponse parsed = response != null
      ? QualResponseParser.parseResponse(response)
      : new QualResponseParser.ParsedResponse();

    qual_Integration_Log__c log = createBaseLog(caseId, requestBody, config);
    log.qual_Status__c = 'Retrying';
    log.qual_Status_Code__c = parsed.statusCode;
    log.qual_Response_Body__c = response != null
      ? truncateField(response.getBody(), 131072)
      : null;

    String effectiveErrorMessage = String.isNotBlank(parsed.errorMessage)
      ? parsed.errorMessage
      : errorMessage;
    log.qual_Error_Message__c = truncateField(effectiveErrorMessage, 32000);
    log.qual_Stack_Trace__c = truncateField(stackTrace, 32000);
    log.qual_Retry_Count__c = retryCount;
    log.qual_Processed_Date__c = Datetime.now();

    // Calculate next retry time
    Integer intervalMinutes = config != null &&
      config.qual_Retry_Interval_Minutes__c != null
      ? Integer.valueOf(config.qual_Retry_Interval_Minutes__c)
      : 15;
    log.qual_Next_Retry_Date__c = Datetime.now().addMinutes(intervalMinutes);

    insert log;
    return log.Id;
  }

  /**
   * @description Log a dead letter (max retries exceeded)
   * @param caseId Related Case ID
   * @param requestBody JSON payload sent
   * @param response HTTP response (may be null)
   * @param errorMessage Error description
   * @param stackTrace Apex stack trace
   * @param config Configuration used
   * @return Created log record ID
   */
  public static Id logDeadLetter(
    Id caseId,
    String requestBody,
    HttpResponse response,
    String errorMessage,
    String stackTrace,
    qual_Config__mdt config
  ) {
    qual_Integration_Log__c log = createDeadLetterLog(
      caseId,
      requestBody,
      response,
      errorMessage,
      stackTrace,
      config
    );
    insert log;
    return log.Id;
  }

  // ========== Batch-friendly methods (return record without DML) ==========

  /**
   * @description Create a success log record without inserting
   * Used for batch processing to avoid DML-before-callout issues
   */
  public static qual_Integration_Log__c createSuccessLog(
    Id caseId,
    String requestBody,
    HttpResponse response,
    qual_Config__mdt config
  ) {
    String logLevel = config != null ? config.qual_Log_Level__c : 'Info';
    if (logLevel == 'Error') {
      return null;
    }

    QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
      response
    );

    qual_Integration_Log__c log = createBaseLog(caseId, requestBody, config);
    log.qual_Status__c = 'Success';
    log.qual_Status_Code__c = parsed.statusCode;
    log.qual_Workflow_Execution_Id__c = parsed.requestId;
    log.qual_Qualtrics_Event_Id__c = parsed.eventId;
    log.qual_Processed_Date__c = Datetime.now();

    if (logLevel == 'Info') {
      log.qual_Request_Body__c = null;
      log.qual_Response_Body__c = null;
    } else {
      log.qual_Response_Body__c = truncateField(response.getBody(), 131072);
    }

    return log;
  }

  public static qual_Integration_Log__c createSuccessLog(
    QualCalloutService.CalloutResult result,
    qual_Config__mdt config
  ) {
    String logLevel = config != null ? config.qual_Log_Level__c : 'Info';
    if (logLevel == 'Error') {
      return null;
    }

    QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
      result.response
    );

    qual_Integration_Log__c log = createBaseLog(result, config);
    log.qual_Status__c = 'Success';
    log.qual_Status_Code__c = parsed.statusCode;
    log.qual_Workflow_Execution_Id__c = parsed.requestId;
    log.qual_Qualtrics_Event_Id__c = parsed.eventId;
    log.qual_Processed_Date__c = Datetime.now();

    if (logLevel == 'Info') {
      log.qual_Request_Body__c = null;
      log.qual_Response_Body__c = null;
    } else if (result.response != null) {
      log.qual_Response_Body__c = truncateField(
        result.response.getBody(),
        131072
      );
    }

    return log;
  }

  /**
   * @description Create a retry log record without inserting
   * Used for batch processing to avoid DML-before-callout issues
   */
  public static qual_Integration_Log__c createRetryLog(
    Id caseId,
    String requestBody,
    HttpResponse response,
    Integer retryCount,
    String errorMessage,
    String stackTrace,
    qual_Config__mdt config
  ) {
    QualResponseParser.ParsedResponse parsed = response != null
      ? QualResponseParser.parseResponse(response)
      : new QualResponseParser.ParsedResponse();

    qual_Integration_Log__c log = createBaseLog(caseId, requestBody, config);
    log.qual_Status__c = 'Retrying';
    log.qual_Status_Code__c = parsed.statusCode;
    log.qual_Response_Body__c = response != null
      ? truncateField(response.getBody(), 131072)
      : null;

    String effectiveErrorMessage = String.isNotBlank(parsed.errorMessage)
      ? parsed.errorMessage
      : errorMessage;
    log.qual_Error_Message__c = truncateField(effectiveErrorMessage, 32000);
    log.qual_Stack_Trace__c = truncateField(stackTrace, 32000);
    log.qual_Retry_Count__c = retryCount;
    log.qual_Processed_Date__c = Datetime.now();

    // Calculate next retry time
    Integer intervalMinutes = config != null &&
      config.qual_Retry_Interval_Minutes__c != null
      ? Integer.valueOf(config.qual_Retry_Interval_Minutes__c)
      : 15;
    log.qual_Next_Retry_Date__c = Datetime.now().addMinutes(intervalMinutes);

    return log;
  }

  public static qual_Integration_Log__c createRetryLog(
    QualCalloutService.CalloutResult result,
    Integer retryCount,
    qual_Config__mdt config
  ) {
    QualResponseParser.ParsedResponse parsed = result.response != null
      ? QualResponseParser.parseResponse(result.response)
      : new QualResponseParser.ParsedResponse();

    qual_Integration_Log__c log = createBaseLog(result, config);
    log.qual_Status__c = 'Retrying';
    log.qual_Status_Code__c = parsed.statusCode;
    log.qual_Response_Body__c = result.response != null
      ? truncateField(result.response.getBody(), 131072)
      : null;

    String effectiveErrorMessage = String.isNotBlank(parsed.errorMessage)
      ? parsed.errorMessage
      : result.errorMessage;
    log.qual_Error_Message__c = truncateField(effectiveErrorMessage, 32000);
    log.qual_Stack_Trace__c = truncateField(result.stackTrace, 32000);
    log.qual_Retry_Count__c = retryCount;
    log.qual_Processed_Date__c = Datetime.now();

    Integer intervalMinutes = config != null &&
      config.qual_Retry_Interval_Minutes__c != null
      ? Integer.valueOf(config.qual_Retry_Interval_Minutes__c)
      : 15;
    log.qual_Next_Retry_Date__c = Datetime.now().addMinutes(intervalMinutes);

    return log;
  }

  /**
   * @description Create a dead letter log record without inserting
   * Used for batch processing to avoid DML-before-callout issues
   */
  public static qual_Integration_Log__c createDeadLetterLog(
    Id caseId,
    String requestBody,
    HttpResponse response,
    String errorMessage,
    String stackTrace,
    qual_Config__mdt config
  ) {
    qual_Integration_Log__c log = createBaseLog(caseId, requestBody, config);
    log.qual_Status__c = 'Dead Letter';
    log.qual_Error_Message__c = truncateField(errorMessage, 32000);
    log.qual_Stack_Trace__c = truncateField(stackTrace, 32000);
    log.qual_Processed_Date__c = Datetime.now();

    if (response != null) {
      QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
        response
      );
      log.qual_Status_Code__c = parsed.statusCode;
      log.qual_Response_Body__c = truncateField(response.getBody(), 131072);
    }

    return log;
  }

  public static qual_Integration_Log__c createDeadLetterLog(
    QualCalloutService.CalloutResult result,
    qual_Config__mdt config
  ) {
    qual_Integration_Log__c log = createBaseLog(result, config);
    log.qual_Status__c = 'Dead Letter';
    log.qual_Error_Message__c = truncateField(result.errorMessage, 32000);
    log.qual_Stack_Trace__c = truncateField(result.stackTrace, 32000);
    log.qual_Processed_Date__c = Datetime.now();

    if (result.response != null) {
      QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
        result.response
      );
      log.qual_Status_Code__c = parsed.statusCode;
      log.qual_Response_Body__c = truncateField(
        result.response.getBody(),
        131072
      );
    }

    return log;
  }

  /**
   * @description Create a deferred log that will be picked up by the schedulable after a delay.
   * Used for Opened/Updated events that need time for data enrichment.
   * @param caseId Related Case ID
   * @param eventType Lifecycle event type (Opened, Updated)
   * @param delayMinutes Minutes to wait before sending
   * @param config Configuration used
   */
  public static void createDeferredLog(
    Id caseId,
    String eventType,
    Integer delayMinutes,
    qual_Config__mdt config
  ) {
    if (caseId == null) {
      return;
    }
    createDeferredLogs(
      new Map<Id, String>{ caseId => eventType },
      delayMinutes,
      config
    );
  }

  /**
   * @description Bulk-create deferred logs for multiple cases.
   * @param caseEventMap Map of Case ID to event type
   * @param delayMinutes Minutes to wait before sending
   * @param config Configuration used
   */
  public static void createDeferredLogs(
    Map<Id, String> caseEventMap,
    Integer delayMinutes,
    qual_Config__mdt config
  ) {
    if (caseEventMap == null || caseEventMap.isEmpty()) {
      return;
    }

    Set<Id> caseIds = new Set<Id>();
    for (Id caseId : caseEventMap.keySet()) {
      if (caseId != null) {
        caseIds.add(caseId);
      }
    }
    if (caseIds.isEmpty()) {
      return;
    }

    // The FOR UPDATE read serializes concurrent first deferred-log creation.
    List<Case> lockedCases = [
      SELECT Id
      FROM Case
      WHERE Id IN :caseIds
      FOR UPDATE
    ];

    String casePayloadType = QualCalloutService.PAYLOAD_TYPE_CASE;
    Map<Id, qual_Integration_Log__c> existingByCase = new Map<Id, qual_Integration_Log__c>();
    List<qual_Integration_Log__c> duplicateDeferredLogs = new List<qual_Integration_Log__c>();
    for (qual_Integration_Log__c log : [
      SELECT Id, qual_Case__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Case__c IN :caseIds
        AND qual_Status__c = 'Deferred'
        AND (qual_Payload_Type__c = :casePayloadType
        OR qual_Payload_Type__c = NULL)
      ORDER BY CreatedDate ASC
    ]) {
      if (!existingByCase.containsKey(log.qual_Case__c)) {
        existingByCase.put(log.qual_Case__c, log);
      } else {
        duplicateDeferredLogs.add(log);
      }
    }

    Integer effectiveDelay = delayMinutes != null ? delayMinutes : 0;
    Datetime sendAfter = Datetime.now().addMinutes(effectiveDelay);
    List<qual_Integration_Log__c> logsToInsert = new List<qual_Integration_Log__c>();
    List<qual_Integration_Log__c> logsToUpdate = new List<qual_Integration_Log__c>();

    for (Id caseId : caseIds) {
      qual_Integration_Log__c log = existingByCase.get(caseId);
      if (log == null) {
        log = new qual_Integration_Log__c();
        logsToInsert.add(log);
      } else {
        logsToUpdate.add(log);
      }
      applyDeferredCaseFields(
        log,
        caseId,
        caseEventMap.get(caseId),
        sendAfter,
        config
      );
    }

    for (qual_Integration_Log__c duplicateLog : duplicateDeferredLogs) {
      duplicateLog.qual_Status__c = 'Cancelled';
      duplicateLog.qual_Processed_Date__c = Datetime.now();
      duplicateLog.qual_Error_Message__c = 'Superseded by newer deferred Case event';
      logsToUpdate.add(duplicateLog);
    }

    if (!logsToUpdate.isEmpty()) {
      update logsToUpdate;
    }
    if (!logsToInsert.isEmpty()) {
      insert logsToInsert;
    }
  }

  /**
   * @description Create or refresh deferred Call logs for UJET Sessions.
   * Reuses one pending Deferred log per session so repeated UJET updates do not
   * create competing scheduler work for the same Call payload.
   * @param sessions UJET Sessions to defer
   * @param delayMinutes Minutes to wait before sending
   * @param config Configuration used
   */
  public static void createOrRefreshDeferredCallLogs(
    List<UJET__UJET_Session__c> sessions,
    Integer delayMinutes,
    qual_Config__mdt config
  ) {
    if (sessions == null || sessions.isEmpty()) {
      return;
    }

    Map<String, UJET__UJET_Session__c> sessionsById = new Map<String, UJET__UJET_Session__c>();
    for (UJET__UJET_Session__c session : sessions) {
      if (session == null || session.Id == null) {
        continue;
      }
      sessionsById.put(String.valueOf(session.Id), session);
    }

    if (sessionsById.isEmpty()) {
      return;
    }

    Set<Id> sessionIdsToLock = new Set<Id>();
    for (String sessionIdString : sessionsById.keySet()) {
      sessionIdsToLock.add((Id) sessionIdString);
    }
    // The FOR UPDATE read serializes concurrent first deferred-log creation.
    List<UJET__UJET_Session__c> lockedSessions = [
      SELECT Id
      FROM UJET__UJET_Session__c
      WHERE Id IN :sessionIdsToLock
      FOR UPDATE
    ];

    String callPayloadType = QualCalloutService.PAYLOAD_TYPE_CALL;
    Set<String> sessionIdStrings = sessionsById.keySet();
    Map<String, qual_Integration_Log__c> existingBySession = new Map<String, qual_Integration_Log__c>();
    List<qual_Integration_Log__c> duplicateDeferredLogs = new List<qual_Integration_Log__c>();

    for (qual_Integration_Log__c log : [
      SELECT Id, qual_Ujet_Session_Id__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Payload_Type__c = :callPayloadType
        AND qual_Status__c = 'Deferred'
        AND qual_Ujet_Session_Id__c IN :sessionIdStrings
      ORDER BY CreatedDate ASC
    ]) {
      if (!existingBySession.containsKey(log.qual_Ujet_Session_Id__c)) {
        existingBySession.put(log.qual_Ujet_Session_Id__c, log);
      } else {
        duplicateDeferredLogs.add(log);
      }
    }

    Integer effectiveDelay = delayMinutes != null ? delayMinutes : 0;
    Datetime sendAfter = Datetime.now().addMinutes(effectiveDelay);
    List<qual_Integration_Log__c> logsToInsert = new List<qual_Integration_Log__c>();
    List<qual_Integration_Log__c> logsToUpdate = new List<qual_Integration_Log__c>();

    for (String sessionIdString : sessionsById.keySet()) {
      UJET__UJET_Session__c session = sessionsById.get(sessionIdString);
      qual_Integration_Log__c log = existingBySession.get(sessionIdString);
      if (log == null) {
        log = new qual_Integration_Log__c();
        logsToInsert.add(log);
      } else {
        logsToUpdate.add(log);
      }
      applyDeferredCallFields(log, session, sessionIdString, sendAfter, config);
    }

    for (qual_Integration_Log__c duplicateLog : duplicateDeferredLogs) {
      duplicateLog.qual_Status__c = 'Cancelled';
      duplicateLog.qual_Processed_Date__c = Datetime.now();
      duplicateLog.qual_Error_Message__c = 'Superseded by newer deferred Call event';
      logsToUpdate.add(duplicateLog);
    }

    if (!logsToUpdate.isEmpty()) {
      update logsToUpdate;
    }
    if (!logsToInsert.isEmpty()) {
      insert logsToInsert;
    }
  }

  /**
   * @description Cancel any pending deferred logs for given Case IDs.
   * Called when a Closed event supersedes a deferred Opened/Updated.
   * @param caseIds Set of Case IDs to cancel deferred logs for
   */
  public static void cancelDeferredLogs(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return;
    }
    List<qual_Integration_Log__c> deferred = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE qual_Case__c IN :caseIds AND qual_Status__c = 'Deferred'
    ];
    for (qual_Integration_Log__c log : deferred) {
      log.qual_Status__c = 'Cancelled';
      log.qual_Processed_Date__c = Datetime.now();
      log.qual_Error_Message__c = 'Superseded by Closed event';
    }
    if (!deferred.isEmpty()) {
      update deferred;
    }
  }

  /**
   * @description Log an exception
   * @param caseId Related Case ID
   * @param requestBody JSON payload (may be null)
   * @param ex Exception that occurred
   * @param config Configuration used
   * @return Created log record ID
   */
  public static Id logException(
    Id caseId,
    String requestBody,
    Exception ex,
    qual_Config__mdt config
  ) {
    qual_Integration_Log__c log = createBaseLog(caseId, requestBody, config);
    log.qual_Status__c = 'Failed';
    log.qual_Error_Message__c = truncateField(ex.getMessage(), 32000);
    log.qual_Stack_Trace__c = truncateField(ex.getStackTraceString(), 32000);
    log.qual_Processed_Date__c = Datetime.now();

    insert log;
    return log.Id;
  }

  /**
   * @description Create base log record with common fields
   */
  private static qual_Integration_Log__c createBaseLog(
    Id caseId,
    String requestBody,
    qual_Config__mdt config
  ) {
    qual_Integration_Log__c log = new qual_Integration_Log__c();
    log.qual_Case__c = caseId;
    log.qual_Integration_Name__c = CASE_INTEGRATION_NAME;
    log.qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE;
    log.qual_Request_Body__c = truncateField(requestBody, 131072);
    log.qual_Payload_Size_Bytes__c = String.isNotBlank(requestBody)
      ? Blob.valueOf(requestBody).size()
      : 0;

    if (config != null) {
      log.qual_Workflow_Id__c = getCaseWorkflowId(config);
      log.qual_Datacenter__c = config.qual_Datacenter__c;
    }

    // Set lifecycle event type if available
    if (caseId != null && eventTypeMap.containsKey(caseId)) {
      log.qual_Event_Type__c = eventTypeMap.get(caseId);
    }

    return log;
  }

  private static void applyDeferredCaseFields(
    qual_Integration_Log__c log,
    Id caseId,
    String eventType,
    Datetime sendAfter,
    qual_Config__mdt config
  ) {
    log.qual_Case__c = caseId;
    log.qual_Integration_Name__c = CASE_INTEGRATION_NAME;
    log.qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CASE;
    log.qual_Status__c = 'Deferred';
    log.qual_Event_Type__c = eventType;
    log.qual_Retry_Count__c = 0;
    log.qual_Next_Retry_Date__c = sendAfter;
    log.qual_Processed_Date__c = Datetime.now();
    log.qual_Error_Message__c = null;

    if (config != null) {
      log.qual_Workflow_Id__c = getCaseWorkflowId(config);
      log.qual_Datacenter__c = config.qual_Datacenter__c;
    }
  }

  private static void applyDeferredCallFields(
    qual_Integration_Log__c log,
    UJET__UJET_Session__c session,
    String sessionIdString,
    Datetime sendAfter,
    qual_Config__mdt config
  ) {
    log.qual_Case__c = session.UJET__Case__c;
    log.qual_Ujet_Session_Id__c = sessionIdString;
    log.qual_Call_Id__c = session.UJET__Call_Id__c != null
      ? String.valueOf(session.UJET__Call_Id__c.longValue())
      : null;
    log.qual_Integration_Name__c = CALL_INTEGRATION_NAME;
    log.qual_Payload_Type__c = QualCalloutService.PAYLOAD_TYPE_CALL;
    log.qual_Status__c = 'Deferred';
    log.qual_Event_Type__c = 'Call';
    log.qual_Retry_Count__c = 0;
    log.qual_Next_Retry_Date__c = sendAfter;
    log.qual_Processed_Date__c = Datetime.now();
    log.qual_Error_Message__c = null;

    if (config != null) {
      log.qual_Workflow_Id__c = getCallWorkflowId(config);
      log.qual_Datacenter__c = config.qual_Datacenter__c;
    }
  }

  private static qual_Integration_Log__c createBaseLog(
    QualCalloutService.CalloutResult result,
    qual_Config__mdt config
  ) {
    qual_Integration_Log__c log = new qual_Integration_Log__c();
    log.qual_Case__c = result.caseId;
    log.qual_Ujet_Session_Id__c = result.sessionId != null
      ? String.valueOf(result.sessionId)
      : null;
    log.qual_Call_Id__c = result.callId;
    log.qual_Payload_Type__c = result.payloadType;
    log.qual_Integration_Name__c = result.payloadType ==
      QualCalloutService.PAYLOAD_TYPE_CALL
      ? CALL_INTEGRATION_NAME
      : CASE_INTEGRATION_NAME;
    log.qual_Request_Body__c = truncateField(result.requestBody, 131072);
    log.qual_Payload_Size_Bytes__c = result.payloadSize;
    log.qual_Workflow_Id__c = result.workflowId;

    if (config != null) {
      log.qual_Datacenter__c = config.qual_Datacenter__c;
    }

    if (result.payloadType == QualCalloutService.PAYLOAD_TYPE_CALL) {
      log.qual_Event_Type__c = 'Call';
    } else if (
      result.caseId != null && eventTypeMap.containsKey(result.caseId)
    ) {
      log.qual_Event_Type__c = eventTypeMap.get(result.caseId);
    }

    return log;
  }

  private static String getCaseWorkflowId(qual_Config__mdt config) {
    if (config != null && String.isNotBlank(config.qual_Case_Workflow_Id__c)) {
      return config.qual_Case_Workflow_Id__c;
    }
    return config != null ? config.qual_Workflow_Id__c : null;
  }

  private static String getCallWorkflowId(qual_Config__mdt config) {
    return config != null ? config.qual_Call_Workflow_Id__c : null;
  }

  /**
   * @description Truncate string to max length
   */
  private static String truncateField(String value, Integer maxLength) {
    if (String.isBlank(value)) {
      return value;
    }
    if (value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength - 3) + '...';
  }

  /**
   * @description Update existing log record status
   * @param logId Log record ID
   * @param status New status
   */
  public static void updateLogStatus(Id logId, String status) {
    qual_Integration_Log__c log = new qual_Integration_Log__c(
      Id = logId,
      qual_Status__c = status,
      qual_Processed_Date__c = Datetime.now()
    );
    update log;
  }

  /**
   * @description Get logs pending retry
   * @return List of log records to retry
   */
  public static List<qual_Integration_Log__c> getLogsForRetry() {
    return [
      SELECT
        Id,
        qual_Case__c,
        qual_Request_Body__c,
        qual_Retry_Count__c,
        qual_Workflow_Id__c,
        qual_Datacenter__c,
        qual_Event_Type__c,
        qual_Status__c,
        qual_Payload_Type__c,
        qual_Ujet_Session_Id__c,
        qual_Call_Id__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Status__c IN ('Retrying', 'Deferred')
        AND qual_Next_Retry_Date__c <= :Datetime.now()
      LIMIT 100
      FOR UPDATE
    ];
  }

  /**
   * @description Recover Processing logs that were abandoned by a failed async job.
   * Logs with newer related follow-up work are left untouched.
   * @param staleMinutes Age threshold in minutes
   * @return Number of logs reset to Retrying
   */
  public static Integer recoverStaleProcessingLogs(Integer staleMinutes) {
    if (staleMinutes == null || staleMinutes <= 0) {
      return 0;
    }

    Datetime cutoff = Datetime.now().addMinutes(-staleMinutes);
    List<qual_Integration_Log__c> candidates = [
      SELECT
        Id,
        CreatedDate,
        qual_Case__c,
        qual_Event_Type__c,
        qual_Status__c,
        qual_Payload_Type__c,
        qual_Ujet_Session_Id__c,
        qual_Retry_Count__c,
        qual_Processed_Date__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Status__c = 'Processing'
        AND (qual_Processed_Date__c <= :cutoff
        OR (qual_Processed_Date__c = NULL
        AND CreatedDate <= :cutoff))
      LIMIT 100
      FOR UPDATE
    ];

    if (candidates.isEmpty()) {
      return 0;
    }

    Set<Id> candidateIds = new Set<Id>();
    Set<Id> caseIds = new Set<Id>();
    Set<String> sessionIdStrings = new Set<String>();
    for (qual_Integration_Log__c log : candidates) {
      candidateIds.add(log.Id);
      if (isCallLog(log)) {
        sessionIdStrings.add(log.qual_Ujet_Session_Id__c);
      } else if (log.qual_Case__c != null) {
        caseIds.add(log.qual_Case__c);
      }
    }

    List<qual_Integration_Log__c> possibleFollowUps = new List<qual_Integration_Log__c>();
    if (!sessionIdStrings.isEmpty() || !caseIds.isEmpty()) {
      String callPayloadType = QualCalloutService.PAYLOAD_TYPE_CALL;
      String casePayloadType = QualCalloutService.PAYLOAD_TYPE_CASE;
      Set<String> followUpStatuses = new Set<String>{
        'Success',
        'Retrying',
        'Dead Letter',
        'Deferred',
        'Cancelled',
        'Failed',
        'Processing'
      };
      possibleFollowUps = [
        SELECT
          Id,
          CreatedDate,
          qual_Case__c,
          qual_Event_Type__c,
          qual_Status__c,
          qual_Payload_Type__c,
          qual_Ujet_Session_Id__c
        FROM qual_Integration_Log__c
        WHERE
          Id NOT IN :candidateIds
          AND qual_Status__c IN :followUpStatuses
          AND ((qual_Payload_Type__c = :callPayloadType
          AND qual_Ujet_Session_Id__c IN :sessionIdStrings)
          OR (qual_Case__c IN :caseIds
          AND (qual_Payload_Type__c = :casePayloadType
          OR qual_Payload_Type__c = NULL)))
      ];
    }

    List<qual_Integration_Log__c> logsToRecover = new List<qual_Integration_Log__c>();
    for (qual_Integration_Log__c candidate : candidates) {
      if (hasNewerFollowUp(candidate, possibleFollowUps)) {
        continue;
      }
      candidate.qual_Status__c = 'Retrying';
      candidate.qual_Next_Retry_Date__c = Datetime.now();
      candidate.qual_Processed_Date__c = Datetime.now();
      candidate.qual_Error_Message__c =
        'Recovered stale Processing log after ' +
        staleMinutes +
        ' minutes';
      logsToRecover.add(candidate);
    }

    if (!logsToRecover.isEmpty()) {
      update logsToRecover;
    }
    return logsToRecover.size();
  }

  private static Boolean hasNewerFollowUp(
    qual_Integration_Log__c candidate,
    List<qual_Integration_Log__c> possibleFollowUps
  ) {
    for (qual_Integration_Log__c followUp : possibleFollowUps) {
      if (followUp.CreatedDate < candidate.CreatedDate) {
        continue;
      }
      if (isCallLog(candidate)) {
        if (
          isCallLog(followUp) &&
          followUp.qual_Ujet_Session_Id__c == candidate.qual_Ujet_Session_Id__c
        ) {
          return true;
        }
      } else if (
        !isCallLog(followUp) &&
        followUp.qual_Case__c == candidate.qual_Case__c &&
        followUp.qual_Event_Type__c == candidate.qual_Event_Type__c
      ) {
        return true;
      }
    }
    return false;
  }

  private static Boolean isCallLog(qual_Integration_Log__c log) {
    return log != null &&
      log.qual_Payload_Type__c == QualCalloutService.PAYLOAD_TYPE_CALL &&
      String.isNotBlank(log.qual_Ujet_Session_Id__c);
  }

  /**
   * @description Delete old non-active logs in bounded chunks.
   * Retrying and Deferred logs are excluded because they represent pending work.
   * @param retentionDays Number of days to retain logs
   * @return Number of logs successfully deleted
   */
  public static Integer deleteLogsOlderThan(Integer retentionDays) {
    if (retentionDays == null || retentionDays <= 0) {
      return 0;
    }

    Datetime cutoff = Datetime.now().addDays(-retentionDays);
    List<qual_Integration_Log__c> logsToDelete = [
      SELECT Id
      FROM qual_Integration_Log__c
      WHERE
        qual_Status__c IN (
          'Success',
          'Dead Letter',
          'Failed',
          'Cancelled',
          'Processing'
        )
        AND (qual_Processed_Date__c < :cutoff
        OR (qual_Processed_Date__c = NULL
        AND CreatedDate < :cutoff))
      ORDER BY qual_Processed_Date__c ASC NULLS FIRST, CreatedDate ASC
      LIMIT 200
    ];

    if (logsToDelete.isEmpty()) {
      return 0;
    }

    Integer deletedCount = 0;
    for (Database.DeleteResult result : Database.delete(logsToDelete, false)) {
      if (result.isSuccess()) {
        deletedCount++;
      }
    }
    return deletedCount;
  }
}