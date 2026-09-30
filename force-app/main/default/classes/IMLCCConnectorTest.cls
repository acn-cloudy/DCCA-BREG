@isTest
private class IMLCCConnectorTest {

    @isTest
    static void test_getList() {
        Test.startTest();
        try{
            IMLCCConnector.getList('license', null);
        } catch (Exception e){
            System.debug('Callouts not allowed on test');
        }
        Test.stopTest();
    }

    @isTest
    static void test_getRecordDetailst() {
        Test.startTest();
        try{
            IMLCCConnector.getRecordDetails('license', null);
        } catch (Exception e){
            System.debug('Callouts not allowed on test');
        }
        Test.stopTest();
    }

    @isTest
    static void test_pushSingleLicenseToCompact() {
        Test.startTest();
        try{
            IMLCCConnector.pushSingleLicenseToCompact(null, null);
        } catch (Exception e){
            System.debug('Callouts not allowed on test');
        }
        Test.stopTest();
    }

    @isTest
    static void test_pushBulkLicensesToCompact() {
        Test.startTest();
        try{
            IMLCCConnector.pushBulkLicensesToCompact(null);
        } catch (Exception e){
            System.debug('Callouts not allowed on test');
        }
        Test.stopTest();
    }
}