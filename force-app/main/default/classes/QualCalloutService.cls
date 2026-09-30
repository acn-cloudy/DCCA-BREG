/**
 * @description HTTP callout service for Qualtrics API
 * @author Qualtrics Integration Team
 */
public with sharing class QualCalloutService {
  public static final String PAYLOAD_TYPE_CASE = 'Case';
  public static final String PAYLOAD_TYPE_CALL = 'Call';

  private static final String CONTENT_TYPE = 'application/json';
  private static final String API_TOKEN_HEADER = 'X-API-TOKEN';
  // Qualtrics Inbound Event endpoint - appended to Named Credential base URL
  private static final String WORKFLOW_ENDPOINT_TEMPLATE = '/events/json/triggers?urlTokenId={0}';

  /**
   * @description Send payload to Qualtrics workflow endpoint
   * @param jsonPayload JSON payload to send
   * @param config Configuration settings
   * @return HTTP response
   */
  public static HttpResponse postToWorkflow(
    String jsonPayload,
    qual_Config__mdt config
  ) {
    return postToWorkflow(jsonPayload, config, PAYLOAD_TYPE_CASE);
  }

  /**
   * @description Send payload to a specific Qualtrics workflow endpoint.
   * @param jsonPayload JSON payload to send
   * @param config Configuration settings
   * @param payloadType Case or Call
   * @return HTTP response
   */
  public static HttpResponse postToWorkflow(
    String jsonPayload,
    qual_Config__mdt config,
    String payloadType
  ) {
    if (config == null) {
      throw new QualCalloutException('Configuration is required');
    }

    String endpoint = buildEndpoint(config, payloadType);
    Integer timeout = config.qual_Timeout_Seconds__c != null
      ? Integer.valueOf(config.qual_Timeout_Seconds__c) * 1000
      : 30000;

    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod('POST');
    req.setHeader('Content-Type', CONTENT_TYPE);

    // Add API token header if configured (optional for inbound-event endpoints)
    String apiToken = QualConfigSelector.getApiToken();
    if (String.isNotBlank(apiToken)) {
      req.setHeader(API_TOKEN_HEADER, apiToken);
    }

    req.setBody(jsonPayload);
    req.setTimeout(timeout);

    Http http = new Http();
    return http.send(req);
  }

  /**
   * @description Build the full endpoint URL
   */
  private static String buildEndpoint(qual_Config__mdt config) {
    return buildEndpoint(config, PAYLOAD_TYPE_CASE);
  }

  /**
   * @description Build the full endpoint URL for a Case or Call payload.
   */
  private static String buildEndpoint(
    qual_Config__mdt config,
    String payloadType
  ) {
    String namedCredential = config.qual_Named_Credential__c;
    String workflowId = resolveWorkflowId(config, payloadType);
    if (String.isBlank(workflowId)) {
      throw new QualCalloutException(
        'Workflow ID is required for ' + payloadType + ' payloads'
      );
    }

    String workflowPath = String.format(
      WORKFLOW_ENDPOINT_TEMPLATE,
      new List<String>{ workflowId }
    );

    return 'callout:' + namedCredential + workflowPath;
  }

  private static String resolveWorkflowId(
    qual_Config__mdt config,
    String payloadType
  ) {
    if (
      payloadType == PAYLOAD_TYPE_CALL &&
      String.isNotBlank(config.qual_Call_Workflow_Id__c)
    ) {
      return config.qual_Call_Workflow_Id__c;
    }
    if (
      payloadType == PAYLOAD_TYPE_CASE &&
      String.isNotBlank(config.qual_Case_Workflow_Id__c)
    ) {
      return config.qual_Case_Workflow_Id__c;
    }
    return config.qual_Workflow_Id__c;
  }

  /**
   * @description Process a single Case + call combination and send to Qualtrics.
   * Each UJET call/session gets its own HTTP POST with duplicated case data.
   * @param caseRecord Case with related data
   * @param config Configuration settings
   * @param callData Single deserialized UJET call JSON object (may be null)
   * @return Callout result
   */
  public static CalloutResult processCaseCallout(
    Case caseRecord,
    qual_Config__mdt config,
    Object callData
  ) {
    CalloutResult result = new CalloutResult();
    result.caseId = caseRecord.Id;
    result.payloadType = PAYLOAD_TYPE_CASE;
    result.workflowId = config != null
      ? resolveWorkflowId(config, PAYLOAD_TYPE_CASE)
      : null;

    try {
      String jsonPayload = QualCasePayloadBuilder.buildCasePayload(
        caseRecord,
        config
      );
      result.requestBody = jsonPayload;
      result.payloadSize = QualCasePayloadBuilder.getPayloadSizeBytes(
        jsonPayload
      );

      // Make callout
      HttpResponse response = postToWorkflow(
        jsonPayload,
        config,
        PAYLOAD_TYPE_CASE
      );
      result.response = response;

      // Parse response
      QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
        response
      );
      result.isSuccess = parsed.isSuccess;
      result.isRetryable = QualResponseParser.isRetryable(parsed);
      result.errorMessage = parsed.errorMessage;
      result.requestId = parsed.requestId;
    } catch (QualCalloutException ex) {
      result.isSuccess = false;
      result.isRetryable = false;
      result.errorMessage = ex.getMessage();
      result.stackTrace = ex.getStackTraceString();
    } catch (Exception ex) {
      result.isSuccess = false;
      result.isRetryable = true;
      result.errorMessage = ex.getMessage();
      result.stackTrace = ex.getStackTraceString();
    }

    return result;
  }

  /**
   * @description Process a Case without call data (backward-compatible overload).
   * @param caseRecord Case with related data
   * @param config Configuration settings
   * @return Callout result
   */
  public static CalloutResult processCaseCallout(
    Case caseRecord,
    qual_Config__mdt config
  ) {
    return processCaseCallout(caseRecord, config, null);
  }

  /**
   * @description Process a single UJET Session/Call and send it to the Call workflow endpoint.
   * @param session UJET Session with related Case data
   * @param config Configuration settings
   * @param callJson Deserialized UJET call JSON object, if a .json attachment is available
   * @return Callout result
   */
  public static CalloutResult processCallCallout(
    UJET__UJET_Session__c session,
    qual_Config__mdt config,
    Object callJson
  ) {
    CalloutResult result = new CalloutResult();
    result.caseId = session != null ? session.UJET__Case__c : null;
    result.sessionId = session != null ? session.Id : null;
    result.callId = QualCallPayloadBuilder.getCallIdAsString(session, callJson);
    result.payloadType = PAYLOAD_TYPE_CALL;
    result.workflowId = config != null
      ? resolveWorkflowId(config, PAYLOAD_TYPE_CALL)
      : null;

    try {
      if (callJson == null) {
        throw new QualCalloutException(
          'Required call JSON attachment not found for UJET Session ' +
            result.sessionId +
            ' and Call ID ' +
            result.callId
        );
      }

      String jsonPayload = QualCallPayloadBuilder.buildCallPayload(
        session,
        callJson,
        config
      );
      result.requestBody = jsonPayload;
      result.payloadSize = QualCallPayloadBuilder.getPayloadSizeBytes(
        jsonPayload
      );

      HttpResponse response = postToWorkflow(
        jsonPayload,
        config,
        PAYLOAD_TYPE_CALL
      );
      result.response = response;

      QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(
        response
      );
      result.isSuccess = parsed.isSuccess;
      result.isRetryable = QualResponseParser.isRetryable(parsed);
      result.errorMessage = parsed.errorMessage;
      result.requestId = parsed.requestId;
    } catch (QualCalloutException ex) {
      result.isSuccess = false;
      result.isRetryable = false;
      result.errorMessage = ex.getMessage();
      result.stackTrace = ex.getStackTraceString();
    } catch (Exception ex) {
      result.isSuccess = false;
      result.isRetryable = true;
      result.errorMessage = ex.getMessage();
      result.stackTrace = ex.getStackTraceString();
    }

    return result;
  }

  /**
   * @description Result wrapper for callout operations
   */
  public class CalloutResult {
    public Id caseId { get; set; }
    public Id sessionId { get; set; }
    public String callId { get; set; }
    public String payloadType { get; set; }
    public String workflowId { get; set; }
    public String requestBody { get; set; }
    public Integer payloadSize { get; set; }
    public HttpResponse response { get; set; }
    public Boolean isSuccess { get; set; }
    public Boolean isRetryable { get; set; }
    public String errorMessage { get; set; }
    public String stackTrace { get; set; }
    public String requestId { get; set; }

    public CalloutResult() {
      this.isSuccess = false;
      this.isRetryable = false;
    }
  }

  /**
   * @description Custom exception for callout errors
   */
  public class QualCalloutException extends Exception {
  }
}