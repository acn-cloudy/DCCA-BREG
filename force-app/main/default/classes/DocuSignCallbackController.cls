public class DocuSignCallbackController {
    public String code { get; private set; }
    public String error { get; private set; }
    public String message { get; private set; }
    private Boolean processed { get; set; }
    
    public DocuSignCallbackController() {
        code = ApexPages.currentPage().getParameters().get('code');
        error = ApexPages.currentPage().getParameters().get('error');
        processed = false;
    }
    
    public PageReference init() {
        if (!processed && String.isNotBlank(code)) {
            handleCallback();
            processed = true;
        }
        return null;
    }
    
    private void handleCallback() {
        try {
            SpringCLMSetting__mdt settings = SpringCMApiEnvironment.getApiEnvironment();
            String clientId = settings.Client_Id__c;
            String clientSecret = settings.Client_Secret__c;
            String tokenEndpoint = settings.AuthEndpoint__c;
            
            // Get the VF page domain for redirect_uri
            String vfDomain = URL.getSalesforceBaseUrl().toExternalForm();
            String redirectUri = vfDomain + '/apex/docucallback';
            
            // Prepare token request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            // Set request body
            String body = 'grant_type=authorization_code' +
                '&code=' + code +
                '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
                '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8');
            req.setBody(body);
            
            // Send request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse response
                Map<String, Object> tokenResponse = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                String accessToken = (String)tokenResponse.get('access_token');
                String refreshToken = (String)tokenResponse.get('refresh_token');
                Integer expiresIn = (Integer)tokenResponse.get('expires_in');
                
                // Store tokens using SpringCMConnector
                SpringCMConnector.cacheSession(accessToken, refreshToken, expiresIn);
                SpringCMConnector.saveToken();
                
                message = 'Authorization successful! You can close this window.';
            } else {
                message = 'Error getting access token: ' + res.getBody();
            }
        } catch (Exception e) {
            message = 'Error: ' + e.getMessage();
        }
    }
}