/**
 * @description Test class for QualResponseParser
 * @author Qualtrics Integration Team
 */
@IsTest
private class QualResponseParserTest {
    
    @IsTest
    static void testParseResponse_Success() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"result": {"eventId": "EVT_json_test123"}, "meta": {"httpStatus": "200 - OK", "requestId": "test-123"}}');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isSuccess, 'Should be success');
        System.assertEquals(200, parsed.statusCode, 'Status code should be 200');
        System.assertEquals('test-123', parsed.requestId, 'Request ID should match');
        System.assertEquals('EVT_json_test123', parsed.eventId, 'Event ID should match');
        System.assertEquals(false, parsed.isRateLimited, 'Should not be rate limited');
    }

    @IsTest
    static void testParseResponse_SuccessWithEventId() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(202);
        response.setBody('{"result": {"eventId": "EVT_json_ABC123xyz"}, "meta": {"httpStatus": "202 - Accepted", "requestId": "req-456"}}');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isSuccess, 'Should be success for 202');
        System.assertEquals(202, parsed.statusCode, 'Status code should be 202');
        System.assertEquals('req-456', parsed.requestId, 'Request ID should match');
        System.assertEquals('EVT_json_ABC123xyz', parsed.eventId, 'Event ID should be extracted from result');
    }
    
    @IsTest
    static void testParseResponse_RateLimit() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(429);
        response.setHeader('X-RateLimit-Reset', '60');
        response.setBody('{"meta": {"httpStatus": "429 - Too Many Requests", "error": {"errorMessage": "Rate limit exceeded", "errorCode": "RL_1"}}}');
        
        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();
        
        System.assertEquals(false, parsed.isSuccess, 'Should not be success');
        System.assertEquals(429, parsed.statusCode, 'Status code should be 429');
        System.assertEquals(true, parsed.isRateLimited, 'Should be rate limited');
        System.assertEquals(60, parsed.retryAfterSeconds, 'Retry after should be 60');
        System.assertEquals('Rate limit exceeded', parsed.errorMessage, 'Error message should match');
        System.assertEquals('RL_1', parsed.errorCode, 'Error code should match');
    }
    
    @IsTest
    static void testParseResponse_ServerError() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setBody('{"meta": {"httpStatus": "500 - Internal Server Error", "error": {"errorMessage": "Server error", "errorCode": "SE_1"}}}');
        
        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();
        
        System.assertEquals(false, parsed.isSuccess, 'Should not be success');
        System.assertEquals(500, parsed.statusCode, 'Status code should be 500');
        System.assertEquals('Server error', parsed.errorMessage, 'Error message should match');
    }
    
    @IsTest
    static void testParseResponse_NullResponse() {
        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(null);
        Test.stopTest();
        
        System.assertEquals(false, parsed.isSuccess, 'Should not be success');
        System.assertEquals('Null response received', parsed.errorMessage, 'Should have null response error');
    }
    
    @IsTest
    static void testParseResponse_InvalidJson() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('not valid json');
        
        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();
        
        System.assertEquals(true, parsed.isSuccess, 'Should be success based on status code');
        System.assert(parsed.errorMessage != null && parsed.errorMessage.contains('Failed to parse'), 'Should have parse error');
    }
    
    @IsTest
    static void testIsRetryable_RateLimit() {
        QualResponseParser.ParsedResponse parsed = new QualResponseParser.ParsedResponse();
        parsed.statusCode = 429;
        parsed.isRateLimited = true;
        
        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(parsed);
        Test.stopTest();
        
        System.assertEquals(true, isRetryable, 'Rate limited should be retryable');
    }
    
    @IsTest
    static void testIsRetryable_ServerError() {
        QualResponseParser.ParsedResponse parsed = new QualResponseParser.ParsedResponse();
        parsed.statusCode = 500;
        
        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(parsed);
        Test.stopTest();
        
        System.assertEquals(true, isRetryable, 'Server error should be retryable');
    }
    
    @IsTest
    static void testIsRetryable_ClientError() {
        QualResponseParser.ParsedResponse parsed = new QualResponseParser.ParsedResponse();
        parsed.statusCode = 400;
        
        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(parsed);
        Test.stopTest();
        
        System.assertEquals(false, isRetryable, 'Client error should not be retryable');
    }
    
    @IsTest
    static void testIsRetryable_Null() {
        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(null);
        Test.stopTest();

        System.assertEquals(true, isRetryable, 'Null should be retryable');
    }

    @IsTest
    static void testIsRetryable_Timeout408() {
        QualResponseParser.ParsedResponse parsed = new QualResponseParser.ParsedResponse();
        parsed.statusCode = 408;

        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(parsed);
        Test.stopTest();

        System.assertEquals(true, isRetryable, '408 Request Timeout should be retryable');
    }

    @IsTest
    static void testIsRetryable_GatewayTimeout504() {
        QualResponseParser.ParsedResponse parsed = new QualResponseParser.ParsedResponse();
        parsed.statusCode = 504;

        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(parsed);
        Test.stopTest();

        System.assertEquals(true, isRetryable, '504 Gateway Timeout should be retryable');
    }

    @IsTest
    static void testIsRetryable_Success2xx() {
        QualResponseParser.ParsedResponse parsed = new QualResponseParser.ParsedResponse();
        parsed.statusCode = 200;

        Test.startTest();
        Boolean isRetryable = QualResponseParser.isRetryable(parsed);
        Test.stopTest();

        System.assertEquals(false, isRetryable, '2xx success should not be retryable');
    }

    @IsTest
    static void testParseResponse_RateLimitWithRetryAfterHeader() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(429);
        response.setHeader('Retry-After', '120');
        response.setBody('{"meta": {"error": {"errorMessage": "Rate limit"}}}');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isRateLimited, 'Should be rate limited');
        System.assertEquals(120, parsed.retryAfterSeconds, 'Should use Retry-After header value');
    }

    @IsTest
    static void testParseResponse_RateLimitNonNumericRetryAfter() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(429);
        response.setHeader('Retry-After', 'not-a-number');
        response.setBody('{"meta": {"error": {"errorMessage": "Rate limit"}}}');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isRateLimited, 'Should be rate limited');
        System.assertEquals(60, parsed.retryAfterSeconds, 'Should default to 60 on non-numeric Retry-After');
    }

    @IsTest
    static void testParseResponse_RateLimitNoHeaders() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(429);
        response.setBody('{"meta": {"error": {"errorMessage": "Rate limit"}}}');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isRateLimited, 'Should be rate limited');
        System.assertEquals(60, parsed.retryAfterSeconds, 'Should default to 60 when no rate limit headers');
    }

    @IsTest
    static void testParseResponse_BodyWithNoMetaOrResult() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"status": "ok"}');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isSuccess, 'Should be success based on status code');
        System.assertEquals(null, parsed.requestId, 'Request ID should be null when no meta section');
        System.assertEquals(null, parsed.eventId, 'Event ID should be null when no result section');
    }

    @IsTest
    static void testParseResponse_EmptyBody() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('');

        Test.startTest();
        QualResponseParser.ParsedResponse parsed = QualResponseParser.parseResponse(response);
        Test.stopTest();

        System.assertEquals(true, parsed.isSuccess, 'Should be success based on status code');
    }
}