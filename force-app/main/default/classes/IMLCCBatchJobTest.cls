@isTest
private class IMLCCBatchJobTest {

    @isTest
    static void test_getLicenses() {
        Test.startTest();
        Datetime fireTime = Datetime.now();
        String cron = fireTime.second() + ' ' + fireTime.minute() + ' ' + fireTime.hour() + ' * * ?';
        System.schedule('IMLCCBatchJob Test run', cron, new IMLCCBatchJob());
        Test.stopTest();
    }
}