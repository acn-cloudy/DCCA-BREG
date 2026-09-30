/**
 * @description Handler for UJET Session trigger - independent Qualtrics Call payloads.
 */
public with sharing class QualUjetSessionTriggerHandler {
  private static Boolean isExecuting = false;

  @TestVisible
  private static Boolean bypassInTests = true;

  public static void handleAfterInsert(
    List<UJET__UJET_Session__c> newSessions
  ) {
    enqueueEligibleSessions(newSessions, null);
  }

  public static void handleAfterUpdate(
    List<UJET__UJET_Session__c> newSessions,
    Map<Id, UJET__UJET_Session__c> oldSessionMap
  ) {
    enqueueEligibleSessions(newSessions, oldSessionMap);
  }

  private static void enqueueEligibleSessions(
    List<UJET__UJET_Session__c> sessions,
    Map<Id, UJET__UJET_Session__c> oldSessionMap
  ) {
    if (isExecuting || sessions == null || sessions.isEmpty()) {
      return;
    }
    if (Test.isRunningTest() && bypassInTests) {
      return;
    }

    qual_Config__mdt config = QualConfigSelector.getActiveConfig();
    if (
      config == null ||
      !config.qual_Is_Active__c ||
      String.isBlank(config.qual_Call_Workflow_Id__c)
    ) {
      return;
    }

    try {
      isExecuting = true;
      List<UJET__UJET_Session__c> eligibleSessions = new List<UJET__UJET_Session__c>();
      for (UJET__UJET_Session__c session : sessions) {
        if (
          session.UJET__Case__c == null ||
          !hasQualifyingChange(session, oldSessionMap)
        ) {
          continue;
        }
        eligibleSessions.add(session);
      }

      if (!eligibleSessions.isEmpty()) {
        Integer delayMinutes = QualConfigSelector.getCallDelayMinutes();
        if (delayMinutes > 0) {
          QualIntegrationLogger.createOrRefreshDeferredCallLogs(
            eligibleSessions,
            delayMinutes,
            config
          );
        } else {
          List<Id> sessionIds = new List<Id>();
          for (UJET__UJET_Session__c session : eligibleSessions) {
            sessionIds.add(session.Id);
          }
          System.enqueueJob(new QualCallSessionQueueable(sessionIds));
        }
      }
    } finally {
      isExecuting = false;
    }
  }

  private static Boolean hasQualifyingChange(
    UJET__UJET_Session__c session,
    Map<Id, UJET__UJET_Session__c> oldSessionMap
  ) {
    if (oldSessionMap == null || !oldSessionMap.containsKey(session.Id)) {
      return true;
    }

    UJET__UJET_Session__c oldSession = oldSessionMap.get(session.Id);
    return session.UJET__Call_Id__c != oldSession.UJET__Call_Id__c ||
      session.UJET__Status__c != oldSession.UJET__Status__c ||
      session.UJET__Call_Duration__c != oldSession.UJET__Call_Duration__c ||
      session.UJET__Hold_Duration__c != oldSession.UJET__Hold_Duration__c ||
      session.UJET__Wait_Duration__c != oldSession.UJET__Wait_Duration__c ||
      session.UJET__Fail_Reason__c != oldSession.UJET__Fail_Reason__c ||
      session.UJET__Case__c != oldSession.UJET__Case__c;
  }

  @TestVisible
  private static void resetRecursionGuard() {
    isExecuting = false;
  }
}