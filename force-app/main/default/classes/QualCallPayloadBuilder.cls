/**
 * @description Builds the simplified Call/Session payload for the Qualtrics Call endpoint.
 */
public with sharing class QualCallPayloadBuilder {
  public static String buildCallPayload(
    UJET__UJET_Session__c session,
    Object callJson,
    qual_Config__mdt config
  ) {
    Map<String, Object> payload = buildCallPayloadMap(session, callJson, config);
    String jsonPayload = JSON.serialize(payload);
    return enforcePayloadSize(jsonPayload, config);
  }

  @TestVisible
  private static Map<String, Object> buildCallPayloadMap(
    UJET__UJET_Session__c session,
    Object callJson,
    qual_Config__mdt config
  ) {
    Map<String, Object> callData = new Map<String, Object>();
    if (callJson instanceof Map<String, Object>) {
      callData.putAll(copyScalarsAndObjects((Map<String, Object>) callJson));
    }

    Object jsonCallId = callData.get('id');
    if (
      jsonCallId == null &&
      session != null &&
      session.UJET__Call_Id__c != null
    ) {
      callData.put('id', session.UJET__Call_Id__c.longValue());
    }

    Decimal acwDuration = extractAcwDuration(callJson);
    if (acwDuration != null) {
      callData.put('acw_duration', acwDuration);
    }

    callData.put('session', buildSessionMap(session));

    Map<String, Object> caseData = new Map<String, Object>();
    if (session != null && session.UJET__Case__r != null) {
      caseData.put('caseNumber', session.UJET__Case__r.CaseNumber);
    }

    return new Map<String, Object>{
      'call' => callData,
      'case' => caseData,
      'contact' => buildContactMap(session),
      'metadata' => buildMetadataMap(config)
    };
  }

  /**
   * @description Resolves the Salesforce Contact for the call. The session's own
   * Contact wins; the linked Case's Contact is the fallback. The key is always
   * present, carrying null when neither source has a Contact, so the Call payload
   * matches the Case payload's nullable contract.
   */
  private static Map<String, Object> buildContactMap(
    UJET__UJET_Session__c session
  ) {
    Map<String, Object> contactData = new Map<String, Object>{
      'salesforceContactId' => null
    };

    if (session == null) {
      return contactData;
    }

    if (session.UJET__Contact__c != null) {
      contactData.put('salesforceContactId', session.UJET__Contact__c);
      return contactData;
    }

    if (
      session.UJET__Case__r != null &&
      session.UJET__Case__r.ContactId != null
    ) {
      contactData.put('salesforceContactId', session.UJET__Case__r.ContactId);
    }

    return contactData;
  }

  private static Map<String, Object> buildMetadataMap(qual_Config__mdt config) {
    return new Map<String, Object>{
      'salesforceOrgId' => UserInfo.getOrganizationId(),
      'integrationTimestamp' => Datetime.now()
        .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
      'payloadVersion' => config != null
        ? config.qual_Payload_Version__c
        : '1.0',
      'isTestContact' => config != null &&
        config.qual_Is_Test_Contact__c == true
    };
  }

  private static Map<String, Object> buildSessionMap(
    UJET__UJET_Session__c session
  ) {
    Map<String, Object> sessionData = new Map<String, Object>{
      'callDurationSeconds' => null,
      'holdDurationSeconds' => null,
      'waitDurationSeconds' => null,
      'abandonedCall' => null,
      'speedToAnswerSeconds' => null
    };

    if (session == null) {
      return sessionData;
    }

    if (session.UJET__Call_Duration__c != null) {
      sessionData.put(
        'callDurationSeconds',
        session.UJET__Call_Duration__c.intValue()
      );
    }
    if (session.UJET__Hold_Duration__c != null) {
      sessionData.put(
        'holdDurationSeconds',
        session.UJET__Hold_Duration__c.intValue()
      );
    }
    if (session.UJET__Wait_Duration__c != null) {
      sessionData.put(
        'waitDurationSeconds',
        session.UJET__Wait_Duration__c.intValue()
      );
    }

    Boolean abandoned = session.UJET__Fail_Reason__c == 'eu_abandoned';
    sessionData.put('abandonedCall', abandoned);

    if (
      session.UJET__Status__c == 'finished' &&
      session.UJET__Wait_Duration__c != null
    ) {
      sessionData.put(
        'speedToAnswerSeconds',
        session.UJET__Wait_Duration__c.intValue()
      );
    }

    return sessionData;
  }

  private static Map<String, Object> copyScalarsAndObjects(
    Map<String, Object> source
  ) {
    Map<String, Object> result = new Map<String, Object>();
    if (source == null) {
      return result;
    }

    for (String key : source.keySet()) {
      Object value = source.get(key);
      if (value instanceof List<Object>) {
        continue;
      }
      if (value instanceof Map<String, Object>) {
        result.put(key, copyScalarsAndObjects((Map<String, Object>) value));
      } else {
        result.put(key, value);
      }
    }
    return result;
  }

  @TestVisible
  private static Decimal extractAcwDuration(Object callJson) {
    if (!(callJson instanceof Map<String, Object>)) {
      return null;
    }

    Map<String, Object> callMap = (Map<String, Object>) callJson;
    Object handleDurations = callMap.get('handle_durations');
    if (!(handleDurations instanceof List<Object>)) {
      return null;
    }

    Decimal total = 0;
    Boolean found = false;
    for (Object entry : (List<Object>) handleDurations) {
      if (!(entry instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> durationEntry = (Map<String, Object>) entry;
      if (
        !durationEntry.containsKey('acw_duration') ||
        durationEntry.get('acw_duration') == null
      ) {
        continue;
      }

      Decimal value = parseDecimal(durationEntry.get('acw_duration'));
      if (value != null) {
        total += value;
        found = true;
      }
    }

    return found ? total : null;
  }

  private static Decimal parseDecimal(Object value) {
    if (value == null) {
      return null;
    }
    try {
      return Decimal.valueOf(String.valueOf(value));
    } catch (Exception ex) {
      return null;
    }
  }

  public static String getCallIdAsString(
    UJET__UJET_Session__c session,
    Object callJson
  ) {
    if (callJson instanceof Map<String, Object>) {
      Object jsonCallId = ((Map<String, Object>) callJson).get('id');
      if (jsonCallId != null) {
        return String.valueOf(jsonCallId);
      }
    }
    if (session != null && session.UJET__Call_Id__c != null) {
      return String.valueOf(session.UJET__Call_Id__c.longValue());
    }
    return null;
  }

  private static String enforcePayloadSize(
    String jsonPayload,
    qual_Config__mdt config
  ) {
    Integer maxSize = config != null &&
      config.qual_Max_Payload_Size_KB__c != null
      ? Integer.valueOf(config.qual_Max_Payload_Size_KB__c) * 1024
      : 102400;

    Integer payloadBytes = Blob.valueOf(jsonPayload).size();
    if (payloadBytes <= maxSize) {
      return jsonPayload;
    }

    throw new QualCalloutService.QualCalloutException(
      'Call payload size ' +
        payloadBytes +
        ' bytes exceeds configured maximum of ' +
        maxSize +
        ' bytes'
    );
  }

  public static Integer getPayloadSizeBytes(String jsonPayload) {
    if (String.isBlank(jsonPayload)) {
      return 0;
    }
    return Blob.valueOf(jsonPayload).size();
  }
}