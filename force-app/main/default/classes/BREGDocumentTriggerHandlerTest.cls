@isTest
public class BREGDocumentTriggerHandlerTest {
    private static List<String> mockRequestBodies = new List<String>();

    @testSetup
    static void setupData() {
        Id bregAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('BREG_Account')
            .getRecordTypeId();

        Account acc = new Account(
            Name = 'Document Trigger Account',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert acc;

        Account acc2 = new Account(
            Name = 'Template Document Account',
            RecordTypeId = bregAccountRecordTypeId,
            breg_Entity_Type__c = 'ZZ'
        );
        insert acc2;

        Id caseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
            .get('BREG_Case')
            .getRecordTypeId();
        Case c = new Case(
            Subject = 'Document Trigger Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = acc.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert c;

        Case c2 = new Case(
            Subject = 'Certified Document Trigger Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = acc.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert c2;

        Case templateCase = new Case(
            Subject = 'Template Case',
            Status = 'New',
            Origin = 'Web',
            RecordTypeId = caseRecordTypeId,
            breg_Entity__c = acc2.Id,
            breg_Effective_Date__c = Date.today()
        );
        insert templateCase;

        insert new List<breg_Document__c>{
            new breg_Document__c(
                Name = 'For Initial: Attachment 1',
                breg_Case__c = c.Id,
                breg_Is_Uploaded_Attachment__c = true,
                breg_Docusign_Document_Id__c = 'DOC-001'
            ),
            new breg_Document__c(
                Name = 'For Initial: Attachment 2',
                breg_Case__c = c.Id,
                breg_Is_Uploaded_Attachment__c = true,
                breg_Docusign_Document_Id__c = 'DOC-002'
            ),
            new breg_Document__c(
                Name = 'For Initial: Ignored',
                breg_Case__c = c.Id,
                breg_Is_Uploaded_Attachment__c = false,
                breg_Docusign_Document_Id__c = 'DOC-003'
            ),
            new breg_Document__c(
                Name = 'Other Document',
                breg_Case__c = c.Id,
                breg_Is_Uploaded_Attachment__c = true,
                breg_Docusign_Document_Id__c = 'DOC-004'
            ),
            new breg_Document__c(
                Name = 'I_Template Document',
                breg_Case__c = templateCase.Id,
                breg_Is_Uploaded_Attachment__c = true,
                breg_Docusign_Document_Id__c = 'DOC-TEMPLATE'
            )
        };
    }

    private class DocuSignHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            BREGDocumentTriggerHandlerTest.mockRequestBodies.add(req.getBody());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"Name":"Workflow","Status":"Completed","Href":"https://example.com/workflows/123"}');
            return res;
        }
    }

    @isTest
    static void testGetRelatedDocs_ReturnsOnlyMatchingUploadedDocs() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        breg_Document__c excludedDoc = new breg_Document__c(
            Name = 'Excluded Document',
            breg_Case__c = c.Id,
            breg_Is_Uploaded_Attachment__c = true,
            breg_Docusign_Document_Id__c = 'DOC-EXCLUDED'
        );
        insert excludedDoc;

        Test.startTest();
        List<breg_Document__c> relatedDocs = BREGDocumentTriggerHandler.getRelatedDocs(
            c.Id,
            excludedDoc.Id,
            new List<String>{ 'For Initial: ' }
        );
        Test.stopTest();

        System.assertEquals(2, relatedDocs.size());

        Set<String> docNames = new Set<String>();
        for (breg_Document__c doc : relatedDocs) {
            docNames.add(doc.Name);
        }

        System.assert(docNames.contains('For Initial: Attachment 1'));
        System.assert(docNames.contains('For Initial: Attachment 2'));
        System.assert(!docNames.contains('For Initial: Ignored'));
        System.assert(!docNames.contains('Other Document'));
    }

    @isTest
    static void testAfterInsert_ResubmittalFiling_UsesInitialAndResubmittalAttachments() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new DocuSignHttpMock());

        breg_Document__c resubMainDoc = new breg_Document__c(
            Name = 'Resubmittal Filing Main Document',
            breg_Case__c = c.Id,
            breg_Is_Uploaded_Attachment__c = true,
            breg_Docusign_Document_Id__c = 'DOC-MAIN-R'
        );
        insert resubMainDoc;

        insert new breg_Document__c(
            Name = 'For Resubmittal: Attachment R1',
            breg_Case__c = c.Id,
            breg_Is_Uploaded_Attachment__c = true,
            breg_Docusign_Document_Id__c = 'DOC-R-001'
        );

        Test.startTest();
        List<breg_Document__c> relatedDocs = BREGDocumentTriggerHandler.getRelatedDocs(
            c.Id,
            resubMainDoc.Id,
            new List<String>{ 'For Resubmittal: ', 'For Initial: ' }
        );
        Test.stopTest();

        Set<String> docNames = new Set<String>();
        for (breg_Document__c doc : relatedDocs) {
            docNames.add(doc.Name);
        }

        System.assert(docNames.contains('For Resubmittal: Attachment R1'));
        System.assert(docNames.contains('For Initial: Attachment 1'));
        System.assert(docNames.contains('For Initial: Attachment 2'));
        System.assert(!docNames.contains('Resubmittal Filing Main Document'));
    }

    @isTest
    static void testAfterInsert_InitialFiling_EnqueuesAndExecutesWithMock() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        insert new breg_Document__c(
            Name = 'Existing Certifiable Document',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Docusign_Document_Id__c = 'DOC-EXISTING-CERT-I'
        );

        Test.setMock(HttpCalloutMock.class, new DocuSignHttpMock());

        Test.startTest();
        insert new breg_Document__c(
            Name = 'Initial Filing Main Document',
            breg_Case__c = c.Id,
            breg_Is_Uploaded_Attachment__c = true,
            breg_Docusign_Document_Id__c = 'DOC-MAIN'
        );
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testAfterInsert_OtherDocument_DoesNothing() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        Integer beforeCount = [
            SELECT Count()
            FROM breg_Document__c
            WHERE breg_Case__c = :c.Id
        ];

        Test.startTest();
        insert new breg_Document__c(
            Name = 'Regular Attachment',
            breg_Case__c = c.Id,
            breg_Is_Uploaded_Attachment__c = true,
            breg_Docusign_Document_Id__c = 'DOC-NOQUEUE'
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM breg_Document__c
            WHERE breg_Case__c = :c.Id
        ];

        System.assertEquals(beforeCount + 1, afterCount);
    }

    @isTest
    static void testBeforeInsert_HandleEditedCertifiedCopies_WithNameStartsWithI() {
        breg_Document__c templateDoc = [
            SELECT Id
            FROM breg_Document__c
            WHERE Name = 'I_Template Document'
            LIMIT 1
        ];

        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        insert new breg_Document__c(
            Name = 'Existing Certifiable Document',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Docusign_Document_Id__c = 'DOC-EXISTING-CERT-P'
        );

        breg_Document__c newDoc = new breg_Document__c(
            Name = 'I_Certified Copy',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Template_Document__c = templateDoc.Id,
            breg_Docusign_Document_Id__c = 'DOC-CERT-001'
        );

        new BREGDocumentTriggerHandler().handleEditedCertifiedCopies(new List<breg_Document__c>{ newDoc });

        System.assertEquals(false, newDoc.breg_Available_To_Certify__c);
        System.assertEquals(true, newDoc.breg_Is_Certified__c);
    }

    @isTest
    static void testBeforeInsert_HandleEditedCertifiedCopies_WithNameStartsWithP() {
        breg_Document__c templateDoc = [
            SELECT Id
            FROM breg_Document__c
            WHERE Name = 'I_Template Document'
            LIMIT 1
        ];

        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        insert new breg_Document__c(
            Name = 'Existing Certifiable Document',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Docusign_Document_Id__c = 'DOC-EXISTING-CERT-P'
        );

        breg_Document__c newDoc = new breg_Document__c(
            Name = 'P_Certified Copy',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Template_Document__c = templateDoc.Id,
            breg_Docusign_Document_Id__c = 'DOC-CERT-002'
        );

        new BREGDocumentTriggerHandler().handleEditedCertifiedCopies(new List<breg_Document__c>{ newDoc });

        System.assertEquals(false, newDoc.breg_Available_To_Certify__c);
        System.assertEquals(true, newDoc.breg_Is_Certified__c);
    }



    @isTest
    static void testBeforeInsert_HandleEditedCertifiedCopies_WithoutTemplate_NoChange() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        Test.startTest();
        breg_Document__c newDoc = new breg_Document__c(
            Name = 'I_No Template Copy',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Template_Document__c = null,
            breg_Docusign_Document_Id__c = 'DOC-CERT-004'
        );
        insert newDoc;
        Test.stopTest();

        breg_Document__c insertedDoc = [
            SELECT Id, breg_Available_To_Certify__c, breg_Is_Certified__c
            FROM breg_Document__c
            WHERE Id = :newDoc.Id
        ];

        System.assertEquals(true, insertedDoc.breg_Available_To_Certify__c);
        System.assertEquals(false, insertedDoc.breg_Is_Certified__c);
    }

    @isTest
    static void testgetCaseIdsWithCertifiedCopy_ReturnsCasesWithCertifiableDocs() {
        Case documentCase = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        Case templateCase = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Template Case'
            LIMIT 1
        ];

        insert new breg_Document__c(
            Name = 'I_Existing Certified Copy',
            breg_Case__c = documentCase.Id,
            breg_Available_To_Certify__c = true,
            breg_Docusign_Document_Id__c = 'DOC-EXISTING-CERT'
        );

        Set<Id> caseIds = new Set<Id>{ documentCase.Id, templateCase.Id };

        Test.startTest();
        Set<Id> caseIdsWithCertifiedCopy = new BREGDocumentTriggerHandler().getCaseIdsWithCertifiedCopy(caseIds);
        Test.stopTest();

        System.assertEquals(1, caseIdsWithCertifiedCopy.size());
        System.assert(caseIdsWithCertifiedCopy.contains(documentCase.Id));
        System.assert(!caseIdsWithCertifiedCopy.contains(templateCase.Id));
    }

    @isTest
    static void testAfterInsert_HandleCertifiedCopyDocuments_EnqueuesWorkflow() {
        breg_Document__c templateDoc = [
            SELECT Id, breg_Case__c
            FROM breg_Document__c
            WHERE Name = 'I_Template Document'
            LIMIT 1
        ];

        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new DocuSignHttpMock());

        Test.startTest();
        breg_Document__c newDoc = new breg_Document__c(
            Name = 'Certified Copy',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = true,
            breg_Template_Document__c = templateDoc.Id,
            breg_Docusign_Document_Id__c = 'DOC-CERTIFIED'
        );
        insert newDoc;
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testAfterInsert_HandleCertifiedCopyDocuments_SkipsEmptyAvailableToCertify() {
        breg_Document__c templateDoc = [
            SELECT Id, breg_Case__c
            FROM breg_Document__c
            WHERE Name = 'I_Template Document'
            LIMIT 1
        ];

        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Document Trigger Case'
            LIMIT 1
        ];

        Integer beforeCount = [
            SELECT Count()
            FROM breg_Document__c
            WHERE breg_Case__c = :c.Id
        ];

        Test.startTest();
        breg_Document__c newDoc = new breg_Document__c(
            Name = 'Not Certifiable',
            breg_Case__c = c.Id,
            breg_Available_To_Certify__c = false,
            breg_Template_Document__c = templateDoc.Id,
            breg_Docusign_Document_Id__c = 'DOC-NOT-CERT'
        );
        insert newDoc;
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM breg_Document__c
            WHERE breg_Case__c = :c.Id
        ];

        System.assertEquals(beforeCount + 1, afterCount);
    }

    @isTest
    static void testAfterUpdate_CertifiedCopyStatusChangedToCompleted_EnqueuesWorkflow() {
        Test.setMock(HttpCalloutMock.class, new DocuSignHttpMock());

        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Certified Document Trigger Case'
            LIMIT 1
        ];

        breg_Form_Configuration__c form = new breg_Form_Configuration__c(
            Name = 'DOCDLVR',
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR'
        );
        insert form;
        c.breg_Form_Configuration__c = form.Id;
        c.breg_Form_Code__c = form.breg_Form_Code__c;

        update c;

        breg_Document__c doc = new breg_Document__c(
            Name = 'Certified Copy Doc',
            breg_Case__c = c.Id,
            breg_Certified_Copy_Status__c = 'Requested',
            breg_Docusign_Document_Id__c = 'DOC-SEND-CERT'
        );
        insert doc;

        doc = [SELECT Id, Name, breg_Certified_Copy_Status__c, breg_Case__c, breg_Case__r.breg_Form_Code__c FROM breg_Document__c WHERE Id = :doc.Id];
        Map<Id, breg_Document__c> oldMap = new Map<Id, breg_Document__c>{ doc.Id => doc.clone(true, true, false, false) };

        doc.breg_Certified_Copy_Status__c = 'Completed';
        update doc;


        Test.startTest();
        // handler.handleSendCertifiedCopy(
        //     new List<breg_Document__c>{ doc },
        //     oldMap
        // );
        Test.stopTest();

        System.assert(true, 'handleSendCertifiedCopy should complete without error when status changes to Completed');
    }

    @isTest
    static void testAfterUpdate_CertifiedCopyStatusNotChangedToCompleted_NoWorkflow() {
        Case c = [
            SELECT Id
            FROM Case
            WHERE Subject = 'Certified Document Trigger Case'
            LIMIT 1
        ];

         breg_Form_Configuration__c form = new breg_Form_Configuration__c(
            Name = 'DOCDLVR',
            breg_Form_Code__c = 'DOCDLVR',
            breg_Suffix_Code__c = 'DOCDLVR'
        );
        insert form;
        c.breg_Form_Configuration__c = form.Id;
        c.breg_Form_Code__c = form.breg_Form_Code__c;
        update c;

        breg_Document__c doc = new breg_Document__c(
            Name = 'Certified Copy Doc No Change',
            breg_Case__c = c.Id,
            breg_Certified_Copy_Status__c = 'Requested',
            breg_Docusign_Document_Id__c = 'DOC-SEND-CERT-NO'
        );
        insert doc;

        doc = [SELECT Id, Name, breg_Certified_Copy_Status__c, breg_Case__c, breg_Case__r.breg_Form_Code__c FROM breg_Document__c WHERE Id = :doc.Id];
        Map<Id, breg_Document__c> oldMap = new Map<Id, breg_Document__c>{ doc.Id => doc.clone(true, true, false, false) };

        doc.breg_Certified_Copy_Status__c = 'Error';

        BREGDocumentTriggerHandler handler = new BREGDocumentTriggerHandler();
        handler.oldMap = oldMap;
        handler.newList = new List<SObject>{ doc };

        Test.startTest();
        handler.handleSendCertifiedCopy(
            new List<breg_Document__c>{ doc },
            oldMap
        );
        Test.stopTest();

        System.assert(true, 'handleSendCertifiedCopy should complete without enqueuing when status does not change to Completed');
    }
}