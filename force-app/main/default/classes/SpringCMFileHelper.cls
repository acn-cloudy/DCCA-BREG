public class SpringCMFileHelper {
    public class URLParser {
        // Method to parse the URL and return the new format
        public String parseUrl(String originalUrl) {
            // Extract the base domain and construct the new URL base dynamically
            String newUrlBase = 'https://' + extractBaseDomain(originalUrl) + '/v201411/documents/';
    
            // Extract the parameters from the original URL
            String id = extractParameter(originalUrl, 'Id=');
    
            // Construct and return the new URL
            return newUrlBase + id;
        }
    
        // Helper method to extract the base domain from the URL
        private String extractBaseDomain(String url) {
            Pattern domainPattern = Pattern.compile('https://([^/]+)');
            Matcher matcher = domainPattern.matcher(url);
            if (matcher.find()) {
                return 'apidownload' + matcher.group(1);
            }
            return null;
        }
    
        // Helper method to extract parameter values from the URL
        private String extractParameter(String url, String paramName) {
            Integer start = url.indexOf(paramName);
            if (start == -1) {
                return '';
            }
            start += paramName.length();
            Integer endStr = url.indexOf('&', start);
            endStr = (endStr == -1) ? url.length() : endStr;
            return url.substring(start, endStr);
        }
    }
    @future(callout=true)
    public static void saveFileAndSendEmail(String recordId, String email, String docUrl, String subject) {
        String fileName = subject + '.pdf';
        String token = SpringCMConnector.getAccessToken();
        HttpRequest req1= new HttpRequest();
        req1.setHeader('Authorization','bearer '+token);
        req1.setHeader('Content-Type', 'application/json');
        req1.setHeader('Accept', 'application/pdf');
        req1.setEndpoint((new SpringCMFileHelper.URLParser()).parseUrl(docUrl));
        req1.setMethod('GET');
        Http h = new Http();
        HttpResponse res = h.send(req1);
        if(res.getStatusCode() == 200) {
            Blob b = res.getBodyAsBlob();
            sendEmail(email, subject, fileName, b);
        } else {
            String errorMessage = res.getBody();
            Notification__c record = new Notification__c();
            record.Content__c = errorMessage;
            record.Id = recordId;
            update record;
        }
    }
    public static void sendEmail(String email, String subject, String fileName, Blob file) {
        String htmlMsg = '<p>Please see attached file for deficiency letter.</p>';
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        OrgWideEmailAddress[] owea = [Select Id from OrgWideEmailAddress where DisplayName = 'DCCA No Reply'];
        if (owea.size() > 0) {
            semail.setOrgWideEmailAddressId(owea[0].Id);
        }
        semail.setSubject(subject);
        String[] sendTo = new String[]{email};
        semail.setToAddresses(sendTo);
        semail.setHtmlBody(htmlMsg);
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        // Attache the files
        efa.setFileName(fileName);
        efa.setBody(file);
        semail.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
    }
}