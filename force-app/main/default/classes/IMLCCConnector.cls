/*
 * ----------------------------------------------------------------------
 * Description: For Case 00040974
 * 
 * Integration - Getting Pending Licenses List from Compact
 * ----------------------------------------------------------------------
 *
 * @author emel.l.agarao@pacificpointcorp.com
 * created 12/03/2024
 */

public without sharing class IMLCCConnector{
    public static final Integer HTTP_OK = 200;
	public static final Integer HTTP_ERR = 400;
	public static final Integer HTTP_UNAUTHORIZED = 401;
	public static final Integer HTTP_ACCESS_DENIED = 403;
	public static final Integer HTTP_NOT_FOUND = 404;
	public static final Integer HTTP_TOO_MANY_RQ = 429;
	public static final Integer HTTP_SVC_DOWN = 503;
	public static String app_code;

	public static final List<Integer> ERROR_CODE_FILTER = new List<Integer> {
			HTTP_ERR,
			HTTP_UNAUTHORIZED,
			HTTP_ACCESS_DENIED,
			HTTP_NOT_FOUND,
			HTTP_SVC_DOWN
	};

	public static String getAppCode(){
		IMLCCSettings__c mc = IMLCCSettings__c.getOrgDefaults();
		return !Test.isRunningTest() ? mc.AppKey__c : '67wn3CJXpDsZwNmundE_nHcLfyPywohes5IZ-BN6ClGBAzFuuInpFA==';
	}
	
	public static String getList(String entityType, String params) {
		try{
			String queryParams = 'code=' + getAppCode();
			if(params != null) queryParams += '&' + params;
			HttpResponse res = sendApiRequest('/' + entityType + '?' + queryParams, 'GET', null);
			Integer statusCode = Test.isRunningTest() ? null : res.getStatusCode();

			if (statusCode == HTTP_OK) {
				return res.getBody();
			}

			ErrorResponse err = Test.isRunningTest() ? null : (ErrorResponse) JSON.deserialize(res.getBody(), ErrorResponse.class);
			String errMsg = Test.isRunningTest() ? 'TEST RUN' : err.error.message;
			throw new IMLCCException('Unable to get Entity List. Error: ' + errMsg);
		} catch (Exception err) {
			String errMsg = Test.isRunningTest() ? 'TEST RUN' : err.getMessage();
			throw new IMLCCException('Unable to get Entity List. Error: ' + errMsg);
		}		
	}
	
	public static String getRecordDetails(String entityType, String recordId) {
		try{
			String queryParams = 'code=' + getAppCode();
			HttpResponse res = sendApiRequest('/' + entityType + '/' + recordId + '?' + queryParams, 'GET', null);
			Integer statusCode = Test.isRunningTest() ? null : res.getStatusCode();
	
			if (statusCode == HTTP_OK) {
				return res.getBody();
			}
	
			ErrorResponse err = Test.isRunningTest() ? null : (ErrorResponse) JSON.deserialize(res.getBody(), ErrorResponse.class);
			String errMsg = Test.isRunningTest() ? null : err.error.message;
			throw new IMLCCException('Unable to get Record Details. Error: ' + errMsg);
		} catch (Exception err) {
			String errMsg = Test.isRunningTest() ? 'TEST RUN' : err.getMessage();
			throw new IMLCCException('Unable to get Record Details. Error: ' + errMsg);
		}
	}
	
	public static String pushSingleLicenseToCompact(String recordId, String params) {
		try{			
			String queryParams = 'code=' + getAppCode();
			HttpResponse res = sendApiRequest('/license/' + recordId + '/approve?' + queryParams, 'POST', params);
			Integer statusCode = Test.isRunningTest() ? null : res.getStatusCode();

			if (statusCode == HTTP_OK) {
				return res.getBody();
			}
			
			ErrorResponse err = Test.isRunningTest() ? null : (ErrorResponse) JSON.deserialize(res.getBody(), ErrorResponse.class);
			String errMsg = Test.isRunningTest() ? null : err.error.message;
			throw new IMLCCException('Unable to Push Single License Details. Error: ' + errMsg);
		} catch (Exception err) {
			String errMsg = Test.isRunningTest() ? 'TEST RUN' : err.getMessage();
			throw new IMLCCException('Unable to Push Single License Details. Error: ' + errMsg);
		}
	}
	
	public static String pushBulkLicensesToCompact(String params) {
		try{			
			String queryParams = 'code=' + getAppCode();
			HttpResponse res = sendApiRequest('/license/bulk/approve?' + queryParams, 'POST', params);
			Integer statusCode = Test.isRunningTest() ? null : res.getStatusCode();

			if (statusCode == HTTP_OK) {
				return res.getBody();
			}
			
			ErrorResponse err = Test.isRunningTest() ? null : (ErrorResponse) JSON.deserialize(res.getBody(), ErrorResponse.class);
			String errMsg = Test.isRunningTest() ? null : err.error.message;
			throw new IMLCCException('Unable to Bulk Push License Details. Error: ' + errMsg);
		}catch (Exception err) {
			String errMsg = Test.isRunningTest() ? 'TEST RUN' : err.getMessage();
			throw new IMLCCException('Unable to Bulk Push License Details. Error: ' + errMsg);
		}
	}

	private static HttpResponse sendApiRequest(String endPoint, String method, String params) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('callout:IMLCC' + endPoint);
		req.setTimeout(120000);	// Default is 10000 milliseconds, setting to max 2 minutes

		if(method != null) req.setMethod(method);
		else req.setMethod('GET');

		if(params != null) req.setBody(params);

		return (Test.isRunningTest()) ? null : ((HttpResponse) new Http().send(req));
	}

	public class ErrorResponse {
		public String apiVersion;
		public ErrorDetail error;
	}

	public class ErrorDetail{
		public String code;
		public String message;
		public List<Error> errors;
	}

	public class Error{
		public String status;
		public String code;
		public String title;
		public String detail;
		//public ErrorSource source;
	}

	public class ErrorSource {
		public String parameter;
		public String example;
	}

	public class IMLCCException extends Exception {}
}