/**
 * @description Builds JSON payload from Case data for Qualtrics workflow
 * @author Qualtrics Integration Team
 */
public with sharing class QualCasePayloadBuilder {
  private static final Integer MAX_DESCRIPTION_LENGTH = 1000;
  private static final Integer MAX_SUBJECT_LENGTH = 255;

  // Static map to hold User data (Department, Manager) - populated by QualCalloutQueueable
  private static Map<Id, User> userDataMap = new Map<Id, User>();

  // Static map to hold UJET Call IDs per Case - populated by QualCalloutQueueable
  private static Map<Id, List<Long>> ujetCallIdMap = new Map<Id, List<Long>>();

  // Static map to hold voice call transcripts per Case - populated by QualCalloutQueueable
  private static Map<Id, String> voiceCallTranscriptMap = new Map<Id, String>();

  // Static map to hold UJET Session durations per Case - populated by QualCalloutQueueable
  private static Map<Id, UjetDurations> ujetDurationsMap = new Map<Id, UjetDurations>();

  // Static map to hold event type per Case - populated by QualCalloutQueueable
  private static Map<Id, String> eventTypeMap = new Map<Id, String>();

  // Static map to hold abandoned call flag per Case - populated by QualCalloutQueueable
  private static Map<Id, Boolean> abandonedCallMap = new Map<Id, Boolean>();

  // Static map to hold speed-to-answer (ASA) per Case - populated by QualCalloutQueueable
  private static Map<Id, Integer> speedToAnswerMap = new Map<Id, Integer>();

  // Static map to hold raw UJET call JSON objects per Case - populated by QualCalloutQueueable
  private static Map<Id, List<Object>> callJsonMap = new Map<Id, List<Object>>();

  /**
   * @description Wrapper class for UJET Session duration data
   */
  public class UjetDurations {
    public Integer callDurationSeconds { get; set; }
    public Integer holdDurationSeconds { get; set; }
    public Integer waitDurationSeconds { get; set; }

    public UjetDurations() {
      this.callDurationSeconds = 0;
      this.holdDurationSeconds = 0;
      this.waitDurationSeconds = 0;
    }
  }

  /**
   * @description Set User data map for enriching payload with Team/Supervisor info
   * @param userData Map of User Id to User record with Department and Manager info
   */
  public static void setUserDataMap(Map<Id, User> userData) {
    userDataMap = userData != null ? userData : new Map<Id, User>();
  }

  /**
   * @description Set UJET Call ID map for enriching payload with Call IDs from UJET Sessions
   * @param callIdData Map of Case Id to list of UJET Call IDs
   */
  public static void setUjetCallIdMap(Map<Id, List<Long>> callIdData) {
    ujetCallIdMap = callIdData != null ? callIdData : new Map<Id, List<Long>>();
  }

  /**
   * @description Set voice call transcript map for enriching payload with combined transcript text
   * @param transcriptData Map of Case Id to combined transcript string
   */
  public static void setVoiceCallTranscriptMap(Map<Id, String> transcriptData) {
    voiceCallTranscriptMap = transcriptData != null
      ? transcriptData
      : new Map<Id, String>();
  }

  /**
   * @description Set UJET durations map for enriching payload with call duration metrics
   * @param durationsData Map of Case Id to UjetDurations wrapper
   */
  public static void setUjetDurationsMap(Map<Id, UjetDurations> durationsData) {
    ujetDurationsMap = durationsData != null
      ? durationsData
      : new Map<Id, UjetDurations>();
  }

  /**
   * @description Set event type map for including lifecycle event type in payload
   * @param eventTypes Map of Case Id to event type string (Opened, Updated, Closed)
   */
  public static void setEventTypeMap(Map<Id, String> eventTypes) {
    eventTypeMap = eventTypes != null ? eventTypes : new Map<Id, String>();
  }

  /**
   * @description Set abandoned call map for enriching payload with UJET abandoned call data
   * @param data Map of Case Id to Boolean (true if any session was abandoned)
   */
  public static void setAbandonedCallMap(Map<Id, Boolean> data) {
    abandonedCallMap = data != null ? data : new Map<Id, Boolean>();
  }

  /**
   * @description Set speed-to-answer map for enriching payload with per-case ASA metric
   * @param data Map of Case Id to wait duration in seconds for the first answered session
   */
  public static void setSpeedToAnswerMap(Map<Id, Integer> data) {
    speedToAnswerMap = data != null ? data : new Map<Id, Integer>();
  }

  /**
   * @description Set raw UJET call JSON map for including full call data in payload
   * @param data Map of Case Id to list of deserialized JSON objects from Session file attachments
   */
  public static void setCallJsonMap(Map<Id, List<Object>> data) {
    callJsonMap = data != null ? data : new Map<Id, List<Object>>();
  }

  /**
   * @description Build the Case endpoint payload from a Case record.
   * The field shape matches the latest historical cases CSV export:
   * case/contact/agent/metadata roots only, with no embedded call object.
   * @param caseRecord Case with related Contact and Owner
   * @param config Configuration settings
   * @return JSON payload string
   */
  public static String buildCasePayload(
    Case caseRecord,
    qual_Config__mdt config
  ) {
    QualCasePayload payload = new QualCasePayload();

    // Populate case data
    populateCaseData(payload.caseData, caseRecord);

    // Populate contact data
    populateContactData(payload.contact, caseRecord, config);

    // Populate agent data
    populateAgentData(payload.agent, caseRecord);

    // Populate metadata
    populateMetadata(payload.metadata, caseRecord, config);

    // Generate JSON and enforce size
    String jsonPayload = payload.toJson();
    jsonPayload = enforcePayloadSize(jsonPayload, config);

    return jsonPayload;
  }

  /**
   * @description Backward-compatible alias for building the Case endpoint payload.
   * @param caseRecord Case with related Contact and Owner
   * @param config Configuration settings
   * @return JSON payload string
   */
  public static String buildPayload(Case caseRecord, qual_Config__mdt config) {
    return buildCasePayload(caseRecord, config);
  }

  /**
   * @description Deprecated overload retained for older tests/scripts. Call data is no longer embedded in Case payloads.
   */
  public static String buildPayload(
    Case caseRecord,
    qual_Config__mdt config,
    Object callData
  ) {
    return buildCasePayload(caseRecord, config);
  }

  /**
   * @description Get the list of call JSON objects for a Case from the pre-queried map.
   * Used by QualCalloutQueueable to iterate and build one payload per call.
   * @param caseId The Case ID
   * @return List of deserialized JSON objects, or empty list if none
   */
  public static List<Object> getCallJsonList(Id caseId) {
    if (caseId != null && callJsonMap.containsKey(caseId)) {
      return callJsonMap.get(caseId);
    }
    return new List<Object>();
  }

  /**
   * @description Populate case section of payload
   */
  private static void populateCaseData(
    QualCasePayload.CaseData caseData,
    Case caseRecord
  ) {
    caseData.caseNumber = caseRecord.CaseNumber;
    caseData.status = caseRecord.Status;
    caseData.priority = caseRecord.Priority;
    caseData.origin = caseRecord.Origin;

    Map<String, SObjectField> fieldMap = caseRecord.getSObjectType()
      .getDescribe()
      .fields.getMap();

    // Division Mapping
    if (fieldMap.containsKey('Incoming_Division__c')) {
      caseData.division = getOptionalString(caseRecord, 'Incoming_Division__c');
    } else if (fieldMap.containsKey('qual_Division__c')) {
      caseData.division = getOptionalString(caseRecord, 'qual_Division__c');
    }

    // Branch Mapping — INS_Branch_v2__c (label "Branch") is the reporting
    // source; fall through on blank values, not just missing fields, so an
    // existing-but-empty field never suppresses the fallbacks
    if (fieldMap.containsKey('INS_Branch_v2__c')) {
      caseData.branch = getOptionalString(caseRecord, 'INS_Branch_v2__c');
    }
    if (
      String.isBlank(caseData.branch) &&
      fieldMap.containsKey('Respondent_Branch__c')
    ) {
      caseData.branch = getOptionalString(caseRecord, 'Respondent_Branch__c');
    }
    if (
      String.isBlank(caseData.branch) &&
      fieldMap.containsKey('qual_Branch__c')
    ) {
      caseData.branch = getOptionalString(caseRecord, 'qual_Branch__c');
    }

    // Disposition Mapping
    if (fieldMap.containsKey('Disposition__c')) {
      caseData.disposition = getOptionalString(caseRecord, 'Disposition__c');
    } else if (fieldMap.containsKey('qual_Disposition__c')) {
      caseData.disposition = getOptionalString(
        caseRecord,
        'qual_Disposition__c'
      );
    }

    // Date fields in ISO-8601 format
    if (caseRecord.CreatedDate != null) {
      caseData.openDate = caseRecord.CreatedDate.formatGmt(
        'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
      );
    }
    if (caseRecord.ClosedDate != null) {
      caseData.closeDate = caseRecord.ClosedDate.formatGmt(
        'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
      );
    }

    // Calculate case time in seconds (time from case open to close)
    caseData.caseTimeSeconds = calculateCaseTime(caseRecord);

    // Populate UJET Call IDs from pre-queried data as integer array
    if (caseRecord.Id != null && ujetCallIdMap.containsKey(caseRecord.Id)) {
      caseData.callIds = ujetCallIdMap.get(caseRecord.Id);
    }

    // Populate UJET duration fields from pre-queried Session data
    if (caseRecord.Id != null && ujetDurationsMap.containsKey(caseRecord.Id)) {
      UjetDurations durations = ujetDurationsMap.get(caseRecord.Id);
      caseData.callDurationSeconds = durations.callDurationSeconds;
      caseData.holdDurationSeconds = durations.holdDurationSeconds;
      caseData.waitDurationSeconds = durations.waitDurationSeconds;
    }

    // Populate voice call transcript from pre-queried Session file data
    if (
      caseRecord.Id != null && voiceCallTranscriptMap.containsKey(caseRecord.Id)
    ) {
      caseData.voiceCallTranscript = voiceCallTranscriptMap.get(caseRecord.Id);
    }

    // Call Forwarding Division (Routed_to_Division__c with qual_ fallback)
    if (fieldMap.containsKey('Routed_to_Division__c')) {
      caseData.callForwardingDivision = getOptionalString(
        caseRecord,
        'Routed_to_Division__c'
      );
    } else if (fieldMap.containsKey('qual_Call_Forwarding_Division__c')) {
      caseData.callForwardingDivision = getOptionalString(
        caseRecord,
        'qual_Call_Forwarding_Division__c'
      );
    }

    if (fieldMap.containsKey('Auto_Close_Reason__c')) {
      caseData.autoCloseReason = getOptionalString(
        caseRecord,
        'Auto_Close_Reason__c'
      );
    }

    // Abandoned call flag from pre-queried UJET Session data
    if (caseRecord.Id != null && abandonedCallMap.containsKey(caseRecord.Id)) {
      caseData.abandonedCall = abandonedCallMap.get(caseRecord.Id);
    }

    // Speed to answer (ASA) from pre-queried UJET Session data
    if (caseRecord.Id != null && speedToAnswerMap.containsKey(caseRecord.Id)) {
      caseData.speedToAnswerSeconds = speedToAnswerMap.get(caseRecord.Id);
    }
  }

  /**
   * @description Calculate case time between open and close in seconds
   */
  private static Integer calculateCaseTime(Case caseRecord) {
    if (caseRecord.CreatedDate != null && caseRecord.ClosedDate != null) {
      Long openMillis = caseRecord.CreatedDate.getTime();
      Long closeMillis = caseRecord.ClosedDate.getTime();
      return Integer.valueOf((closeMillis - openMillis) / 1000);
    }

    return 0;
  }

  private static String getOptionalString(SObject record, String fieldName) {
    try {
      Object value = record.get(fieldName);
      return value != null ? String.valueOf(value) : null;
    } catch (SObjectException ex) {
      return null;
    }
  }

  /**
   * @description Populate contact section of payload
   */
  private static void populateContactData(
    QualCasePayload.ContactData contactData,
    Case caseRecord,
    qual_Config__mdt config
  ) {
    if (caseRecord.Contact != null) {
      contactData.firstName = caseRecord.Contact.FirstName;
      contactData.lastName = caseRecord.Contact.LastName;
      contactData.email = caseRecord.Contact.Email;
      contactData.salesforceContactId = caseRecord.ContactId;

      // Format phone to E.164
      String countryCode = config != null
        ? config.qual_Default_Country_Code__c
        : '1';
      contactData.phone = QualPhoneFormatter.formatToE164(
        caseRecord.Contact.Phone,
        countryCode
      );
    }
  }

  /**
   * @description Populate agent section of payload
   */
  private static void populateAgentData(
    QualCasePayload.AgentData agentData,
    Case caseRecord
  ) {
    agentData.agentId = caseRecord.OwnerId;

    // Get Owner name from Case relationship
    SObject owner = caseRecord.getSObject('Owner');
    if (owner != null) {
      agentData.agentName = (String) owner.get('Name');
    }

    // Get Team (qual_Team__c) and Supervisor (Manager) from pre-queried User data
    // This avoids issues with polymorphic Owner relationship
    if (
      caseRecord.OwnerId != null && userDataMap.containsKey(caseRecord.OwnerId)
    ) {
      User ownerUser = userDataMap.get(caseRecord.OwnerId);
      agentData.teamId = ownerUser.qual_Team__c;

      if (ownerUser.Manager != null) {
        agentData.supervisorName = ownerUser.Manager.Name;
      }
    }
  }

  /**
   * @description Populate metadata section of payload
   */
  private static void populateMetadata(
    QualCasePayload.MetadataInfo metadata,
    Case caseRecord,
    qual_Config__mdt config
  ) {
    metadata.salesforceCaseId = caseRecord.Id;
    metadata.salesforceOrgId = UserInfo.getOrganizationId();
    metadata.integrationTimestamp = Datetime.now()
      .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
    metadata.payloadVersion = config != null
      ? config.qual_Payload_Version__c
      : '1.0';
    metadata.isTestContact = config != null &&
      config.qual_Is_Test_Contact__c == true;

    // Include lifecycle event type if available
    if (caseRecord.Id != null && eventTypeMap.containsKey(caseRecord.Id)) {
      metadata.eventType = eventTypeMap.get(caseRecord.Id);
    } else {
      // Default to Closed for backward compatibility
      metadata.eventType = 'Closed';
    }
  }

  /**
   * @description Enforce configured payload size limit.
   */
  private static String enforcePayloadSize(
    String jsonPayload,
    qual_Config__mdt config
  ) {
    Integer maxSize = config != null &&
      config.qual_Max_Payload_Size_KB__c != null
      ? Integer.valueOf(config.qual_Max_Payload_Size_KB__c) * 1024
      : 102400;

    Integer payloadBytes = Blob.valueOf(jsonPayload).size();

    // If payload is within limits, return as-is
    if (payloadBytes <= maxSize) {
      return jsonPayload;
    }

    throw new QualCalloutService.QualCalloutException(
      'Case payload size ' +
        payloadBytes +
        ' bytes exceeds configured maximum of ' +
        maxSize +
        ' bytes'
    );
  }

  /**
   * @description Get payload size in bytes
   * @param jsonPayload JSON string
   * @return Size in bytes
   */
  public static Integer getPayloadSizeBytes(String jsonPayload) {
    if (String.isBlank(jsonPayload)) {
      return 0;
    }
    return Blob.valueOf(jsonPayload).size();
  }
}