public with sharing class BREGAmazonSesEmailService {
    static final String namedCredential = 'callout:Amazon_SES';
    static final BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();

    @TestVisible
    private static Boolean mockMode = false;

    public class EmailWrapper {
        public List<String> to { get; set; }
        public List<String> cc { get; set; }
        public List<String> bcc { get; set; }
        public Map<String, Object> replacementData { get; set; }
        public Id whoId { get; set; }
        public Id whatId { get; set; }

        public EmailWrapper() {
            this.to = new List<String>();
            this.cc = new List<String>();
            this.bcc = new List<String>();
        }
    }

    public class EmailResponse {
        public String Status;
        public String Error;
        //public String MessageId;
    }

    public static HttpResponse sendBulkTemplatedEmail(String templateName, List<EmailWrapper> destinations) {
        // Explicit mock mode is used by tests that do not register an HttpCalloutMock.
        if (mockMode) {
            HttpResponse mockResponse = new HttpResponse();
            mockResponse.setStatusCode(200);
            mockResponse.setStatus('OK');
            mockResponse.setHeader('Content-Type', 'application/json');

            // Create successful mock response matching the expected format
            List<EmailResponse> mockResults = new List<EmailResponse>();
            for (EmailWrapper wrapper : destinations) {
                EmailResponse mockResult = new EmailResponse();
                mockResult.Status = 'Success';
                mockResult.Error = null;
                mockResults.add(mockResult);
            }

            BulkEmailResponse bulkResponse = new BulkEmailResponse();
            bulkResponse.BulkEmailEntryResults = mockResults;
            mockResponse.setBody(JSON.serialize(bulkResponse));

            return mockResponse;
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint(namedCredential + '/v2/email/outbound-bulk-emails');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000); // 2 minutes

        String body = buildSesPayload(templateName, destinations);
        req.setBody(body);

        return http.send(req);
    }

    @TestVisible
    private static String buildSesPayload(String templateName, List<EmailWrapper> destinations) {
        BulkEmailRequest bulkEmailRequest = new BulkEmailRequest();
        bulkEmailRequest.FromEmailAddress = setting?.Send_Emails_Org_Wide_Address__c;
        bulkEmailRequest.BulkEmailEntries = new List<BulkEmailEntry>();
        for (EmailWrapper wrapper : destinations) {
            BulkEmailEntry entry = new BulkEmailEntry();
            SESDestination destination = new SESDestination();
            destination.ToAddresses = wrapper.to;
            destination.CcAddresses = wrapper.cc;
            destination.BccAddresses = wrapper.bcc;
            entry.Destination = destination;
            ReplacementEmailContent replacementContent = new ReplacementEmailContent();
            ReplacementTemplate replacementTemplate = new ReplacementTemplate();

            replacementTemplate.ReplacementTemplateData = JSON.serialize(wrapper.replacementData);
            replacementContent.ReplacementTemplate = replacementTemplate;
            entry.ReplacementEmailContent = replacementContent;
            bulkEmailRequest.BulkEmailEntries.add(entry);
        }
        bulkEmailRequest.DefaultContent = new BulkEmailContent();
        SESTemplate sesTemplate = new SESTemplate();
        sesTemplate.TemplateName = templateName;

        // Add DefaultTemplateData parameter with the specified default values
        Map<String, String> defaultTemplateData = new Map<String, String>{
        };
        String defaultTemplateDataJson = JSON.serialize(defaultTemplateData);

        sesTemplate.TemplateData = defaultTemplateDataJson;
        bulkEmailRequest.DefaultContent.Template = sesTemplate;

        return JSON.serialize(bulkEmailRequest);
    }

    public static List<String> parseEmails(String input) {
        List<String> result = new List<String>();
        if (String.isNotBlank(input)) {
            for (String e : input.split(';')) {
                if (String.isNotBlank(e)) {
                    result.add(e.trim());
                }
            }
        }
        return result;
    }

    /**
     * Parses Amazon SES SendBulkTemplatedEmail response
     * and returns a list of EmailResponse objects.
     */
    public static List<EmailResponse> parseResponse(String responseBoby) {
        List<EmailResponse> responses = new List<EmailResponse>();

        if (String.isBlank(responseBoby)) {
            System.debug('Empty response body.');
            return responses;
        }

        BulkEmailResponse bulkResponse = (BulkEmailResponse) JSON.deserialize(responseBoby, BulkEmailResponse.class);
        return bulkResponse.BulkEmailEntryResults;
    }

    public class BulkEmailRequest {
        public List<BulkEmailEntry> BulkEmailEntries { get; set; }
        public BulkEmailContent DefaultContent { get; set; }
        public String FromEmailAddress { get; set; }
    }

    public class BulkEmailEntry {
        public SESDestination Destination { get; set; }
        public ReplacementEmailContent ReplacementEmailContent { get; set; }
    }

    public class ReplacementEmailContent {
        public ReplacementTemplate ReplacementTemplate { get; set; }
    }

    public class ReplacementTemplate {
        public String ReplacementTemplateData { get; set; }
    }

    public class BulkEmailContent {
        public SESTemplate Template { get; set; }
    }

    public class SESTemplate {
        public String TemplateName { get; set; }
        public String TemplateData { get; set; }
    }

    public class SESDestination {
        public List<String> ToAddresses { get; set; }
        public List<String> CcAddresses { get; set; }
        public List<String> BccAddresses { get; set; }
    }

    public class BulkEmailResponse {
        public List<EmailResponse> BulkEmailEntryResults { get; set; }
    }
}

/**
 * // Amazon SES endpoint for API v2 - adjust the region if needed (e.g., us-east-1)
        String endpoint = '/v2/email/templates';

        // Request body for the CreateEmailTemplate API
        Map<String, Object> payload = new Map<String, Object>{
            'TemplateName' => 'BREG_Template_Test',
            'TemplateContent' => new Map<String, Object>{
                'Subject' => '{{subject}}!',
                'Text'    => 'This is a plain text test template',
                'Html'    => '<h1>Dear {{name}}</h1><p>{{body}}</p>'
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Amazon_SES' + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res;

        try {
            res = http.send(req);
            if (res.getStatusCode() == 200) {
                System.debug('Template created successfully: ' + res.getBody());
            } else {
                System.debug('Error creating template. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
        }
 */