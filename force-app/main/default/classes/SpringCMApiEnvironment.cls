public class SpringCMApiEnvironment {
    public static String getEnvironmentPrefix() {
        String environmentPrefix = '';
        String hostname = URL.getOrgDomainURL().toExternalForm();
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
        if (hostname.contains('sandbox')) {
            environmentPrefix = 'UAT';
        } else if (org.IsSandbox) {
            environmentPrefix = 'DEV';
        } else {
            environmentPrefix = 'PROD';
        }
        return environmentPrefix;
    }
    public static SpringCLMSetting__mdt getApiEnvironment() {
        String environmentqueryname = getEnvironmentPrefix();
        if (Test.isRunningTest())
            environmentqueryname = 'TEST';

        return [ Select Id, Client_Id__c, Client_Secret__c, AuthEndpoint__c,API_URL__c,
        Account_Id__c from SpringCLMSetting__mdt WHERE DeveloperName =: environmentqueryname];
    }
}