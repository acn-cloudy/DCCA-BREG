/**
 * @description Queueable class for independent UJET Call/Session payloads to Qualtrics.
 */
public with sharing class QualCallSessionQueueable implements Queueable, Database.AllowsCallouts {
  @TestVisible
  private static final Integer CALLOUT_SAFETY_BUFFER = 5;

  private List<Id> sessionIds;
  private Integer retryCount;
  private Map<Id, Integer> retryCountBySession;

  public QualCallSessionQueueable(List<Id> sessionIds) {
    this(sessionIds, 0);
  }

  public QualCallSessionQueueable(List<Id> sessionIds, Integer retryCount) {
    this.sessionIds = sessionIds != null ? sessionIds : new List<Id>();
    this.retryCount = retryCount != null ? retryCount : 0;
    this.retryCountBySession = new Map<Id, Integer>();
  }

  public QualCallSessionQueueable(
    List<Id> sessionIds,
    Map<Id, Integer> retryCountBySession
  ) {
    this.sessionIds = sessionIds != null ? sessionIds : new List<Id>();
    this.retryCount = 0;
    this.retryCountBySession = retryCountBySession != null
      ? retryCountBySession
      : new Map<Id, Integer>();
  }

  public void execute(QueueableContext context) {
    qual_Config__mdt config = QualConfigSelector.getActiveConfig();
    if (config == null || !config.qual_Is_Active__c) {
      System.debug(LoggingLevel.WARN, 'Qualtrics integration is not active');
      return;
    }
    if (String.isBlank(config.qual_Call_Workflow_Id__c)) {
      System.debug(
        LoggingLevel.WARN,
        'Qualtrics Call workflow ID is not configured'
      );
      return;
    }

    Set<Id> sessionIdSet = new Set<Id>(sessionIds);
    List<UJET__UJET_Session__c> sessions = querySessions(sessionIds);
    CallJsonLookupResult callJsonLookup = queryCallJsonBySession(sessions);
    Set<String> alreadySentSessionIds = getAlreadySentSessionIds(sessionIdSet);
    Set<String> sessionsHeldByFutureDeferred = getSessionsHeldByFutureDeferred(
      sessionIdSet
    );

    Integer maxRetries = QualConfigSelector.getMaxRetries();
    List<QualCalloutService.CalloutResult> allResults = new List<QualCalloutService.CalloutResult>();
    List<Id> deferredSessionIds = new List<Id>();
    Boolean budgetExhausted = false;

    for (UJET__UJET_Session__c session : sessions) {
      if (budgetExhausted) {
        deferredSessionIds.add(session.Id);
        continue;
      }
      if (alreadySentSessionIds.contains(String.valueOf(session.Id))) {
        continue;
      }
      if (sessionsHeldByFutureDeferred.contains(String.valueOf(session.Id))) {
        continue;
      }
      if (
        Limits.getCallouts() >=
        Limits.getLimitCallouts() - CALLOUT_SAFETY_BUFFER
      ) {
        budgetExhausted = true;
        deferredSessionIds.add(session.Id);
        continue;
      }

      QualCalloutService.CalloutResult result = callJsonLookup.sessionErrors.containsKey(
          session.Id
        )
        ? createNonRetryableCallResult(
            session,
            config,
            callJsonLookup.sessionErrors.get(session.Id)
          )
        : QualCalloutService.processCallCallout(
            session,
            config,
            callJsonLookup.sessionToCallJson.get(session.Id)
          );
      allResults.add(result);
    }

    List<qual_Integration_Log__c> logsToInsert = new List<qual_Integration_Log__c>();
    List<QualAlertService.DeadLetterAlert> deadLetterAlerts = new List<QualAlertService.DeadLetterAlert>();

    for (QualCalloutService.CalloutResult result : allResults) {
      if (result.isSuccess) {
        qual_Integration_Log__c log = QualIntegrationLogger.createSuccessLog(
          result,
          config
        );
        if (log != null) {
          logsToInsert.add(log);
        }
      } else if (
        result.isRetryable &&
        getRetryCountForSession(result.sessionId) < maxRetries
      ) {
        logsToInsert.add(
          QualIntegrationLogger.createRetryLog(
            result,
            getRetryCountForSession(result.sessionId) + 1,
            config
          )
        );
      } else {
        logsToInsert.add(
          QualIntegrationLogger.createDeadLetterLog(result, config)
        );
        if (result.caseId != null) {
          deadLetterAlerts.add(
            new QualAlertService.DeadLetterAlert(
              result.caseId,
              result.errorMessage
            )
          );
        }
      }
    }

    if (!logsToInsert.isEmpty()) {
      insert logsToInsert;
    }

    QualAlertService.sendDeadLetterAlerts(deadLetterAlerts, config);

    if (!deferredSessionIds.isEmpty() && !Test.isRunningTest()) {
      Map<Id, Integer> deferredRetryCounts = new Map<Id, Integer>();
      for (Id sessionId : deferredSessionIds) {
        deferredRetryCounts.put(sessionId, getRetryCountForSession(sessionId));
      }
      System.enqueueJob(
        new QualCallSessionQueueable(deferredSessionIds, deferredRetryCounts)
      );
    }
  }

  private Integer getRetryCountForSession(Id sessionId) {
    if (
      sessionId != null &&
      retryCountBySession != null &&
      retryCountBySession.containsKey(sessionId) &&
      retryCountBySession.get(sessionId) != null
    ) {
      return retryCountBySession.get(sessionId);
    }
    return retryCount != null ? retryCount : 0;
  }

  private List<UJET__UJET_Session__c> querySessions(List<Id> ids) {
    if (ids == null || ids.isEmpty()) {
      return new List<UJET__UJET_Session__c>();
    }

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
      WHERE Id IN :ids
    ];
  }

  private CallJsonLookupResult queryCallJsonBySession(
    List<UJET__UJET_Session__c> sessions
  ) {
    CallJsonLookupResult result = new CallJsonLookupResult();
    if (sessions == null || sessions.isEmpty()) {
      return result;
    }

    Map<Id, UJET__UJET_Session__c> sessionsById = new Map<Id, UJET__UJET_Session__c>();
    Map<Id, String> callIdBySession = new Map<Id, String>();
    for (UJET__UJET_Session__c session : sessions) {
      if (session == null || session.Id == null) {
        continue;
      }
      sessionsById.put(session.Id, session);
      if (session.UJET__Call_Id__c != null) {
        callIdBySession.put(
          session.Id,
          String.valueOf(session.UJET__Call_Id__c.longValue())
        );
      } else {
        result.sessionErrors.put(
          session.Id,
          'Cannot locate required call JSON attachment because UJET Session ' +
            session.Id +
            ' has no Call ID'
        );
      }
    }

    if (sessionsById.isEmpty()) {
      return result;
    }

    try {
      Set<Id> sessionLookupIds = sessionsById.keySet();
      List<ContentDocumentLink> cdls = [
        SELECT
          LinkedEntityId,
          ContentDocument.LatestPublishedVersionId,
          ContentDocument.Title,
          ContentDocument.FileExtension
        FROM ContentDocumentLink
        WHERE
          LinkedEntityId IN :sessionLookupIds
          AND ContentDocument.FileExtension = 'json'
      ];

      Set<Id> contentVersionIds = new Set<Id>();
      Map<Id, List<JsonFileCandidate>> candidatesByVersionId = new Map<Id, List<JsonFileCandidate>>();
      for (ContentDocumentLink cdl : cdls) {
        String callId = callIdBySession.get(cdl.LinkedEntityId);
        if (String.isBlank(callId)) {
          continue;
        }
        String fileName = buildFileName(
          cdl.ContentDocument.Title,
          cdl.ContentDocument.FileExtension
        );
        if (!fileNameContainsCallId(fileName, callId)) {
          continue;
        }
        Id cvId = cdl.ContentDocument.LatestPublishedVersionId;
        contentVersionIds.add(cvId);
        if (!candidatesByVersionId.containsKey(cvId)) {
          candidatesByVersionId.put(cvId, new List<JsonFileCandidate>());
        }
        candidatesByVersionId.get(cvId)
          .add(new JsonFileCandidate(cdl.LinkedEntityId, cvId, fileName));
      }

      Map<Id, JsonFileCandidate> selectedBySession = new Map<Id, JsonFileCandidate>();
      for (ContentVersion cv : [
        SELECT Id, VersionData, CreatedDate
        FROM ContentVersion
        WHERE Id IN :contentVersionIds
        ORDER BY CreatedDate DESC, Id DESC
      ]) {
        for (JsonFileCandidate candidate : candidatesByVersionId.get(cv.Id)) {
          if (!selectedBySession.containsKey(candidate.sessionId)) {
            candidate.createdDate = cv.CreatedDate;
            candidate.versionData = cv.VersionData;
            selectedBySession.put(candidate.sessionId, candidate);
          }
        }
      }

      for (JsonFileCandidate candidate : selectedBySession.values()) {
        try {
          result.sessionToCallJson.put(
            candidate.sessionId,
            JSON.deserializeUntyped(candidate.versionData.toString())
          );
        } catch (Exception parseEx) {
          result.sessionErrors.put(
            candidate.sessionId,
            'Could not parse required call JSON file ' +
              candidate.fileName +
              ' for UJET Session ' +
              candidate.sessionId +
              ': ' +
              parseEx.getMessage()
          );
        }
      }
    } catch (Exception ex) {
      for (Id sessionId : sessionsById.keySet()) {
        result.sessionErrors.put(
          sessionId,
          'Could not query required call JSON files for UJET Session ' +
            sessionId +
            ': ' +
            ex.getMessage()
        );
      }
    }

    for (Id sessionId : sessionsById.keySet()) {
      if (
        !result.sessionToCallJson.containsKey(sessionId) &&
        !result.sessionErrors.containsKey(sessionId)
      ) {
        result.sessionErrors.put(
          sessionId,
          'Required call JSON attachment with Call ID ' +
            callIdBySession.get(sessionId) +
            ' in the filename was not found for UJET Session ' +
            sessionId
        );
      }
    }

    return result;
  }

  private QualCalloutService.CalloutResult createNonRetryableCallResult(
    UJET__UJET_Session__c session,
    qual_Config__mdt config,
    String errorMessage
  ) {
    QualCalloutService.CalloutResult result = new QualCalloutService.CalloutResult();
    result.caseId = session != null ? session.UJET__Case__c : null;
    result.sessionId = session != null ? session.Id : null;
    result.callId = session != null &&
      session.UJET__Call_Id__c != null
      ? String.valueOf(session.UJET__Call_Id__c.longValue())
      : null;
    result.payloadType = QualCalloutService.PAYLOAD_TYPE_CALL;
    result.workflowId = config != null ? config.qual_Call_Workflow_Id__c : null;
    result.isSuccess = false;
    result.isRetryable = false;
    result.errorMessage = errorMessage;
    result.payloadSize = 0;
    return result;
  }

  private static String buildFileName(String title, String extension) {
    String fileName = String.isNotBlank(title) ? title : '';
    if (
      String.isNotBlank(extension) &&
      !fileName.toLowerCase().endsWith('.' + extension.toLowerCase())
    ) {
      fileName += '.' + extension;
    }
    return fileName;
  }

  @TestVisible
  private static Boolean fileNameContainsCallId(
    String fileName,
    String callId
  ) {
    if (String.isBlank(fileName) || String.isBlank(callId)) {
      return false;
    }
    Integer index = fileName.indexOf(callId);
    while (index >= 0) {
      Integer afterIndex = index + callId.length();
      Boolean beforeIsClear =
        index == 0 || !isDigit(fileName.substring(index - 1, index));
      Boolean afterIsClear =
        afterIndex >= fileName.length() ||
        !isDigit(fileName.substring(afterIndex, afterIndex + 1));
      if (beforeIsClear && afterIsClear) {
        return true;
      }
      index = fileName.indexOf(callId, index + 1);
    }
    return false;
  }

  private static Boolean isDigit(String value) {
    return String.isNotBlank(value) && '0123456789'.contains(value);
  }

  private class CallJsonLookupResult {
    public Map<Id, Object> sessionToCallJson = new Map<Id, Object>();
    public Map<Id, String> sessionErrors = new Map<Id, String>();
  }

  private class JsonFileCandidate {
    public Id sessionId;
    public Id contentVersionId;
    public String fileName;
    public Datetime createdDate;
    public Blob versionData;

    public JsonFileCandidate(
      Id sessionId,
      Id contentVersionId,
      String fileName
    ) {
      this.sessionId = sessionId;
      this.contentVersionId = contentVersionId;
      this.fileName = fileName;
    }
  }

  @TestVisible
  private Set<String> getAlreadySentSessionIds(Set<Id> ids) {
    Set<String> sessionIdStrings = new Set<String>();
    for (Id sessionId : ids) {
      sessionIdStrings.add(String.valueOf(sessionId));
    }
    if (sessionIdStrings.isEmpty()) {
      return sessionIdStrings;
    }

    Set<String> alreadySent = new Set<String>();
    String callPayloadType = QualCalloutService.PAYLOAD_TYPE_CALL;
    for (qual_Integration_Log__c log : [
      SELECT qual_Ujet_Session_Id__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Payload_Type__c = :callPayloadType
        AND qual_Status__c = 'Success'
        AND qual_Ujet_Session_Id__c IN :sessionIdStrings
    ]) {
      if (String.isNotBlank(log.qual_Ujet_Session_Id__c)) {
        alreadySent.add(log.qual_Ujet_Session_Id__c);
      }
    }
    return alreadySent;
  }

  @TestVisible
  private Set<String> getSessionsHeldByFutureDeferred(Set<Id> ids) {
    Set<String> sessionIdStrings = new Set<String>();
    for (Id sessionId : ids) {
      sessionIdStrings.add(String.valueOf(sessionId));
    }
    if (sessionIdStrings.isEmpty()) {
      return sessionIdStrings;
    }

    Set<String> heldSessions = new Set<String>();
    String callPayloadType = QualCalloutService.PAYLOAD_TYPE_CALL;
    for (qual_Integration_Log__c log : [
      SELECT qual_Ujet_Session_Id__c
      FROM qual_Integration_Log__c
      WHERE
        qual_Payload_Type__c = :callPayloadType
        AND qual_Status__c = 'Deferred'
        AND qual_Next_Retry_Date__c > :Datetime.now()
        AND qual_Ujet_Session_Id__c IN :sessionIdStrings
    ]) {
      if (String.isNotBlank(log.qual_Ujet_Session_Id__c)) {
        heldSessions.add(log.qual_Ujet_Session_Id__c);
      }
    }
    return heldSessions;
  }
}