@isTest
private class TriggerUtilsTest {
    @isTest
    static void testResetDisableTrigger() {
        TriggerUtils.disableTrigger = true;

        Test.startTest();
        TriggerUtils.resetDisableTrigger(new List<String>{ 'ignored' });
        Test.stopTest();

        Assert.isFalse(TriggerUtils.disableTrigger, 'resetDisableTrigger should reset the flag to false');
    }
}