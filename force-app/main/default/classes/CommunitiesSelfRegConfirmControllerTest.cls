@isTest
private class CommunitiesSelfRegConfirmControllerTest {
    @isTest
    static void testConstructor() {
        CommunitiesSelfRegConfirmController controller = new CommunitiesSelfRegConfirmController();
        System.assertNotEquals(null, controller, 'Controller should be created');
    }
}