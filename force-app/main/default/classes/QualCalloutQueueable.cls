/**
 * @description Queueable class for async Qualtrics callouts
 * @author Qualtrics Integration Team
 */
public with sharing class QualCalloutQueueable implements Queueable, Database.AllowsCallouts {
  @TestVisible
  private static final Integer CALLOUT_SAFETY_BUFFER = 5;

  private List<Id> caseIds;
  private Integer retryCount;
  private Map<Id, Integer> retryCountByCase;
  private Map<Id, String> eventTypeMap;

  /**
   * @description Constructor for initial processing
   * @param caseIds List of Case IDs to process
   */
  public QualCalloutQueueable(List<Id> caseIds) {
    this(caseIds, 0);
  }

  /**
   * @description Constructor with retry count
   * @param caseIds List of Case IDs to process
   * @param retryCount Current retry attempt
   */
  public QualCalloutQueueable(List<Id> caseIds, Integer retryCount) {
    this(caseIds, retryCount, new Map<Id, String>());
  }

  /**
   * @description Constructor with retry count and event types (used by retry scheduler)
   * @param caseIds List of Case IDs to process
   * @param retryCount Current retry attempt
   * @param eventTypeMap Map of Case ID to event type preserved from original log
   */
  public QualCalloutQueueable(
    List<Id> caseIds,
    Integer retryCount,
    Map<Id, String> eventTypeMap
  ) {
    this.caseIds = caseIds;
    this.retryCount = retryCount;
    this.retryCountByCase = new Map<Id, Integer>();
    this.eventTypeMap = eventTypeMap != null
      ? eventTypeMap
      : new Map<Id, String>();
  }

  /**
   * @description Constructor with per-Case retry counts and event types.
   * @param caseIds List of Case IDs to process
   * @param retryCountByCase Map of Case ID to current retry attempt
   * @param eventTypeMap Map of Case ID to event type preserved from original log
   */
  public QualCalloutQueueable(
    List<Id> caseIds,
    Map<Id, Integer> retryCountByCase,
    Map<Id, String> eventTypeMap
  ) {
    this.caseIds = caseIds;
    this.retryCount = 0;
    this.retryCountByCase = retryCountByCase != null
      ? retryCountByCase
      : new Map<Id, Integer>();
    this.eventTypeMap = eventTypeMap != null
      ? eventTypeMap
      : new Map<Id, String>();
  }

  /**
   * @description Constructor with event types for lifecycle events
   * @param caseIds List of Case IDs to process
   * @param eventTypeMap Map of Case ID to event type (Opened, Updated, Closed)
   */
  public QualCalloutQueueable(List<Id> caseIds, Map<Id, String> eventTypeMap) {
    this.caseIds = caseIds;
    this.retryCount = 0;
    this.retryCountByCase = new Map<Id, Integer>();
    this.eventTypeMap = eventTypeMap != null
      ? eventTypeMap
      : new Map<Id, String>();
  }

  /**
   * @description Execute the queueable job
   * FIX: All callouts are performed FIRST, then all DML happens AFTER
   * This prevents the "uncommitted work pending" error when processing multiple cases
   * @param context Queueable context
   */
  public void execute(QueueableContext context) {
    // Get configuration
    qual_Config__mdt config = QualConfigSelector.getActiveConfig();

    if (config == null || !config.qual_Is_Active__c) {
      System.debug(LoggingLevel.WARN, 'Qualtrics integration is not active');
      return;
    }

    // Query ALL cases up front — the callout loop dynamically checks
    // remaining budget so we never exceed the governor limit.
    List<Case> cases = queryCases(caseIds);

    // Set event type data on payload builder and logger
    QualCasePayloadBuilder.setEventTypeMap(this.eventTypeMap);
    QualIntegrationLogger.setEventTypeMap(this.eventTypeMap);

    // PHASE 1: Perform Case callouts with dynamic budget guard.
    // Calls/Sessions are sent independently by QualCallSessionQueueable.
    // We stop when the remaining callout budget is exhausted and chain the rest.
    Integer maxRetries = QualConfigSelector.getMaxRetries();
    List<CalloutResultWrapper> allResults = new List<CalloutResultWrapper>();
    List<Id> deferredCaseIds = new List<Id>();
    Boolean budgetExhausted = false;

    for (Case c : cases) {
      if (budgetExhausted) {
        deferredCaseIds.add(c.Id);
        continue;
      }

      if (
        Limits.getCallouts() >=
        Limits.getLimitCallouts() - CALLOUT_SAFETY_BUFFER
      ) {
        budgetExhausted = true;
        deferredCaseIds.add(c.Id);
        continue;
      }
      QualCalloutService.CalloutResult result = QualCalloutService.processCaseCallout(
        c,
        config
      );
      allResults.add(new CalloutResultWrapper(c.Id, result));
    }

    // PHASE 2: Now perform all DML after callouts are complete
    List<qual_Integration_Log__c> logsToInsert = new List<qual_Integration_Log__c>();
    List<Id> failedCaseIds = new List<Id>();
    List<QualAlertService.DeadLetterAlert> deadLetterAlerts = new List<QualAlertService.DeadLetterAlert>();

    for (CalloutResultWrapper wrapper : allResults) {
      QualCalloutService.CalloutResult result = wrapper.result;

      if (result.isSuccess) {
        // Create success log
        qual_Integration_Log__c log = QualIntegrationLogger.createSuccessLog(
          result,
          config
        );
        if (log != null) {
          logsToInsert.add(log);
        }
      } else if (
        result.isRetryable && getRetryCountForCase(wrapper.caseId) < maxRetries
      ) {
        // Create retry log
        qual_Integration_Log__c log = QualIntegrationLogger.createRetryLog(
          result,
          getRetryCountForCase(wrapper.caseId) + 1,
          config
        );
        logsToInsert.add(log);
        failedCaseIds.add(wrapper.caseId);
      } else {
        // Create dead letter log
        qual_Integration_Log__c log = QualIntegrationLogger.createDeadLetterLog(
          result,
          config
        );
        logsToInsert.add(log);
        deadLetterAlerts.add(
          new QualAlertService.DeadLetterAlert(
            wrapper.caseId,
            result.errorMessage
          )
        );
      }
    }

    // Batch insert all logs at once
    if (!logsToInsert.isEmpty()) {
      insert logsToInsert;
    }

    // Send one summary alert after log DML so alert fan-out cannot exhaust email invocations.
    QualAlertService.sendDeadLetterAlerts(deadLetterAlerts, config);

    // Chain for deferred cases (budget exceeded) if any
    if (!deferredCaseIds.isEmpty() && !Test.isRunningTest()) {
      Map<Id, String> deferredEventTypes = new Map<Id, String>();
      Map<Id, Integer> deferredRetryCounts = new Map<Id, Integer>();
      for (Id caseId : deferredCaseIds) {
        if (this.eventTypeMap.containsKey(caseId)) {
          deferredEventTypes.put(caseId, this.eventTypeMap.get(caseId));
        }
        deferredRetryCounts.put(caseId, getRetryCountForCase(caseId));
      }
      System.enqueueJob(
        new QualCalloutQueueable(
          deferredCaseIds,
          deferredRetryCounts,
          deferredEventTypes
        )
      );
    }
  }

  private Integer getRetryCountForCase(Id caseId) {
    if (
      caseId != null &&
      retryCountByCase != null &&
      retryCountByCase.containsKey(caseId) &&
      retryCountByCase.get(caseId) != null
    ) {
      return retryCountByCase.get(caseId);
    }
    return retryCount != null ? retryCount : 0;
  }

  /**
   * @description Wrapper class to hold callout result with its case ID
   */
  private class CalloutResultWrapper {
    public Id caseId;
    public QualCalloutService.CalloutResult result;

    public CalloutResultWrapper(
      Id caseId,
      QualCalloutService.CalloutResult result
    ) {
      this.caseId = caseId;
      this.result = result;
    }
  }

  /**
   * @description Query Cases with all required related data
   */
  private List<Case> queryCases(List<Id> caseIdList) {
    // Build dynamic query to handle fields that might not exist in all orgs
    // Note: Owner.Manager fields removed - polymorphic relationship doesn't support these
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
      ' FROM Case WHERE Id IN :caseIdList';
    List<Case> cases = Database.query(query);

    // Enrich cases with User data (Department, Manager) for User owners
    enrichCasesWithUserData(cases);

    // Enrich cases with UJET Session Call IDs
    enrichCasesWithUjetCallIds(cases);

    return cases;
  }

  /**
   * @description Query UJET Session records for Cases and store Call IDs and durations in payload builder maps
   */
  private void enrichCasesWithUjetCallIds(List<Case> cases) {
    // Collect Case IDs
    Set<Id> caseIds = new Set<Id>();
    for (Case c : cases) {
      caseIds.add(c.Id);
    }

    if (caseIds.isEmpty()) {
      return;
    }

    // Query UJET Sessions with Call IDs, duration, and status fields for these Cases
    Map<Id, List<Decimal>> caseToCallIds = new Map<Id, List<Decimal>>();
    Map<Id, QualCasePayloadBuilder.UjetDurations> caseToDurations = new Map<Id, QualCasePayloadBuilder.UjetDurations>();
    Map<Id, Boolean> caseToAbandoned = new Map<Id, Boolean>();
    Map<Id, Integer> caseToSpeedToAnswer = new Map<Id, Integer>();

    try {
      List<UJET__UJET_Session__c> sessions = [
        SELECT
          Id,
          UJET__Case__c,
          UJET__Call_Id__c,
          UJET__Call_Duration__c,
          UJET__Hold_Duration__c,
          UJET__Wait_Duration__c,
          UJET__Fail_Reason__c,
          UJET__Status__c
        FROM UJET__UJET_Session__c
        WHERE UJET__Case__c IN :caseIds
      ];

      for (UJET__UJET_Session__c session : sessions) {
        Id caseId = session.UJET__Case__c;

        // Collect Call IDs (only if not null)
        if (session.UJET__Call_Id__c != null) {
          if (!caseToCallIds.containsKey(caseId)) {
            caseToCallIds.put(caseId, new List<Decimal>());
          }
          caseToCallIds.get(caseId).add(session.UJET__Call_Id__c);
        }

        // Aggregate durations across all sessions for this case
        if (!caseToDurations.containsKey(caseId)) {
          caseToDurations.put(
            caseId,
            new QualCasePayloadBuilder.UjetDurations()
          );
        }
        QualCasePayloadBuilder.UjetDurations durations = caseToDurations.get(
          caseId
        );

        // Use intValue() instead of Integer.valueOf() to safely handle decimals
        // intValue() truncates fractional parts, valueOf() throws on non-whole numbers
        if (session.UJET__Call_Duration__c != null) {
          durations.callDurationSeconds += session.UJET__Call_Duration__c.intValue();
        }
        if (session.UJET__Hold_Duration__c != null) {
          durations.holdDurationSeconds += session.UJET__Hold_Duration__c.intValue();
        }
        if (session.UJET__Wait_Duration__c != null) {
          durations.waitDurationSeconds += session.UJET__Wait_Duration__c.intValue();
        }

        // Track abandoned calls (eu_abandoned fail reason)
        if (session.UJET__Fail_Reason__c == 'eu_abandoned') {
          caseToAbandoned.put(caseId, true);
        } else if (!caseToAbandoned.containsKey(caseId)) {
          caseToAbandoned.put(caseId, false);
        }

        // Speed to answer: wait duration from the first finished inbound session
        if (
          session.UJET__Status__c == 'finished' &&
          session.UJET__Wait_Duration__c != null &&
          !caseToSpeedToAnswer.containsKey(caseId)
        ) {
          caseToSpeedToAnswer.put(
            caseId,
            session.UJET__Wait_Duration__c.intValue()
          );
        }
      }
    } catch (Exception e) {
      // UJET package may not be installed - log and continue without session data
      System.debug(
        LoggingLevel.WARN,
        'Could not query UJET Sessions: ' + e.getMessage()
      );
    }

    // Convert Call IDs to List<Long> map and store in payload builder
    Map<Id, List<Long>> caseToCallIdLongs = new Map<Id, List<Long>>();
    for (Id caseId : caseToCallIds.keySet()) {
      List<Decimal> callIds = caseToCallIds.get(caseId);
      List<Long> callIdLongs = new List<Long>();
      for (Decimal callId : callIds) {
        callIdLongs.add(callId.longValue());
      }
      caseToCallIdLongs.put(caseId, callIdLongs);
    }

    QualCasePayloadBuilder.setUjetCallIdMap(caseToCallIdLongs);
    QualCasePayloadBuilder.setUjetDurationsMap(caseToDurations);
    QualCasePayloadBuilder.setAbandonedCallMap(caseToAbandoned);
    QualCasePayloadBuilder.setSpeedToAnswerMap(caseToSpeedToAnswer);
  }

  /**
   * @description Query User data for Case owners and store in a static map for payload builder
   */
  private void enrichCasesWithUserData(List<Case> cases) {
    // Collect User IDs from Case owners
    Set<Id> userOwnerIds = new Set<Id>();
    for (Case c : cases) {
      if (c.OwnerId != null && String.valueOf(c.OwnerId).startsWith('005')) {
        userOwnerIds.add(c.OwnerId);
      }
    }

    if (userOwnerIds.isEmpty()) {
      return;
    }

    // Query Users with Qualtrics Team and Manager info
    Map<Id, User> userMap = new Map<Id, User>(
      [
        SELECT Id, Name, qual_Team__c, ManagerId, Manager.Name
        FROM User
        WHERE Id IN :userOwnerIds
      ]
    );

    // Store in static variable for payload builder to access
    QualCasePayloadBuilder.setUserDataMap(userMap);
  }
}