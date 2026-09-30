@isTest
private class DocuSignCallbackControllerTest {
    @TestSetup
    static void setupTestData() {
        // Create test SpringCLM_Session__c record if needed
        SpringCLM_Session__c session = new SpringCLM_Session__c();
        insert session;
    }
    
    @isTest
    static void testSuccessfulCallback() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));
        
        Test.startTest();
        
        // Set up the page parameters
        PageReference pageRef = Page.docucallback;
        pageRef.getParameters().put('code', 'test_auth_code');
        Test.setCurrentPage(pageRef);
        
        // Initialize controller
        DocuSignCallbackController controller = new DocuSignCallbackController();
        controller.init();
        
        Test.stopTest();
    }
    
    @isTest
    static void testErrorCallback() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));
        
        Test.startTest();
        
        // Set up the page parameters
        PageReference pageRef = Page.docucallback;
        pageRef.getParameters().put('code', 'invalid_code');
        Test.setCurrentPage(pageRef);
        
        // Initialize controller
        DocuSignCallbackController controller = new DocuSignCallbackController();
        controller.init();
        
        Test.stopTest();
        
        // Verify error handling
        System.assert(controller.message.contains('Error'), 'Error message should be displayed');
    }
    
    @isTest
    static void testErrorParameter() {
        Test.startTest();
        
        // Set up the page parameters with error
        PageReference pageRef = Page.docucallback;
        pageRef.getParameters().put('error', 'access_denied');
        Test.setCurrentPage(pageRef);
        
        // Initialize controller
        DocuSignCallbackController controller = new DocuSignCallbackController();
        
        Test.stopTest();
        
        // Verify error parameter is captured
        System.assertEquals('access_denied', controller.error, 'Error parameter should be captured');
    }
    
    // Mock HTTP response generator
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Boolean isSuccess;
        
        public MockHttpResponseGenerator(Boolean isSuccess) {
            this.isSuccess = isSuccess;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (isSuccess) {
                res.setBody('{"access_token":"mockToken","refresh_token":"mockRefresh","expires_in":3600}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"error":"invalid_grant","error_description":"Invalid authorization code"}');
                res.setStatusCode(400);
            }
            
            return res;
        }
    }
}