/**
 * @description Parses Qualtrics API responses
 * @author Qualtrics Integration Team
 */
public with sharing class QualResponseParser {
    
    /**
     * @description Parsed response wrapper
     */
    public class ParsedResponse {
        public Boolean isSuccess { get; set; }
        public Integer statusCode { get; set; }
        public String requestId { get; set; }
        public String eventId { get; set; }
        public String errorMessage { get; set; }
        public String errorCode { get; set; }
        public Boolean isRateLimited { get; set; }
        public Integer retryAfterSeconds { get; set; }

        public ParsedResponse() {
            this.isSuccess = false;
            this.isRateLimited = false;
        }
    }
    
    /**
     * @description Parse HTTP response from Qualtrics
     * @param response HTTP response
     * @return Parsed response object
     */
    public static ParsedResponse parseResponse(HttpResponse response) {
        ParsedResponse parsed = new ParsedResponse();
        
        if (response == null) {
            parsed.errorMessage = 'Null response received';
            return parsed;
        }
        
        parsed.statusCode = response.getStatusCode();
        parsed.isSuccess = parsed.statusCode >= 200 && parsed.statusCode < 300;
        parsed.isRateLimited = parsed.statusCode == 429;
        
        // Parse rate limit headers
        if (parsed.isRateLimited) {
            String retryAfter = response.getHeader('Retry-After');
            if (String.isNotBlank(retryAfter)) {
                try {
                    parsed.retryAfterSeconds = Integer.valueOf(retryAfter);
                } catch (Exception e) {
                    parsed.retryAfterSeconds = 60; // Default
                }
            } else {
                // Check X-RateLimit-Reset header
                String resetSeconds = response.getHeader('X-RateLimit-Reset');
                if (String.isNotBlank(resetSeconds)) {
                    try {
                        parsed.retryAfterSeconds = Integer.valueOf(resetSeconds);
                    } catch (Exception e) {
                        parsed.retryAfterSeconds = 60;
                    }
                } else {
                    parsed.retryAfterSeconds = 60;
                }
            }
        }
        
        // Parse response body
        String body = response.getBody();
        if (String.isNotBlank(body)) {
            try {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(body);

                // Parse result section (contains eventId)
                if (responseMap.containsKey('result')) {
                    Map<String, Object> result = (Map<String, Object>)responseMap.get('result');
                    if (result.containsKey('eventId')) {
                        parsed.eventId = (String)result.get('eventId');
                    }
                }

                // Parse meta section
                if (responseMap.containsKey('meta')) {
                    Map<String, Object> meta = (Map<String, Object>)responseMap.get('meta');

                    if (meta.containsKey('requestId')) {
                        parsed.requestId = (String)meta.get('requestId');
                    }

                    // Parse error if present
                    if (meta.containsKey('error')) {
                        Map<String, Object> error = (Map<String, Object>)meta.get('error');
                        parsed.errorMessage = (String)error.get('errorMessage');
                        parsed.errorCode = (String)error.get('errorCode');
                    }
                }
            } catch (Exception e) {
                // Response body is not valid JSON
                parsed.errorMessage = 'Failed to parse response: ' + e.getMessage();
            }
        }
        
        return parsed;
    }
    
    /**
     * @description Check if error is retryable
     * @param parsed Parsed response
     * @return True if request should be retried
     */
    public static Boolean isRetryable(ParsedResponse parsed) {
        if (parsed == null) {
            return true; // Retry on null response
        }
        
        // Rate limited - always retry
        if (parsed.isRateLimited) {
            return true;
        }
        
        // Server errors (5xx) - retry
        if (parsed.statusCode >= 500 && parsed.statusCode < 600) {
            return true;
        }
        
        // Timeout or connection errors
        if (parsed.statusCode == 408 || parsed.statusCode == 504) {
            return true;
        }
        
        // Client errors (4xx except 429) - don't retry
        if (parsed.statusCode >= 400 && parsed.statusCode < 500) {
            return false;
        }
        
        return false;
    }
}