@isTest
public class BREGPaymentReceiptPdfControllerTest {
    @testSetup
    static void setupData() {
        // Create BREG Setting
        BREG_Setting__c setting = new BREG_Setting__c();
        setting.Published_Document_Code_Valid_Days__c = 7;
        insert setting;

        // Create test Account
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        Account testAccount = new Account(
            Name = 'Test Corporation',
            BillingStreet = '123 Main St',
            BillingCity = 'Honolulu',
            BillingStateCode = 'HI',
            BillingPostalCode = '96813',
            BillingCountry = 'United States',
            BillingCountryCode = 'US',
            breg_File__c = '12345-D1',
            breg_Business_Structure__c = 'Corporation',
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)',
            breg_Formation_Date__c = Date.newInstance(2020, 1, 1),
            breg_Good_Standing__c = true,
            RecordTypeId = bregAccRecordType
        );
        insert testAccount;

        // Create test Contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            Phone = '808-555-1234',
            AccountId = testAccount.Id,
            MailingStreet = '789 Pine Rd',
            MailingCity = 'Kailua',
            MailingStateCode = 'HI',
            MailingPostalCode = '96734',
            MailingCountry = 'United States'
        );
        insert testContact;

        // Create BREG Portal Guest User Contact
        Contact guestContact = new Contact(FirstName = 'BREG Portal', LastName = 'Guest User Contact', Email = 'guest@breg.test.com');
        insert guestContact;

        // Create Form Configuration
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'D1',
            breg_Suffix_Code__c = 'D1',
            breg_Form_Code__c = 'DC-1',
            breg_Form_Name__c = 'Articles of Incorporation',
            breg_Business_Process__c = 'New Business'
        );
        insert formConfig;

        // Create DOCDLVR Form Configuration
        breg_Form_Configuration__c docdlvrFormConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR',
            breg_Form_Name__c = 'Document Delivery'
        );
        insert docdlvrFormConfig;

        // Create Case
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        Case testCase = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = bregCaseRecordTypeId,
            breg_New_Entity_Name__c = 'Test Corporation',
            breg_Name_of_the_Entity__c = 'Test Corporation',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-1',
            breg_Form_Action__c = 'Initial Filing',
            breg_Delivery_Method__c = 'Email',
            breg_Workitem_Number__c = 'WI-12345',
            ContactId = testContact.Id,
            breg_Entity__c = testAccount.Id
        );
        insert testCase;

        // Create Document
        breg_Document__c testDocument = new breg_Document__c(
            Name = 'Test Document',
            breg_Account__c = testAccount.Id,
            breg_Case__c = testCase.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0,
            breg_Docusign_Document_Id__c = 'test-docusign-id',
            CreatedDate = System.now()
        );
        insert testDocument;

        // Create Transaction
        Transaction__c trans = new Transaction__c();
        trans.Division__c = 'BREG';
        trans.PaymentAmount__c = 100.00;
        trans.TotalAmount__c = 100.00;
        trans.Status__c = 'Completed';
        trans.TransactionType__c = 'Payment';
        trans.Date__c = Date.today();
        insert trans;

        // Create Payment
        Id paymentRecordTypeId = Schema.SObjectType.pymt__PaymentX__c.getRecordTypeInfosByDeveloperName().get('Payment').getRecordTypeId();
        pymt__PaymentX__c payment = new pymt__PaymentX__c();
        payment.RecordTypeId = paymentRecordTypeId;
        payment.Name = 'BREG Portal Payment';
        payment.Division__c = 'BREG';
        payment.Transaction__c = trans.Id;
        payment.pymt__Transaction_Type__c = 'Payment';
        payment.pymt__Payment_Processor__c = 'Authorize.Net';
        payment.pymt__Payment_Type__c = 'Credit Card';
        payment.pymt__Date__c = Date.today();
        payment.pymt__Status__c = 'Completed';
        payment.pymt__Amount__c = 100.00;
        payment.pymt__Currency_ISO_Code__c = 'USD';
        payment.pymt__Contact__c = testContact.Id;
        payment.pymt__Transaction_Id__c = 'TXN-123456';
        payment.pymt__Authorization_Id__c = 'AUTH-123456';
        payment.pymt__Card_Type__c = 'Visa';
        payment.pymt__Last_4_Digits__c = '1234';
        payment.pymt__Billing_First_Name__c = 'John';
        payment.pymt__Billing_Last_Name__c = 'Doe';
        payment.pymt__Billing_Email__c = 'john.doe@test.com';
        payment.pymt__Billing_Street__c = '789 Pine Rd';
        payment.pymt__Billing_City__c = 'Kailua';
        payment.pymt__Billing_State__c = 'HI';
        payment.pymt__Billing_Postal_Code__c = '96734';
        payment.pymt__Billing_Country__c = 'US';
        insert payment;

        // Create Cashier Code
        CashierCode__c cashierCode = new CashierCode__c(CashierCode__c = 'B71', Division__c = 'BREG', Name = 'Entity List Fee');
        insert cashierCode;

        // Create Fee
        breg_Fee__c fee = new breg_Fee__c(
            breg_Record_Type__c = 'Entity List',
            breg_Fee_Amount__c = 10.00,
            breg_Purchase_Type_Fee_type__c = 'Document',
            breg_Cashier_Code__c = 'B71'
        );
        insert fee;

        // Create Transaction Lines
        List<TransactionLine__c> transLines = new List<TransactionLine__c>();

        TransactionLine__c transLine1 = new TransactionLine__c();
        transLine1.breg_Document__c = testDocument.Id;
        transLine1.breg_Case__c = testCase.Id;
        transLine1.Transaction__c = trans.Id;
        transLine1.Payment__c = payment.Id;
        transLine1.Description__c = 'Test Corporation - Test Document';
        transLine1.breg_Quantity__c = 1;
        transLine1.breg_Unit_Price__c = 10.00;
        transLine1.Amount__c = 10.00;
        transLine1.breg_Type__c = 'Document';
        transLine1.breg_Fee__c = fee.Id;
        transLine1.PaidStatus__c = 'Paid';
        transLine1.CashierCode__c = cashierCode.Id;
        transLines.add(transLine1);

        TransactionLine__c transLine2 = new TransactionLine__c();
        transLine2.Transaction__c = trans.Id;
        transLine2.Payment__c = payment.Id;
        transLine2.Description__c = 'Entity List';
        transLine2.breg_Quantity__c = 2;
        transLine2.breg_Unit_Price__c = 50.00;
        transLine2.Amount__c = 100.00;
        transLine2.breg_Type__c = 'Entity List';
        transLine2.breg_Fee__c = fee.Id;
        transLine2.PaidStatus__c = 'Paid';
        transLine2.CashierCode__c = cashierCode.Id;
        transLines.add(transLine2);

        insert transLines;
    }

    @isTest
    static void testConstructorWithValidPaymentId() {
        pymt__PaymentX__c payment = [SELECT Id, pymt__Date__c, pymt__Amount__c FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        PageReference pageRef = Page.BREG_PaymentReceipt;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', payment.Id);

        BREGPaymentReceiptPdfController controller = new BREGPaymentReceiptPdfController();
        Test.stopTest();

        System.assertNotEquals(null, controller.payment, 'Payment should not be null');
        System.assertEquals(payment.Id, controller.payment.Id, 'Payment ID should match');
        System.assertNotEquals(null, controller.transactionDate, 'Transaction date should not be null');
        System.assertEquals('$100.00', controller.transactionAmount, 'Transaction amount should be $100.00');
        System.assertNotEquals(null, controller.transactionLineItems, 'Transaction line items should not be null');
        System.assertEquals(2, controller.transactionLineItems.size(), 'Should have 2 transaction lines');
        System.assertNotEquals(null, controller.transactionLineItemWrappers, 'Transaction line item wrappers should not be null');
        System.assertEquals(2, controller.transactionLineItemWrappers.size(), 'Should have 2 wrappers');
    }

    @isTest
    static void testConstructorWithNoPaymentId() {
        Test.startTest();
        PageReference pageRef = Page.BREG_PaymentReceipt;
        Test.setCurrentPage(pageRef);

        BREGPaymentReceiptPdfController controller = new BREGPaymentReceiptPdfController();
        Test.stopTest();

        System.assertEquals(null, controller.payment, 'Payment should be null when no ID provided');
        System.assertEquals(null, controller.transactionLineItems, 'Transaction line items should be null');
        System.assertEquals(null, controller.transactionLineItemWrappers, 'Wrappers should be null');
    }

    @isTest
    static void testTransactionLineItemWrapperValues() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        PageReference pageRef = Page.BREG_PaymentReceipt;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', payment.Id);

        BREGPaymentReceiptPdfController controller = new BREGPaymentReceiptPdfController();
        Test.stopTest();

        // Find the wrapper for the document transaction line (has a case with workitem number)
        BREGPaymentReceiptPdfController.TransactionLineItemWrapper docWrapper = null;
        BREGPaymentReceiptPdfController.TransactionLineItemWrapper entityWrapper = null;
        for (BREGPaymentReceiptPdfController.TransactionLineItemWrapper wrapper : controller.transactionLineItemWrappers) {
            if (wrapper.item == 'Test Corporation - Test Document') {
                docWrapper = wrapper;
            } else if (wrapper.item == 'Entity List') {
                entityWrapper = wrapper;
            }
        }

        // Verify document transaction line wrapper
        System.assertNotEquals(null, docWrapper, 'Document wrapper should exist');
        System.assertEquals('WI-12345', docWrapper.workItemNumber, 'Work item number should match');
        System.assertEquals('Test Corporation - Test Document', docWrapper.item, 'Item description should match');
        System.assertEquals('1', docWrapper.quantity, 'Quantity should be 1');
        System.assertEquals('$10.00', docWrapper.amount, 'Amount should be $10.00');

        // Verify entity list transaction line wrapper (no case linked)
        System.assertNotEquals(null, entityWrapper, 'Entity list wrapper should exist');
        System.assertEquals('N/A', entityWrapper.workItemNumber, 'Work item number should be N/A when no case');
        System.assertEquals('Entity List', entityWrapper.item, 'Item description should match');
        System.assertEquals('2', entityWrapper.quantity, 'Quantity should be 2');
        System.assertEquals('$100.00', entityWrapper.amount, 'Amount should be $100.00');
    }

    @isTest
    static void testConstructorWithBlankPaymentId() {
        Test.startTest();
        PageReference pageRef = Page.BREG_PaymentReceipt;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', '');

        BREGPaymentReceiptPdfController controller = new BREGPaymentReceiptPdfController();
        Test.stopTest();

        System.assertEquals(null, controller.payment, 'Payment should be null when blank ID provided');
    }
}