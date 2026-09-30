@isTest
private class CounterServiceTest {
    public static testMethod void testGetApprenticeApplicationCounter() {
        CounterService.getApprenticeApplicationCounter();
        CounterService.saveApprenticeApplication();
    }
}