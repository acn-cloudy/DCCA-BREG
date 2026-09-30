/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test codes for the HPEAPRequestCreate - Used to test create specific for HPEAP Request
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* PacPoint-LC250717 - Created for PQB phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
private class HPEAPRequestCreateTest {
    private static String cashierId = '';
    private static String accountId = '';
    private static String contactId = '';
    
    public static void init(){
        CashierCode__c cc = new CashierCode__c();
        cc.Name = '000 - Test';
        cc.CashierCode__c = 'EDX';
        cc.Division__c = 'HPEAP';
        insert cc;
        cashierId = cc.Id;
        // Data setup
		Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;
        
        Contact cnt = new Contact();
        cnt.AccountId = acc.Id;
        cnt.LastName = 'Test 375734';
        insert cnt;

        acc.Contact__c = cnt.Id;
        update acc;
        accountId = acc.Id;
        contactId = cnt.Id;
    }
    public static testMethod void testCreateTranscript() {
        init();
        String transcriptStr = '{"FirstName__c":"Test First Name","StudentIDOrLAST4OfSSN__c":"8473","ProgramOfStudy__c":"IT","LastName__c":"Test Last Name","LastYearAttended__c":"2017","TranscriptDeliveryMethod__c":"I will pick up the Transcript in person","MailingCountry__c":"United States","BillingCountry__c":"United States","Phone__c":"874-9483","Email__c":"testSample@sample.com","SignatureFirstName__c":"Test First Name","SignatureLastName__c":"Test Last Name"}';
        String cashierRecordStr = '{"Amount__c":23442,"CashierCode__c":"323","Id":"'+cashierId+'","SystemModstamp":"2019-06-09T05:01:12.000Z"}';
        String contactRecordStr = '{"AccountId":"'+accountId+'","Id":"'+contactId+'","SystemModstamp":"2019-06-05T17:34:56.000Z"}';
        String paymentId = HPEAPRequestCreate.createTranscript(transcriptStr, contactRecordStr, cashierRecordStr, 'HPEAP', 'USD');
        List<pymt__PaymentX__c> payments = [Select Id from pymt__PaymentX__c where Id =: paymentId];
        System.assertEquals(payments.size(), 1);
    }
    public static testMethod void testLoadGenericContact() {
        init();
        System.assert(HPEAPRequestCreate.loadGenericContact(contactId).contains(contactId));
    }
    public static testMethod void testLoadCashierCode() {
        init();
        System.assert(HPEAPRequestCreate.loadCashierCode(cashierId).contains('EDX'));
    }
    
    
}