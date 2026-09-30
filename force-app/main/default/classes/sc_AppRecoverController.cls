public class sc_AppRecoverController {
    public static final String DYNAMICAPPLICATIONS = 'Dynamic Application - ';
    
    @AuraEnabled(cacheable=true)
    public static List<String> getAppsInStaticResource(){
        try {
            List<String> appNames = new List<String>();
            String queryName = DYNAMICAPPLICATIONS + '%';
            List<StaticResource> resourceRecords = [Select Id, Description from StaticResource where Description like: queryName];
            for(StaticResource resource: resourceRecords) {
                appNames.add(resource.Description.replace(DYNAMICAPPLICATIONS, ''));
            }
            return appNames;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void createApp(List<String> appNames) {
        for(String appName: appNames) {
            sc_AppMetaDataManagement.parseResource(appName);
        }
    }
    
}