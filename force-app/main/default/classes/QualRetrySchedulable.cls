/**
 * @description Schedulable class to process retry queue
 * @author Qualtrics Integration Team
 */
public with sharing class QualRetrySchedulable implements Schedulable {
  private static final String DEFAULT_JOB_NAME = 'Qualtrics Retry Processor';

  /**
   * @description Execute scheduled job
   * @param sc Schedulable context
   */
  public void execute(SchedulableContext sc) {
    // Check if integration is active
    if (!QualConfigSelector.isIntegrationActive()) {
      return;
    }

    QualIntegrationLogger.recoverStaleProcessingLogs(120);

    QualIntegrationLogger.deleteLogsOlderThan(
      QualConfigSelector.getLogRetentionDays()
    );

    // Get logs pending retry
    List<qual_Integration_Log__c> logsToRetry = QualIntegrationLogger.getLogsForRetry();

    if (logsToRetry.isEmpty()) {
      return;
    }

    // Collect unique Case and Call Session IDs, retry counts, and event types
    Map<Id, Integer> caseRetryMap = new Map<Id, Integer>();
    Map<Id, String> eventTypeMap = new Map<Id, String>();
    Map<Id, Integer> sessionRetryMap = new Map<Id, Integer>();

    for (qual_Integration_Log__c log : logsToRetry) {
      String payloadType = String.isNotBlank(log.qual_Payload_Type__c)
        ? log.qual_Payload_Type__c
        : QualCalloutService.PAYLOAD_TYPE_CASE;
      Integer logRetry = log.qual_Retry_Count__c != null
        ? Integer.valueOf(log.qual_Retry_Count__c)
        : 0;

      if (
        payloadType == QualCalloutService.PAYLOAD_TYPE_CALL &&
        String.isNotBlank(log.qual_Ujet_Session_Id__c)
      ) {
        Id sessionId = Id.valueOf(log.qual_Ujet_Session_Id__c);
        Integer existingSessionRetry = sessionRetryMap.get(sessionId);
        if (existingSessionRetry == null || logRetry > existingSessionRetry) {
          sessionRetryMap.put(sessionId, logRetry);
        }
      } else if (log.qual_Case__c != null) {
        Integer existingRetry = caseRetryMap.get(log.qual_Case__c);

        // Keep the highest retry count
        if (existingRetry == null || logRetry > existingRetry) {
          caseRetryMap.put(log.qual_Case__c, logRetry);
        }
        if (
          String.isNotBlank(log.qual_Event_Type__c) &&
          !eventTypeMap.containsKey(log.qual_Case__c)
        ) {
          eventTypeMap.put(log.qual_Case__c, log.qual_Event_Type__c);
        }
      }

      // Update log status to Processing
      log.qual_Status__c = 'Processing';
    }

    // Update logs
    if (!logsToRetry.isEmpty()) {
      update logsToRetry;
    }

    // Enqueue job for retry processing
    if (!caseRetryMap.isEmpty()) {
      List<Id> caseIds = new List<Id>(caseRetryMap.keySet());
      System.enqueueJob(
        new QualCalloutQueueable(caseIds, caseRetryMap, eventTypeMap)
      );
    }

    if (!sessionRetryMap.isEmpty()) {
      System.enqueueJob(
        new QualCallSessionQueueable(
          new List<Id>(sessionRetryMap.keySet()),
          sessionRetryMap
        )
      );
    }
  }

  /**
   * @description Schedule the retry job
   * @param jobName Name for the scheduled job
   * @param cronExpression Cron expression for schedule
   * @return Scheduled job ID
   */
  public static Id scheduleJob(String jobName, String cronExpression) {
    return System.schedule(jobName, cronExpression, new QualRetrySchedulable());
  }

  /**
   * @description Schedule with default settings (hourly)
   * @return Scheduled job ID
   */
  public static Id scheduleDefault() {
    // Cron format: Seconds Minutes Hours Day_of_month Month Day_of_week Year
    String cronExp = '0 0 * * * ?'; // Run at top of every hour
    String jobName = DEFAULT_JOB_NAME;

    if (Test.isRunningTest()) {
      jobName += ' ' + String.valueOf(Datetime.now().getTime());
    } else {
      List<CronTrigger> existingJobs = [
        SELECT Id
        FROM CronTrigger
        WHERE
          CronJobDetail.Name = :DEFAULT_JOB_NAME
          AND State IN ('WAITING', 'ACQUIRED')
        LIMIT 1
      ];
      if (!existingJobs.isEmpty()) {
        return existingJobs[0].Id;
      }
    }

    return scheduleJob(jobName, cronExp);
  }
}