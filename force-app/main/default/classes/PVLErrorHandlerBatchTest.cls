@isTest
private class PVLErrorHandlerBatchTest {
    @TestSetup
    static void makeData(){
        pymt__PaymentX__c record = TestDataFactory.createDummyChargebackPayment();
        insert record;
    }

    @isTest
    static void testPVLEmailException() {
        pymt__PaymentX__c record = [Select Id, pymt__Billing_Email__c from pymt__PaymentX__c limit 1];
        Test.startTest();
        Exception exT;
        try{
            PVL_SendPVLEmails.sendLicenseApplicationEmails(record.Id);
        } catch(Exception ex) {
            exT = ex;
        }
        System.assert(ext != null);
        Test.stopTest();
    }

    @isTest
    static void testCreateApplicationLog() {
        Test.startTest();
        pymt__PaymentX__c record = [Select Id from pymt__PaymentX__c limit 1];
        ApplicationLogService.logApplicationError('Send PVL Payment Receipt Issue', record.Id, '', 'Error message');
        Test.stopTest();
        List<Application_Log__c> logs = [Select Id from Application_Log__c];
        System.assert(!logs.isEmpty());
    }

    @isTest
    static void testSchedulJobAndBatch() {
        pymt__PaymentX__c record = [Select Id, pymt__Billing_Email__c, EmailAsyncId__c from pymt__PaymentX__c limit 1];
        record.pymt__Billing_Email__c = 'testsample@test.salesforce.com';
        
        Test.startTest();
        PVLErrorHandlerBatch scheduler = new PVLErrorHandlerBatch();
        String sch = '0 0 23 * * ?';
        String asyncId = System.schedule('Test sch PVLErrorHandlerBatch test', sch, scheduler);
        record.EmailAsyncId__c = asyncId;
        update record;
        Database.executeBatch(new PVLErrorHandlerBatch());
        Test.stopTest();
    
    }
}