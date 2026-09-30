/**
 * @description Selector class for Qualtrics configuration Custom Metadata and Settings
 * @author Qualtrics Integration Team
 */
public with sharing class QualConfigSelector {
  @TestVisible
  private static qual_Config__mdt cachedConfig;

  @TestVisible
  private static qual_Config__mdt testConfig;

  @TestVisible
  private static List<qual_Config__mdt> testMetadataConfigs;

  @TestVisible
  private static Boolean testConfigExplicitlyNull = false;

  @TestVisible
  private static qual_Integration_Settings__c testSettings;

  /**
   * @description Get the org's integration settings (Custom Setting)
   * @return qual_Integration_Settings__c org defaults or null
   */
  public static qual_Integration_Settings__c getIntegrationSettings() {
    // Return test settings if set (for unit tests)
    if (Test.isRunningTest() && testSettings != null) {
      return testSettings;
    }
    return qual_Integration_Settings__c.getOrgDefaults();
  }

  /**
   * @description Get the API token from org settings
   * @return API token string or null
   */
  public static String getApiToken() {
    qual_Integration_Settings__c settings = getIntegrationSettings();
    if (settings != null) {
      return settings.qual_Api_Token__c;
    }
    return null;
  }

  /**
   * @description Get the org's current environment
   * @return Environment string (Production, Sandbox, GovCloud) or null
   */
  public static String getOrgEnvironment() {
    qual_Integration_Settings__c settings = getIntegrationSettings();
    if (settings != null) {
      return settings.qual_Environment__c;
    }
    return null;
  }

  /**
   * @description Get the active configuration record for the org's environment
   * @return Active qual_Config__mdt record or null
   */
  public static qual_Config__mdt getActiveConfig() {
    // Return null if test explicitly set config to null (for unit tests)
    if (Test.isRunningTest() && testConfigExplicitlyNull) {
      return null;
    }
    // Return test config if set (for unit tests)
    if (Test.isRunningTest() && testConfig != null) {
      return testConfig;
    }

    if (cachedConfig == null) {
      String orgEnvironment = getOrgEnvironment();
      List<qual_Config__mdt> configs;

      // If org environment is set, select config matching that environment
      if (String.isNotBlank(orgEnvironment)) {
        if (Test.isRunningTest() && testMetadataConfigs != null) {
          configs = filterActiveConfigsForEnvironment(
            testMetadataConfigs,
            orgEnvironment
          );
        } else {
          configs = [
            SELECT
              qual_Workflow_Id__c,
              qual_Case_Workflow_Id__c,
              qual_Call_Workflow_Id__c,
              qual_Datacenter__c,
              qual_Named_Credential__c,
              qual_Is_Active__c,
              qual_Max_Retries__c,
              qual_Retry_Interval_Minutes__c,
              qual_Default_Country_Code__c,
              qual_Environment__c,
              qual_Is_Test_Contact__c,
              qual_Alert_Email_Addresses__c,
              qual_Payload_Version__c,
              qual_Max_Payload_Size_KB__c,
              qual_Timeout_Seconds__c,
              qual_Case_Require_Contact__c,
              qual_Case_Filter_Statuses__c,
              qual_Case_Filter_Origins__c,
              qual_Case_Filter_Priorities__c,
              qual_Case_Filter_Types__c,
              qual_Case_Filter_RecordTypes__c,
              qual_Case_Custom_Soql_Filter__c,
              qual_Log_Level__c,
              qual_Case_Event_Types__c,
              qual_Case_Tracked_Update_Fields__c,
              qual_Case_Opened_Delay_Minutes__c,
              qual_Call_Delay_Minutes__c,
              qual_Log_Retention_Days__c,
              DeveloperName
            FROM qual_Config__mdt
            WHERE
              qual_Is_Active__c = TRUE
              AND qual_Environment__c = :orgEnvironment
            LIMIT 1
          ];
        }
      }

      if (configs != null && !configs.isEmpty()) {
        cachedConfig = configs[0];
      }
    }
    return cachedConfig;
  }

  private static List<qual_Config__mdt> filterActiveConfigsForEnvironment(
    List<qual_Config__mdt> configs,
    String orgEnvironment
  ) {
    List<qual_Config__mdt> matches = new List<qual_Config__mdt>();
    if (configs == null || String.isBlank(orgEnvironment)) {
      return matches;
    }

    for (qual_Config__mdt config : configs) {
      if (
        config.qual_Is_Active__c == true &&
        config.qual_Environment__c == orgEnvironment
      ) {
        matches.add(config);
        break;
      }
    }
    return matches;
  }

  /**
   * @description Get configuration by developer name
   * @param developerName The developer name of the config record
   * @return qual_Config__mdt record or null
   */
  public static qual_Config__mdt getConfigByName(String developerName) {
    if (Test.isRunningTest() && testConfig != null) {
      return testConfig;
    }

    return qual_Config__mdt.getInstance(developerName);
  }

  /**
   * @description Check if integration is active
   * @return True if integration is enabled
   */
  public static Boolean isIntegrationActive() {
    qual_Config__mdt config = getActiveConfig();
    return config != null && config.qual_Is_Active__c;
  }

  /**
   * @description Get max retries from config
   * @return Max retry count
   */
  public static Integer getMaxRetries() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Max_Retries__c != null) {
      return Integer.valueOf(config.qual_Max_Retries__c);
    }
    return 3; // Default
  }

  /**
   * @description Get retry interval in minutes
   * @return Retry interval
   */
  public static Integer getRetryIntervalMinutes() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Retry_Interval_Minutes__c != null) {
      return Integer.valueOf(config.qual_Retry_Interval_Minutes__c);
    }
    return 15; // Default
  }

  /**
   * @description Get max payload size in bytes
   * @return Max payload size
   */
  public static Integer getMaxPayloadSizeBytes() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Max_Payload_Size_KB__c != null) {
      return Integer.valueOf(config.qual_Max_Payload_Size_KB__c) * 1024;
    }
    return 102400; // 100KB default
  }

  /**
   * @description Get HTTP timeout in seconds
   * @return Timeout value
   */
  public static Integer getTimeoutSeconds() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Timeout_Seconds__c != null) {
      return Integer.valueOf(config.qual_Timeout_Seconds__c);
    }
    return 30; // Default
  }

  public static String getCaseWorkflowId() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && String.isNotBlank(config.qual_Case_Workflow_Id__c)) {
      return config.qual_Case_Workflow_Id__c;
    }
    return config != null ? config.qual_Workflow_Id__c : null;
  }

  public static String getCallWorkflowId() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && String.isNotBlank(config.qual_Call_Workflow_Id__c)) {
      return config.qual_Call_Workflow_Id__c;
    }
    return null;
  }

  /**
   * @description Get delay in minutes before sending Opened/Updated events.
   * Allows time for data enrichment (e.g., UJET session sync).
   * @return Delay in minutes (0 = immediate, default 120)
   */
  public static Integer getOpenedDelayMinutes() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Case_Opened_Delay_Minutes__c != null) {
      return Integer.valueOf(config.qual_Case_Opened_Delay_Minutes__c);
    }
    return 120;
  }

  /**
   * @description Get delay in minutes before sending Call/Session events.
   * Allows attached UJET call JSON files to arrive before the Call payload is built.
   * @return Delay in minutes (0 = immediate, default 0)
   */
  public static Integer getCallDelayMinutes() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Call_Delay_Minutes__c != null) {
      return Integer.valueOf(config.qual_Call_Delay_Minutes__c);
    }
    return 0;
  }

  /**
   * @description Get number of days to retain completed integration logs.
   * @return Retention in days (default 60)
   */
  public static Integer getLogRetentionDays() {
    qual_Config__mdt config = getActiveConfig();
    if (config != null && config.qual_Log_Retention_Days__c != null) {
      return Integer.valueOf(config.qual_Log_Retention_Days__c);
    }
    return 60;
  }

  /**
   * @description Get enabled event types from config
   * @return Set of enabled event type strings (lowercase). Defaults to {'closed'} if not configured.
   */
  public static Set<String> getEnabledEventTypes() {
    qual_Config__mdt config = getActiveConfig();
    Set<String> result = new Set<String>();
    if (config != null && String.isNotBlank(config.qual_Case_Event_Types__c)) {
      for (String part : config.qual_Case_Event_Types__c.split('[,\\n\\r]+')) {
        String trimmed = part.trim();
        if (String.isNotBlank(trimmed)) {
          result.add(trimmed.toLowerCase());
        }
      }
    }
    // Default to Closed only for backward compatibility
    if (result.isEmpty()) {
      result.add('closed');
    }
    return result;
  }

  /**
   * @description Get tracked update field API names from config (lowercase)
   * @return Set of lowercase field API names. Empty set if not configured.
   */
  public static Set<String> getTrackedUpdateFields() {
    qual_Config__mdt config = getActiveConfig();
    Set<String> result = new Set<String>();
    if (
      config != null &&
      String.isNotBlank(config.qual_Case_Tracked_Update_Fields__c)
    ) {
      for (
        String part : config.qual_Case_Tracked_Update_Fields__c.split(
          '[,\\n\\r]+'
        )
      ) {
        String trimmed = part.trim();
        if (String.isNotBlank(trimmed)) {
          result.add(trimmed.toLowerCase());
        }
      }
    }
    return result;
  }

  /**
   * @description Clear cached config (for testing)
   */
  @TestVisible
  private static void clearCache() {
    cachedConfig = null;
    testConfigExplicitlyNull = false;
  }

  /**
   * @description Set test config (for unit tests)
   * @param config Test configuration
   */
  @TestVisible
  private static void setTestConfig(qual_Config__mdt config) {
    testConfig = config;
    testMetadataConfigs = null;
    testConfigExplicitlyNull = (config == null);
  }

  /**
   * @description Set test metadata configs for selector query tests
   * @param configs Candidate custom metadata records
   */
  @TestVisible
  private static void setTestMetadataConfigs(List<qual_Config__mdt> configs) {
    testConfig = null;
    testMetadataConfigs = configs;
    testConfigExplicitlyNull = false;
  }

  /**
   * @description Set test integration settings (for unit tests)
   * @param settings Test settings
   */
  @TestVisible
  private static void setTestSettings(qual_Integration_Settings__c settings) {
    testSettings = settings;
  }
}