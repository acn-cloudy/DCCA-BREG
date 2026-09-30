/**
 * @description HTTP callout mock for Qualtrics API tests
 * @author Qualtrics Integration Team
 */
@IsTest
public class QualCalloutMock implements HttpCalloutMock {
    
    private Integer statusCode;
    private String responseBody;
    private Map<String, String> responseHeaders;
    
    /**
     * @description Constructor with status code and body
     * @param statusCode HTTP status code
     * @param responseBody Response body
     */
    public QualCalloutMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
        this.responseHeaders = new Map<String, String>();
    }
    
    /**
     * @description Constructor with headers
     * @param statusCode HTTP status code
     * @param responseBody Response body
     * @param headers Response headers
     */
    public QualCalloutMock(Integer statusCode, String responseBody, Map<String, String> headers) {
        this(statusCode, responseBody);
        this.responseHeaders = headers;
    }
    
    /**
     * @description Respond to HTTP request
     * @param req HTTP request
     * @return HTTP response
     */
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(responseBody);
        
        for (String header : responseHeaders.keySet()) {
            res.setHeader(header, responseHeaders.get(header));
        }
        
        return res;
    }
    
    // Factory methods for common scenarios
    
    /**
     * @description Create mock for successful response
     * @return Mock instance
     */
    public static QualCalloutMock createSuccessMock() {
        String body = JSON.serialize(new Map<String, Object>{
            'meta' => new Map<String, Object>{
                'httpStatus' => '200 - OK',
                'requestId' => 'test-request-id-123'
            }
        });
        return new QualCalloutMock(200, body);
    }
    
    /**
     * @description Create mock for rate limit response
     * @return Mock instance
     */
    public static QualCalloutMock createRateLimitMock() {
        String body = JSON.serialize(new Map<String, Object>{
            'meta' => new Map<String, Object>{
                'httpStatus' => '429 - Too Many Requests',
                'error' => new Map<String, Object>{
                    'errorMessage' => 'Rate limit exceeded',
                    'errorCode' => 'RL_1'
                },
                'requestId' => 'test-request-id-429'
            }
        });
        
        Map<String, String> headers = new Map<String, String>{
            'X-RateLimit-Limit' => '3000',
            'X-RateLimit-Remaining' => '0',
            'X-RateLimit-Reset' => '60'
        };
        
        return new QualCalloutMock(429, body, headers);
    }
    
    /**
     * @description Create mock for server error response
     * @return Mock instance
     */
    public static QualCalloutMock createServerErrorMock() {
        String body = JSON.serialize(new Map<String, Object>{
            'meta' => new Map<String, Object>{
                'httpStatus' => '500 - Internal Server Error',
                'error' => new Map<String, Object>{
                    'errorMessage' => 'Internal server error',
                    'errorCode' => 'SE_1'
                },
                'requestId' => 'test-request-id-500'
            }
        });
        return new QualCalloutMock(500, body);
    }
    
    /**
     * @description Create mock for not found response
     * @return Mock instance
     */
    public static QualCalloutMock createNotFoundMock() {
        String body = JSON.serialize(new Map<String, Object>{
            'meta' => new Map<String, Object>{
                'httpStatus' => '404 - Not Found',
                'error' => new Map<String, Object>{
                    'errorMessage' => 'Workflow not found',
                    'errorCode' => 'WF_1'
                },
                'requestId' => 'test-request-id-404'
            }
        });
        return new QualCalloutMock(404, body);
    }
    
    /**
     * @description Create mock for bad request response
     * @return Mock instance
     */
    public static QualCalloutMock createBadRequestMock() {
        String body = JSON.serialize(new Map<String, Object>{
            'meta' => new Map<String, Object>{
                'httpStatus' => '400 - Bad Request',
                'error' => new Map<String, Object>{
                    'errorMessage' => 'Invalid JSON payload',
                    'errorCode' => 'RP_9'
                },
                'requestId' => 'test-request-id-400'
            }
        });
        return new QualCalloutMock(400, body);
    }
}