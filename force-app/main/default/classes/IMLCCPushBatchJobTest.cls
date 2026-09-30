@isTest
private class IMLCCPushBatchJobTest {

    @isTest
    static void test_pushTest() {
        Test.startTest();
        Datetime fireTime = Datetime.now();
        String cron = fireTime.second() + ' ' + fireTime.minute() + ' ' + fireTime.hour() + ' * * ?';
        System.schedule('IMLCCPushBatchJob Test run', cron, new IMLCCPushBatchJob());
        Test.stopTest();
    }
}