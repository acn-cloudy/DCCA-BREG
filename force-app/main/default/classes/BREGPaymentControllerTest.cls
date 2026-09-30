@isTest
public class BREGPaymentControllerTest {
    @testSetup
    static void setupData() {
        // Create BREG Setting
        BREG_Setting__c setting = new BREG_Setting__c();
        setting.Published_Document_Code_Valid_Days__c = 7;
        setting.Expedited_Processing_Disabled__c = true;
        setting.Payment_Authorization_Notice_Enabled__c = true;
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

        // Create DOCDLVR Form Configuration (required for document delivery)
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

        // Update Case with Document
        testCase.breg_Document__c = testDocument.Id;
        update testCase;

        // Create Entity List
        breg_Entity_List__c entityList = new breg_Entity_List__c(breg_Status__c = 'All');
        insert entityList;

        // Create Entity List Result
        breg_Entity_List_Result__c entityListResult = new breg_Entity_List_Result__c(
            breg_Entity_List__c = entityList.Id,
            breg_Docusign_Document_Id__c = 'entity-list-doc-id',
            breg_Expiration_Date__c = Date.today().addDays(5)
        );
        insert entityListResult;

        // Create Agent Search List
        breg_Agent_Search_List__c agentSearchList = new breg_Agent_Search_List__c(breg_Agents_JSON__c = '[{"name":"Test Agent","address":"123 Test St"}]');
        insert agentSearchList;

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
        transLine2.breg_Entity_List__c = entityList.Id;
        transLine2.Transaction__c = trans.Id;
        transLine2.Payment__c = payment.Id;
        transLine2.Description__c = 'Entity List';
        transLine2.breg_Quantity__c = 1;
        transLine2.breg_Unit_Price__c = 50.00;
        transLine2.Amount__c = 50.00;
        transLine2.breg_Type__c = 'Entity List';
        transLine2.breg_Fee__c = fee.Id;
        transLine2.PaidStatus__c = 'Paid';
        transLine2.CashierCode__c = cashierCode.Id;
        transLines.add(transLine2);

        TransactionLine__c transLine3 = new TransactionLine__c();
        transLine3.breg_Agent_Search_List__c = agentSearchList.Id;
        transLine3.Transaction__c = trans.Id;
        transLine3.Payment__c = payment.Id;
        transLine3.Description__c = 'Agent Search List';
        transLine3.breg_Quantity__c = 1;
        transLine3.breg_Unit_Price__c = 40.00;
        transLine3.Amount__c = 40.00;
        transLine3.breg_Type__c = 'Agent Search List';
        transLine3.breg_Fee__c = fee.Id;
        transLine3.PaidStatus__c = 'Paid';
        transLine3.CashierCode__c = cashierCode.Id;
        transLines.add(transLine3);

        insert transLines;
    }

    @isTest
    static void testDownloadDocument() {
        Test.setMock(HttpCalloutMock.class, new MockDocuSignHttpResponse());

        Test.startTest();
        String base64Document = BREGPaymentController.downloadDocument('test-docusign-id');
        Test.stopTest();

        System.assertNotEquals(null, base64Document, 'Base64 document should not be null');
    }

    @isTest
    static void testDownloadDocumentException() {
        Test.setMock(HttpCalloutMock.class, new MockDocuSignHttpResponseError());

        Test.startTest();
        try {
            String base64Document = BREGPaymentController.downloadDocument('invalid-id');
            System.assert(false, 'Expected exception to be thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPaymentStatus() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        String status = BREGPaymentController.getPaymentStatus(payment.Id);
        Test.stopTest();

        System.assertEquals('Completed', status, 'Payment status should be Completed');
    }

    @isTest
    static void testGetPaymentStatusNull() {
        Test.startTest();
        String status = BREGPaymentController.getPaymentStatus(null);
        Test.stopTest();

        System.assertEquals(null, status, 'Payment status should be null when paymentId is null');
    }

    @isTest
    static void testGetPaymentStatusInvalidId() {
        // Create a fake ID that doesn't exist
        Id fakePaymentId = Schema.SObjectType.pymt__PaymentX__c.getKeyPrefix() + '000000000001';

        Test.startTest();
        String status = BREGPaymentController.getPaymentStatus(fakePaymentId);
        Test.stopTest();

        System.assertEquals(null, status, 'Payment status should be null when payment not found');
    }

    @isTest
    static void testCreatePaymentDocumentDeliveryFlows() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        breg_Document__c templateDoc = new breg_Document__c(
            Name = 'Template Document',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0,
            breg_Available_To_Certify__c = true
        );
        insert templateDoc;

        String baseItemId = acc.Id + '_' + templateDoc.Id;

        breg_Document__c mailDoc = new breg_Document__c(
            Name = 'Mail Document',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available by Mail or Pickup',
            breg_Is_Public__c = true,
            breg_Type__c = 'Printed',
            breg_Price__c = 10.0
        );
        insert mailDoc;

        List<Map<String, Object>> cartItems = new List<Map<String, Object>>{
            new Map<String, Object>{ 'type' => 'Document', 'id' => baseItemId, 'documentType' => 'Test Document', 'format' => 'Digital', 'quantity' => 1, 'unitPrice' => 10.0, 'feeId' => fee.Id },
            new Map<String, Object>{ 'type' => 'Document', 'documentType' => 'Certified Copy Fee', 'parentItemId' => baseItemId, 'quantity' => 1, 'unitPrice' => 5.0, 'feeId' => fee.Id },
            new Map<String, Object>{ 'type' => 'Document', 'id' => acc.Id + '_' + mailDoc.Id, 'documentType' => 'Mail Document', 'format' => 'Printed', 'quantity' => 1, 'unitPrice' => 10.0, 'feeId' => fee.Id }
        };
        String cartItemsJson = JSON.serialize(cartItems);
        // existing email -> exercises dedup branch; delivery address -> exercises mail-address branch
        String deliveryDetailsJson = JSON.serialize(
            new Map<String, Object>{
                'contact' => new Map<String, Object>{ 'FirstName' => 'Different', 'LastName' => 'Name', 'Email' => 'john.doe@test.com' },
                'deliveryAddress' => new Map<String, Object>{ 'street' => '123 Mail St', 'city' => 'Honolulu', 'state' => 'HI', 'postalCode' => '96813', 'country' => 'US' }
            }
        );

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 25.0, cartItemsJson, deliveryDetailsJson, false);
        // Base document + its Certified Copy Fee share the same generated Case -> exercises consolidateSinglePrimary
        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getPaymentTransactionLineWrappers(paymentId);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment should be created');
        Integer contactCount = [SELECT COUNT() FROM Contact WHERE Email = 'john.doe@test.com'];
        System.assertEquals(1, contactCount, 'Existing contact should be reused, not duplicated');
        Contact deliveryContact = [SELECT Id FROM Contact WHERE Email = 'john.doe@test.com' LIMIT 1];
        List<TransactionLine__c> deliveredLines = [
            SELECT Id, breg_Delivery_Contact__c
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId AND breg_Type__c = 'Document'
        ];
        System.assertEquals(3, deliveredLines.size(), 'Should create three document transaction lines for this delivery flow');
        for (TransactionLine__c deliveredLine : deliveredLines) {
            System.assertEquals(deliveryContact.Id, deliveredLine.breg_Delivery_Contact__c, 'Document transaction lines should store the resolved delivery contact');
        }
        List<Case> cases = [SELECT Id, breg_Delivery_Method__c FROM Case WHERE breg_Document__c = :mailDoc.Id];
        System.assertEquals(1, cases.size(), 'Case should be created for mail delivery document');

        BREGPaymentController.TransactionLineWrapper consolidated = null;
        for (BREGPaymentController.TransactionLineWrapper w : wrappers) {
            if (w.isCertified) {
                consolidated = w;
            }
        }
        System.assertNotEquals(null, consolidated, 'Document + Certified Copy Fee should consolidate into one certified wrapper');
        System.assertEquals(15.0, consolidated.price, 'Consolidated price should sum document + certified copy fee');
    }

    @isTest
    static void testGetFeeIdForTransactionLineItemDirect() {
        TransactionLine__c line = [
            SELECT Id, breg_Fee__c
            FROM TransactionLine__c
            WHERE breg_Fee__c != NULL
            LIMIT 1
        ];

        Test.startTest();
        Id feeId = BREGPaymentController.getFeeIdForTransactionLineItem(line.Id);
        Test.stopTest();

        System.assertEquals(line.breg_Fee__c, feeId, 'Method should return feeId already stored on TLI');
    }

    @isTest
    static void testGetFeeIdForTransactionLineItemFallbackByCashierCode() {
        Transaction__c trans = [SELECT Id FROM Transaction__c LIMIT 1];
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        CashierCode__c cashierCode = [SELECT Id, CashierCode__c FROM CashierCode__c WHERE Division__c = 'BREG' LIMIT 1];
        breg_Fee__c expectedFee = [SELECT Id FROM breg_Fee__c WHERE breg_Cashier_Code__c = :cashierCode.CashierCode__c LIMIT 1];

        TransactionLine__c manualLine = new TransactionLine__c(
            Transaction__c = trans.Id,
            Payment__c = payment.Id,
            Description__c = 'Manual document fee',
            breg_Type__c = 'Document',
            CashierCode__c = cashierCode.Id,
            breg_Quantity__c = 1,
            breg_Unit_Price__c = 10,
            Amount__c = 10,
            PaidStatus__c = 'Pending'
        );
        insert manualLine;

        Test.startTest();
        Id feeId = BREGPaymentController.getFeeIdForTransactionLineItem(manualLine.Id);
        Test.stopTest();

        System.assertEquals(expectedFee.Id, feeId, 'Method should resolve feeId from cashier code when TLI fee is empty');
    }

    @isTest
    static void testGetTransactionLines() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        List<TransactionLine__c> transLines = BREGPaymentController.getTransactionLines(payment.Id);
        Test.stopTest();

        System.assertNotEquals(null, transLines, 'Transaction lines should not be null');
        System.assertEquals(3, transLines.size(), 'Should have 3 transaction lines');
    }

    @isTest
    static void testGetPaymentConfirmationCompleted() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        BREGPaymentController.PaymentConfirmationWrapper wrapper = BREGPaymentController.getPaymentConfirmation(payment.Id);
        Test.stopTest();

        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertEquals(true, wrapper.isCompleted, 'Payment should be completed');
        System.assertEquals('Completed', wrapper.paymentStatus, 'Payment status should be Completed');
        System.assertEquals('TXN-123456', wrapper.transactionId, 'Transaction ID should match');
        System.assertEquals('AUTH-123456', wrapper.authorizationId, 'Authorization ID should match');
        System.assertEquals(100.00, wrapper.paymentAmount, 'Payment amount should be 100.00');
        System.assertEquals('USD', wrapper.currencyCode, 'Currency code should be USD');
        System.assertEquals('Visa', wrapper.cardType, 'Card type should be Visa');
        System.assertEquals('1234', wrapper.last4Digits, 'Last 4 digits should be 1234');
        System.assertEquals('john.doe@test.com', wrapper.billingEmail, 'Billing email should match');
        System.assertNotEquals(null, wrapper.transactionLineWrappers, 'Transaction line wrappers should not be null');
    }

    @isTest
    static void testGetPaymentConfirmationNotCompleted() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        payment.pymt__Status__c = 'In Process';
        update payment;

        Test.startTest();
        BREGPaymentController.PaymentConfirmationWrapper wrapper = BREGPaymentController.getPaymentConfirmation(payment.Id);
        Test.stopTest();

        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertEquals(false, wrapper.isCompleted, 'Payment should not be completed');
        System.assertEquals('In Process', wrapper.paymentStatus, 'Payment status should be In Process');
    }

    // Covers: downloadDocument (success/error), generatePaymentReceiptPdf, getPaymentSiteBaseUrl, isExpeditedProcessingDisabled, isPaymentAuthorizationNoticeEnabled
    @isTest
    static void testGeneratePaymentReceiptPdf() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        Test.startTest();
        String base64Pdf = BREGPaymentController.generatePaymentReceiptPdf(payment.Id);
        String siteUrl = BREGPaymentController.getPaymentSiteBaseUrl();
        Boolean expeditedDisabled = BREGPaymentController.isExpeditedProcessingDisabled();
        Boolean paymentNoticeEnabled = BREGPaymentController.isPaymentAuthorizationNoticeEnabled();
        Test.stopTest();

        System.assertEquals(true, paymentNoticeEnabled, 'Payment authorization notice flag should reflect setting');

        System.assertNotEquals(null, base64Pdf, 'Receipt PDF should generate');
        System.assertNotEquals(null, siteUrl, 'Site base URL should resolve');
        System.assertEquals(true, expeditedDisabled, 'Expedited processing flag should reflect setting');
    }

    @isTest
    static void testCreatePaymentWithDocuments() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Document',
            'id' => acc.Id +
            '_' +
            doc.Id,
            'documentType' => 'Test Document',
            'companyName' => 'Test Corporation',
            'format' => 'Digital',
            'quantity' => 1,
            'unitPrice' => 10.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);

        // Create delivery details JSON
        Map<String, Object> deliveryDetails = new Map<String, Object>{
            'contact' => new Map<String, Object>{ 'FirstName' => 'Jane', 'LastName' => 'Smith', 'Email' => 'jane.smith@test.com' },
            'phone' => '808-555-5678'
        };
        String deliveryDetailsJson = JSON.serialize(deliveryDetails);

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 10.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        pymt__PaymentX__c createdPayment = [SELECT Id, pymt__Amount__c, pymt__Status__c FROM pymt__PaymentX__c WHERE Id = :paymentId];
        System.assertEquals(10.0, createdPayment.pymt__Amount__c, 'Payment amount should be 10.0');
        System.assertEquals('In Process', createdPayment.pymt__Status__c, 'Payment status should be In Process');
    }

    @isTest
    static void testCreatePaymentZeroAmount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Agent Search List',
            'agentSearchListId' => [SELECT Id FROM breg_Agent_Search_List__c LIMIT 1]
            .Id,
            'documentType' => 'Agent Search',
            'quantity' => 1,
            'unitPrice' => 0.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 0.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        pymt__PaymentX__c createdPayment = [SELECT Id, pymt__Amount__c, pymt__Status__c FROM pymt__PaymentX__c WHERE Id = :paymentId];
        System.assertEquals(0.0, createdPayment.pymt__Amount__c, 'Payment amount should be 0.0');
        System.assertEquals('Completed', createdPayment.pymt__Status__c, 'Payment status should be Completed for zero amount');
    }

    @isTest
    static void testCreatePaymentWithEntityList() {
        breg_Entity_List__c entityList = [SELECT Id FROM breg_Entity_List__c LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Entity List',
            'entityListId' => entityList.Id,
            'documentType' => 'Entity List',
            'quantity' => 1,
            'unitPrice' => 50.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 50.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Entity_List__c, Amount__c
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId AND breg_Entity_List__c = :entityList.Id
        ];
        System.assertEquals(1, transLines.size(), 'Should have 1 transaction line for entity list');
        System.assertEquals(50.0, transLines[0].Amount__c, 'Transaction line amount should be 50.0');
    }

    @isTest
    static void testCreatePaymentWithAgentSearchList() {
        breg_Agent_Search_List__c agentSearchList = [SELECT Id FROM breg_Agent_Search_List__c LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Agent Search List',
            'agentSearchListId' => agentSearchList.Id,
            'documentType' => 'Agent Search',
            'quantity' => 1,
            'unitPrice' => 40.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 40.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Agent_Search_List__c, Amount__c
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId AND breg_Agent_Search_List__c = :agentSearchList.Id
        ];
        System.assertEquals(1, transLines.size(), 'Should have 1 transaction line for agent search list');
        System.assertEquals(40.0, transLines[0].Amount__c, 'Transaction line amount should be 40.0');
    }

    @isTest
    static void testCreatePaymentWithInitialFiling() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'NBR Form',
            'caseId' => testCase.Id,
            'documentType' => 'Articles of Incorporation',
            'quantity' => 1,
            'unitPrice' => 75.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 75.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Case__c, Amount__c
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId AND breg_Case__c = :testCase.Id
        ];
        System.assertEquals(1, transLines.size(), 'Should have 1 transaction line for initial filing');
        System.assertEquals(75.0, transLines[0].Amount__c, 'Transaction line amount should be 75.0');
    }

    @isTest
    static void testCreatePaymentSkipPaymentCreation() {
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Entity List',
            'entityListId' => [SELECT Id FROM breg_Entity_List__c LIMIT 1]
            .Id,
            'documentType' => 'Entity List',
            'quantity' => 1,
            'unitPrice' => 50.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id transactionId = BREGPaymentController.createPayment((Double) 50.0, cartItemsJson, deliveryDetailsJson, true);
        Test.stopTest();

        System.assertNotEquals(null, transactionId, 'Transaction ID should not be null');

        Transaction__c trans = [SELECT Id, PaymentAmount__c FROM Transaction__c WHERE Id = :transactionId];
        System.assertEquals((Double) 50.0, trans.PaymentAmount__c, 'Transaction amount should be 50.0');
    }

    @isTest
    static void testGetTransactionLineWrappersDocumentDownloadable() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        List<TransactionLine__c> transLines = BREGPaymentController.getTransactionLines(new Set<Id>{ payment.Id });

        Test.startTest();
        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transLines);
        Test.stopTest();

        System.assertNotEquals(null, wrappers, 'Wrappers should not be null');
        System.assertEquals(3, wrappers.size(), 'Should have 3 wrappers');

        // Check document wrapper
        BREGPaymentController.TransactionLineWrapper docWrapper = null;
        for (BREGPaymentController.TransactionLineWrapper w : wrappers) {
            if (w.isDocumentRelated && !w.isEntityListDocument && !w.isAgentSearchList) {
                docWrapper = w;
                break;
            }
        }
        System.assertNotEquals(null, docWrapper, 'Document wrapper should exist');
        System.assertEquals(true, docWrapper.isDocumentRelated, 'Should be document related');
        System.assertNotEquals(null, docWrapper.downloadableDocuments, 'Downloadable documents should not be null');
        System.assertEquals(true, docWrapper.isAvailableToDownload, 'Document should be available to download');
        System.assertEquals(1, docWrapper.downloadableDocuments.size(), 'Should have 1 downloadable document');
        System.assertNotEquals(null, docWrapper.downloadableDocuments[0].docusignDocumentId, 'DocuSign document ID should not be null');
        System.assertNotEquals(null, docWrapper.downloadableDocuments[0].name, 'Document name should not be null');
    }

    @isTest
    static void testGetInitialFilingDocument() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        BREGPaymentController.DocumentInfo beforeGeneration = BREGPaymentController.getInitialFilingDocument(testCase.Id);

        insert new breg_Document__c(
            Name = 'Test Corporation - Initial Filing.pdf',
            breg_Case__c = testCase.Id,
            breg_Is_Public__c = true,
            breg_Is_Irrelevant__c = false,
            breg_Type__c = 'Digital',
            breg_Docusign_Document_Id__c = 'initial-filing-docusign-id'
        );

        BREGPaymentController.DocumentInfo afterGeneration = BREGPaymentController.getInitialFilingDocument(testCase.Id);
        BREGPaymentController.DocumentInfo nullCaseResult = BREGPaymentController.getInitialFilingDocument(null);
        Test.stopTest();

        System.assertEquals(null, beforeGeneration, 'Should return null before the Initial Filing document exists');
        System.assertNotEquals(null, afterGeneration, 'Should find the Initial Filing document once generated');
        System.assertEquals('initial-filing-docusign-id', afterGeneration.docusignDocumentId, 'Should return the matching DocuSign document Id');
        System.assertEquals('Test Corporation - Initial Filing.pdf', afterGeneration.name, 'Should return the document name');
        System.assertEquals(null, nullCaseResult, 'Should return null when caseId is null');
    }

    // Covers: getCashierCodeIdToFeeId, getFeeIdForTransactionLineItem (direct fee already on line)
    @isTest
    static void testGetTransactionLineWrappersEntityList() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        List<TransactionLine__c> transLines = BREGPaymentController.getTransactionLines(new Set<Id>{ payment.Id });

        Test.startTest();
        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transLines);
        Test.stopTest();

        // Check entity list wrapper
        BREGPaymentController.TransactionLineWrapper entityListWrapper = null;
        for (BREGPaymentController.TransactionLineWrapper w : wrappers) {
            if (w.isEntityListDocument) {
                entityListWrapper = w;
                break;
            }
        }
        System.assertNotEquals(null, entityListWrapper, 'Entity list wrapper should exist');
        System.assertEquals(true, entityListWrapper.isEntityListDocument, 'Should be entity list document');
        System.assertEquals('Digital', entityListWrapper.documentType, 'Document type should be Digital');
        System.assertEquals('Email', entityListWrapper.deliveryMethod, 'Delivery method should be Email');
    }

    @isTest
    static void testGetTransactionLineWrappersAgentSearchList() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        List<TransactionLine__c> transLines = BREGPaymentController.getTransactionLines(new Set<Id>{ payment.Id });

        Test.startTest();
        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transLines);
        Test.stopTest();

        // Check agent search list wrapper
        BREGPaymentController.TransactionLineWrapper agentWrapper = null;
        for (BREGPaymentController.TransactionLineWrapper w : wrappers) {
            if (w.isAgentSearchList) {
                agentWrapper = w;
                break;
            }
        }
        System.assertNotEquals(null, agentWrapper, 'Agent search list wrapper should exist');
        System.assertEquals(true, agentWrapper.isAgentSearchList, 'Should be agent search list');
        System.assertEquals('Digital', agentWrapper.documentType, 'Document type should be Digital');
        System.assertEquals('Email', agentWrapper.deliveryMethod, 'Delivery method should be Email');
    }

    @isTest
    static void testGetTransactionLineWrappersMultiplePublicDocuments() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Transaction__c trans = [SELECT Id FROM Transaction__c LIMIT 1];

        // Add a second public document linked to the same case
        breg_Document__c secondDocument = new breg_Document__c(
            Name = 'Second Public Document',
            breg_Account__c = acc.Id,
            breg_Case__c = testCase.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0,
            breg_Docusign_Document_Id__c = 'second-docusign-id'
        );
        insert secondDocument;

        Test.startTest();
        // Create a transaction line linked only to the case (not directly to a document)
        // so getCaseIdToDocumentMap is exercised for multiple docs
        TransactionLine__c caseOnlyLine = new TransactionLine__c(
            breg_Case__c = testCase.Id,
            Transaction__c = trans.Id,
            Payment__c = payment.Id,
            Description__c = 'Case Only Line',
            breg_Quantity__c = 1,
            breg_Unit_Price__c = 10.00,
            Amount__c = 10.00,
            breg_Type__c = 'Document',
            PaidStatus__c = 'Paid'
        );
        insert caseOnlyLine;

        List<TransactionLine__c> transLines = BREGPaymentController.getTransactionLines(new Set<Id>{ payment.Id });
        BREGPaymentController.TransactionLineWrapper caseOnlyWrapper = null;

        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transLines);
        Test.stopTest();

        for (BREGPaymentController.TransactionLineWrapper w : wrappers) {
            if (w.description == 'Case Only Line') {
                caseOnlyWrapper = w;
                break;
            }
        }

        System.assertNotEquals(null, caseOnlyWrapper, 'Case-only wrapper should exist');
        System.assertEquals(true, caseOnlyWrapper.isAvailableToDownload, 'Should be available to download');
        System.assertNotEquals(null, caseOnlyWrapper.downloadableDocuments, 'Downloadable documents should not be null');
        System.assertEquals(2, caseOnlyWrapper.downloadableDocuments.size(), 'Should have 2 downloadable documents for the case');
    }

    @isTest
    static void testGetTransactionLineWrappersExpiredEntityList() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Transaction__c trans = [SELECT Id FROM Transaction__c LIMIT 1];

        breg_Entity_List_Result__c expiredResult = new breg_Entity_List_Result__c(
            breg_Entity_List__c = [SELECT Id FROM breg_Entity_List__c LIMIT 1].Id,
            breg_Docusign_Document_Id__c = 'expired-entity-list-doc-id',
            breg_Expiration_Date__c = Date.today().addDays(-5)
        );
        insert expiredResult;

        breg_Document__c expiredDoc = new breg_Document__c(
            Name = 'Expired Entity List Document',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0,
            breg_Docusign_Document_Id__c = 'expired-entity-list-doc-id'
        );
        insert expiredDoc;

        Test.startTest();
        TransactionLine__c expiredLine = new TransactionLine__c(
            breg_Document__c = expiredDoc.Id,
            Transaction__c = trans.Id,
            Payment__c = payment.Id,
            Description__c = 'Expired Entity List',
            breg_Quantity__c = 1,
            breg_Unit_Price__c = 10.00,
            Amount__c = 10.00,
            breg_Type__c = 'Entity List',
            PaidStatus__c = 'Paid'
        );
        insert expiredLine;

        List<TransactionLine__c> transLines = BREGPaymentController.getTransactionLines(new Set<Id>{ payment.Id });
        BREGPaymentController.TransactionLineWrapper expiredWrapper = null;

        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transLines);
        Test.stopTest();

        for (BREGPaymentController.TransactionLineWrapper w : wrappers) {
            if (w.description == 'Expired Entity List') {
                expiredWrapper = w;
                break;
            }
        }

        System.assertNotEquals(null, expiredWrapper, 'Expired entity list wrapper should exist');
        System.assertEquals(false, expiredWrapper.isAvailableToDownload, 'Expired entity list document should not be available to download');
        System.assertEquals(0, expiredWrapper.downloadableDocuments.size(), 'Downloadable documents should be empty for expired entity list');
    }

    // Mock HTTP Response for DocuSign API
    private class MockDocuSignHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBody('Mock PDF content');
            res.setStatusCode(200);
            return res;
        }
    }

    // Mock HTTP Response for DocuSign API Error
    private class MockDocuSignHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Document not found"}');
            res.setStatusCode(404);
            return res;
        }
    }

    @isTest
    static void testCreatePaymentWithCOGSDocument() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create a COGS template document
        breg_Document__c cogsTemplate = new breg_Document__c(
            Name = 'COGS Template',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 7.5,
            breg_Is_Certificate_Of_Good_Standing__c = true
        );
        insert cogsTemplate;

        // Create cart items JSON for COGS
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Document',
            'id' => acc.Id +
            '_' +
            cogsTemplate.Id,
            'documentType' => 'COGS - Certificate of Good Standing',
            'companyName' => 'Test Corporation',
            'format' => 'Digital',
            'quantity' => 1,
            'unitPrice' => 7.5,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);

        // Create delivery details JSON
        Map<String, Object> deliveryDetails = new Map<String, Object>{
            'contact' => new Map<String, Object>{ 'FirstName' => 'Jane', 'LastName' => 'Smith', 'Email' => 'jane.smith@test.com' }
        };
        String deliveryDetailsJson = JSON.serialize(deliveryDetails);

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 7.5, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        // Verify new COGS document was created
        List<breg_Document__c> cogsDocuments = [
            SELECT Id, breg_Template_Document__c, breg_Is_Certificate_Of_Good_Standing__c, breg_Delivery_Email__c
            FROM breg_Document__c
            WHERE breg_Template_Document__c = :cogsTemplate.Id
        ];
        System.assertEquals(1, cogsDocuments.size(), 'A new COGS document should be created');
        System.assertEquals('jane.smith@test.com', cogsDocuments[0].breg_Delivery_Email__c, 'Delivery email should be set');
    }

    @isTest
    static void testCreatePaymentWithCOGSPrinted() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create a COGS template document
        breg_Document__c cogsTemplate = new breg_Document__c(
            Name = 'COGS Template Printed',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Printed',
            breg_Price__c = 7.5,
            breg_Is_Certificate_Of_Good_Standing__c = true
        );
        insert cogsTemplate;

        // Create cart items JSON for COGS Printed
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Document',
            'id' => acc.Id +
            '_' +
            cogsTemplate.Id,
            'documentType' => 'COGS - Certificate of Good Standing (Printed)',
            'companyName' => 'Test Corporation',
            'format' => 'Printed',
            'quantity' => 1,
            'unitPrice' => 7.5,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);

        // Create delivery details JSON
        Map<String, Object> deliveryDetails = new Map<String, Object>{
            'contact' => new Map<String, Object>{ 'FirstName' => 'John', 'LastName' => 'Doe', 'Email' => 'john.doe@test.com' }
        };
        String deliveryDetailsJson = JSON.serialize(deliveryDetails);

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 7.5, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        // Verify COGS document type is set to Printed
        List<breg_Document__c> cogsDocuments = [
            SELECT Id, breg_Type__c, breg_Availability__c
            FROM breg_Document__c
            WHERE breg_Template_Document__c = :cogsTemplate.Id
        ];
        System.assertEquals(1, cogsDocuments.size(), 'A new COGS document should be created');
        System.assertEquals('Printed', cogsDocuments[0].breg_Type__c, 'Document type should be Printed');
        System.assertEquals('Available by Mail or Pickup', cogsDocuments[0].breg_Availability__c, 'Availability should be set for printed');
    }

    @isTest
    static void testCreatePaymentWithCertifiedDocument() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];
        breg_Fee__c certifyFee = new breg_Fee__c(
            breg_Record_Type__c = '	Agent List',
            breg_Fee_Amount__c = 5.00,
            breg_Purchase_Type_Fee_type__c = 'Document',
            breg_Cashier_Code__c = 'B71'
        );
        insert certifyFee;

        // Create a document available in 7 business days
        breg_Document__c templateDoc = new breg_Document__c(
            Name = 'Template Document',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available in 7 business days',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0,
            breg_Available_To_Certify__c = true
        );
        insert templateDoc;

        // Create cart items JSON for certified document
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        String baseDocumentItemId = acc.Id + '_' + templateDoc.Id;
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Document',
            'id' => baseDocumentItemId,
            'documentType' => 'Test Document',
            'companyName' => 'Test Corporation',
            'format' => 'Digital',
            'quantity' => 2,
            'unitPrice' => 10.0,
            'isCertified' => true,
            'certifyPrice' => 5.0,
            'feeId' => fee.Id,
            'certifyFeeId' => certifyFee.Id
        };
        cartItems.add(cartItem);
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Document',
                'documentType' => 'Certified Copy Fee',
                'parentItemId' => baseDocumentItemId,
                'quantity' => 2,
                'unitPrice' => 5.0,
                'feeId' => certifyFee.Id
            }
        );
        String cartItemsJson = JSON.serialize(cartItems);

        // Create delivery details JSON with address
        Map<String, Object> deliveryDetails = new Map<String, Object>{
            'contact' => new Map<String, Object>{ 'FirstName' => 'Jane', 'LastName' => 'Smith', 'Email' => 'jane.smith@example.com' },
            'phone' => '808-555-9999',
            'deliveryAddress' => new Map<String, Object>{
                'street' => '789 Test St',
                'street2' => 'Apt 5',
                'city' => 'Honolulu',
                'state' => 'HI',
                'postalCode' => '96813',
                'country' => 'US'
            }
        };
        String deliveryDetailsJson = JSON.serialize(deliveryDetails);

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 30.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        // Verify certified document was created
        List<breg_Document__c> certifiedDocs = [
            SELECT Id, breg_Is_Certified__c, breg_Is_Template_Copy__c, breg_Case__c, breg_Available_To_Certify__c
            FROM breg_Document__c
            WHERE breg_Template_Document__c = :templateDoc.Id
        ];
        System.assertEquals(1, certifiedDocs.size(), 'A certified document should be created');
        System.assertEquals(true, certifiedDocs[0].breg_Available_To_Certify__c, 'Document should be marked as available to certify');
        System.assertNotEquals(null, certifiedDocs[0].breg_Case__c, 'Case should be created for certified document');

        // Verify case was created with delivery address
        List<Case> cases = [
            SELECT Id, breg_Delivery_Method__c, breg_Delivery_Address__Street__s, breg_Delivery_Address__City__s
            FROM Case
            WHERE breg_Document__c = :certifiedDocs[0].Id
        ];
        System.assertEquals(1, cases.size(), 'A case should be created for certified document');

    }
    // ── createCOGSDocument unit tests ──────────────────────────────────────────

    // Covers: Account entity branch, Digital format, delivery contact populated
    @isTest
    static void testCreateCOGSDocument_AccountDigital() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Document__c templateDoc = new breg_Document__c(
            Name = 'COGS Template - Account Digital',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0
        );
        insert templateDoc;
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Contact deliveryContact = new Contact(FirstName = 'Alice', LastName = 'Walker', Email = 'alice@breg.test.com');

        Test.startTest();
        breg_Document__c result = BREGPaymentController.createCOGSDocument(
            'COGS - Digital',
            acc.Id,
            templateDoc.Id,
            'Digital',
            testCase.Id,
            deliveryContact
        );
        Test.stopTest();

        System.assertEquals(acc.Id, result.breg_Account__c, 'Account entity should be set on breg_Account__c');
        System.assertEquals(null, result.breg_TN_TM_SM__c, 'TN/TM/SM should not be set for an Account entity');
        System.assertEquals(templateDoc.Id, result.breg_Template_Document__c, 'Template document should be linked');
        System.assertEquals(testCase.Id, result.breg_Case__c, 'Case should be linked');
        System.assertEquals('COGS - Digital', result.Name, 'Name should match the argument');
        System.assertEquals('Available Now', result.breg_Availability__c, 'Digital format should set Available Now');
        System.assertEquals('Digital', result.breg_Type__c, 'Digital format should set type to Digital');
        System.assertEquals(true, result.breg_Is_Certificate_Of_Good_Standing__c, 'COGS flag should be true');
        System.assertEquals(true, result.breg_Is_Public__c, 'Document should be public');
        System.assertEquals('alice@breg.test.com', result.breg_Delivery_Email__c, 'Delivery email should come from contact');
        System.assertEquals('Alice Walker', result.breg_Annotation__c, 'Annotation should be first + last name');
    }

    // Covers: TN/TM/SM entity branch, Printed format
    @isTest
    static void testCreateCOGSDocument_TnTmSmPrinted() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_TN_TM_SM__c tradeName = new breg_TN_TM_SM__c(
            breg_Trade_Name__c = 'Test Trade Name',
            breg_File__c = 'TN-99999',
            breg_Type__c = 'Trade Name',
            breg_Status__c = 'A',
            breg_Registration_Date__c = Date.today(),
            breg_Start_Date__c = Date.today()
        );
        insert tradeName;

        breg_Document__c templateDoc = new breg_Document__c(
            Name = 'COGS Template - TN/TM/SM Printed',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available by Mail or Pickup',
            breg_Is_Public__c = true,
            breg_Type__c = 'Printed',
            breg_Price__c = 10.0
        );
        insert templateDoc;

        Contact deliveryContact = new Contact(FirstName = 'Bob', LastName = 'Stone', Email = 'bob@breg.test.com');

        Test.startTest();
        breg_Document__c result = BREGPaymentController.createCOGSDocument(
            'COGS - Printed',
            tradeName.Id,
            templateDoc.Id,
            'Printed',
            null,
            deliveryContact
        );
        Test.stopTest();

        System.assertEquals(tradeName.Id, result.breg_TN_TM_SM__c, 'TN/TM/SM entity should be set on breg_TN_TM_SM__c');
        System.assertEquals(null, result.breg_Account__c, 'breg_Account__c should not be set for a TN/TM/SM entity');
        System.assertEquals('Available by Mail or Pickup', result.breg_Availability__c, 'Printed format should set Available by Mail or Pickup');
        System.assertEquals('Printed', result.breg_Type__c, 'Printed format should set type to Printed');
        System.assertEquals(null, result.breg_Case__c, 'Case should be null when not supplied');
    }

    // Covers: null delivery contact (safe-navigation on all contact fields)
    @isTest
    static void testCreateCOGSDocument_NullContact() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Document__c templateDoc = new breg_Document__c(
            Name = 'COGS Template - Null Contact',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0
        );
        insert templateDoc;

        Test.startTest();
        breg_Document__c result = BREGPaymentController.createCOGSDocument(
            'COGS - No Contact',
            acc.Id,
            templateDoc.Id,
            'Digital',
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Method should return a document even with null contact');
        System.assertEquals(null, result.breg_Delivery_Email__c, 'Delivery email should be null when contact is null');
        // null?.FirstName + ' ' + null?.LastName → 'null null' is Apex's concatenation behaviour
        System.assertEquals('null null', result.breg_Annotation__c, 'Annotation should be null null when contact is null');
    }

    @isTest
    static void testCreatePaymentWithMailDelivery() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create a document available by mail or pickup
        breg_Document__c mailDoc = new breg_Document__c(
            Name = 'Mail Document',
            breg_Account__c = acc.Id,
            breg_Availability__c = 'Available by Mail or Pickup',
            breg_Is_Public__c = true,
            breg_Type__c = 'Printed',
            breg_Price__c = 10.0
        );
        insert mailDoc;

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Document',
            'id' => acc.Id +
            '_' +
            mailDoc.Id,
            'documentType' => 'Mail Document',
            'companyName' => 'Test Corporation',
            'format' => 'Printed',
            'quantity' => 1,
            'unitPrice' => 10.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);

        // Create delivery details JSON with address but no phone
        Map<String, Object> deliveryDetails = new Map<String, Object>{
            'contact' => new Map<String, Object>{ 'FirstName' => 'Mail', 'LastName' => 'Recipient', 'Email' => 'mail@example.com' },
            'deliveryAddress' => new Map<String, Object>{
                'street' => '123 Mail St',
                'city' => 'Honolulu',
                'state' => 'HI',
                'postalCode' => '96813',
                'country' => 'US'
            }
        };
        String deliveryDetailsJson = JSON.serialize(deliveryDetails);

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 10.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        // Verify case was created with mail delivery
        List<Case> cases = [
            SELECT Id, breg_Delivery_Method__c, breg_Delivery_Address__Street__s
            FROM Case
            WHERE breg_Document__c = :mailDoc.Id
        ];
        System.assertEquals(1, cases.size(), 'A case should be created');
        System.assertEquals('Mail To The Address', cases[0].breg_Delivery_Method__c, 'Delivery method should be mail when no phone');
        System.assertEquals('123 Mail St', cases[0].breg_Delivery_Address__Street__s, 'Delivery address should be set');
        
    }
    @isTest
    static void testCreatePaymentFallsBackToCaseContactForUserWithoutContact() {
        Case testCase = [SELECT Id, ContactId, Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone, Contact.MailingStreet, Contact.MailingCity, Contact.MailingState, Contact.MailingPostalCode, Contact.MailingCountry FROM Case LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];
        User internalUser = createInternalUserWithoutContact();

        String cartItemsJson = JSON.serialize(
            new List<Map<String, Object>>{
                new Map<String, Object>{ 'type' => 'NBR Form', 'caseId' => testCase.Id, 'documentType' => 'NBR Form', 'quantity' => 1, 'unitPrice' => 75.0, 'feeId' => fee.Id }
            }
        );

        Test.startTest();
        System.runAs(internalUser) {
            BREGPaymentController.allowPaymentContactFallbackInTests = true;
            Id paymentId = BREGPaymentController.createPayment((Double) 75.0, cartItemsJson, '{}', false);

            pymt__PaymentX__c payment = [
                SELECT
                    pymt__Contact__c,
                    pymt__Billing_First_Name__c,
                    pymt__Billing_Last_Name__c,
                    pymt__Billing_Email__c,
                    pymt__Billing_Phone__c,
                    pymt__Billing_Street__c,
                    pymt__Billing_City__c,
                    pymt__Billing_State__c,
                    pymt__Billing_Postal_Code__c,
                    pymt__Billing_Country__c
                FROM pymt__PaymentX__c
                WHERE Id = :paymentId
            ];

            System.assertEquals(testCase.ContactId, payment.pymt__Contact__c, 'Payment should be updated from the case contact when the current user has no contact');
            System.assertEquals(testCase.Contact.FirstName, payment.pymt__Billing_First_Name__c, 'Billing first name should come from the case contact');
            System.assertEquals(testCase.Contact.LastName, payment.pymt__Billing_Last_Name__c, 'Billing last name should come from the case contact');
            System.assertEquals(testCase.Contact.Email, payment.pymt__Billing_Email__c, 'Billing email should come from the case contact');
            System.assertEquals(testCase.Contact.Phone, payment.pymt__Billing_Phone__c, 'Billing phone should come from the case contact');
            System.assertEquals(testCase.Contact.MailingStreet, payment.pymt__Billing_Street__c, 'Billing street should come from the case contact');
            System.assertEquals(testCase.Contact.MailingCity, payment.pymt__Billing_City__c, 'Billing city should come from the case contact');
            System.assertEquals(testCase.Contact.MailingState != null ? testCase.Contact.MailingState : 'HI', payment.pymt__Billing_State__c, 'Billing state should come from the case contact with the same fallback as production code');
            System.assertEquals(testCase.Contact.MailingPostalCode, payment.pymt__Billing_Postal_Code__c, 'Billing postal code should come from the case contact');
            System.assertEquals(testCase.Contact.MailingCountry != null ? testCase.Contact.MailingCountry : 'US', payment.pymt__Billing_Country__c, 'Billing country should come from the case contact with the same fallback as production code');
            BREGPaymentController.allowPaymentContactFallbackInTests = false;
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePaymentKeepsGuestContactWhenFallbackCaseHasNoContact() {
        breg_Entity_List__c entityList = [SELECT Id FROM breg_Entity_List__c LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];
        Contact guestContact = [SELECT Id FROM Contact WHERE Email = 'guest@breg.test.com' LIMIT 1];
        User internalUser = createInternalUserWithoutContact();

        String cartItemsJson = JSON.serialize(
            new List<Map<String, Object>>{
                new Map<String, Object>{ 'type' => 'Entity List', 'entityListId' => entityList.Id, 'documentType' => 'Entity List', 'quantity' => 1, 'unitPrice' => 50.0, 'feeId' => fee.Id }
            }
        );

        Test.startTest();
        System.runAs(internalUser) {
            BREGPaymentController.allowPaymentContactFallbackInTests = true;
            Id paymentId = BREGPaymentController.createPayment((Double) 75.0, cartItemsJson, '{}', false);

            pymt__PaymentX__c payment = [SELECT pymt__Contact__c FROM pymt__PaymentX__c WHERE Id = :paymentId];
            System.assertEquals(guestContact.Id, payment.pymt__Contact__c, 'Payment should keep the guest/default contact when no case contact is available for fallback');
            BREGPaymentController.allowPaymentContactFallbackInTests = false;
        }
        Test.stopTest();
    }

    private static User createInternalUserWithoutContact() {
        Profile internalProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueValue = String.valueOf(DateTime.now().getTime());

        User internalUser = new User(
            LastName = 'BREG Payment Test User',
            Alias = 'bpmtst',
            Email = 'breg.payment.' + uniqueValue + '@example.com',
            Username = 'breg.payment.' + uniqueValue + '@example.com.test',
            CommunityNickname = 'bpmtst' + uniqueValue,
            ProfileId = internalProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert internalUser;
        return internalUser;
    }

    @isTest
    static void testContactParsingWithExistingEmail() {
        Contact existingContact = [SELECT Id, Email FROM Contact WHERE Email = 'john.doe@test.com' LIMIT 1];

        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Entity List',
            'entityListId' => [SELECT Id FROM breg_Entity_List__c LIMIT 1]
            .Id,
            'documentType' => 'Entity List',
            'quantity' => 1,
            'unitPrice' => 50.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);

        // Use existing contact email
        Map<String, Object> deliveryDetails = new Map<String, Object>{
            'contact' => new Map<String, Object>{ 'FirstName' => 'Different', 'LastName' => 'Name', 'Email' => 'john.doe@test.com' }
        };
        String deliveryDetailsJson = JSON.serialize(deliveryDetails);

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 50.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        // Verify no new contact was created
        Integer contactCount = [SELECT COUNT() FROM Contact WHERE Email = 'john.doe@test.com'];
        System.assertEquals(1, contactCount, 'Should still have only one contact with this email');
    }

    @isTest
    static void testCreatePaymentWithInvalidDocumentId() {
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create cart items JSON with invalid ID format
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        Map<String, Object> cartItem = new Map<String, Object>{
            'type' => 'Document',
            'id' => 'invalid-id-format',
            'documentType' => 'Test Document',
            'quantity' => 1,
            'unitPrice' => 10.0,
            'feeId' => fee.Id
        };
        cartItems.add(cartItem);
        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 10.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null even with invalid doc ID');
    }

    @isTest
    static void testGetTransactionLineWrappersWithExpiredDocument() {
        pymt__PaymentX__c payment = [SELECT Id FROM pymt__PaymentX__c LIMIT 1];

        // Create a transaction line with an expired entity list document
        breg_Entity_List__c expiredList = new breg_Entity_List__c(breg_Status__c = 'All');
        insert expiredList;

        breg_Entity_List_Result__c expiredResult = new breg_Entity_List_Result__c(
            breg_Entity_List__c = expiredList.Id,
            breg_Docusign_Document_Id__c = 'expired-doc-id',
            breg_Expiration_Date__c = Date.today().addDays(-5)
        );
        insert expiredResult;

        breg_Document__c expiredDoc = new breg_Document__c(
            Name = 'Expired Document',
            breg_Account__c = [SELECT Id FROM Account LIMIT 1]
            .Id,
            breg_Availability__c = 'Available Now',
            breg_Is_Public__c = true,
            breg_Type__c = 'Digital',
            breg_Price__c = 10.0,
            breg_Docusign_Document_Id__c = 'expired-doc-id'
        );
        insert expiredDoc;

        TransactionLine__c expiredTransLine = new TransactionLine__c();
        expiredTransLine.breg_Document__c = expiredDoc.Id;
        expiredTransLine.Transaction__c = [SELECT Id FROM Transaction__c LIMIT 1].Id;
        expiredTransLine.Payment__c = payment.Id;
        expiredTransLine.Description__c = 'Expired Document';
        expiredTransLine.breg_Quantity__c = 1;
        expiredTransLine.breg_Unit_Price__c = 10.00;
        expiredTransLine.Amount__c = 10.00;
        expiredTransLine.breg_Type__c = 'Document';
        expiredTransLine.PaidStatus__c = 'Paid';
        insert expiredTransLine;

        Test.startTest();
        List<TransactionLine__c> transLines = [
            SELECT
                Id,
                Description__c,
                Amount__c,
                Payment__c,
                breg_Quantity__c,
                breg_Unit_Price__c,
                breg_Fee__c,
                breg_Entity_List__c,
                breg_Type__c,
                breg_Case__c,
                breg_Document__c,
                breg_Document__r.Name,
                breg_Document__r.breg_Availability__c,
                breg_Document__r.breg_Docusign_Document_Id__c,
                breg_Document__r.breg_Is_Public__c,
                breg_Document__r.breg_Type__c,
                breg_Document__r.CreatedDate,
                breg_Document__r.breg_Account__c,
                breg_Document__r.breg_Annual__r.breg_Account__c,
                breg_Document__r.breg_TN_TM_SM__c,
                breg_Document__r.breg_Account__r.Name,
                breg_Case__r.Subject,
                breg_Case__r.breg_Delivery_Method__c,
                breg_Case__r.breg_Workitem_Number__c,
                breg_Case__r.Status,
                breg_Case__r.breg_Form_Configuration__r.breg_Form_Name__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Form_Code__c,
                breg_Case__r.breg_Form_Action__c,
                breg_Case__r.breg_Annual__r.breg_Account__c,
                breg_Case__r.breg_Portal_User_Entity_Selected__c,
                breg_Case__r.breg_Entity__c,
                breg_Case__r.breg_TN_TM_SM__c,
                Transaction__c,
                Transaction__r.Date__c
            FROM TransactionLine__c
            WHERE Id = :expiredTransLine.Id
        ];
        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transLines);
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'Should have 1 wrapper');
        // breg_Type__c = 'Document' (not 'Entity List'), so expiration check does not apply — document is downloadable
        System.assertEquals(true, wrappers[0].isAvailableToDownload, 'Non-entity-list document should be available to download regardless of expiration');
        System.assertNotEquals(null, wrappers[0].downloadableDocuments, 'Downloadable documents list should not be null');
        System.assertEquals(1, wrappers[0].downloadableDocuments.size(), 'Should have 1 downloadable document');
    }

    @isTest
    static void testCreatePaymentWithOtherFormTypes() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Test TNTMSM Form
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        cartItems.add(
            new Map<String, Object>{
                'type' => 'TNTMSM Form',
                'caseId' => testCase.Id,
                'documentType' => 'TN/TM/SM Filing',
                'quantity' => 1,
                'unitPrice' => 50.0,
                'feeId' => fee.Id
            }
        );
        // Test Change Form
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Change Form',
                'caseId' => testCase.Id,
                'documentType' => 'Change Form',
                'quantity' => 1,
                'unitPrice' => 25.0,
                'feeId' => fee.Id
            }
        );
        // Test Annual Form
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Annual Form',
                'caseId' => testCase.Id,
                'documentType' => 'Annual Filing',
                'quantity' => 1,
                'unitPrice' => 15.0,
                'feeId' => fee.Id
            }
        );
        // Test Name Reservation Form
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Name Reservation Form',
                'caseId' => testCase.Id,
                'documentType' => 'Name Reservation',
                'quantity' => 1,
                'unitPrice' => 10.0,
                'feeId' => fee.Id
            }
        );
        // Test CRA Registration Form
        cartItems.add(
            new Map<String, Object>{
                'type' => 'CRA Registration Form',
                'caseId' => testCase.Id,
                'documentType' => 'CRA Registration',
                'quantity' => 1,
                'unitPrice' => 20.0,
                'feeId' => fee.Id
            }
        );

        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 120.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Case__c
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId
        ];
        System.assertEquals(5, transLines.size(), 'Should have 5 transaction lines for different form types');
    }

    @isTest
    static void testCreatePaymentWithMultipleCartItems() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        breg_Entity_List__c entityList = [SELECT Id FROM breg_Entity_List__c LIMIT 1];
        breg_Agent_Search_List__c agentSearchList = [SELECT Id FROM breg_Agent_Search_List__c LIMIT 1];
        breg_Fee__c fee = [SELECT Id FROM breg_Fee__c LIMIT 1];

        // Create multiple cart items of different types
        List<Map<String, Object>> cartItems = new List<Map<String, Object>>();
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Document',
                'id' => acc.Id +
                '_' +
                doc.Id,
                'documentType' => 'Document 1',
                'companyName' => 'Test Corp',
                'quantity' => 1,
                'unitPrice' => 10.0,
                'feeId' => fee.Id
            }
        );
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Entity List',
                'entityListId' => entityList.Id,
                'documentType' => 'Entity List',
                'quantity' => 1,
                'unitPrice' => 50.0,
                'feeId' => fee.Id
            }
        );
        cartItems.add(
            new Map<String, Object>{
                'type' => 'Agent Search List',
                'agentSearchListId' => agentSearchList.Id,
                'documentType' => 'Agent Search',
                'quantity' => 1,
                'unitPrice' => 40.0,
                'feeId' => fee.Id
            }
        );
        cartItems.add(
            new Map<String, Object>{
                'type' => 'NBR Form',
                'caseId' => testCase.Id,
                'documentType' => 'NBR Form',
                'quantity' => 1,
                'unitPrice' => 75.0,
                'feeId' => fee.Id
            }
        );

        String cartItemsJson = JSON.serialize(cartItems);
        String deliveryDetailsJson = '{}';

        Test.startTest();
        Id paymentId = BREGPaymentController.createPayment((Double) 175.0, cartItemsJson, deliveryDetailsJson, false);
        Test.stopTest();

        System.assertNotEquals(null, paymentId, 'Payment ID should not be null');

        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Type__c
            FROM TransactionLine__c
            WHERE Payment__c = :paymentId
        ];
        System.assertEquals(4, transLines.size(), 'Should have 4 transaction lines');
    }
}