@isTest
private class sc_AppRecoverControllerTest {
    
    @isTest
    static void testGetAppsInStaticResource() {
        System.assert(sc_AppRecoverController.getAppsInStaticResource() != null);
    }

    @isTest
    static void testCreateApp() {
        sc_AppRecoverController.createApp(new List<String>{'sc_testData'});
        
    }
}