public class DocuSignAuthController {
    public static String generateAuthUrl() {
        SpringCLMSetting__mdt settings = SpringCMApiEnvironment.getApiEnvironment();
        String clientId = settings.Client_Id__c;
        String authURL = settings.AuthEndpoint__c;
        authURL = authUrl.replace('token', 'auth');
        // Get the VF page domain dynamically
        String vfDomain = URL.getSalesforceBaseUrl().toExternalForm();
        String callbackUrl = vfDomain + '/apex/docucallback';
        
        // Construct authorization URL
        authUrl = authURL  + 
            '?response_type=code' +
            '&scope=' + EncodingUtil.urlEncode('impersonation signature spring_read spring_write', 'UTF-8') +
            '&client_id=' + clientId +
            '&redirect_uri=' + EncodingUtil.urlEncode(callbackUrl, 'UTF-8');
            
        return authUrl;
    }
}