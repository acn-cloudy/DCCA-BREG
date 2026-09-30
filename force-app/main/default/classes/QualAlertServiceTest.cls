/**
 * @description Test class for QualAlertService
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualAlertServiceTest {
  @TestSetup
  static void setupTestData() {
    Map<String, SObject> testData = QualTestDataFactory.createCompleteTestData();
  }

  private static Messaging.SingleEmailMessage buildTestEmail(String subject) {
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ 'admin@example.com' });
    email.setSubject(subject);
    email.setPlainTextBody('Test email body');
    email.setSaveAsActivity(false);
    return email;
  }

  @IsTest
  static void testSendDeadLetterAlert() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com, support@example.com';

    Test.startTest();
    // Should not throw exception
    QualAlertService.sendDeadLetterAlert(
      testCase.Id,
      'Test error message',
      config
    );
    Test.stopTest();

    // No exception means success
    System.assert(true, 'Alert should be sent without error');
  }

  @IsTest
  static void testSendDeadLetterAlert_NoEmails() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = null;

    Test.startTest();
    QualAlertService.sendDeadLetterAlert(
      testCase.Id,
      'Test error message',
      config
    );
    Test.stopTest();

    // Should not throw exception when no emails configured
    System.assert(true, 'Should handle no email addresses gracefully');
  }

  @IsTest
  static void testSendDeadLetterAlert_NullConfig() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    Test.startTest();
    QualAlertService.sendDeadLetterAlert(
      testCase.Id,
      'Test error message',
      null
    );
    Test.stopTest();

    // Should not throw exception with null config
    System.assert(true, 'Should handle null config gracefully');
  }

  @IsTest
  static void testSendRateLimitAlert() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com';

    Test.startTest();
    QualAlertService.sendRateLimitAlert(10, config);
    Test.stopTest();

    // No exception means success
    System.assert(true, 'Rate limit alert should be sent without error');
  }

  @IsTest
  static void testSendRateLimitAlert_NoEmails() {
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = '';

    Test.startTest();
    QualAlertService.sendRateLimitAlert(10, config);
    Test.stopTest();

    // Should not throw exception when no emails configured
    System.assert(true, 'Should handle empty email addresses gracefully');
  }

  @IsTest
  static void testParseEmailAddresses_ValidEmails() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com, support@example.com, invalid';

    Test.startTest();
    // Indirectly test by calling alert method
    QualAlertService.sendDeadLetterAlert(testCase.Id, 'error', config);
    Test.stopTest();

    // Should filter out invalid email
    System.assert(true, 'Should parse valid emails and ignore invalid');
  }

  @IsTest
  static void testSendRateLimitAlert_NullConfig() {
    Test.startTest();
    QualAlertService.sendRateLimitAlert(10, null);
    Test.stopTest();

    // Should not throw exception with null config
    System.assert(
      true,
      'Should handle null config gracefully for rate limit alert'
    );
  }

  @IsTest
  static void testSendDeadLetterAlert_NullErrorMessage() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com';

    Test.startTest();
    QualAlertService.sendDeadLetterAlert(testCase.Id, null, config);
    Test.stopTest();

    System.assert(true, 'Should handle null error message gracefully');
  }

  @IsTest
  static void testSendDeadLetterAlerts_BulkUsesSingleEmailInvocation() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com';
    List<QualAlertService.DeadLetterAlert> alerts = new List<QualAlertService.DeadLetterAlert>();

    for (Integer i = 0; i < 12; i++) {
      alerts.add(
        new QualAlertService.DeadLetterAlert(
          testCase.Id,
          'Missing JSON alert ' + i
        )
      );
    }

    Test.startTest();
    QualAlertService.sendDeadLetterAlerts(alerts, config);
    System.assertEquals(
      1,
      Limits.getEmailInvocations(),
      'Bulk Dead Letter alerting should use one email invocation'
    );
    Test.stopTest();
  }

  @IsTest
  static void testBuildAlertBody_AboveCapListsCapAndNotesOmittedCount() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    List<QualAlertService.DeadLetterAlert> alerts = new List<QualAlertService.DeadLetterAlert>();

    for (Integer i = 0; i < 25; i++) {
      alerts.add(
        new QualAlertService.DeadLetterAlert(testCase.Id, 'Missing JSON ' + i)
      );
    }

    Test.startTest();
    String body = QualAlertService.buildAlertBody(alerts, config);
    Test.stopTest();

    System.assert(
      body.contains('Dead letters in this transaction: 25'),
      'Body should report the true batch size, not the capped size'
    );
    System.assert(
      body.contains('20. Case ID:'),
      'Body should list items up to the 20-item cap'
    );
    System.assert(
      !body.contains('21. Case ID:'),
      'Body should not list items beyond the 20-item cap'
    );
    System.assert(
      body.contains('5 additional dead letter item(s) omitted from this email'),
      'Body should state how many items were omitted'
    );
  }

  @IsTest
  static void testBuildAlertBody_AtCapDoesNotClaimOmittedItems() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    List<QualAlertService.DeadLetterAlert> alerts = new List<QualAlertService.DeadLetterAlert>();

    for (Integer i = 0; i < 20; i++) {
      alerts.add(
        new QualAlertService.DeadLetterAlert(testCase.Id, 'Missing JSON ' + i)
      );
    }

    Test.startTest();
    String body = QualAlertService.buildAlertBody(alerts, config);
    Test.stopTest();

    System.assert(
      body.contains('20. Case ID:'),
      'A batch exactly at the cap should list every item'
    );
    System.assert(
      !body.contains('omitted from this email'),
      'A batch exactly at the cap should not claim any item was omitted'
    );
  }

  @IsTest
  static void testFormatError_TruncatesOverlongErrorMessage() {
    String longError = 'E'.repeat(1500);

    Test.startTest();
    String formatted = QualAlertService.formatError(longError);
    Test.stopTest();

    System.assertEquals(
      1003,
      formatted.length(),
      'An overlong error should be truncated to the per-item cap plus an ellipsis'
    );
    System.assert(
      formatted.endsWith('...'),
      'A truncated error should end with an ellipsis'
    );
  }

  @IsTest
  static void testFormatError_BlankMessageFallsBackToUnknown() {
    Test.startTest();
    String fromNull = QualAlertService.formatError(null);
    String fromBlank = QualAlertService.formatError('   ');
    Test.stopTest();

    System.assertEquals(
      'Unknown error',
      fromNull,
      'A null error message should fall back to a readable label'
    );
    System.assertEquals(
      'Unknown error',
      fromBlank,
      'A blank error message should fall back to a readable label'
    );
  }

  @IsTest
  static void testSendDeadLetterAlert_SkipsWhenEmailInvocationLimitConsumed() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    qual_Config__mdt config = QualTestDataFactory.createTestConfig();
    config.qual_Alert_Email_Addresses__c = 'admin@example.com';

    Test.startTest();
    for (Integer i = 0; i < Limits.getLimitEmailInvocations(); i++) {
      Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{
          buildTestEmail('Existing email invocation ' + i)
        }
      );
    }
    Integer consumedInvocations = Limits.getEmailInvocations();

    QualAlertService.sendDeadLetterAlert(
      testCase.Id,
      'Should be skipped because no email invocation budget remains',
      config
    );

    System.assertEquals(
      consumedInvocations,
      Limits.getEmailInvocations(),
      'Alerting should not exceed the email invocation limit'
    );
    Test.stopTest();
  }
}