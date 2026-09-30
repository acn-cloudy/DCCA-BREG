/**
 * @description Alert service for Qualtrics integration errors
 * @author Qualtrics Integration Team
 */
public with sharing class QualAlertService {
  private static final String EMAIL_SUBJECT = 'Qualtrics Integration Alert: Dead Letter';
  private static final Integer MAX_ALERT_ITEMS_IN_EMAIL = 20;
  private static final Integer MAX_ERROR_CHARS_PER_ITEM = 1000;

  public class DeadLetterAlert {
    public Id caseId;
    public String errorMessage;

    public DeadLetterAlert(Id caseId, String errorMessage) {
      this.caseId = caseId;
      this.errorMessage = errorMessage;
    }
  }

  /**
   * @description Send alert for dead letter cases
   * @param caseId Related Case ID
   * @param errorMessage Error description
   * @param config Configuration with email addresses
   */
  public static void sendDeadLetterAlert(
    Id caseId,
    String errorMessage,
    qual_Config__mdt config
  ) {
    sendDeadLetterAlerts(
      new List<DeadLetterAlert>{ new DeadLetterAlert(caseId, errorMessage) },
      config
    );
  }

  /**
   * @description Send one summary alert for a group of dead letters.
   * @param alerts Dead letter cases and errors to summarize
   * @param config Configuration with email addresses
   */
  public static void sendDeadLetterAlerts(
    List<DeadLetterAlert> alerts,
    qual_Config__mdt config
  ) {
    if (
      config == null ||
      String.isBlank(config.qual_Alert_Email_Addresses__c) ||
      alerts == null ||
      alerts.isEmpty()
    ) {
      return;
    }

    List<DeadLetterAlert> validAlerts = new List<DeadLetterAlert>();
    for (DeadLetterAlert alert : alerts) {
      if (alert != null) {
        validAlerts.add(alert);
      }
    }
    if (validAlerts.isEmpty()) {
      return;
    }

    List<String> emailAddresses = parseEmailAddresses(
      config.qual_Alert_Email_Addresses__c
    );

    if (emailAddresses.isEmpty()) {
      return;
    }

    String subject = EMAIL_SUBJECT;
    if (validAlerts.size() > 1) {
      subject += ' (' + validAlerts.size() + ')';
    }

    sendEmail(emailAddresses, subject, buildAlertBody(validAlerts, config));
  }

  /**
   * @description Send alert for rate limiting
   * @param caseCount Number of cases affected
   * @param config Configuration with email addresses
   */
  public static void sendRateLimitAlert(
    Integer caseCount,
    qual_Config__mdt config
  ) {
    if (
      config == null || String.isBlank(config.qual_Alert_Email_Addresses__c)
    ) {
      return;
    }

    List<String> emailAddresses = parseEmailAddresses(
      config.qual_Alert_Email_Addresses__c
    );

    if (emailAddresses.isEmpty()) {
      return;
    }

    String subject = 'Qualtrics Integration Alert: Rate Limit Exceeded';
    String body = 'The Qualtrics integration has hit rate limits.\n\n';
    body += 'Cases affected: ' + caseCount + '\n';
    body +=
      'Environment: ' +
      (config.qual_Environment__c != null
        ? config.qual_Environment__c
        : 'Unknown') +
      '\n';
    body += 'Datacenter: ' + config.qual_Datacenter__c + '\n\n';
    body += 'The system will automatically retry these cases.';

    sendEmail(emailAddresses, subject, body);
  }

  /**
   * @description Parse comma-separated email addresses
   */
  private static List<String> parseEmailAddresses(String emailString) {
    List<String> emails = new List<String>();

    if (String.isBlank(emailString)) {
      return emails;
    }

    for (String email : emailString.split(',')) {
      String trimmed = email.trim();
      if (String.isNotBlank(trimmed) && trimmed.contains('@')) {
        emails.add(trimmed);
      }
    }

    return emails;
  }

  /**
   * @description Build alert email body
   */
  @TestVisible
  private static String buildAlertBody(
    List<DeadLetterAlert> alerts,
    qual_Config__mdt config
  ) {
    String body = 'One or more Qualtrics integration callouts failed and reached the dead letter queue.\n\n';
    body += 'Dead letters in this transaction: ' + alerts.size() + '\n';
    body +=
      'Environment: ' +
      (config.qual_Environment__c != null
        ? config.qual_Environment__c
        : 'Unknown') +
      '\n';
    body += 'Workflow ID: ' + config.qual_Workflow_Id__c + '\n';
    body += 'Datacenter: ' + config.qual_Datacenter__c + '\n\n';
    body += 'Items:\n';

    Integer itemCount = 0;
    for (DeadLetterAlert alert : alerts) {
      if (itemCount >= MAX_ALERT_ITEMS_IN_EMAIL) {
        break;
      }
      itemCount++;
      body += '\n' + itemCount + '. Case ID: ' + formatCaseId(alert.caseId);
      body += '\n   Error: ' + formatError(alert.errorMessage) + '\n';
    }

    Integer omittedCount = alerts.size() - itemCount;
    if (omittedCount > 0) {
      body +=
        '\n' +
        omittedCount +
        ' additional dead letter item(s) omitted from this email. Review the Qualtrics Integration Logs for the full list.\n';
    }

    body += '\nPlease investigate these cases in the Qualtrics Integration Logs.';

    return body;
  }

  private static String formatCaseId(Id caseId) {
    return caseId != null ? String.valueOf(caseId) : 'Unknown';
  }

  @TestVisible
  private static String formatError(String errorMessage) {
    if (String.isBlank(errorMessage)) {
      return 'Unknown error';
    }

    String trimmed = errorMessage.trim();
    if (trimmed.length() > MAX_ERROR_CHARS_PER_ITEM) {
      return trimmed.substring(0, MAX_ERROR_CHARS_PER_ITEM) + '...';
    }

    return trimmed;
  }

  /**
   * @description Send email to recipients
   */
  private static void sendEmail(
    List<String> toAddresses,
    String subject,
    String body
  ) {
    if (Limits.getEmailInvocations() >= Limits.getLimitEmailInvocations()) {
      System.debug(
        LoggingLevel.ERROR,
        'Skipped Qualtrics alert email because the email invocation limit is already exhausted'
      );
      return;
    }

    try {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(toAddresses);
      email.setSubject(subject);
      email.setPlainTextBody(body);
      email.setSaveAsActivity(false);

      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Failed to send alert email: ' + ex.getMessage()
      );
    }
  }
}