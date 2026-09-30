@isTest
public with sharing class BREGAmazonSesEmailServiceTest {
    // Mock HTTP response class
    public class BREGAmazonSesMockHttpPositiveResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            BREGAmazonSesEmailService.BulkEmailRequest request = (BREGAmazonSesEmailService.BulkEmailRequest) JSON.deserialize(req.getBody(), BREGAmazonSesEmailService.BulkEmailRequest.class);
            Integer idx = request.BulkEmailEntries.size();
            // Create a successful response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            res.setStatusCode(200);
            res.setStatus('OK');

            // Return as JSON array (since the code expects a list)
            List<BREGAmazonSesEmailService.EmailResponse> responses = new List<BREGAmazonSesEmailService.EmailResponse>();

            for (Integer i = 1; i <= idx; i++) {
                // Create a successful BREGAmazonSesEmailResponse
                BREGAmazonSesEmailService.EmailResponse emailResponse = new BREGAmazonSesEmailService.EmailResponse();
                emailResponse.Status = 'Success';
                emailResponse.Error = null;
                //emailResponse.MessageId = 'test-message-id-' + System.currentTimeMillis();

                responses.add(emailResponse);
            }

            BREGAmazonSesEmailService.BulkEmailResponse bulkEmailResponse = new BREGAmazonSesEmailService.BulkEmailResponse();
            bulkEmailResponse.BulkEmailEntryResults = responses;

            res.setBody(JSON.serialize(bulkEmailResponse));
            return res;
        }
    }

    public class BREGAmazonSesMockHttpNegativeResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            BREGAmazonSesEmailService.BulkEmailRequest request = (BREGAmazonSesEmailService.BulkEmailRequest) JSON.deserialize(req.getBody(), BREGAmazonSesEmailService.BulkEmailRequest.class);
            Integer idx = request.BulkEmailEntries.size();

            // Create a successful response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            res.setStatusCode(401);

            List<BREGAmazonSesEmailService.EmailResponse> responses = new List<BREGAmazonSesEmailService.EmailResponse>();

            for (Integer i = 1; i <= idx; i++) {
                // Create a successful BREGAmazonSesEmailResponse
                BREGAmazonSesEmailService.EmailResponse emailResponse = new BREGAmazonSesEmailService.EmailResponse();
                emailResponse.Status = 'Failed';
                emailResponse.Error = 'Bad Request';
                responses.add(emailResponse);
            }

            BREGAmazonSesEmailService.BulkEmailResponse bulkEmailResponse = new BREGAmazonSesEmailService.BulkEmailResponse();
            bulkEmailResponse.BulkEmailEntryResults = responses;

            res.setBody(JSON.serialize(bulkEmailResponse));
            return res;
        }
    }


    @isTest
    static void testSendBulkTemplatedEmail_Positive() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesMockHttpPositiveResponse());

        List<BREGAmazonSesEmailService.EmailWrapper> destinations = new List<BREGAmazonSesEmailService.EmailWrapper>();
        BREGAmazonSesEmailService.EmailWrapper wrapper = new BREGAmazonSesEmailService.EmailWrapper();
        wrapper.to.add('to1@example.com');
        wrapper.cc.add('cc1@example.com');
        wrapper.bcc.add('bcc1@example.com');
        wrapper.replacementData = new Map<String, Object>{'name' => 'Test User'};
        destinations.add(wrapper);

        // Act
        Test.startTest();
        HttpResponse res = BREGAmazonSesEmailService.sendBulkTemplatedEmail('Email_Online_Annual_Reminders_Upcoming', destinations);
        Test.stopTest();

        // Parse the XML response using the BREGAmazonSesEmailService.parseResponse method
        List<BREGAmazonSesEmailService.EmailResponse> parsedResponses = BREGAmazonSesEmailService.parseResponse(res.getBody());
        // There should be one response in the list
        Assert.areEqual(1, parsedResponses.size(), 'Should return one response');
        BREGAmazonSesEmailService.EmailResponse parsedResp = parsedResponses[0];
        Assert.areEqual('Success', parsedResp.Status, 'Status should be Success');
        Assert.areEqual(null, parsedResp.Error, 'Error should be null');
    }

    @isTest
    static void testSendBulkTemplatedEmail_Negative() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new BREGAmazonSesMockHttpNegativeResponse());

        List<BREGAmazonSesEmailService.EmailWrapper> destinations = new List<BREGAmazonSesEmailService.EmailWrapper>();
        BREGAmazonSesEmailService.EmailWrapper wrapper = new BREGAmazonSesEmailService.EmailWrapper();
        wrapper.to.add('to2@example.com');
        wrapper.replacementData = new Map<String, Object>{'name' => 'Error User'};
        destinations.add(wrapper);

        // Act
        Test.startTest();
        HttpResponse res = BREGAmazonSesEmailService.sendBulkTemplatedEmail('Test', destinations);
        Test.stopTest();

        // Parse the XML response using the BREGAmazonSesEmailService.parseResponse method
        List<BREGAmazonSesEmailService.EmailResponse> parsedResponses = BREGAmazonSesEmailService.parseResponse(res.getBody());
        // There should be one response in the list
        Assert.areEqual(1, parsedResponses.size(), 'Should return one response');
        BREGAmazonSesEmailService.EmailResponse parsedResp = parsedResponses[0];
        Assert.areEqual('Failed', parsedResp.Status, 'Status should be Failed');
        Assert.areEqual('Bad Request', parsedResp.Error, 'Error should be Bad Request');
        // Assert
        // Assert.areEqual(401, res.getStatusCode(), 'Status code should be 401');
        // List<Object> responseList = (List<Object>) JSON.deserializeUntyped(res.getBody());
        // Assert.areEqual(1, responseList.size(), 'Should return one response');
        // Map<String, Object> resp = (Map<String, Object>) responseList[0];
        // Assert.areEqual('Bad Request', (String)resp.get('Error'), 'Error should be Bad Request');
        // Assert.isTrue(((String)resp.get('MessageId')).startsWith('test-message-id-'), 'MessageId should be present');
    }

    @isTest
    static void testBuildSesPayload_MultipleRecipientsAndReplacementData() {
        List<BREGAmazonSesEmailService.EmailWrapper> destinations = new List<BREGAmazonSesEmailService.EmailWrapper>();

        BREGAmazonSesEmailService.EmailWrapper w1 = new BREGAmazonSesEmailService.EmailWrapper();
        w1.to.addAll(new List<String>{'to1@example.com', 'to2@example.com'});
        w1.cc.add('cc1@example.com');
        w1.bcc.add('bcc1@example.com');
        w1.replacementData = new Map<String, Object>{'firstName' => 'Alice'};

        BREGAmazonSesEmailService.EmailWrapper w2 = new BREGAmazonSesEmailService.EmailWrapper();
        w2.to.add('to3@example.com');
        w2.replacementData = new Map<String, Object>{'firstName' => 'Bob'};

        destinations.add(w1);
        destinations.add(w2);

        // Use reflection to call private method
        String payload = BREGAmazonSesEmailService.buildSesPayload('Email_Online_Annual_Reminders_Upcoming', destinations);

        BREGAmazonSesEmailService.BulkEmailRequest request = (BREGAmazonSesEmailService.BulkEmailRequest) JSON.deserialize(payload, BREGAmazonSesEmailService.BulkEmailRequest.class);

        // Assert

        Assert.areEqual('Email_Online_Annual_Reminders_Upcoming', request.DefaultContent.Template.TemplateName, 'Payload should contain template name');
        Assert.areEqual(2, request.BulkEmailEntries.size(), 'Payload should contain 2 entries');
        Assert.areEqual('to2@example.com', request.BulkEmailEntries[0].Destination.ToAddresses[1], 'First entry should contain to2');
        Assert.isNotNull(request.BulkEmailEntries[0].ReplacementEmailContent.ReplacementTemplate.ReplacementTemplateData);
    }

    @isTest
    static void testParseEmails() {
        // Test with semicolon separated
        String input = 'a@example.com; b@example.com ;c@example.com;';
        List<String> result = BREGAmazonSesEmailService.parseEmails(input);
        Assert.areEqual(3, result.size(), 'Should parse 3 emails');
        Assert.areEqual('a@example.com', result[0]);
        Assert.areEqual('b@example.com', result[1]);
        Assert.areEqual('c@example.com', result[2]);

        // Test with empty and null
        Assert.areEqual(0, BREGAmazonSesEmailService.parseEmails(null).size(), 'Null input should return empty');
        Assert.areEqual(0, BREGAmazonSesEmailService.parseEmails('').size(), 'Blank input should return empty');

        // Test with only spaces and semicolons
        Assert.areEqual(0, BREGAmazonSesEmailService.parseEmails(' ; ; ').size(), 'Only delimiters should return empty');
    }

}