/*
 * ___________________________________________________________________________________
 * Code coverage for GenericCommunityPaymentController
 * __________________________________________________________________________________
 * PacPoint-CL02132020 - Created for DFI Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 2/13/2020
 * __________________________________________________________________________________
 */
@IsTest
private class GenericCommunityPaymentControllerTest {
    @TestSetup
    static void setup() {
        CashierCode__c cc = new CashierCode__c();
        cc.Name = '000 - Test';
        cc.CashierCode__c = 'EDX';
        cc.Division__c = 'DFI';
        insert cc;
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
    }

    @IsTest
    static void testCreateSObject() {
        String cashierId = [SELECT Id FROM CashierCode__c  limit 1].Id;
        String accountId = [SELECT Id FROM Account  limit 1 ].Id;
        String contactId = [SELECT Id FROM Contact limit 1].Id;

        DFIRegistration__c testObj = new DFIRegistration__c();
        testObj.FirstName__c = 'test';
        testObj.LastName__c = 'test';
        testObj.EmailAddress__c = 'test@test.test';
        testObj.CompanyName__c = 'test';
        testObj.Acknowledgementof35Fee__c = true;
        testObj.Areyouattending__c = 'Yes, I am coming';
        testObj.Dietaryrestrictions__c = 'Vegan';

        String cashierRecordStr = '{"Amount__c":23442,"CashierCode__c":"323","Id":"' + cashierId +
                '","SystemModstamp":"2019-06-09T05:01:12.000Z"}';
        String contactRecordStr = '{"AccountId":"' + accountId + '","Id":"' + contactId +
                '","SystemModstamp":"2019-06-05T17:34:56.000Z"}';
        String paymentId =
                GenericCommunityPaymentController.createSObject(testObj, contactRecordStr, cashierRecordStr, 'DFI',
                        'USD', 'DFIRegistration__c');
        List<pymt__PaymentX__c> payments = [Select Id from pymt__PaymentX__c where Id =: paymentId];
        System.assertEquals(payments.size(), 1);
    }

    @IsTest
    static void testCreateSObjectError() {
        String cashierId = [SELECT Id FROM CashierCode__c  limit 1].Id;
        String accountId = [SELECT Id FROM Account  limit 1 ].Id;
        String contactId = [SELECT Id FROM Contact limit 1].Id;

        DFIRegistration__c testObj = new DFIRegistration__c();
        testObj.put('EmailAddress__c', 'invalid email');

        String cashierRecordStr = '{"Amount__c":23442,"CashierCode__c":"323","Id":"' + cashierId +
                '","SystemModstamp":"2019-06-09T05:01:12.000Z"}';
        String contactRecordStr = '{"AccountId":"' + accountId + '","Id":"' + contactId +
                '","SystemModstamp":"2019-06-05T17:34:56.000Z"}';
        try {
            GenericCommunityPaymentController.createSObject(testObj, contactRecordStr, cashierRecordStr, 'DFI',
                    'USD', 'DFIRegistration__c');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
        }
    }

    @IsTest
    static void testLoadGenericContact() {
        String contactId = [SELECT Id FROM Contact limit 1].Id;
        System.assert(GenericCommunityPaymentController.loadGenericContact(contactId).contains(contactId));
    }

    @IsTest
    static void testLoadCashierCode() {
        String cashierId = [SELECT Id FROM CashierCode__c].Id;
        System.assert(GenericCommunityPaymentController.loadCashierCode(cashierId).contains('EDX'));
    }

    @IsTest
    static void testCheckPaymentStatusNotComplete() {
        String cashierId = [SELECT Id FROM CashierCode__c  limit 1].Id;
        String accountId = [SELECT Id FROM Account  limit 1 ].Id;
        String contactId = [SELECT Id FROM Contact limit 1].Id;

        DFIRegistration__c testObj = new DFIRegistration__c();
        testObj.FirstName__c = 'test';
        testObj.LastName__c = 'test';
        testObj.EmailAddress__c = 'test@test.test';
        testObj.CompanyName__c = 'test';
        testObj.Areyouattending__c = 'Yes, I am coming';
        testObj.Dietaryrestrictions__c = 'Vegan';
        testObj.Acknowledgementof35Fee__c = true;

        String cashierRecordStr = '{"Amount__c":23442,"CashierCode__c":"323","Id":"' + cashierId +
                '","SystemModstamp":"2019-06-09T05:01:12.000Z"}';
        String contactRecordStr = '{"AccountId":"' + accountId + '","Id":"' + contactId +
                '","SystemModstamp":"2019-06-05T17:34:56.000Z"}';
        String paymentId =
                GenericCommunityPaymentController.createSObject(testObj, contactRecordStr, cashierRecordStr, 'DFI',
                        'USD', 'DFIRegistration__c');

        try {
            GenericCommunityPaymentController.checkPaymentStatus(paymentId);
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
            System.assert(e.getMessage().contains('PAYMENT NOT COMPLETED'));
        }
    }

    @IsTest
    static void testCheckPaymentStatusNoPaymentIdNull() {
        try {
            GenericCommunityPaymentController.checkPaymentStatus(null);
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException);
            System.assert(e.getMessage().contains('NO PAYMENT ID'));
        }
    }
}