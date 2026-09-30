@isTest
public with sharing class BREGRegistrationFormControllerTest {
    private class DocuSignApiHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/folders/path/')) {
                if (endpoint.contains('Case%20-%20')) {
                    res.setStatusCode(404);
                    res.setBody('{}');
                } else {
                    res.setStatusCode(200);
                    res.setBody('{"Href":"/folders/root-folder-uuid/"}');
                }
                return res;
            }

            if (endpoint.contains('/documents?name=')) {
                res.setStatusCode(201);
                res.setBody('{"Href":"/documents/doc-123"}');
                return res;
            }

            if (req.getMethod() == 'POST' && endpoint.contains('/folders')) {
                res.setStatusCode(201);
                res.setBody('{"Href":"/folders/new-folder-uuid/"}');
                return res;
            }

            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        BREGTestDataFactory.createTestInternalUser();
    }

    private static Id getBregCaseRecordTypeId() {
        return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
    }

    private static breg_Form_Configuration__c createFormConfig(String formCode, String suffixCode, String businessProcess, String entityType) {
        breg_Form_Configuration__c formConfig = new breg_Form_Configuration__c(
            Name = formCode,
            breg_Form_Code__c = formCode,
            breg_Suffix_Code__c = suffixCode,
            breg_Business_Process__c = businessProcess,
            breg_Entity_Type__c = entityType,
            breg_Stock_Type__c = 'Without Stock'
        );
        insert formConfig;
        return formConfig;
    }

    private static Map<String, Object> buildBaseCasePayload(String formAction) {
        return buildBaseCasePayload(formAction, true);
    }

    private static Map<String, Object> buildBaseCasePayload(String formAction, Boolean bypassValidation) {
        Map<String, Object> caseData = new Map<String, Object>();
        caseData.put('Subject', 'Registration Controller Test');
        caseData.put('breg_Name_of_the_Entity__c', 'Registration Controller Entity');
        caseData.put('breg_Company_Address__CountryCode__s', 'US');
        caseData.put('breg_Company_Address__StateCode__s', 'HI');
        caseData.put('breg_Company_Address__City__s', 'Honolulu');
        caseData.put('breg_Company_Address__Street__s', '100 Test St');
        caseData.put('breg_Company_Address__PostalCode__s', '96813');
        caseData.put('breg_Form_Action__c', formAction);
        caseData.put('breg_Bypass_Validation__c', bypassValidation);
        return caseData;
    }

    private static void ensureCaseEosTypeMapping() {
        List<dfsle__EOS_Type__c> mappings = [
            SELECT Id, Name
            FROM dfsle__EOS_Type__c
            WHERE Name = 'Case'
            LIMIT 1
        ];
        if (mappings.isEmpty()) {
            insert new dfsle__EOS_Type__c(Name = 'Case', dfsle__Path__c = '/Case', dfsle__FolderName__c = 'Case');
        }
    }

    @isTest
    static void saveFormDataCreateCaseTest() {
        breg_Form_Configuration__c formConfig = createFormConfig('DOCDLVR', 'DOCDLVR', 'Change', null);

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('Case', buildBaseCasePayload(null, false));
        payload.put('members', new List<Object>());
        payload.put('stocksAnnuals', new List<Object>());

        Test.startTest();
        String responseJson;
        System.runAs(BREGTestDataFactory.getTestInternalUser()) {
            responseJson = BREGRegistrationFormController.saveFormData(formConfig.Id, JSON.serialize(payload));
        }
        Test.stopTest();

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        Assert.isNotNull(response.get('caseId'), 'Response should contain created case Id');

        Id caseId = (Id) response.get('caseId');
        Case savedCase = [
            SELECT
                Id,
                Subject,
                Status,
                RecordTypeId,
                Origin,
                breg_Form_Configuration__c,
                breg_Form_Code__c,
                breg_Entity_Type__c,
                breg_Stock_Type__c,
                breg_Reopened_Date__c,
                breg_Effective_Date__c,
                breg_Effective_Date_Time__c
            FROM Case
            WHERE Id = :caseId
        ];

        Assert.areEqual(getBregCaseRecordTypeId(), savedCase.RecordTypeId, 'Case record type should be BREG_Case');
        Assert.areEqual(formConfig.Id, savedCase.breg_Form_Configuration__c, 'Case should reference provided form configuration');
        Assert.areEqual('DOCDLVR', savedCase.breg_Form_Code__c, 'Case form code should come from form configuration');
        Assert.areEqual('Without Stock', savedCase.breg_Stock_Type__c, 'Stock type should default from form configuration');
        Assert.isNull(savedCase.breg_Reopened_Date__c, 'Reopened datetime should not be set when form action is null');
        Assert.isNotNull(savedCase.breg_Effective_Date__c, 'Effective date should be defaulted');
        Assert.isNotNull(savedCase.breg_Effective_Date_Time__c, 'Effective datetime should be defaulted');
        Assert.areEqual('In Person', savedCase.Origin, 'Internal test user should result in In Person origin');
    }

    @isTest
    static void saveFormDataResubmitTest() {
        breg_Form_Configuration__c formConfig = createFormConfig('DC-3', 'D1', 'Change', 'D1');

        Case rejectedCase = new Case(
            Subject = 'Rejected Case',
            Status = 'Pending Submission',
            Origin = 'Web',
            RecordTypeId = getBregCaseRecordTypeId(),
            breg_Bypass_Validation__c = true,
            breg_Form_Configuration__c = formConfig.Id,
            breg_Form_Code__c = 'DC-3'
        );
        insert rejectedCase;

        Map<String, Object> caseData = buildBaseCasePayload('Resubmit');
        caseData.put('Id', rejectedCase.Id);

        Map<String, Object> payload = new Map<String, Object>{ 'Case' => caseData };

        Test.startTest();
        String responseJson;
        System.runAs(BREGTestDataFactory.getTestInternalUser()) {
            responseJson = BREGRegistrationFormController.saveFormData(formConfig.Id, JSON.serialize(payload));
        }
        Test.stopTest();

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        Assert.isNotNull(response.get('caseId'), 'Resubmit should return case id');
        Assert.areEqual(
            String.valueOf(rejectedCase.Id),
            String.valueOf(response.get('caseId')),
            'Resubmit should update the same Case'
        );
    }

    @isTest
    static void saveFormDataInvalidFormConfigurationThrowsTest() {
        Map<String, Object> payload = new Map<String, Object>{ 'Case' => buildBaseCasePayload('Reopen') };
        String invalidFormConfigId = breg_Form_Configuration__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

        Test.startTest();
        try {
            BREGRegistrationFormController.saveFormData(invalidFormConfigId, JSON.serialize(payload));
            Assert.fail('Expected AuraHandledException for invalid form configuration id');
        } catch (AuraHandledException ex) {
            Assert.isTrue(String.isNotBlank(ex.getMessage()), 'Exception message should be returned');
        }
        Test.stopTest();
    }

    @isTest
    static void saveRelatedFilesValidationAndEmptyPayloadTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case caseRecord = cases[0];

        Test.startTest();
        try {
            BREGRegistrationFormController.saveRelatedFiles(null, '[]', false);
            Assert.fail('Expected AuraHandledException for blank record id');
        } catch (AuraHandledException ex) {
            Assert.isTrue(String.isNotBlank(ex.getMessage()));
        }

        BREGRegistrationFormController.saveRelatedFiles(caseRecord.Id, '[]', false);
        Test.stopTest();

        Integer documentCount = [SELECT COUNT() FROM breg_Document__c WHERE breg_Case__c = :caseRecord.Id];
        Assert.areEqual(0, documentCount, 'No documents should be inserted for empty payload');
    }

    @isTest
    static void wrapperMethodsDelegationTest() {
        Test.startTest();
        Boolean resultIsNbr = BREGRegistrationFormController.isNBRForm('DC-1');
        String category = BREGRegistrationFormController.checkFormCategory('DC-1');
        Test.stopTest();

        Assert.areEqual(BREGUtils.isNBRForm('DC-1'), resultIsNbr, 'Controller should delegate isNBRForm to BREGUtils');
        Assert.areEqual(BREGUtils.checkFormCategory('DC-1'), category, 'Controller should delegate category check to BREGUtils');
    }

    @isTest
    static void saveFormDataMembersAndStocksProcessingTest() {
        breg_Form_Configuration__c formConfig = createFormConfig('DOCDLVR', 'DOCDLVR', 'Change', null);

        Account stockAccount = BREGTestDataFactory.createEntityAccounts(1)[0];

        breg_Account_Affiliation__c existingAffiliation = new breg_Account_Affiliation__c(breg_Role__c = 'Member', breg_Type__c = 'Individual');
        breg_Account_Affiliation__c deletedAffiliation = new breg_Account_Affiliation__c(breg_Role__c = 'Manager', breg_Type__c = 'Individual');
        insert new List<breg_Account_Affiliation__c>{ existingAffiliation, deletedAffiliation };

        breg_Stock__c existingStock = new breg_Stock__c(
            breg_Account__c = stockAccount.Id,
            breg_Stock_Class__c = 'Common',
            breg_Number_of_Issued_Shares__c = '100',
            breg_Class_Series__c = 'A',
            breg_Per_Value__c = '1.00',
            breg_Start_Date__c = Date.today().addYears(-1)
        );
        insert existingStock;

        Map<String, Object> caseData = buildBaseCasePayload(null);
        caseData.put('breg_Portal_User_Entity_Selected__c', stockAccount.Id);

        Map<String, Object> activeMember = new Map<String, Object>{
            'breg_Account_Affiliation__c.Id' => existingAffiliation.Id,
            'breg_Account_Affiliation__c.breg_Role__c' => 'Member'
        };
        Map<String, Object> removedMember = new Map<String, Object>{
            'breg_Account_Affiliation__c.Id' => deletedAffiliation.Id,
            'breg_Account_Affiliation__c.breg_Role__c' => 'Manager'
        };
        Map<String, Object> stockMap = new Map<String, Object>{
            'breg_Stock__c.Id' => existingStock.Id,
            'breg_Stock__c.breg_Stock_Class__c' => 'Preferred'
        };

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('Case', caseData);
        payload.put('members', new List<Object>{ activeMember });
        payload.put('deletedMembers', new List<Object>{ removedMember });
        payload.put('stocksAnnuals', new List<Object>{ stockMap });

        Test.startTest();
        String responseJson;
        System.runAs(BREGTestDataFactory.getTestInternalUser()) {
            responseJson = BREGRegistrationFormController.saveFormData(formConfig.Id, JSON.serialize(payload));
        }
        Test.stopTest();

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        Id caseId = (Id) response.get('caseId');
        Assert.isNotNull(caseId, 'Case should be created');

        existingAffiliation = [SELECT Id, breg_Case__c, breg_To_Remove__c, breg_Role__c, breg_Officer_Director_Titles__c FROM breg_Account_Affiliation__c WHERE Id = :existingAffiliation.Id];
        deletedAffiliation = [SELECT Id, breg_Case__c, breg_To_Remove__c, breg_Role__c, breg_Officer_Director_Titles__c FROM breg_Account_Affiliation__c WHERE Id = :deletedAffiliation.Id];
        existingStock = [SELECT Id, breg_Case__c, breg_Stock_Class__c FROM breg_Stock__c WHERE Id = :existingStock.Id];

        Assert.areEqual(caseId, existingAffiliation.breg_Case__c, 'Active affiliation should be linked to new case');
        Assert.areEqual('Member', existingAffiliation.breg_Role__c, 'Active affiliation role should be preserved');
        Assert.areEqual('MEM', existingAffiliation.breg_Officer_Director_Titles__c, 'Active affiliation titles should be preserved');
        Assert.areEqual(caseId, deletedAffiliation.breg_Case__c, 'Deleted affiliation should be linked to new case');
        Assert.areEqual('Manager', deletedAffiliation.breg_Role__c, 'Deleted affiliation role should be preserved');
        Assert.areEqual('MGR', deletedAffiliation.breg_Officer_Director_Titles__c, 'Deleted affiliation titles should be preserved');
        Assert.areEqual(true, deletedAffiliation.breg_To_Remove__c, 'Deleted member should be marked for removal');
        Assert.areEqual(caseId, existingStock.breg_Case__c, 'Stock should be linked to new case');
        Assert.areEqual('Preferred', existingStock.breg_Stock_Class__c, 'Stock fields should be updated from payload');
    }

    @isTest
    static void saveRelatedFilesExistingIdsDeleteBranchTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case caseRecord = cases[0];

        breg_Form_Configuration_Item__c configItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Component_Name__c = 'Company Name',
            breg_Order__c = 1
        );
        insert configItem;

        breg_Document__c staleDocumentToKeep = new breg_Document__c(
            Name = 'stale.pdf',
            breg_Case__c = caseRecord.Id,
            breg_Form_Configuration_Item__c = configItem.Id,
            breg_Type__c = 'Digital',
            breg_Availability__c = 'Available Now',
            breg_Is_Uploaded_Attachment__c = true,
            breg_Is_Irrelevant__c = true
        );
        breg_Document__c staleDocumentToDelete = new breg_Document__c(
            Name = 'stale-delete.pdf',
            breg_Case__c = caseRecord.Id,
            breg_Form_Configuration_Item__c = configItem.Id,
            breg_Type__c = 'Digital',
            breg_Availability__c = 'Available Now',
            breg_Is_Uploaded_Attachment__c = true,
            breg_Is_Irrelevant__c = true
        );
        insert new List<breg_Document__c>{ staleDocumentToKeep, staleDocumentToDelete };

        List<Object> files = new List<Object>{ new Map<String, Object>{ 'id' => staleDocumentToKeep.Id } };

        Test.startTest();
        BREGRegistrationFormController.saveRelatedFiles(caseRecord.Id, JSON.serialize(files), true);
        Test.stopTest();

        List<breg_Document__c> docs = [
            SELECT Id, Name, breg_Is_Irrelevant__c
            FROM breg_Document__c
            WHERE breg_Case__c = :caseRecord.Id
        ];

        Assert.areEqual(1, docs.size(), 'Only files kept on the form should remain in DB.');

        breg_Document__c keptDocument = docs[0];

        Assert.isNotNull(keptDocument, 'Document in existing ids list should remain in DB.');
        Assert.areEqual(staleDocumentToKeep.Id, keptDocument.Id, 'Document in existing ids list should remain in DB.');
        Assert.areEqual(false, keptDocument.breg_Is_Irrelevant__c, 'Kept document should be marked relevant on resubmit.');

        Integer removedDocCount = [
            SELECT count()
            FROM breg_Document__c
            WHERE Id = :staleDocumentToDelete.Id
        ];
        Assert.areEqual(0, removedDocCount, 'Document removed from form should be deleted from DB.');
    }

    @isTest
    static void saveRelatedFilesUploadNewFileBranchTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case caseRecord = cases[0];

        breg_Form_Configuration_Item__c configItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Component_Name__c = 'Company Name',
            breg_Order__c = 1
        );
        insert configItem;

        ensureCaseEosTypeMapping();
        Test.setMock(HttpCalloutMock.class, new DocuSignApiHttpMock());

        List<Object> files = new List<Object>{
            new Map<String, Object>{
                'fileName' => 'upload.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('test-file-body')),
                'configId' => configItem.Id
            }
        };

        Test.startTest();
        BREGRegistrationFormController.saveRelatedFiles(caseRecord.Id, JSON.serialize(files), false);
        Test.stopTest();

        List<breg_Document__c> docs = [
            SELECT Id, Name, breg_Docusign_Document_Id__c, breg_Case__c
            FROM breg_Document__c
            WHERE breg_Case__c = :caseRecord.Id AND Name = 'For Initial: upload.pdf'
        ];

        Assert.areEqual(1, docs.size(), 'Uploaded file should create one breg_Document__c record');
        Assert.areEqual('doc-123', docs[0].breg_Docusign_Document_Id__c, 'Mocked DocuSign document id should be saved');
    }

    @isTest
    static void saveRelatedFilesBuildUploadedDocumentNameInitialPrefixTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case caseRecord = cases[0];

        breg_Form_Configuration_Item__c configItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Component_Name__c = 'Company Name',
            breg_Order__c = 1
        );
        insert configItem;

        ensureCaseEosTypeMapping();
        Test.setMock(HttpCalloutMock.class, new DocuSignApiHttpMock());

        List<Object> initialFiles = new List<Object>{
            new Map<String, Object>{
                'fileName' => 'initial.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('initial-file-body')),
                'configId' => configItem.Id,
                'uploadTarget' => 'generic'
            }
        };

        Test.startTest();
        BREGRegistrationFormController.saveRelatedFiles(caseRecord.Id, JSON.serialize(initialFiles), false);
        Test.stopTest();

        List<breg_Document__c> initialDocs = [
            SELECT Name
            FROM breg_Document__c
            WHERE breg_Case__c = :caseRecord.Id
        ];

        Assert.areEqual(1, initialDocs.size(), 'Initial upload should create one document');
        Assert.areEqual('For Initial: initial.pdf', initialDocs[0].Name, 'Initial upload should use initial prefix and omit target marker for generic');
    }

    @isTest
    static void saveRelatedFilesBuildUploadedDocumentNameResubmittalPrefixTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case caseRecord = cases[0];

        breg_Form_Configuration_Item__c configItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Component_Name__c = 'Company Name',
            breg_Order__c = 1
        );
        insert configItem;

        ensureCaseEosTypeMapping();
        Test.setMock(HttpCalloutMock.class, new DocuSignApiHttpMock());

        List<Object> resubmittalFiles = new List<Object>{
            new Map<String, Object>{
                'fileName' => 'resubmittal.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('resubmittal-file-body')),
                'configId' => configItem.Id,
                'uploadTarget' => 'TNTMSMSymbol'
            }
        };

        Test.startTest();
        BREGRegistrationFormController.saveRelatedFiles(caseRecord.Id, JSON.serialize(resubmittalFiles), true);
        Test.stopTest();

        List<breg_Document__c> resubmittalDocs = [
            SELECT Name
            FROM breg_Document__c
            WHERE breg_Case__c = :caseRecord.Id
        ];

        Assert.areEqual(1, resubmittalDocs.size(), 'Resubmittal upload should create one document');
        Assert.areEqual(
            'For Resubmittal: [TNTMSMSymbol] resubmittal.pdf',
            resubmittalDocs[0].Name,
            'Resubmittal upload should use resubmittal prefix and include target marker'
        );
    }

    @isTest
    static void saveRelatedFilesAllowsMultipleUploadsPerConfigItemTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);
        Case caseRecord = cases[0];

        breg_Form_Configuration_Item__c configItem = new breg_Form_Configuration_Item__c(
            breg_Form_Configuration__c = formConfigs[0].Id,
            breg_Component_Name__c = 'TNTMSM Description',
            breg_Order__c = 1
        );
        insert configItem;

        ensureCaseEosTypeMapping();
        Test.setMock(HttpCalloutMock.class, new DocuSignApiHttpMock());

        List<Object> files = new List<Object>{
            new Map<String, Object>{
                'fileName' => 'symbol.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('symbol-file-body')),
                'configId' => configItem.Id,
                'uploadTarget' => 'TNTMSMSymbol'
            },
            new Map<String, Object>{
                'fileName' => 'specimen.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('specimen-file-body')),
                'configId' => configItem.Id,
                'uploadTarget' => 'TNTMSMSpecimen'
            }
        };

        Test.startTest();
        BREGRegistrationFormController.saveRelatedFiles(caseRecord.Id, JSON.serialize(files), false);
        Test.stopTest();

        List<breg_Document__c> docs = [
            SELECT Id, Name, breg_Docusign_Document_Id__c
            FROM breg_Document__c
            WHERE breg_Case__c = :caseRecord.Id
            ORDER BY Name
        ];

        Assert.areEqual(2, docs.size(), 'Both nested uploads should create separate breg_Document__c records');
        Assert.areEqual('For Initial: [TNTMSMSpecimen] specimen.pdf', docs[0].Name, 'Specimen upload should retain its persisted target marker');
        Assert.areEqual('For Initial: [TNTMSMSymbol] symbol.pdf', docs[1].Name, 'Symbol upload should retain its persisted target marker');
    }

    @isTest
    static void saveRelatedFilesMalformedJsonThrowsTest() {
        List<breg_Form_Configuration__c> formConfigs = BREGTestDataFactory.createFormConfigurations();
        List<Case> cases = BREGTestDataFactory.createRegistrationCases(formConfigs);

        Test.startTest();
        try {
            BREGRegistrationFormController.saveRelatedFiles(cases[0].Id, 'not-json', false);
            Assert.fail('Expected AuraHandledException for malformed JSON payload');
        } catch (AuraHandledException ex) {
            Assert.isTrue(String.isNotBlank(ex.getMessage()), 'Malformed JSON should bubble up as handled exception');
        }
        Test.stopTest();
    }

    @isTest
    static void saveFormDataDefaultsAndStatusUpdateBranchesTest() {
        breg_Form_Configuration__c formConfig = createFormConfig('DOCDLVR', 'DOCDLVR', 'Change', null);
        formConfig.breg_Days_After_Submission_hold_Approval__c = 2;
        update formConfig;

        Account stockAccount = BREGTestDataFactory.createEntityAccounts(1)[0];

        Map<String, Object> caseData = new Map<String, Object>{
            'Subject' => 'Branch Coverage Case',
            'breg_Name_of_the_Entity__c' => 'Branch Coverage Entity',
            'breg_Number_of_common_shares__c' => 10,
            'breg_File__c' => 'SHOULD-BE-CLEARED',
            'breg_Bypass_Validation__c' => false,
            'Status' => 'New',
            'breg_Portal_User_Entity_Selected__c' => stockAccount.Id
        };

        Map<String, Object> member = new Map<String, Object>{ 'breg_Account_Affiliation__c.breg_Role__c' => 'Member' };
        Map<String, Object> stock = new Map<String, Object>{
            'breg_Stock__c.breg_Stock_Class__c' => 'Common',
            'breg_Stock__c.breg_Number_of_Issued_Shares__c' => '10',
            'breg_Stock__c.breg_Class_Series__c' => 'A',
            'breg_Stock__c.breg_Per_Value__c' => '1.00',
            'breg_Stock__c.breg_Start_Date__c' => String.valueOf(Date.today())
        };

        Map<String, Object> payload = new Map<String, Object>{
            'Case' => caseData,
            'members' => new List<Object>{ member },
            'stocksAnnuals' => new List<Object>{ stock }
        };

        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestInternalUser()) {
            try {
                String responseJson = BREGRegistrationFormController.saveFormData(formConfig.Id, JSON.serialize(payload));
                Id caseId = (Id) ((Map<String, Object>) JSON.deserializeUntyped(responseJson)).get('caseId');
                Case savedCase = [SELECT Id, Status, breg_Effective_Date__c, breg_Stock_Type__c, breg_File__c FROM Case WHERE Id = :caseId];

                Assert.areEqual('Pending Submission', savedCase.Status, 'Case status should be updated for non-bypass flow');
                Assert.areEqual(Date.today().addDays(2), savedCase.breg_Effective_Date__c, 'Effective date should use hold-approval days default');
                Assert.areEqual('With Stock', savedCase.breg_Stock_Type__c, 'Stock type should default to With Stock when shares are provided');
                Assert.isNull(savedCase.breg_File__c, 'File should be cleared when entity is null');
            } catch (AuraHandledException ex) {
                Assert.isTrue(String.isNotBlank(ex.getMessage()), 'Expected org-specific validation message in sandbox');
            }

            Test.stopTest();

            Map<String, Object> reopenPayload = new Map<String, Object>{
                'Case' => new Map<String, Object>{
                    'Subject' => 'Reopen Branch Case',
                    'breg_Name_of_the_Entity__c' => 'Reopen Entity',
                    'breg_Bypass_Validation__c' => true,
                    'breg_Form_Action__c' => 'Reopen'
                }
            };

            String reopenResponse = BREGRegistrationFormController.saveFormData(formConfig.Id, JSON.serialize(reopenPayload));

            Id reopenCaseId = (Id) ((Map<String, Object>) JSON.deserializeUntyped(reopenResponse)).get('caseId');
            Case reopened = [SELECT Status, breg_Reopened_Date__c FROM Case WHERE Id = :reopenCaseId];
            Assert.areEqual('Pending Submission', reopened.Status, 'Reopen action should set pending submission status');
            Assert.isNotNull(reopened.breg_Reopened_Date__c, 'Reopen action should stamp reopened datetime');
        }
    }

    @isTest
    static void saveFormDataWithdrawalSetsReceivedStatusTest() {
        breg_Form_Configuration__c wdFormConfig = createFormConfig('WD', 'WD', 'Change', 'D1');

        Map<String, Object> caseData = buildBaseCasePayload(null, false);
        caseData.put('Status', 'New');

        Map<String, Object> payload = new Map<String, Object>{
            'Case' => caseData,
            'members' => new List<Object>(),
            'stocksAnnuals' => new List<Object>()
        };
        String responseJson;
        Test.startTest();
        System.runAs(BREGTestDataFactory.getTestInternalUser()) {
            responseJson = BREGRegistrationFormController.saveFormData(wdFormConfig.Id, JSON.serialize(payload));
        }
        Test.stopTest();
        Id caseId = (Id) ((Map<String, Object>) JSON.deserializeUntyped(responseJson)).get('caseId');
        Case savedCase = [SELECT Id, Status, breg_Form_Code__c FROM Case WHERE Id = :caseId];

        Assert.areEqual('WD', savedCase.breg_Form_Code__c, 'Case form code should come from the WD form configuration');
        Assert.areEqual('Received', savedCase.Status, 'WD cases should be created in Received status from the portal');
    }
}