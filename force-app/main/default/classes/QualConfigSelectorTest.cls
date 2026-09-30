/**
 * @description Test class for QualConfigSelector
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualConfigSelectorTest {
  @IsTest
  static void testGetActiveConfig() {
    // Set up test config
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    qual_Config__mdt result = QualConfigSelector.getActiveConfig();
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return config');
    System.assertEquals(
      'test-token-uuid-12345',
      result.qual_Workflow_Id__c,
      'Should have correct workflow ID'
    );
    System.assertEquals(true, result.qual_Is_Active__c, 'Should be active');
  }

  @IsTest
  static void testIsIntegrationActive() {
    // Set up active config
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Boolean isActive = QualConfigSelector.isIntegrationActive();
    Test.stopTest();

    System.assertEquals(true, isActive, 'Integration should be active');
  }

  @IsTest
  static void testIsIntegrationActive_NoConfig() {
    // Clear any cached config and test settings
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);
    QualConfigSelector.setTestSettings(null);

    Test.startTest();
    Boolean isActive = QualConfigSelector.isIntegrationActive();
    Test.stopTest();

    System.assertEquals(
      false,
      isActive,
      'Integration should be inactive when no config'
    );
  }

  @IsTest
  static void testGetMaxRetries() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer maxRetries = QualConfigSelector.getMaxRetries();
    Test.stopTest();

    System.assertEquals(3, maxRetries, 'Should return configured max retries');
  }

  @IsTest
  static void testGetRetryIntervalMinutes() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer interval = QualConfigSelector.getRetryIntervalMinutes();
    Test.stopTest();

    System.assertEquals(
      15,
      interval,
      'Should return configured retry interval'
    );
  }

  @IsTest
  static void testGetMaxPayloadSizeBytes() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer maxSize = QualConfigSelector.getMaxPayloadSizeBytes();
    Test.stopTest();

    System.assertEquals(102400, maxSize, 'Should return 100KB in bytes');
  }

  @IsTest
  static void testGetTimeoutSeconds() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer timeout = QualConfigSelector.getTimeoutSeconds();
    Test.stopTest();

    System.assertEquals(30, timeout, 'Should return configured timeout');
  }

  @IsTest
  static void testClearCache() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    // Get config to cache it
    QualConfigSelector.getActiveConfig();

    Test.startTest();
    QualConfigSelector.clearCache();
    Test.stopTest();

    // Should be able to get config again after clearing cache
    qual_Config__mdt result = QualConfigSelector.getActiveConfig();
    System.assertNotEquals(
      null,
      result,
      'Should return config after cache clear'
    );
  }

  @IsTest
  static void testGetIntegrationSettings() {
    qual_Integration_Settings__c testSettings = QualTestDataFactory.createTestSettings(
      'PRODUCTION',
      'my-api-token'
    );
    QualConfigSelector.setTestSettings(testSettings);

    Test.startTest();
    qual_Integration_Settings__c result = QualConfigSelector.getIntegrationSettings();
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return settings');
    System.assertEquals(
      'PRODUCTION',
      result.qual_Environment__c,
      'Should have correct environment'
    );
    System.assertEquals(
      'my-api-token',
      result.qual_Api_Token__c,
      'Should have correct API token'
    );
  }

  @IsTest
  static void testGetApiToken() {
    qual_Integration_Settings__c testSettings = QualTestDataFactory.createTestSettings(
      'DEV',
      'test-token-xyz'
    );
    QualConfigSelector.setTestSettings(testSettings);

    Test.startTest();
    String token = QualConfigSelector.getApiToken();
    Test.stopTest();

    System.assertEquals(
      'test-token-xyz',
      token,
      'Should return correct API token'
    );
  }

  @IsTest
  static void testGetApiToken_NoSettings() {
    QualConfigSelector.setTestSettings(null);

    Test.startTest();
    String token = QualConfigSelector.getApiToken();
    Test.stopTest();

    System.assertEquals(null, token, 'Should return null when no settings');
  }

  @IsTest
  static void testGetOrgEnvironment() {
    qual_Integration_Settings__c testSettings = QualTestDataFactory.createTestSettings(
      'UAT',
      'uat-token'
    );
    QualConfigSelector.setTestSettings(testSettings);

    Test.startTest();
    String env = QualConfigSelector.getOrgEnvironment();
    Test.stopTest();

    System.assertEquals('UAT', env, 'Should return correct environment');
  }

  @IsTest
  static void testGetOrgEnvironment_NoSettings() {
    QualConfigSelector.setTestSettings(null);

    Test.startTest();
    String env = QualConfigSelector.getOrgEnvironment();
    Test.stopTest();

    System.assertEquals(null, env, 'Should return null when no settings');
  }

  @IsTest
  static void testGetActiveConfig_StrictEnvironmentMatch() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings('DEV', 'test-token')
    );
    qual_Config__mdt uatConfig = QualTestDataFactory.createTestConfig();
    uatConfig.DeveloperName = 'Active_UAT_Config';
    uatConfig.qual_Environment__c = 'UAT';

    qual_Config__mdt inactiveDevConfig = QualTestDataFactory.createTestConfig();
    inactiveDevConfig.DeveloperName = 'Inactive_DEV_Config';
    inactiveDevConfig.qual_Is_Active__c = false;

    qual_Config__mdt activeDevConfig = QualTestDataFactory.createTestConfig();
    activeDevConfig.DeveloperName = 'Active_DEV_Config';
    activeDevConfig.qual_Environment__c = 'DEV';
    activeDevConfig.qual_Is_Test_Contact__c = false;

    QualConfigSelector.setTestMetadataConfigs(
      new List<qual_Config__mdt>{
        uatConfig,
        inactiveDevConfig,
        activeDevConfig
      }
    );

    Test.startTest();
    qual_Config__mdt result = QualConfigSelector.getActiveConfig();
    Test.stopTest();

    System.assertNotEquals(
      null,
      result,
      'Matching active DEV config should be returned'
    );
    System.assertEquals(
      'DEV',
      result.qual_Environment__c,
      'Config should match org environment'
    );
    System.assertEquals(
      'Active_DEV_Config',
      result.DeveloperName,
      'Inactive or mismatched active configs should be ignored'
    );
    System.assertEquals(
      false,
      result.qual_Is_Test_Contact__c,
      'Selected config should carry the configured test-contact flag'
    );
  }

  @IsTest
  static void testGetActiveConfig_UnmatchedEnvironmentFailsClosed() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings(
        'NO_SUCH_ENVIRONMENT',
        'test-token'
      )
    );
    QualConfigSelector.setTestMetadataConfigs(
      new List<qual_Config__mdt>{ QualTestDataFactory.createTestConfig() }
    );

    Test.startTest();
    qual_Config__mdt result = QualConfigSelector.getActiveConfig();
    Test.stopTest();

    System.assertEquals(
      null,
      result,
      'Unmatched environment should not fall back to any active config'
    );
  }

  @IsTest
  static void testGetActiveConfig_BlankEnvironmentFailsClosed() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestSettings(
      QualTestDataFactory.createTestSettings(null, 'test-token')
    );
    QualConfigSelector.setTestMetadataConfigs(
      new List<qual_Config__mdt>{ QualTestDataFactory.createTestConfig() }
    );

    Test.startTest();
    qual_Config__mdt result = QualConfigSelector.getActiveConfig();
    Test.stopTest();

    System.assertEquals(
      null,
      result,
      'Blank environment should not fall back to any active config'
    );
  }

  @IsTest
  static void testGetEnabledEventTypes_Configured() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfigAllEvents();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Set<String> result = QualConfigSelector.getEnabledEventTypes();
    Test.stopTest();

    System.assertEquals(3, result.size(), 'Should have 3 event types');
    System.assert(result.contains('opened'), 'Should contain opened');
    System.assert(result.contains('updated'), 'Should contain updated');
    System.assert(result.contains('closed'), 'Should contain closed');
  }

  @IsTest
  static void testGetEnabledEventTypes_DefaultsClosed() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Case_Event_Types__c = null;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Set<String> result = QualConfigSelector.getEnabledEventTypes();
    Test.stopTest();

    System.assertEquals(1, result.size(), 'Should default to 1 event type');
    System.assert(result.contains('closed'), 'Should default to closed');
  }

  @IsTest
  static void testGetTrackedUpdateFields_Configured() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Set<String> result = QualConfigSelector.getTrackedUpdateFields();
    Test.stopTest();

    System.assert(result.size() >= 4, 'Should have multiple tracked fields');
    System.assert(
      result.contains('status'),
      'Should contain status (lowercase)'
    );
    System.assert(
      result.contains('priority'),
      'Should contain priority (lowercase)'
    );
    System.assert(
      result.contains('ownerid'),
      'Should contain ownerid (lowercase)'
    );
  }

  @IsTest
  static void testGetTrackedUpdateFields_Empty() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Case_Tracked_Update_Fields__c = null;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Set<String> result = QualConfigSelector.getTrackedUpdateFields();
    Test.stopTest();

    System.assertEquals(
      0,
      result.size(),
      'Should return empty set when not configured'
    );
  }

  @IsTest
  static void testGetOpenedDelayMinutes_Configured() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Case_Opened_Delay_Minutes__c = 90;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getOpenedDelayMinutes();
    Test.stopTest();

    System.assertEquals(90, result, 'Should return configured delay');
  }

  @IsTest
  static void testGetOpenedDelayMinutes_Null_DefaultsTo120() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Case_Opened_Delay_Minutes__c = null;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getOpenedDelayMinutes();
    Test.stopTest();

    System.assertEquals(
      120,
      result,
      'Should default to 120 when not configured'
    );
  }

  @IsTest
  static void testGetOpenedDelayMinutes_Zero() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Case_Opened_Delay_Minutes__c = 0;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getOpenedDelayMinutes();
    Test.stopTest();

    System.assertEquals(0, result, 'Should return 0 for immediate send');
  }

  @IsTest
  static void testGetCallDelayMinutes_Configured() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Call_Delay_Minutes__c = 45;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getCallDelayMinutes();
    Test.stopTest();

    System.assertEquals(45, result, 'Should return configured Call delay');
  }

  @IsTest
  static void testGetCallDelayMinutes_Null_DefaultsToZero() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Call_Delay_Minutes__c = null;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getCallDelayMinutes();
    Test.stopTest();

    System.assertEquals(0, result, 'Should default to immediate Call send');
  }

  @IsTest
  static void testGetLogRetentionDays_Configured() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Log_Retention_Days__c = 30;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getLogRetentionDays();
    Test.stopTest();

    System.assertEquals(30, result, 'Should return configured log retention');
  }

  @IsTest
  static void testGetLogRetentionDays_Null_DefaultsTo60() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    testConfig.qual_Log_Retention_Days__c = null;
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    Integer result = QualConfigSelector.getLogRetentionDays();
    Test.stopTest();

    System.assertEquals(60, result, 'Should default to 60 days');
  }

  @IsTest
  static void testGetConfigByName() {
    qual_Config__mdt testConfig = QualTestDataFactory.createTestConfig();
    QualConfigSelector.setTestConfig(testConfig);

    Test.startTest();
    qual_Config__mdt result = QualConfigSelector.getConfigByName('Test_Config');
    Test.stopTest();

    System.assertNotEquals(
      null,
      result,
      'Should return config via getConfigByName'
    );
    System.assertEquals(
      true,
      result.qual_Is_Active__c,
      'Config should be active'
    );
  }

  @IsTest
  static void testGetMaxRetries_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Integer result = QualConfigSelector.getMaxRetries();
    Test.stopTest();

    System.assertEquals(
      3,
      result,
      'Should return default 3 when config is null'
    );
  }

  @IsTest
  static void testGetRetryIntervalMinutes_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Integer result = QualConfigSelector.getRetryIntervalMinutes();
    Test.stopTest();

    System.assertEquals(
      15,
      result,
      'Should return default 15 when config is null'
    );
  }

  @IsTest
  static void testGetMaxPayloadSizeBytes_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Integer result = QualConfigSelector.getMaxPayloadSizeBytes();
    Test.stopTest();

    System.assertEquals(
      102400,
      result,
      'Should return default 100KB when config is null'
    );
  }

  @IsTest
  static void testGetTimeoutSeconds_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Integer result = QualConfigSelector.getTimeoutSeconds();
    Test.stopTest();

    System.assertEquals(
      30,
      result,
      'Should return default 30 when config is null'
    );
  }

  @IsTest
  static void testGetOpenedDelayMinutes_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Integer result = QualConfigSelector.getOpenedDelayMinutes();
    Test.stopTest();

    System.assertEquals(
      120,
      result,
      'Should return default 120 when config is null'
    );
  }

  @IsTest
  static void testGetEnabledEventTypes_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Set<String> result = QualConfigSelector.getEnabledEventTypes();
    Test.stopTest();

    System.assertEquals(1, result.size(), 'Should default to 1 event type');
    System.assert(result.contains('closed'), 'Should default to closed');
  }

  @IsTest
  static void testGetTrackedUpdateFields_NullConfig() {
    QualConfigSelector.clearCache();
    QualConfigSelector.setTestConfig(null);

    Test.startTest();
    Set<String> result = QualConfigSelector.getTrackedUpdateFields();
    Test.stopTest();

    System.assertEquals(
      0,
      result.size(),
      'Should return empty set when config is null'
    );
  }
}