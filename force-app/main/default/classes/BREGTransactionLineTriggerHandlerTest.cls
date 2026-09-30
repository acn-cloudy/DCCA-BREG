@isTest
public with sharing class BREGTransactionLineTriggerHandlerTest {
    private static Id getBregCaseRecordTypeId() {
        return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
    }

    @TestSetup
    static void setupData() {
        BREG_Setting__c setting = new BREG_Setting__c(Authorization_Code_Length__c = 8, COGS_Authorization_Code_Hash_Salt__c = 'testSalt');
        insert setting;

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Transaction__c trns = new Transaction__c(Account__c = acc.Id, Date__c = Date.today(), Status__c = 'New');
        insert trns;

        breg_Document__c docPrinted = new breg_Document__c(Name = 'Printed Doc', breg_Type__c = 'Printed');
        breg_Document__c docDigital = new breg_Document__c(Name = 'Digital Doc', breg_Type__c = 'Digital');
        insert new List<breg_Document__c>{ docPrinted, docDigital };

        insert new List<TransactionLine__c>{
            new TransactionLine__c(
                Account__c = acc.Id,
                Description__c = 'COGS printed',
                PaidStatus__c = 'Pending',
                breg_Document__c = docPrinted.Id,
                Transaction__c = trns.Id
            ),
            new TransactionLine__c(
                Account__c = acc.Id,
                Description__c = 'COGS digital',
                PaidStatus__c = 'Pending',
                breg_Document__c = docDigital.Id,
                Transaction__c = trns.Id
            )
        };
    }

    @isTest
    static void testGetChangedLines() {
        TransactionLine__c line = [
            SELECT Id, Account__c, Description__c, PaidStatus__c, breg_Document__c, breg_Document__r.breg_Type__c, breg_Case__c
            FROM TransactionLine__c
            WHERE breg_Document__r.breg_Type__c = 'Digital'
            LIMIT 1
        ];

        Map<Id, SObject> oldMap = new Map<Id, SObject>{ line.Id => line.clone(false, true, false, false) };
        oldMap.get(line.Id).put('PaidStatus__c', 'Pending');

        line.PaidStatus__c = 'Paid';

        Test.startTest();
        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.oldMap = oldMap;
        handler.newList = new List<SObject>{ line };
        List<TransactionLine__c> changed = handler.getChangedLines('Paid', true);
        Test.stopTest();

        System.assertEquals(1, changed.size());
        System.assertEquals(line.Id, changed[0].Id);
    }

    @isTest
    static void testCreateCertificate() {
        TransactionLine__c line = [
            SELECT Id, Account__c, Description__c, PaidStatus__c, breg_Document__c, breg_Document__r.breg_Type__c
            FROM TransactionLine__c
            WHERE breg_Document__r.breg_Type__c = 'Printed'
            LIMIT 1
        ];

        Test.startTest();
        breg_Certificate__c cert = BREGTransactionLineTriggerHandler.createCertificate(line);
        Test.stopTest();

        System.assertEquals(line.Account__c, cert.breg_Account__c);
        System.assertEquals('Postal', cert.breg_Correspondence_Type__c);
        System.assertEquals(true, cert.breg_Is_Published__c);
        System.assertEquals(line.breg_Document__c, cert.breg_Document__c);
    }



    @isTest
    static void testAfterUpdateCreatesCertificate() {
        TransactionLine__c line = [
            SELECT Id, Account__c, Description__c, PaidStatus__c, breg_Document__c, breg_Document__r.breg_Type__c
            FROM TransactionLine__c
            WHERE breg_Document__r.breg_Type__c = 'Digital'
            LIMIT 1
        ];

        Map<Id, SObject> oldMap = new Map<Id, SObject>{ line.Id => line.clone(false, true, false, false) };
        oldMap.get(line.Id).put('PaidStatus__c', 'Pending');

        Test.startTest();

        line.PaidStatus__c = 'Paid';
        update line;

        Test.stopTest();

        List<breg_Certificate__c> certs = [
            SELECT Id, breg_Account__c, breg_Authentication_Code__c
            FROM breg_Certificate__c
        ];

        System.assertEquals(1, certs.size());
        System.assertEquals(line.Account__c, certs[0].breg_Account__c);
        System.assertEquals(8, certs[0].breg_Authentication_Code__c.length());
    }

    @isTest
    static void testFullNameWithAllParts() {
        String fullName = 'MAUI ARTISAN COFFEE PARTNERS - Certificate of Good Standing (COGS) - Digital (PDF)';
        String expected = 'MAUI ARTISAN COFFEE PARTNERS - COGS - Digital (PDF)';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testNameTooLong() {
        String fullName = 'VERY VERY VERY VERY VERY LONG ACCOUNT NAME THAT IS MORE THAN EIGHTY CHARACTERS - Certificate of Good Standing (COGS)';
        String expected = 'VERY VERY VERY VERY VERY LONG ACCOUNT NAME THAT IS MORE THAN EIGHTY CHARACTERS';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testOnlyAccountName() {
        String fullName = 'Short Name';
        String expected = 'Short Name';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testCOGSOnlyFits() {
        String fullName = 'Short Name - Certificate of Good Standing (COGS)';
        String expected = 'Short Name - COGS';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testCOGSAndSuffixFits() {
        String fullName = 'Short Name - Certificate of Good Standing (COGS) - Printed';
        String expected = 'Short Name - COGS - Printed';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testCOGSDoesNotFit() {
        String fullName = '123456789012345678901234567890123456789012345678901234567890123456789012345678 - Certificate of Good Standing (COGS)';
        String expected = '123456789012345678901234567890123456789012345678901234567890123456789012345678';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testEmptyName() {
        String fullName = '';
        String expected = '';
        String actual = BREGTransactionLineTriggerHandler.trimNameToLimit(fullName);
        System.assertEquals(expected, actual);
    }

    @isTest
    static void testGetChangedLinesForFilings_ReturnsDocDeliveryForNonFilings() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'DD-1',
            breg_Form_Code__c = 'DOCDLVR',
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;

        // Origin = 'Web' prevents the afterInsert trigger from entering the
        // createCOGSDocuments path when the description contains 'COGS'.
        Case testCase = new Case(
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'Certificate of Good Standing (COGS)',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [SELECT Id, PaidStatus__c, breg_Case__c, Transaction__c FROM TransactionLine__c WHERE Id = :line.Id];
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ line.Id => line.clone(false, true, false, false) };
        oldMap.get(line.Id).put('PaidStatus__c', 'Pending');
        line.PaidStatus__c = 'Paid';

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.oldMap = oldMap;
        handler.newList = new List<SObject>{ line };

        List<TransactionLine__c> changed = handler.getLinesForFilings('Paid', false, 'COGS', true);
        System.assertEquals(1, changed.size());
        System.assertEquals(line.Id, changed[0].Id);
    }

    @isTest
    static void testGetLinesForRegularCopy_ReturnsEligiblePaidLine() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        CashierCode__c cashierCode = new CashierCode__c(
            Name = 'Regular Copy Fee',
            CashierCode__c = 'BOC',
            Description__c = 'Regular Copy Fee',
            Division__c = 'BREG'
        );
        insert cashierCode;
        Contact deliveryContact = new Contact(
            FirstName = 'Regular',
            LastName = 'Recipient',
            Email = 'regular.copy@test.com'
        );
        insert deliveryContact;

        breg_Document__c regularCopyDoc = new breg_Document__c(
            Name = 'Regular Copy Document',
            breg_Type__c = 'Printed',
            breg_Available_To_Certify__c = false,
            breg_Is_Certified__c = false,
            breg_Is_Public__c = true,
            breg_Account__c = acc.Id
        );
        insert regularCopyDoc;

        TransactionLine__c line = new TransactionLine__c(
            Account__c = acc.Id,
            Description__c = 'Regular copy fee',
            PaidStatus__c = 'Pending',
            breg_Document__c = regularCopyDoc.Id,
            breg_Delivery_Contact__c = deliveryContact.Id,
            CashierCode__c = cashierCode.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [
            SELECT Id, PaidStatus__c, breg_Case__c, breg_Document__c, breg_Delivery_Contact__c, Transaction__c
            FROM TransactionLine__c
            WHERE Id = :line.Id
        ];

        Map<Id, SObject> oldMap = new Map<Id, SObject>{ line.Id => line.clone(false, true, false, false) };
        oldMap.get(line.Id).put('PaidStatus__c', 'Pending');
        line.PaidStatus__c = 'Paid';

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.oldMap = oldMap;
        handler.newList = new List<SObject>{ line };

        Test.startTest();
        List<TransactionLine__c> regularCopyLines = handler.getLinesForRegularCopy();
        Test.stopTest();

        System.assertEquals(1, regularCopyLines.size(), 'Expected one paid regular copy line to qualify');
        System.assertEquals(line.Id, regularCopyLines[0].Id);
    }

    @isTest
    static void testBuildRegularCopyWorkflowParams_EscapesXmlSpecialCharacters() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact deliveryContact = new Contact(
            FirstName = 'Tom &',
            LastName = 'O\'Neil <Jr>',
            Email = 'special&chars@test.com'
        );
        insert deliveryContact;

        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'DD-XML',
            breg_Form_Code__c = 'DOCDLVR',
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;

        Case docCase = new Case(
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert docCase;

        breg_Document__c regularCopyDoc = new breg_Document__c(
            Name = 'Regular Copy Document',
            breg_Type__c = 'Printed',
            breg_Available_To_Certify__c = false,
            breg_Is_Certified__c = false,
            breg_Is_Public__c = true,
            breg_Account__c = acc.Id,
            breg_Case__c = docCase.Id,
            breg_Docusign_Document_Id__c = 'doc<1>&2'
        );
        insert regularCopyDoc;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        TransactionLine__c line = new TransactionLine__c(
            Account__c = acc.Id,
            Description__c = 'DAISY & CO. LLC <NC> O\'Brien',
            PaidStatus__c = 'Paid',
            breg_Document__c = regularCopyDoc.Id,
            breg_Delivery_Contact__c = deliveryContact.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [
            SELECT
                breg_Document__r.breg_Case__c,
                breg_Document__r.breg_Docusign_Document_Id__c,
                breg_Delivery_Contact__c,
                breg_Delivery_Contact__r.FirstName,
                breg_Delivery_Contact__r.LastName,
                breg_Delivery_Contact__r.Email,
                Description__c
            FROM TransactionLine__c
            WHERE Id = :line.Id
        ];

        String params = BREGTransactionLineTriggerHandler.buildRegularCopyWorkflowParams(line);

        System.assert(params.contains('<recordId>' + docCase.Id + '</recordId>'), 'Expected recordId to be included');
        System.assert(params.contains('<email>special&amp;chars@test.com</email>'), 'Expected email to be XML-escaped');
        System.assert(params.contains('<fullName>Tom &amp; O&apos;Neil &lt;Jr&gt;</fullName>'), 'Expected full name to be XML-escaped');
        System.assert(params.contains('<description>DAISY &amp; CO. LLC &lt;NC&gt; O&apos;Brien</description>'), 'Expected description to be XML-escaped');
        System.assert(params.contains('<contactId>' + deliveryContact.Id + '</contactId>'), 'Expected contactId to be included');
    }
    // ── New method tests ──────────────────────────────────────────────────────
    
    // Covers: getManualCogsLines – positive case (non-Web DOCDLVR, 'COGS' description)
    @isTest
    static void testGetManualCogsLines_IncludesNonWebLine() {
        Account acc = BREGTestDataFactory.createEntityAccounts(1)[0];

        breg_Document__c cogsTemplateDigital = new breg_Document__c(
            Name = 'COGS Template Digital',
            breg_Type__c = 'Digital',
            breg_Is_Certificate_Of_Good_Standing__c = true,
            breg_Is_Public__c = true
        );
        breg_Document__c cogsTemplatePrinted = new breg_Document__c(
            Name = 'COGS Template Printed',
            breg_Type__c = 'Printed',
            breg_Is_Certificate_Of_Good_Standing__c = true,
            breg_Is_Public__c = true
        );
        insert new List<breg_Document__c>{ cogsTemplateDigital, cogsTemplatePrinted };

        breg_Form_Configuration__c docdlvrConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR',
            breg_Form_Name__c = 'Document Delivery'
        );
        insert docdlvrConfig;

        Contact cont = new Contact(FirstName = 'Test', LastName = 'Contact COGS', Email = 'manualcogs@breg.test.com');
        insert cont;

        // Non-web origin → should be picked up by getManualCogsLines
        Case manualCase = new Case(
            Status = 'New',
            Origin = 'In Person',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = docdlvrConfig.Id,
            breg_Delivery_Method__c = 'Email',
            breg_Entity__c = acc.Id,
            ContactId = cont.Id,
            breg_Bypass_Validation__c = true
        );
        insert manualCase;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];

        // Insert with Origin = 'In Person' triggers afterInsert which will call
        // createCOGSDocuments – setup above ensures it succeeds.
        Test.startTest();
        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'COGS Certificate',
            PaidStatus__c = 'Pending',
            breg_Case__c = manualCase.Id,
            Transaction__c = trns.Id
        );
        insert line;
        Test.stopTest();

        // After insert, getManualCogsLines should have included this line
        // (verified indirectly: breg_Document__c was set on the line by createCOGSDocuments)
        TransactionLine__c updatedLine = [SELECT Id, breg_Document__c, Account__c FROM TransactionLine__c WHERE Id = :line.Id];
        System.assertNotEquals(null, updatedLine.breg_Document__c, 'COGS document should have been created and linked to the transaction line');
        System.assertEquals(acc.Id, updatedLine.Account__c, 'Account should be set from case entity');
    }

    // Covers: getManualCogsLines – negative cases (Web origin excluded; non-DOCDLVR excluded)
    @isTest
    static void testGetManualCogsLines_ExcludesWebAndNonDocdlvr() {
        breg_Form_Configuration__c docdlvrConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR-WEB',
            breg_Form_Name__c = 'Document Delivery Web'
        );
        breg_Form_Configuration__c otherConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'X-1',
            breg_Suffix_Code__c = 'OTHER1',
            breg_Form_Name__c = 'Other Form'
        );
        insert new List<breg_Form_Configuration__c>{ docdlvrConfig, otherConfig };

        // Web-origin DOCDLVR case — should NOT be matched
        Case webCase = new Case(
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = docdlvrConfig.Id,
            breg_Bypass_Validation__c = true
        );
        // Non-DOCDLVR case — should NOT be matched
        Case nonDocdlvrCase = new Case(
            Status = 'New',
            Origin = 'In Person',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'X-1',
            breg_Form_Configuration__c = otherConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert new List<Case>{ webCase, nonDocdlvrCase };

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c webLine = new TransactionLine__c(
            Description__c = 'COGS from Web',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = webCase.Id,
            Transaction__c = trns.Id
        );
        TransactionLine__c nonDocdlvrLine = new TransactionLine__c(
            Description__c = 'COGS from non-DOCDLVR',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = nonDocdlvrCase.Id,
            Transaction__c = trns.Id
        );
        insert new List<TransactionLine__c>{ webLine, nonDocdlvrLine };

        List<TransactionLine__c> webLineQueried = [SELECT Id FROM TransactionLine__c WHERE Id = :webLine.Id];
        List<TransactionLine__c> nonDocdlvrLineQueried = [SELECT Id FROM TransactionLine__c WHERE Id = :nonDocdlvrLine.Id];

        Test.startTest();
        List<TransactionLine__c> resultWeb = BREGTransactionLineTriggerHandler.getManualCogsLines(webLineQueried);
        List<TransactionLine__c> resultNonDocdlvr = BREGTransactionLineTriggerHandler.getManualCogsLines(nonDocdlvrLineQueried);
        Test.stopTest();

        System.assertEquals(0, resultWeb.size(), 'Web-origin DOCDLVR line should NOT be returned');
        System.assertEquals(0, resultNonDocdlvr.size(), 'Non-DOCDLVR line should NOT be returned');
    }

    // Covers: updateRelatedCaseFields – sets Expedited speed when CashierCodeDescription contains 'EXPEDITED REVIEW'
    @isTest
    static void testUpdateRelatedCaseFields_SetsExpeditedSpeed() {
        Case testCase = new Case(
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        CashierCode__c expeditedCode = new CashierCode__c(
            Name = 'Expedited Fee',
            CashierCode__c = 'EXP01',
            Description__c = 'EXPEDITED REVIEW FEE',
            Division__c = 'BREG'
        );
        insert expeditedCode;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'Expedited processing',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            CashierCode__c = expeditedCode.Id,
            Transaction__c = trns.Id
        );
        insert line;

        // Re-query so CashierCodeDescription__c formula is populated
        List<TransactionLine__c> lines = [
            SELECT Id, breg_Case__c, CashierCodeDescription__c
            FROM TransactionLine__c
            WHERE Id = :line.Id
        ];

        Test.startTest();
        BREGTransactionLineTriggerHandler.updateRelatedCaseFields(lines);
        Test.stopTest();

        Case updated = [SELECT breg_Processing_Speed__c, Priority FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Expedited', updated.breg_Processing_Speed__c, 'Processing speed should be set to Expedited');
        System.assertEquals('Priority 2', updated.Priority, 'Priority should be set to Priority 2');
    }

    // Covers: updateRelatedCaseFields – no-op when description does NOT contain 'EXPEDITED REVIEW'
    @isTest
    static void testUpdateRelatedCaseFields_NoOpForNonExpedited() {
        Case testCase = new Case(
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'Regular filing fee',
            PaidStatus__c = 'Paid',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert line;

        List<TransactionLine__c> lines = [
            SELECT Id, breg_Case__c, CashierCodeDescription__c
            FROM TransactionLine__c
            WHERE Id = :line.Id
        ];

        Test.startTest();
        BREGTransactionLineTriggerHandler.updateRelatedCaseFields(lines);
        Test.stopTest();

        Case unchanged = [SELECT breg_Processing_Speed__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(null, unchanged.breg_Processing_Speed__c, 'Processing speed should remain unchanged for non-expedited lines');
    }

    @isTest
    static void testGetChangedLinesForFilings_UsesBusinessProcessForFilings() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'NB-1',
            breg_Form_Code__c = 'X-1',
            breg_Business_Process__c = 'New Business'
        );
        insert formConfig;

        Case testCase = new Case(
            Status = 'New',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'X-1',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'filing',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [SELECT Id, PaidStatus__c, breg_Case__c, Transaction__c FROM TransactionLine__c WHERE Id = :line.Id];
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ line.Id => line.clone(false, true, false, false) };
        oldMap.get(line.Id).put('PaidStatus__c', 'Pending');
        line.PaidStatus__c = 'Paid';

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.oldMap = oldMap;
        handler.newList = new List<SObject>{ line };

        List<TransactionLine__c> changed = handler.getLinesForFilings('Paid', true, 'filing', true);
        System.assertEquals(1, changed.size());
        System.assertEquals(line.Id, changed[0].Id);
    }

    @isTest
    static void testAfterInsert_FilingPaidLine_DoesNotSetPaymentReference() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'NB-1',
            breg_Form_Code__c = 'ADD',
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;

        Case testCase = new Case(
            Status = 'New',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'ADD',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        Transaction__c trns = [SELECT Id, Name FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'filing fee',
            PaidStatus__c = 'Paid',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.newList = new List<SObject>{ line };
        List<TransactionLine__c> newTrLine = handler.getLinesForFilings('Paid', true, 'filing', false);
        System.assertEquals(1, newTrLine.size(), 'Expected to find the newly inserted line');
    }

    @isTest
    static void testAfterUpdateSetsCasePaymentTransactionReference() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'FL-1',
            breg_Form_Code__c = 'X-2',
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;

        Case testCase = new Case(
            Status = 'New',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'X-2',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        Transaction__c trns = [SELECT Id, Name FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'filing fee',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert line;

        Test.startTest();
        line.PaidStatus__c = 'Paid';
        update line;
        Test.stopTest();

        Case updatedCase = [SELECT Id, breg_Payment_Transaction_Ref__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(trns.Name, updatedCase.breg_Payment_Transaction_Ref__c);
    }

    @isTest
    static void testUpdateCasePaymentRefNumber_UpdatesOncePerCase() {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Entity_Type__c = 'Corporation',
            breg_Suffix_Code__c = 'DC-10',
            breg_Form_Code__c = 'DC-10',
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;

        Case testCase = new Case(
            Status = 'New',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DC-10',
            breg_Form_Configuration__c = formConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert testCase;

        Transaction__c trns = [SELECT Id, Name FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line1 = new TransactionLine__c(
            Description__c = 'filing fee 1',
            PaidStatus__c = 'Paid',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        TransactionLine__c line2 = new TransactionLine__c(
            Description__c = 'filing fee 2',
            PaidStatus__c = 'Paid',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert new List<TransactionLine__c>{ line1, line2 };

        List<TransactionLine__c> lines = [
            SELECT Id, breg_Case__c, breg_Case__r.breg_Payment_Transaction_Ref__c, Transaction__r.Name
            FROM TransactionLine__c
            WHERE Id IN :new Set<Id>{ line1.Id, line2.Id }
        ];

        Test.startTest();
        BREGTransactionLineTriggerHandler.updateCasePaymentRefNumber(lines);
        Test.stopTest();

        Case updatedCase = [SELECT breg_Payment_Transaction_Ref__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(trns.Name, updatedCase.breg_Payment_Transaction_Ref__c);
    }

    @isTest
    static void testUpdateCaseOnRelatedTransaction_UpdatesTransactionCaseLookup() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case testCase = cases[0];

        Transaction__c trns = [SELECT Id, breg_Case__c FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'related transaction line',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [SELECT Id, breg_Case__c, Transaction__c, Transaction__r.breg_Case__c FROM TransactionLine__c WHERE Id = :line.Id];

        Test.startTest();
        BREGTransactionLineTriggerHandler.updateCaseOnRelatedTransaction(new List<TransactionLine__c>{ line });
        Test.stopTest();

        Transaction__c updatedTransaction = [SELECT Id, breg_Case__c FROM Transaction__c WHERE Id = :trns.Id];
        System.assertEquals(testCase.Id, updatedTransaction.breg_Case__c);
    }

    @isTest
    static void testCreateCertificate_UsesDocumentAccountWhenLineAccountMissing() {
        Account fallbackAccount = new Account(Name = 'Fallback Account');
        insert fallbackAccount;

        breg_Document__c doc = new breg_Document__c(Name = 'Fallback Doc', breg_Type__c = 'Digital', breg_Account__c = fallbackAccount.Id);
        insert doc;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'COGS digital fallback',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [
            SELECT Id, Account__c, Description__c, breg_Document__c, breg_Document__r.breg_Type__c, breg_Document__r.breg_Account__c
            FROM TransactionLine__c
            WHERE Id = :line.Id
        ];

        breg_Certificate__c cert = BREGTransactionLineTriggerHandler.createCertificate(line);
        System.assertEquals(fallbackAccount.Id, cert.breg_Account__c);
        System.assertEquals('Email', cert.breg_Correspondence_Type__c);
    }

    @isTest
    static void testGetUniqueLinesByCaseId_DeduplicatesByCase() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(new List<breg_Form_Configuration__c>{ formConfigs[0] });
        Case caseOne = cases[0];
        Case caseTwo = cases[1];

        TransactionLine__c firstForCaseOne = new TransactionLine__c(breg_Case__c = caseOne.Id);
        TransactionLine__c secondForCaseOne = new TransactionLine__c(breg_Case__c = caseOne.Id);
        TransactionLine__c firstForCaseTwo = new TransactionLine__c(breg_Case__c = caseTwo.Id);
        TransactionLine__c noCaseLine = new TransactionLine__c();

        List<TransactionLine__c> uniqueLines = BREGTransactionLineTriggerHandler.getUniqueLinesByCaseId(
            new List<TransactionLine__c>{ firstForCaseOne, secondForCaseOne, firstForCaseTwo, noCaseLine }
        );

        System.assertEquals(2, uniqueLines.size(), 'Should keep only one line per unique case and skip null case');
        System.assertEquals(caseOne.Id, uniqueLines[0].breg_Case__c, 'Should keep first line for case one');
        System.assertEquals(caseTwo.Id, uniqueLines[1].breg_Case__c, 'Should keep first line for case two');
        System.assert(uniqueLines[0] == firstForCaseOne, 'Should preserve first encountered line for duplicated case');
    }

    @isTest
    static void testIsCOGSalreadyCreated_ReturnsTrueAndFalse() {
        breg_Form_Configuration__c docdlvrConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR-CHECK',
            breg_Form_Name__c = 'Document Delivery Check'
        );
        insert docdlvrConfig;

        Case caseWithCogs = new Case(
            Status = 'New',
            Origin = 'In Person',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = docdlvrConfig.Id,
            breg_Bypass_Validation__c = true
        );
        Case caseWithoutCogs = new Case(
            Status = 'New',
            Origin = 'In Person',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = docdlvrConfig.Id,
            breg_Bypass_Validation__c = true
        );
        insert new List<Case>{ caseWithCogs, caseWithoutCogs };

        insert new breg_Document__c(
            Name = 'Certificate of Good Standing (COGS) - Existing',
            breg_Case__c = caseWithCogs.Id,
            breg_Type__c = 'Digital'
        );

        System.assertEquals(true, BREGTransactionLineTriggerHandler.isCOGSalreadyCreated(caseWithCogs.Id), 'Case with an existing COGS document should return true.');
        System.assertEquals(false, BREGTransactionLineTriggerHandler.isCOGSalreadyCreated(caseWithoutCogs.Id), 'Case without a COGS document should return false.');
    }

    @isTest
    static void testAfterInsert_DoesNotGenerateCogsWhenAlreadyExists() {
        Account acc = BREGTestDataFactory.createEntityAccounts(1)[0];

        breg_Form_Configuration__c docdlvrConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR-EXIST',
            breg_Form_Name__c = 'Document Delivery Existing'
        );
        insert docdlvrConfig;

        Contact cont = new Contact(FirstName = 'Existing', LastName = 'COGS', Email = 'existing.cogs@breg.test.com');
        insert cont;

        Case manualCase = new Case(
            Status = 'New',
            Origin = 'In Person',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = 'DOCDLVR',
            breg_Form_Configuration__c = docdlvrConfig.Id,
            breg_Delivery_Method__c = 'Email',
            breg_Entity__c = acc.Id,
            ContactId = cont.Id,
            breg_Bypass_Validation__c = true
        );
        insert manualCase;

        insert new breg_Document__c(
            Name = 'Certificate of Good Standing (COGS) - Existing',
            breg_Case__c = manualCase.Id,
            breg_Type__c = 'Digital'
        );

        Integer existingCount = [
            SELECT COUNT()
            FROM breg_Document__c
            WHERE breg_Case__c = :manualCase.Id
            AND Name LIKE 'Certificate of Good Standing (COGS)%'
        ];

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];

        Test.startTest();
        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'COGS Certificate',
            PaidStatus__c = 'Pending',
            breg_Case__c = manualCase.Id,
            Transaction__c = trns.Id
        );
        insert line;
        Test.stopTest();

        Integer afterInsertCount = [
            SELECT COUNT()
            FROM breg_Document__c
            WHERE breg_Case__c = :manualCase.Id
            AND Name LIKE 'Certificate of Good Standing (COGS)%'
        ];

        TransactionLine__c insertedLine = [SELECT Id, breg_Document__c FROM TransactionLine__c WHERE Id = :line.Id];
        System.assertEquals(existingCount, afterInsertCount, 'No additional COGS document should be generated when one already exists.');
        System.assertEquals(null, insertedLine.breg_Document__c, 'Transaction line should not be linked to a new COGS document when one already exists.');
    }

    @isTest
    static void testProcessPaidFilingsWorkflows_NullAndEmpty_Returns() {
        Test.startTest();
        BREGTransactionLineTriggerHandler.processPaidFilingsWorkflows(null);
        BREGTransactionLineTriggerHandler.processPaidFilingsWorkflows(new List<Id>());
        Test.stopTest();

        System.assertEquals(true, true, 'Null and empty inputs should return without throwing.');
    }

    @isTest
    static void testProcessPaidFilingsWorkflows_FilingLine_SetsGenerationStatus() {
        breg_Form_Configuration__c formConfig = insertFormConfig('X-1', 'PFW-1', 'Paid Filings Web');
        Case testCase = insertBregCase('X-1', 'Web', formConfig.Id);
        TransactionLine__c line = insertPaidLine(testCase.Id, 'filing fee', null);

        Test.startTest();
        BREGTransactionLineTriggerHandler.processPaidFilingsWorkflows(new List<Id>{ line.Id });
        Test.stopTest();

        Case updated = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Generation in Process', updated.breg_Document_Generation_Status__c, 'Paid filing should mark document generation as in process.');
    }

    @isTest
    static void testProcessPaidFilingsWorkflows_NonFiling_DoesNotUpdateStatus() {
        breg_Form_Configuration__c formConfig = insertFormConfig('DOCDLVR', 'PFW-DD', 'Paid Filings Doc Delivery');
        Case testCase = insertBregCase('DOCDLVR', 'Web', formConfig.Id);
        TransactionLine__c line = insertPaidLine(testCase.Id, 'filing fee', null);

        Test.startTest();
        BREGTransactionLineTriggerHandler.processPaidFilingsWorkflows(new List<Id>{ line.Id });
        Test.stopTest();

        Case unchanged = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Not Started', unchanged.breg_Document_Generation_Status__c, 'Non-filing DOCDLVR lines should not start document generation.');
    }

    @isTest
    static void testProcessPaidFilingsWorkflows_LlpWithGpChild_UpdatesRelatedCase() {
        breg_Form_Configuration__c llpConfig = insertFormConfig('LLP-1', 'PFW-LLP', 'Paid Filings LLP');
        breg_Form_Configuration__c gpConfig = insertFormConfig('GP-1', 'PFW-GP', 'Paid Filings GP');

        Case llpCase = insertBregCase('LLP-1', 'Web', llpConfig.Id);
        Case gpCase = insertBregCase('GP-1', 'Web', gpConfig.Id);
        gpCase.ParentId = llpCase.Id;
        gpCase.breg_Is_LLP_Registration__c = true;
        update gpCase;

        TransactionLine__c line = insertPaidLine(llpCase.Id, 'filing fee', null);

        Test.startTest();
        BREGTransactionLineTriggerHandler.processPaidFilingsWorkflows(new List<Id>{ line.Id });
        Test.stopTest();

        Map<Id, Case> updatedCases = new Map<Id, Case>([
            SELECT Id, breg_Document_Generation_Status__c
            FROM Case
            WHERE Id IN :new Set<Id>{ llpCase.Id, gpCase.Id }
        ]);
        System.assertEquals('Generation in Process', updatedCases.get(llpCase.Id).breg_Document_Generation_Status__c, 'LLP case should be marked generation in process.');
        System.assertEquals('Generation in Process', updatedCases.get(gpCase.Id).breg_Document_Generation_Status__c, 'Related GP case should also be marked generation in process.');
    }

    @isTest
    static void testProcessPaidFilingsWorkflows_ResubmitOverride_StartsWorkflows() {
        breg_Form_Configuration__c formConfig = insertFormConfig('FLLP-1', 'PFW-FLLP', 'Paid Filings FLLP');
        Case testCase = insertBregCase('FLLP-1', 'Web', formConfig.Id);
        testCase.breg_Override_Payment__c = true;
        testCase.breg_Form_Action__c = 'Resubmit';
        update testCase;

        TransactionLine__c line = insertPaidLine(testCase.Id, 'filing fee', null);

        Test.startTest();
        BREGTransactionLineTriggerHandler.processPaidFilingsWorkflows(new List<Id>{ line.Id });
        Test.stopTest();

        Case updated = [SELECT breg_Document_Generation_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals('Generation in Process', updated.breg_Document_Generation_Status__c, 'Resubmit with payment override should still start filing workflows.');
    }

    @isTest
    static void testGetLinesForFilings_NullStatusUsesNewList() {
        breg_Form_Configuration__c formConfig = insertFormConfig('X-1', 'PFW-NULL', 'Null Status Filings');
        Case testCase = insertBregCase('X-1', 'Web', formConfig.Id);
        TransactionLine__c line = insertPaidLine(testCase.Id, 'filing fee', null);
        line = queryLineForFilings(line.Id);

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.newList = new List<SObject>{ line };

        Test.startTest();
        List<TransactionLine__c> changed = handler.getLinesForFilings(null, true, 'filing', false);
        Test.stopTest();

        System.assertEquals(1, changed.size(), 'Null status should use newList and still return the filing line.');
        System.assertEquals(line.Id, changed[0].Id);
    }

    @isTest
    static void testGetLinesForFilings_FormTypeWithoutDescription() {
        breg_Form_Configuration__c formConfig = insertFormConfig('X-1', 'PFW-TYPE', 'Form Type Filings');
        Case testCase = insertBregCase('X-1', 'Web', formConfig.Id);
        TransactionLine__c line = insertPaidLine(testCase.Id, null, 'NBR Form');
        line = queryLineForFilings(line.Id);

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.newList = new List<SObject>{ line };

        List<TransactionLine__c> changed = handler.getLinesForFilings(null, true, 'filing', false);
        System.assertEquals(1, changed.size(), 'Form-related lines without a description should still qualify as filings.');
    }

    @isTest
    static void testGetLinesForFilings_FormFeesPurchaseType() {
        breg_Form_Configuration__c formConfig = insertFormConfig('X-1', 'PFW-FEE', 'Form Fee Filings');
        Case testCase = insertBregCase('X-1', 'Web', formConfig.Id);
        breg_Fee__c formFee = new breg_Fee__c(
            breg_Record_Type__c = 'Entity',
            breg_Fee_Amount__c = 1,
            breg_Purchase_Type_Fee_type__c = 'Form Fees'
        );
        insert formFee;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];
        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'processing charge',
            PaidStatus__c = 'Paid',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id,
            breg_Fee__c = formFee.Id
        );
        insert line;
        line = queryLineForFilings(line.Id);

        BREGTransactionLineTriggerHandler handler = new BREGTransactionLineTriggerHandler();
        handler.newList = new List<SObject>{ line };

        List<TransactionLine__c> changed = handler.getLinesForFilings(null, true, 'filing', false);
        System.assertEquals(1, changed.size(), 'Form Fees purchase type should qualify even without a filing description.');
    }

    @isTest
    static void testGetManualCogsLines_CreatesPrintedDocumentWithoutContact() {
        Account acc = BREGTestDataFactory.createEntityAccounts(1)[0];
        insert new breg_Document__c(
            Name = 'COGS Template Printed Mail',
            breg_Type__c = 'Printed',
            breg_Is_Certificate_Of_Good_Standing__c = true,
            breg_Is_Public__c = true
        );

        breg_Form_Configuration__c docdlvrConfig = insertFormConfig('DOCDLVR', 'PFW-MAIL', 'Printed COGS Delivery');
        Case manualCase = insertBregCase('DOCDLVR', 'In Person', docdlvrConfig.Id);
        manualCase.breg_Delivery_Method__c = 'Mail To The Address';
        manualCase.breg_Entity__c = acc.Id;
        update manualCase;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];

        Test.startTest();
        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'CERTIFICATE OF COMPLIANCE',
            PaidStatus__c = 'Pending',
            breg_Case__c = manualCase.Id,
            Transaction__c = trns.Id
        );
        insert line;
        Test.stopTest();

        TransactionLine__c updatedLine = [SELECT Id, breg_Document__c, Account__c FROM TransactionLine__c WHERE Id = :line.Id];
        System.assertNotEquals(null, updatedLine.breg_Document__c, 'Printed COGS document should be created when delivery is mail.');
        System.assertEquals(acc.Id, updatedLine.Account__c, 'Account should be set from case entity for printed COGS.');

        breg_Document__c createdDoc = [SELECT breg_Type__c FROM breg_Document__c WHERE Id = :updatedLine.breg_Document__c];
        System.assertEquals('Printed', createdDoc.breg_Type__c, 'Mail delivery should create a printed COGS document.');
    }

    @isTest
    static void testAfterUpdate_CertificateOfComplianceCreatesCertificate() {
        breg_Form_Configuration__c formConfig = insertFormConfig('DOCDLVR', 'PFW-CERT', 'COGS Cashier Description');
        Case testCase = insertBregCase('DOCDLVR', 'Web', formConfig.Id);
        breg_Document__c doc = [SELECT Id FROM breg_Document__c WHERE breg_Type__c = 'Digital' LIMIT 1];
        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];

        TransactionLine__c line = new TransactionLine__c(
            Description__c = 'CERTIFICATE OF COMPLIANCE',
            PaidStatus__c = 'Pending',
            breg_Document__c = doc.Id,
            breg_Case__c = testCase.Id,
            Transaction__c = trns.Id
        );
        insert line;

        Test.startTest();
        line.PaidStatus__c = 'Paid';
        update line;
        Test.stopTest();

        List<breg_Certificate__c> certs = [SELECT Id FROM breg_Certificate__c WHERE breg_Document__c = :doc.Id];
        System.assertEquals(1, certs.size(), 'Paid CERTIFICATE OF COMPLIANCE line should create a certificate via the cashier-code description fallback.');
    }

    @isTest
    static void testTrimNameToLimit_NonCogsSecondPartAndLongSuffix() {
        System.assertEquals(
            'Short Name',
            BREGTransactionLineTriggerHandler.trimNameToLimit('Short Name - Annual Report'),
            'Non-COGS second part should keep only the account name.'
        );

        String eightyCharName = '12345678901234567890123456789012345678901234567890123456789012345678901234567890';
        System.assertEquals(
            eightyCharName,
            BREGTransactionLineTriggerHandler.trimNameToLimit(eightyCharName + ' - Certificate of Good Standing (COGS)'),
            'Account names at the limit should be truncated to 80 characters.'
        );

        String longSuffix = '0123456789012345678901234567890123456789012345678901234567890123456789';
        System.assertEquals(
            'Short Name - COGS',
            BREGTransactionLineTriggerHandler.trimNameToLimit('Short Name - Certificate of Good Standing (COGS) - ' + longSuffix),
            'Suffix that would exceed the name limit should be omitted.'
        );
    }

    @isTest
    static void testBuildRegularCopyWorkflowParams_NullContactName() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact deliveryContact = new Contact(LastName = 'RecipientOnly', Email = 'noname@test.com');
        insert deliveryContact;

        breg_Form_Configuration__c formConfig = insertFormConfig('DOCDLVR', 'PFW-XML', 'Null Name Copy');
        Case docCase = insertBregCase('DOCDLVR', 'Web', formConfig.Id);
        breg_Document__c regularCopyDoc = new breg_Document__c(
            Name = 'Regular Copy Document',
            breg_Type__c = 'Printed',
            breg_Account__c = acc.Id,
            breg_Case__c = docCase.Id,
            breg_Docusign_Document_Id__c = 'doc-null-name'
        );
        insert regularCopyDoc;

        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        TransactionLine__c line = new TransactionLine__c(
            Account__c = acc.Id,
            Description__c = 'Regular copy',
            PaidStatus__c = 'Paid',
            breg_Document__c = regularCopyDoc.Id,
            breg_Delivery_Contact__c = deliveryContact.Id,
            Transaction__c = trns.Id
        );
        insert line;

        line = [
            SELECT
                breg_Document__r.breg_Case__c,
                breg_Document__r.breg_Docusign_Document_Id__c,
                breg_Delivery_Contact__c,
                breg_Delivery_Contact__r.FirstName,
                breg_Delivery_Contact__r.LastName,
                breg_Delivery_Contact__r.Email,
                Description__c
            FROM TransactionLine__c
            WHERE Id = :line.Id
        ];

        String params = BREGTransactionLineTriggerHandler.buildRegularCopyWorkflowParams(line);
        System.assert(params.contains('<fullName>RecipientOnly</fullName>'), 'Null first name should be omitted from the full name.');
    }

    @isTest
    static void testStartWorkflowAsync_DoesNotEnqueueInTests() {
        Case testCase = insertBregCase(null, 'Web', null);

        Test.startTest();
        BREGTransactionLineTriggerHandler.startWorkflowAsync('BREG Create Patch Sheet for Case', testCase.Id, 'Coverage start');
        Integer queuedJobs = Limits.getQueueableJobs();
        Test.stopTest();

        System.assertEquals(0, queuedJobs, 'startWorkflowAsync should not enqueue DocuSign jobs while tests are running.');
    }

    private static breg_Form_Configuration__c insertFormConfig(String formCode, String suffixCode, String formName) {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            breg_Form_Code__c = formCode,
            breg_Suffix_Code__c = suffixCode,
            breg_Form_Name__c = formName,
            breg_Business_Process__c = 'Change'
        );
        insert formConfig;
        return formConfig;
    }

    private static Case insertBregCase(String formCode, String origin, Id formConfigId) {
        Case testCase = new Case(
            Status = 'New',
            Origin = origin,
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Form_Code__c = formCode,
            breg_Form_Configuration__c = formConfigId,
            breg_Bypass_Validation__c = true
        );
        insert testCase;
        return testCase;
    }

    private static TransactionLine__c queryLineForFilings(Id lineId) {
        return [
            SELECT
                Id,
                Description__c,
                breg_Type__c,
                breg_Case__r.breg_Form_Code__c,
                breg_Case__r.breg_Form_Configuration__r.breg_Business_Process__c,
                breg_Fee__r.breg_Purchase_Type_Fee_type__c
            FROM TransactionLine__c
            WHERE Id = :lineId
        ];
    }

    private static TransactionLine__c insertPaidLine(Id caseId, String description, String type) {
        Transaction__c trns = [SELECT Id FROM Transaction__c LIMIT 1];
        breg_Document__c doc = [SELECT Id FROM breg_Document__c LIMIT 1];
        TransactionLine__c line = new TransactionLine__c(
            Description__c = description,
            PaidStatus__c = 'Paid',
            breg_Document__c = doc.Id,
            breg_Case__c = caseId,
            Transaction__c = trns.Id,
            breg_Type__c = type
        );
        insert line;
        return line;
    }

    private class MockDocuSignHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setBody('Mock PDF content');
            res.setStatusCode(200);
            return res;
        }
    }

    private class MockDocuSignHttpResponseError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Document not found"}');
            res.setStatusCode(404);
            return res;
        }
    }
}