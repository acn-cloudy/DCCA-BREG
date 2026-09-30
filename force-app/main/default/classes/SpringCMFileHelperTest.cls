@isTest
private class SpringCMFileHelperTest {

    // Test for URLParser.parseUrl method
    @isTest static void testParseUrl() {
        SpringCMFileHelper.URLParser parser = new SpringCMFileHelper.URLParser();
        String originalUrl = 'https://example.com/Id=123';

        // Call the method
        String result = parser.parseUrl(originalUrl);

        // Verify the result
        String expectedUrl = 'https://apidownloadexample.com/v201411/documents/123';
        System.assertEquals(expectedUrl, result, 'The URL was not parsed correctly.');
    }

    // Test for URLParser.extractBaseDomain method
    // This method is private, so typically it's tested indirectly through the public methods that use it.
    // However, if you want to test it directly, you can use the @TestVisible annotation or reflection.

    // Test for URLParser.extractParameter method
    // Similar to extractBaseDomain, this is a private method and is typically tested indirectly.

    // Test for saveFileAndSendEmail method
    @isTest static void testSaveFileAndSendEmail() {
        // Set up test data
        String recordId = '001xxxxxxx';
        String email = 'test@example.com';
        String docUrl = 'https://example.com/Id=123';
        String subject = 'Test Subject';

        // Mock HTTP callout response
        Test.setMock(HttpCalloutMock.class, new MyHttpCalloutMock());

        // Call the method in a test context
        Test.startTest();
        SpringCMFileHelper.saveFileAndSendEmail(recordId, email, docUrl, subject);
        Test.stopTest();

        // Assertions to verify the behavior
        // Check if the email was sent, if the Notification__c record was updated, etc.
    }

    // Mock class for HTTP callouts
    private class MyHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('Fake PDF Content'));
            res.setStatusCode(200);
            return res;
        }
    }

    // Test for sendEmail method
    @isTest static void testSendEmail() {
        // Set up test data
        String email = 'test@example.com';
        String subject = 'Test Subject';
        Blob file = Blob.valueOf('Test PDF Content');
        String fileName = 'TestFile.pdf';

        // Call the method
        Test.startTest();
        SpringCMFileHelper.sendEmail(email, subject, fileName, file);
        Test.stopTest();

        // Assertions to verify the behavior
        // Check if the email was sent correctly
    }
}