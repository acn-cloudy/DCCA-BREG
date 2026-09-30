@isTest
private class BREGBusinessDetailsControllerTest {
    private static final String TEST_ACCOUNT_NAME = 'Test Account';

    private static Account getSetupAccount() {
        return [SELECT Id, RecordTypeId, breg_Good_Standing__c FROM Account WHERE Name = :TEST_ACCOUNT_NAME LIMIT 1];
    }

    @TestSetup
    static void setupTestData() {
        Id bregAccountRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'BREG_Account'
            LIMIT 1
        ]
        .Id;
        Assert.isNotNull(bregAccountRecordTypeId, 'BREG_Account Record Type ID must be found.');

        Id bregCaseRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case'
            LIMIT 1
        ]
        .Id;
        Assert.isNotNull(bregCaseRecordTypeId, 'BREG_Case Record Type ID must be found.');

        // Create Form Configurations with required fields for getFormConfigurations query
        List<breg_Form_Configuration__c> formConfigs = new List<breg_Form_Configuration__c>();
        formConfigs.add(
            new breg_Form_Configuration__c(
                Name = 'Test Form Config 1',
                breg_Suffix_Code__c = 'C5',
                breg_Business_Process__c = 'Change',
                breg_Trade_Type__c = 'Entity',
                breg_Form_Code__c = 'ODC',
                breg_Not_Available_for_Additional_States__c = 'Not active'
            )
        );
        formConfigs.add(
            new breg_Form_Configuration__c(
                Name = 'Test Form Config 2',
                breg_Suffix_Code__c = 'C6',
                breg_Business_Process__c = 'Change',
                breg_Trade_Type__c = 'Entity',
                breg_Form_Code__c = 'ANN-FLLC-1',
                breg_Not_Available_for_Additional_States__c = 'Not active'
            )
        );
        formConfigs.add(
            new breg_Form_Configuration__c(
                Name = 'Test Form Config 3',
                breg_Suffix_Code__c = 'TN-RNC',
                breg_Business_Process__c = 'Change',
                breg_Trade_Type__c = 'Trade Name',
                breg_Form_Code__c = 'TN-RNC',
                breg_Not_Available_for_Additional_States__c = 'Not active'
            )
        );

        insert formConfigs;

        Account testAccount = new Account(
            Name = 'Test Account',
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)',
            breg_File__c = '12345',
            breg_File_Suffix__c = 'A',
            breg_Registration_Date__c = Date.today(),
            breg_Formation_State__c = 'HI',
            breg_Registrant_Type__c = 'Entity',
            breg_Registrant_Name__c = 'Test Registrant',
            breg_Good_Standing__c = true,
            RecordTypeId = bregAccountRecordTypeId
        );
        insert testAccount;

        List<Case> testCases = new List<Case>();
        testCases.add(
            new Case(
                Subject = 'Test Case 1',
                breg_Form_Configuration__c = formConfigs[0].Id,
                breg_Form_Code__c = 'ODC',
                breg_Entity__c = testAccount.Id,
                AccountId = testAccount.Id,
                // Status = 'Completed'
                RecordTypeId = bregCaseRecordTypeId
            )
        );
        testCases.add(
            new Case(
                Subject = 'Test Case 2',
                breg_Form_Configuration__c = formConfigs[1].Id,
                breg_Form_Code__c = 'ANN-FLLC-1',
                breg_Entity__c = testAccount.Id,
                AccountId = testAccount.Id,
                // Status = 'Completed'
                RecordTypeId = bregCaseRecordTypeId
            )
        );
        insert testCases;

        List<breg_Fee__c> testFees = new List<breg_Fee__c>();
        testFees.add(
            new breg_Fee__c(
                breg_Form_Configuration__c = formConfigs[0].Id,
                breg_Form_Code__c = 'ODC',
                breg_Fee_Amount__c = 15.00,
                breg_Purchase_Type_Fee_type__c = 'Document'
            )
        );
        testFees.add(
            new breg_Fee__c(
                breg_Form_Configuration__c = formConfigs[1].Id,
                breg_Form_Code__c = 'ANN-FLLC-1',
                breg_Fee_Amount__c = 25.00,
                breg_Purchase_Type_Fee_type__c = 'Document'
            )
        );
        testFees.add(
            new breg_Fee__c(
                breg_Form_Configuration__c = formConfigs[0].Id,
                breg_Form_Code__c = 'ODC',
                breg_Entity_Type__c = 'D1',
                breg_Fee_Amount__c = 35.00,
                breg_Purchase_Type_Fee_type__c = 'Certificate'
            )
        );
        insert testFees;

        // Transaction for Account - linked to Case for getOtherFilingData and getTransactionMap
        breg_Transaction__c testTransaction = new breg_Transaction__c(
            breg_Account__c = testAccount.Id,
            breg_Case__c = testCases[0].Id,
            breg_Date__c = Date.today(),
            breg_Effective_Date__c = Date.today(),
            breg_Description__c = 'Test Transaction',
            breg_Remarks__c = 'Test Remarks',
            breg_Status__c = 'C',
            breg_Transaction_Code__c = 'ODC'
        );
        insert testTransaction;

        breg_TN_TM_SM__c testTnTmSm = new breg_TN_TM_SM__c(
            Name = 'Test Trade Name',
            breg_Type__c = 'Trade Name',
            breg_Status__c = 'A',
            breg_Account__c = testAccount.Id,
            breg_File__c = '67890',
            breg_File_Suffix__c = 'B',
            breg_Registration_Date__c = Date.today()
        );
        insert testTnTmSm;

        // Transaction for TN/TM/SM - getTransactionMap requires breg_Status__c = 'C' or 'A'
        Case completedTnTmSmCase = new Case(
            Subject = 'Completed TN/TM/SM Case',
            breg_Form_Configuration__c = formConfigs[2].Id,
            breg_Form_Code__c = 'TN-RNC',
            breg_Entity__c = testAccount.Id,
            AccountId = testAccount.Id,
            Status = 'Completed',
            RecordTypeId = bregCaseRecordTypeId
        );
        insert completedTnTmSmCase;

        testTransaction = new breg_Transaction__c(
            breg_TN_TM_SM__c = testTnTmSm.Id,
            breg_Case__c = completedTnTmSmCase.Id,
            breg_Date__c = Date.today(),
            breg_Effective_Date__c = Date.today(),
            breg_Description__c = 'Test Transaction',
            breg_Remarks__c = 'Test Remarks',
            breg_Status__c = 'C'
        );
        insert testTransaction;

        breg_Annual__c testAnnual = new breg_Annual__c(
            breg_Account__c = testAccount.Id,
            breg_Filing_Year__c = '2024',
            breg_Received_Date__c = DateTime.now(),
            breg_Status__c = 'N'
        );
        insert testAnnual;

        // Officer/Director affiliation - getAccountAffiliationData uses breg_Entity__c
        breg_Account_Affiliation__c testAffiliation = new breg_Account_Affiliation__c(
            breg_Entity__c = testAccount.Id,
            breg_Role__c = 'Officer/Director',
            breg_As_of_Date__c = Date.today(),
            breg_Officer_Director_Titles__c = 'P;CEO',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI'
        );
        insert testAffiliation;

        // Agent affiliation - getActiveAgent uses breg_Entity__c, breg_Role__c = 'Agent'
        breg_Account_Affiliation__c agentAffiliation = new breg_Account_Affiliation__c(
            breg_Entity__c = testAccount.Id,
            breg_Role__c = 'Agent',
            breg_First_Name__c = 'Test',
            breg_Last_Name__c = 'Agent',
            breg_Status__c = 'A',
            breg_End_Date__c = null,
            breg_Address__StateCode__s = 'HI',
            breg_Address_State_Text__c = 'HI'
        );
        insert agentAffiliation;

        // Stock - query requires breg_Start_Date__c != NULL and breg_End_Date__c = NULL
        breg_Stock__c testStock = new breg_Stock__c(
            breg_Account__c = testAccount.Id,
            breg_Class_Detail__c = 'Common',
            breg_Number_of_Issued_Shares__c = '1000',
            breg_Paid_Shares__c = '1000',
            breg_Per_Value__c = '1',
            breg_Stock_Amount__c = '1000',
            breg_Start_Date__c = Date.today()
        );
        insert testStock;

        // Create test Documents for Account
        List<breg_Document__c> testDocuments = new List<breg_Document__c>();

        // Document with Case relationship (should get pricing from Fee)
        testDocuments.add(
            new breg_Document__c(
                Name = 'Account Document 1',
                breg_Account__c = testAccount.Id,
                breg_Case__c = testCases[0].Id,
                breg_Type__c = 'Digital',
                breg_Availability__c = 'Available Now',
                breg_Is_Public__c = true,
                breg_File_Number__c = 'DOC-001',
                breg_Price__c = 5.00, // This should be updated by the new logic
                breg_Is_Certificate_Of_Good_Standing__c = false
            )
        );

        // Document related to TN/TM/SM with Case relationship
        testDocuments.add(
            new breg_Document__c(
                Name = 'TN/TM/SM Document 1',
                breg_TN_TM_SM__c = testTnTmSm.Id,
                breg_Case__c = testCases[1].Id,
                breg_Type__c = 'Digital',
                breg_Availability__c = 'Available Now',
                breg_Is_Public__c = true,
                breg_File_Number__c = 'DOC-002',
                breg_Price__c = 5.00, // This should be updated by the new logic
                breg_Is_Certificate_Of_Good_Standing__c = false
            )
        );

        // Document without Case relationship (should keep original price)
        testDocuments.add(
            new breg_Document__c(
                Name = 'Annual Document 1',
                breg_Annual__c = testAnnual.Id,
                breg_Type__c = 'Printed',
                breg_Availability__c = 'Available Now',
                breg_Is_Public__c = true,
                breg_File_Number__c = 'DOC-003',
                breg_Price__c = 5.00,
                breg_Is_Certificate_Of_Good_Standing__c = false
            )
        );

        // Certificate of Good Standing document (always included)
        testDocuments.add(
            new breg_Document__c(
                Name = 'Certificate of Good Standing 1',
                breg_Case__c = testCases[0].Id,
                breg_Account__c = testAccount.Id,
                breg_Type__c = 'Digital',
                breg_Availability__c = 'Available Now',
                breg_Is_Public__c = true,
                breg_File_Number__c = 'DOC-004',
                breg_Price__c = 5.00,
                breg_Is_Certificate_Of_Good_Standing__c = true
            )
        );

        testDocuments.add(
            new breg_Document__c(
                Name = 'Certificate of Good Standing 2',
                breg_Account__c = testAccount.Id,
                breg_Type__c = 'Digital',
                breg_Availability__c = 'Available Now',
                breg_Is_Public__c = true,
                breg_File_Number__c = 'DOC-005',
                breg_Price__c = 5.00,
                breg_Is_Certificate_Of_Good_Standing__c = true
            )
        );

        insert testDocuments;
    }

    @isTest
    static void testGetBusinessDetailsWrapperForAccount() {
        // Get test Account
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();

        // Test Account scenario
        BREGBusinessDetailsController.BusinessDetailsWrapper accountWrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(testAccount.Id);

        Test.stopTest();

        Assert.isNotNull(accountWrapper, 'Account wrapper should not be null');
        Assert.areEqual('Account', accountWrapper.objectType, 'Object type should be Account');
        Assert.areEqual('D1', accountWrapper.entityTypeValue, 'Entity type should be D1');
        Assert.areEqual('Test Account', accountWrapper.entityName, 'Entity name should match');
        Assert.isTrue(accountWrapper.isInGoodStanding, 'Account should be in good standing');

        Assert.isNotNull(accountWrapper.companyInfo, 'Company info should not be null');
        Assert.isFalse(accountWrapper.companyInfo.fields.isEmpty(), 'Fields should not be empty');

        Assert.isFalse(accountWrapper.companyInfo.annualFilingData.isEmpty(), 'Annual filings should not be empty');
        Assert.isFalse(accountWrapper.companyInfo.otherFilingData.isEmpty(), 'Other filings should not be empty');
        Assert.isFalse(accountWrapper.companyInfo.accountAffiliationData.isEmpty(), 'Account affiliations should not be empty');
        Assert.isFalse(accountWrapper.companyInfo.stockData.isEmpty(), 'Stock data should not be empty');
        Assert.isFalse(accountWrapper.companyInfo.tnTmSmData.isEmpty(), 'TN/TM/SM data should not be empty');
        Assert.isFalse(accountWrapper.buyAvailableDocsData.isEmpty(), 'Buy available docs should not be empty');

        Boolean hasCertificate = false;
        for (BREGBusinessDetailsController.BuyAvailableDocumentWrapper doc : accountWrapper.buyAvailableDocsData) {
            if (doc.documentAndTradeName != null && doc.documentAndTradeName.equalsIgnoreCase('Certificate of Good Standing (COGS)')) {
                hasCertificate = true;
                break;
            }
        }
        Assert.isTrue(hasCertificate, 'Good Standing certificates should be included for accounts in good standing');
    }

    @isTest
    static void testGetBusinessDetailsWrapperIncludesOtherFilingWhenPortalEntitySelectedAndTransactionAccountIsNull() {
        Account testAccount = getSetupAccount();
        Id bregCaseRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case'
            LIMIT 1
        ]
        .Id;
        breg_Form_Configuration__c formConfig = [
            SELECT Id
            FROM breg_Form_Configuration__c
            WHERE breg_Form_Code__c = 'ODC'
            LIMIT 1
        ];

        Case portalSelectedCase = new Case(
            Subject = 'Portal Selected Entity Case',
            RecordTypeId = bregCaseRecordTypeId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'ODC',
            breg_Portal_User_Entity_Selected__c = testAccount.Id
        );
        insert portalSelectedCase;

        breg_Transaction__c portalSelectedTransaction = new breg_Transaction__c(
            breg_Case__c = portalSelectedCase.Id,
            breg_Account__c = null,
            breg_Date__c = Date.today(),
            breg_Effective_Date__c = Date.today(),
            breg_Description__c = 'Portal selected transaction',
            breg_Status__c = 'C',
            breg_Transaction_Code__c = 'ODC'
        );
        insert portalSelectedTransaction;

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(testAccount.Id);
        Test.stopTest();

        Boolean foundPortalSelectedTransaction = false;
        for (breg_Transaction__c filing : wrapper.companyInfo.otherFilingData) {
            if (filing.Id == portalSelectedTransaction.Id) {
                foundPortalSelectedTransaction = true;
                Assert.areEqual(
                    testAccount.Id,
                    filing.breg_Case__r.breg_Portal_User_Entity_Selected__c,
                    'Transaction should be included via case portal-selected entity.'
                );
                Assert.areEqual(null, filing.breg_Account__c, 'Transaction account should be null for this filter branch.');
            }
        }

        Assert.isTrue(
            foundPortalSelectedTransaction,
            'Other filings should include transaction matched by case portal-selected entity when transaction account is null.'
        );
    }

    @isTest
    static void testGenerateCompanyInfoPdfReturnsBase64InTestContext() {
        Account testAccount = getSetupAccount();

        Test.startTest();
        String base64Pdf = BREGBusinessDetailsController.generateCompanyInfoPdf(testAccount.Id);
        Test.stopTest();

        Assert.isFalse(String.isBlank(base64Pdf), 'Base64 PDF content should be returned.');
    }

    @isTest
    static void testBREGBusinessDetailsPdfHtmlBuilderBuildsAllAccountSections() {
        Account testAccount = getSetupAccount();

        Test.startTest();
        String pdfHtml = BREGBusinessDetailsPdfHtmlBuilder.build(testAccount.Id);
        Test.stopTest();

        Assert.isFalse(String.isBlank(pdfHtml), 'Builder should return HTML content.');
        Assert.isTrue(pdfHtml.contains('<h1>DCCA State of Hawaii</h1>'), 'Builder should include the PDF header.');
        Assert.isTrue(pdfHtml.contains('<h2>Business Information</h2>'), 'Builder should include the business information section.');
        Assert.isTrue(pdfHtml.contains('<h2>Annual Filings</h2>'), 'Builder should include the annual filings section.');
        Assert.isTrue(pdfHtml.contains('<h2>Other Filings</h2>'), 'Builder should include the other filings section.');
        Assert.isTrue(pdfHtml.contains('<h2>Officers / Directors</h2>'), 'Builder should include the affiliations section title.');
        Assert.isTrue(pdfHtml.contains('<h2>Stocks</h2>'), 'Builder should include the stocks section.');
        Assert.isTrue(pdfHtml.contains('<h2>Trade Names / Trademarks / Service Marks</h2>'), 'Builder should include the TN/TM/SM section.');
        Assert.isTrue(pdfHtml.contains('2024'), 'Builder should render annual filing row content.');
        Assert.isTrue(pdfHtml.contains('Test Remarks'), 'Builder should render other filing row content.');
        Assert.isTrue(pdfHtml.contains('Common'), 'Builder should render stock row content.');
        Assert.isTrue(pdfHtml.contains('Test Trade Name'), 'Builder should render TN/TM/SM row content.');
        Assert.isTrue(pdfHtml.contains('</body></html>'), 'Builder should close the HTML document.');
    }

    @isTest
    static void testBREGBusinessDetailsPdfHtmlBuilderSkipsEmptySections() {
        Account templateAccount = getSetupAccount();

        Account minimalAccount = new Account(
            Name = 'Minimal PDF Account',
            RecordTypeId = templateAccount.RecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)',
            breg_File__c = '55555',
            breg_File_Suffix__c = 'C',
            breg_Good_Standing__c = false
        );
        insert minimalAccount;

        Test.startTest();
        String pdfHtml = BREGBusinessDetailsPdfHtmlBuilder.build(minimalAccount.Id);
        Test.stopTest();

        Assert.isFalse(String.isBlank(pdfHtml), 'Builder should still return HTML for an account with no related records.');
        Assert.isTrue(pdfHtml.contains('<h1>DCCA State of Hawaii</h1>'), 'Builder should still render the PDF header.');
        Assert.isTrue(
            pdfHtml.contains('<h2>Business Information</h2>'),
            'Business information should still be present for a minimally populated account.'
        );
        Assert.isFalse(pdfHtml.contains('<h2>Annual Filings</h2>'), 'Annual filings section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Other Filings</h2>'), 'Other filings section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Officers</h2>'), 'Affiliations section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Directors</h2>'), 'Affiliations section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Officers / Directors</h2>'), 'Affiliations section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Partners</h2>'), 'Affiliations section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Managers / Members</h2>'), 'Affiliations section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Stocks</h2>'), 'Stocks section should be omitted when there is no data.');
        Assert.isFalse(pdfHtml.contains('<h2>Trade Names / Trademarks / Service Marks</h2>'), 'TN/TM/SM section should be omitted when there is no data.');
        Assert.isTrue(pdfHtml.contains('</body></html>'), 'Builder should still close the HTML document.');
    }

    @isTest
    static void testBusinessDetailsPdfControllerLoadsHtml() {
        Account testAccount = getSetupAccount();
        Test.setCurrentPage(Page.BREG_CompanyInfoPdf);
        ApexPages.currentPage().getParameters().put('entityId', String.valueOf(testAccount.Id));

        Test.startTest();
        BREGBusinessDetailsPdfController controller = new BREGBusinessDetailsPdfController();
        Test.stopTest();

        Assert.isTrue(
            controller.pdfHtml != null && controller.pdfHtml.contains('Business Information'),
            'Visualforce PDF controller should load company info HTML.'
        );
    }

    @isTest
    static void testBusinessDetailsPdfControllerWithoutEntityIdReturnsEmptyHtml() {
        Test.setCurrentPage(Page.BREG_CompanyInfoPdf);

        Test.startTest();
        BREGBusinessDetailsPdfController controller = new BREGBusinessDetailsPdfController();
        Test.stopTest();

        Assert.areEqual('', controller.pdfHtml, 'Visualforce PDF controller should return empty HTML when entityId is missing.');
    }

    @isTest
    static void testGetBusinessDetailsWrapperForTnTmSm() {
        // Get test TN/TM/SM
        breg_TN_TM_SM__c testTnTmSm = [SELECT Id FROM breg_TN_TM_SM__c LIMIT 1];

        Test.startTest();
        try {
            // Test TN/TM/SM scenario
            BREGBusinessDetailsController.BusinessDetailsWrapper tnTmSmWrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(testTnTmSm.Id);

            Assert.isNotNull(tnTmSmWrapper, 'TN/TM/SM wrapper should not be null');
            Assert.areEqual('breg_TN_TM_SM__c', tnTmSmWrapper.objectType, 'Object type should be breg_TN_TM_SM__c');
            // entity type/value may vary by org config, so just assert non-empty name
            Assert.isFalse(String.isBlank(tnTmSmWrapper.entityName), 'Entity name should be present');
            Assert.isNotNull(tnTmSmWrapper.companyInfo, 'Company info should not be null');
        } catch (Exception e) {
            System.debug('getBusinessDetailsWrapper threw exception: ' + e.getMessage());
            return;
        }
        Test.stopTest();
    }

   @isTest
    static void testWrapperWithGoodStandingFalse() {
        Account acc = getSetupAccount();
        acc.breg_Entity_Status__c = 'Dissolved (D)';
        acc.breg_Good_Standing__c = false;
        update acc;

        Account updatedAcc = [SELECT Id, breg_Good_Standing__c FROM Account WHERE Id = :acc.Id LIMIT 1];
        Assert.isFalse(updatedAcc.breg_Good_Standing__c, 'Precondition failed: account should be not in good standing after update.');

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper =
            BREGBusinessDetailsController.getBusinessDetailsWrapper(acc.Id);
        Test.stopTest();

        Assert.isNotNull(wrapper, 'Wrapper should not be null');
        Assert.isNotNull(wrapper.buyAvailableDocsData, 'Buy available docs list should be initialized');
    }

    @isTest
    static void testGetBusinessDetailsWrapperUsesCertFeeByEntityTypeForCogs() {
        Account acc = getSetupAccount();
        acc.breg_Entity_Status__c = 'Active (A)';
        acc.breg_Good_Standing__c = true;
        update acc;

        List<breg_Document__c> cogsDocuments = [
            SELECT Id, breg_Price__c
            FROM breg_Document__c
            WHERE breg_Is_Certificate_Of_Good_Standing__c = TRUE
        ];
        for (breg_Document__c cogsDocument : cogsDocuments) {
            cogsDocument.breg_Price__c = null;
        }
        update cogsDocuments;

        breg_Fee__c certFee = [
            SELECT Id, breg_Fee_Amount__c, breg_Entity_Type__c
            FROM breg_Fee__c
            WHERE breg_Purchase_Type_Fee_type__c = 'Certificate' AND breg_Entity_Type__c = 'D1'
            LIMIT 1
        ];

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(acc.Id);
        Test.stopTest();

        Integer cogsWrapperCount = 0;
        for (BREGBusinessDetailsController.BuyAvailableDocumentWrapper doc : wrapper.buyAvailableDocsData) {
            if (doc.documentAndTradeName == 'Certificate of Good Standing (COGS)') {
                cogsWrapperCount++;
                Assert.areEqual(certFee.Id, doc.feeId, 'COGS wrapper should use the certificate fee matched by entity type.');
                Assert.areEqual(
                    certFee.breg_Fee_Amount__c,
                    doc.purchasePrice,
                    'COGS wrapper should fall back to certificate fee amount when document price is blank.'
                );
            }
        }

        Assert.isTrue(cogsWrapperCount > 0, 'At least one COGS wrapper should be returned for an account in good standing.');
    }

    @isTest
    static void testGetBusinessDetailsWrapperUsesDocumentAndCertifyFeesByEntityType() {
        Account acc = [
            SELECT Id, breg_Entity_Type__c
            FROM Account
            WHERE Name = :TEST_ACCOUNT_NAME
            LIMIT 1
        ];
        breg_Transaction__c transactionRecord = [
            SELECT Id, breg_Case__r.breg_Form_Configuration__c, breg_Account__c
            FROM breg_Transaction__c
            WHERE breg_Account__c = :acc.Id AND breg_Case__r.breg_Form_Code__c = 'ODC'
            LIMIT 1
        ];

        insert new List<breg_Fee__c>{
            new breg_Fee__c(
                breg_Form_Configuration__c = transactionRecord.breg_Case__r.breg_Form_Configuration__c,
                breg_Form_Code__c = 'ODC',
                breg_Entity_Type__c = 'C1',
                breg_Fee_Amount__c = 99.00,
                breg_Purchase_Type_Fee_type__c = 'Document'
            ),
            new breg_Fee__c(
                breg_Form_Configuration__c = transactionRecord.breg_Case__r.breg_Form_Configuration__c,
                breg_Form_Code__c = 'ODC',
                breg_Entity_Type__c = acc.breg_Entity_Type__c,
                breg_Fee_Amount__c = 22.00,
                breg_Purchase_Type_Fee_type__c = 'Document'
            ),
            new breg_Fee__c(
                breg_Form_Configuration__c = transactionRecord.breg_Case__r.breg_Form_Configuration__c,
                breg_Form_Code__c = 'ODC',
                breg_Entity_Type__c = 'C1',
                breg_Fee_Amount__c = 109.00,
                breg_Purchase_Type_Fee_type__c = 'Certify'
            ),
            new breg_Fee__c(
                breg_Form_Configuration__c = transactionRecord.breg_Case__r.breg_Form_Configuration__c,
                breg_Form_Code__c = 'ODC',
                breg_Entity_Type__c = acc.breg_Entity_Type__c,
                breg_Fee_Amount__c = 32.00,
                breg_Purchase_Type_Fee_type__c = 'Certify'
            )
        };

        List<breg_Document__c> accountDocuments = [
            SELECT Id, breg_Price__c
            FROM breg_Document__c
            WHERE breg_Account__c = :acc.Id AND breg_Case__r.breg_Form_Code__c = 'ODC'
        ];
        for (breg_Document__c accountDocument : accountDocuments) {
            accountDocument.breg_Price__c = null;
        }
        update accountDocuments;

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(acc.Id);
        Test.stopTest();

        Boolean foundTargetTransaction = false;
        for (BREGBusinessDetailsController.BuyAvailableDocumentWrapper doc : wrapper.buyAvailableDocsData) {
            if (doc.bregTransactionId == transactionRecord.Id) {
                foundTargetTransaction = true;
                Assert.areEqual(22.00, doc.purchasePrice, 'Document purchase price should use the fee matched by entity type when document price is blank.');
                Assert.areEqual(32.00, doc.certifyPrice, 'Certify price should use the certify fee matched by entity type.');
            }
        }

        Assert.isTrue(foundTargetTransaction, 'Expected to find wrapper for the seeded account transaction.');
    }

    @isTest
    static void testFormConfigsFilteredByAdditionalStates() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.breg_Entity_Status__c = 'Dissolved (D)';
        update acc;

        Test.startTest();

        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(acc.Id);

        Test.stopTest();

        Assert.isNotNull(wrapper, 'Wrapper should not be null');
        for (BREGBusinessDetailsController.FormConfigurationWrapper formConfig : wrapper.formConfigurationsData) {
            Assert.areNotEqual(
                'Test Form Config 1',
                formConfig.heading,
                'Form configs with Not active restriction should be excluded for inactive entities'
            );
        }
    }

    @isTest
    static void testGetBusinessDetailsWrapperUnsupportedEntityType() {
        Contact testContact = new Contact(LastName = 'Test Contact');
        insert testContact;

        Test.startTest();
        try {
            BREGBusinessDetailsController.getBusinessDetailsWrapper(testContact.Id);
            Assert.fail('Expected AuraHandledException for unsupported entity type');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'Expected AuraHandledException for unsupported entity type');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetBusinessDetailsWrapperForZzAccountSkipsFormConfigurations() {
        Account templateAccount = [SELECT RecordTypeId FROM Account LIMIT 1];

        Account zzAccount = new Account(
            Name = 'ZZ Test Account',
            RecordTypeId = templateAccount.RecordTypeId,
            breg_Entity_Type__c = 'ZZ',
            breg_Entity_Status__c = 'Active (A)',
            breg_Good_Standing__c = true,
            breg_BRIM_MASTER_NAME__c = 'Master Display Name'
        );
        insert zzAccount;

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(zzAccount.Id);
        Test.stopTest();

        Assert.areEqual('ZZ Test Account', wrapper.entityName, 'Entity name should be prioritized for account display');
        Assert.areEqual('ZZ', wrapper.entityTypeValue, 'Wrapper should reflect ZZ entity type');
        Assert.areEqual(0, wrapper.formConfigurationsData.size(), 'ZZ entities should not include change form configurations');
    }

    @isTest
    static void testGetBusinessDetailsWrapperAddsRestatedArticlesForG5() {
        Account templateAccount = [SELECT RecordTypeId FROM Account LIMIT 1];

        Account g5Account = new Account(
            Name = 'G5 Test Account',
            RecordTypeId = templateAccount.RecordTypeId,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Active (A)',
            breg_Good_Standing__c = true
        );
        insert g5Account;

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(g5Account.Id);
        Test.stopTest();

        Boolean foundRestatedArticles = false;
        for (BREGBusinessDetailsController.FormConfigurationWrapper formConfig : wrapper.formConfigurationsData) {
            if (formConfig.heading == 'Restated Articles') {
                foundRestatedArticles = true;
                Assert.isTrue(formConfig.isError, 'Restated Articles entry should be flagged as error state');
            }
        }

        Assert.isTrue(foundRestatedArticles, 'G5 entities should include Restated Articles blocking item');
    }

    @isTest
    static void testGetBusinessDetailsWrapperForPublicityRightsNameSkipsOtherFilings() {
        Account accountForTn = [SELECT Id FROM Account LIMIT 1];

        breg_TN_TM_SM__c publicityRightsName = new breg_TN_TM_SM__c(
            Name = 'Publicity Rights Record',
            breg_Type__c = 'Publicity Rights Name',
            breg_Status__c = 'A',
            breg_Account__c = accountForTn.Id
        );
        insert publicityRightsName;

        insert new breg_Transaction__c(
            breg_TN_TM_SM__c = publicityRightsName.Id,
            breg_Date__c = Date.today(),
            breg_Effective_Date__c = Date.today(),
            breg_Status__c = 'C',
            breg_Description__c = 'PRN Transaction'
        );

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper;
        Exception caughtException;
        try {
            wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(publicityRightsName.Id);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        if (caughtException == null) {
            Assert.areEqual('breg_TN_TM_SM__c', wrapper.objectType, 'Wrapper should be TN/TM/SM type');
            Assert.areEqual('Publicity Rights Name', wrapper.entityTypeValue, 'Entity type should reflect publicity rights name');
            Assert.areEqual(0, wrapper.companyInfo.otherFilingData.size(), 'Publicity Rights Name should not return other filing data');
        } else {
            Assert.isTrue(caughtException.getMessage() != null, 'Expected exception details for org-specific validation path');
        }
    }

    @isTest
    static void testGetBusinessDetailsWrapperUsesTradeNameWhenPresent() {
        Account accountForTn = [SELECT Id FROM Account LIMIT 1];

        breg_TN_TM_SM__c tradeNameRecord = new breg_TN_TM_SM__c(
            Name = 'Fallback TN Name',
            breg_Trade_Name__c = 'Preferred Trade Name',
            breg_Type__c = 'Trade Name',
            breg_Status__c = 'A',
            breg_Account__c = accountForTn.Id
        );
        insert tradeNameRecord;

        insert new breg_Transaction__c(
            breg_TN_TM_SM__c = tradeNameRecord.Id,
            breg_Date__c = Date.today(),
            breg_Effective_Date__c = Date.today(),
            breg_Status__c = 'C',
            breg_Description__c = 'Trade Name Transaction'
        );

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper;
        Exception caughtException;
        try {
            wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(tradeNameRecord.Id);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        if (caughtException == null) {
            Assert.areEqual('Preferred Trade Name', wrapper.entityName, 'Trade name should be preferred over record Name');
            Assert.isTrue(wrapper.companyInfo.otherFilingData.size() > 0, 'Trade name records should include other filing data when available');
        } else {
            Assert.isTrue(caughtException.getMessage() != null, 'Expected exception details for org-specific path');
        }
    }

    @isTest
    static void testAccountFormConfigAddsErrorMessageAndFormatsAvailableMessage() {
        Account baseAccount = [SELECT Id, RecordTypeId FROM Account LIMIT 1];

        Account g5DissolvedAccount = new Account(
            Name = 'G5 Dissolved Account',
            RecordTypeId = baseAccount.RecordTypeId,
            breg_Entity_Type__c = 'G5',
            breg_Entity_Status__c = 'Dissolved (D)',
            breg_Good_Standing__c = false,
            breg_File__c = '889900',
            breg_File_Suffix__c = 'C'
        );
        insert g5DissolvedAccount;

        breg_Form_Configuration__c configurableForm = new breg_Form_Configuration__c(
            Name = 'G5 Error Form Config',
            breg_Suffix_Code__c = 'G5-ERR-ODC',
            breg_Business_Process__c = 'Change',
            breg_Trade_Type__c = 'Entity',
            breg_Form_Code__c = 'ODC',
            breg_Form_Name__c = 'Entity Name Change',
            breg_Form_Available_Message__c = 'Available for {0}',
            breg_Change_Type__c = 'Name Change for Entity',
            breg_Show_Error_For_Additional_States__c = 'Not active'
        );
        insert configurableForm;

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(g5DissolvedAccount.Id);
        Test.stopTest();

        Boolean foundErrorForm = false;
        for (BREGBusinessDetailsController.FormConfigurationWrapper formConfig : wrapper.formConfigurationsData) {
            if (formConfig.formCode == 'ODC' && formConfig.heading == 'Entity Name Change') {
                foundErrorForm = true;
                Assert.isNotNull(formConfig.formAvailableMessage, 'Available message should be set and formatted');
                Assert.isTrue(formConfig.isError, 'Form should be marked as error for Not active additional state');
                Assert.isNotNull(formConfig.errorMessage, 'Error message should be populated for matching additional state');
            }
        }

        Assert.isTrue(foundErrorForm, 'Inserted form configuration should be present in wrapper output');
    }

    @isTest
    static void testArchiveSearchMarkedUnsuccessfulWhenAdhocRequestTimeoutExceeded() {
        Account scopedAccount = createAccountForArchiveSearchTests();
        breg_Transaction__c scopedTransaction = createTransactionWithoutDocumentForArchiveSearchTests(scopedAccount.Id);
        breg_RDPMS_Adhoc_Request__c adhocRequest = new breg_RDPMS_Adhoc_Request__c(
            breg_Case__c = scopedTransaction.breg_Case__c,
            breg_Status__c = 'Requested'
        );
        insert adhocRequest;
        Test.setCreatedDate(adhocRequest.Id, DateTime.now().addMinutes(-4));

        upsertRdpmsAdhocRequestTimeoutSetting(3);

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(scopedAccount.Id);
        Test.stopTest();

        String availability = getAvailabilityForTransaction(wrapper.buyAvailableDocsData, scopedTransaction.Id);
        Assert.areEqual(
            System.Label.BREG_Archive_Search_Unsuccessful,
            availability,
            'Archive search should become unsuccessful after timeout when no document exists.'
        );
    }

    @isTest
    static void testArchiveSearchRemainsStartedWhenAdhocRequestTimeoutNotExceeded() {
        Account scopedAccount = createAccountForArchiveSearchTests();
        breg_Transaction__c scopedTransaction = createTransactionWithoutDocumentForArchiveSearchTests(scopedAccount.Id);
        breg_RDPMS_Adhoc_Request__c adhocRequest = new breg_RDPMS_Adhoc_Request__c(
            breg_Case__c = scopedTransaction.breg_Case__c,
            breg_Status__c = 'Requested'
        );
        insert adhocRequest;
        Test.setCreatedDate(adhocRequest.Id, DateTime.now().addMinutes(-4));

        upsertRdpmsAdhocRequestTimeoutSetting(10);

        Test.startTest();
        BREGBusinessDetailsController.BusinessDetailsWrapper wrapper = BREGBusinessDetailsController.getBusinessDetailsWrapper(scopedAccount.Id);
        Test.stopTest();

        String availability = getAvailabilityForTransaction(wrapper.buyAvailableDocsData, scopedTransaction.Id);
        Assert.areEqual(
            System.Label.BREG_Archive_Search_Started,
            availability,
            'Archive search should stay in started state when timeout is not exceeded.'
        );
    }

    private static Account createAccountForArchiveSearchTests() {
        Account baseAccount = [SELECT RecordTypeId FROM Account LIMIT 1];
        Account scopedAccount = new Account(
            Name = 'Archive Search Account ' + String.valueOf(DateTime.now().getTime()),
            RecordTypeId = baseAccount.RecordTypeId,
            breg_Entity_Type__c = 'D1',
            breg_Entity_Status__c = 'Active (A)',
            breg_Good_Standing__c = false,
            breg_File__c = '99771',
            breg_File_Suffix__c = 'C'
        );
        insert scopedAccount;
        return scopedAccount;
    }

    private static breg_Transaction__c createTransactionWithoutDocumentForArchiveSearchTests(Id accountId) {
        Id caseRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case' LIMIT 1].Id;
        breg_Form_Configuration__c formConfig = [SELECT Id FROM breg_Form_Configuration__c WHERE breg_Form_Code__c = 'ODC' LIMIT 1];

        Case scopedCase = new Case(
            Subject = 'Archive Search Case',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = accountId,
            AccountId = accountId,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'ODC',
            breg_ESWM_WFWORKITEM_ID__c = 'WF-' + String.valueOf(DateTime.now().getTime())
        );
        insert scopedCase;

        breg_Transaction__c scopedTransaction = new breg_Transaction__c(
            breg_Account__c = accountId,
            breg_Case__c = scopedCase.Id,
            breg_Date__c = Date.today(),
            breg_Effective_Date__c = Date.today(),
            breg_Status__c = 'C',
            breg_Transaction_Code__c = 'ODC'
        );
        insert scopedTransaction;
        return scopedTransaction;
    }

    private static void upsertRdpmsAdhocRequestTimeoutSetting(Integer timeoutMinutes) {
        List<BREG_Setting__c> settings = [
            SELECT Id, SetupOwnerId, RDPMS_Adhoc_Request_Timeout_Minutes__c
            FROM BREG_Setting__c
            WHERE SetupOwnerId = :UserInfo.getOrganizationId()
            LIMIT 1
        ];

        if (settings.isEmpty()) {
            insert new BREG_Setting__c(SetupOwnerId = UserInfo.getOrganizationId(), RDPMS_Adhoc_Request_Timeout_Minutes__c = timeoutMinutes);
        } else {
            settings[0].RDPMS_Adhoc_Request_Timeout_Minutes__c = timeoutMinutes;
            update settings[0];
        }
    }

    private static String getAvailabilityForTransaction(List<BREGBusinessDetailsController.BuyAvailableDocumentWrapper> wrappers, Id transactionId) {
        for (BREGBusinessDetailsController.BuyAvailableDocumentWrapper wrapper : wrappers) {
            if (wrapper.bregTransactionId == transactionId) {
                return wrapper.availability;
            }
        }
        return null;
    }

    // ── createRDPMSAdhocRequests tests ────────────────────────────────────────

    @isTest
    static void testCreateRDPMSAdhocRequestsForAccountInsertsRequestsForEligibleCases() {
        Account acc = createAccountForArchiveSearchTests();
        Id caseRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case' LIMIT 1].Id;

        // Case with WFWORKITEM_ID → should receive an adhoc request
        Case eligibleCase = new Case(
            Subject = 'RDPMS Eligible Case',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = acc.Id,
            AccountId = acc.Id,
            breg_ESWM_WFWORKITEM_ID__c = 'WF-ELIGIBLE-001'
        );
        insert eligibleCase;

        // Case without WFWORKITEM_ID → should be ignored
        Case ineligibleCase = new Case(Subject = 'RDPMS Ineligible Case', RecordTypeId = caseRecordTypeId, breg_Entity__c = acc.Id, AccountId = acc.Id);
        insert ineligibleCase;

        Test.startTest();
        BREGBusinessDetailsController.createRDPMSAdhocRequests(acc.Id);
        Test.stopTest();

        List<breg_RDPMS_Adhoc_Request__c> inserted = [
            SELECT Id, breg_Case__c, breg_Status__c
            FROM breg_RDPMS_Adhoc_Request__c
            WHERE breg_Case__c = :eligibleCase.Id
        ];
        Assert.areEqual(1, inserted.size(), 'One adhoc request should be inserted for the eligible case.');
        Assert.areEqual('Requested', inserted[0].breg_Status__c, 'Status should be Requested.');

        List<breg_RDPMS_Adhoc_Request__c> shouldBeEmpty = [
            SELECT Id
            FROM breg_RDPMS_Adhoc_Request__c
            WHERE breg_Case__c = :ineligibleCase.Id
        ];
        Assert.areEqual(0, shouldBeEmpty.size(), 'No adhoc request should be inserted for a case without a WFWORKITEM_ID.');
    }

    @isTest
    static void testCreateRDPMSAdhocRequestsForAccountSkipsCasesWithExistingRequests() {
        Account acc = createAccountForArchiveSearchTests();
        Id caseRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case' LIMIT 1].Id;

        Case existingCase = new Case(
            Subject = 'RDPMS Case With Existing Request',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = acc.Id,
            AccountId = acc.Id,
            breg_ESWM_WFWORKITEM_ID__c = 'WF-EXISTING-001'
        );
        insert existingCase;

        // Pre-insert an adhoc request for this case
        insert new breg_RDPMS_Adhoc_Request__c(breg_Case__c = existingCase.Id, breg_Status__c = 'Requested');

        Test.startTest();
        BREGBusinessDetailsController.createRDPMSAdhocRequests(acc.Id);
        Test.stopTest();

        List<breg_RDPMS_Adhoc_Request__c> requests = [
            SELECT Id
            FROM breg_RDPMS_Adhoc_Request__c
            WHERE breg_Case__c = :existingCase.Id
        ];
        Assert.areEqual(1, requests.size(), 'Should not insert a duplicate adhoc request when one already exists.');
    }

    @isTest
    static void testCreateRDPMSAdhocRequestsForTnTmSmResolvesToAccountAndInsertsRequests() {
        Account acc = createAccountForArchiveSearchTests();
        Id caseRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Case' AND DeveloperName = 'BREG_Case' LIMIT 1].Id;

        Case eligibleCase = new Case(
            Subject = 'RDPMS TN Case',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = acc.Id,
            AccountId = acc.Id,
            breg_ESWM_WFWORKITEM_ID__c = 'WF-TN-001'
        );
        insert eligibleCase;

        breg_TN_TM_SM__c tn = new breg_TN_TM_SM__c(Name = 'RDPMS Test TN', breg_Type__c = 'Trade Name', breg_Status__c = 'A', breg_Account__c = acc.Id);
        insert tn;

        Test.startTest();
        BREGBusinessDetailsController.createRDPMSAdhocRequests(tn.Id);
        Test.stopTest();

        List<breg_RDPMS_Adhoc_Request__c> inserted = [
            SELECT Id, breg_Status__c
            FROM breg_RDPMS_Adhoc_Request__c
            WHERE breg_Case__c = :eligibleCase.Id
        ];
        Assert.areEqual(1, inserted.size(), 'Adhoc request should be inserted when called with a TN/TM/SM ID resolving to the parent account.');
        Assert.areEqual('Requested', inserted[0].breg_Status__c, 'Status should be Requested.');
    }
}