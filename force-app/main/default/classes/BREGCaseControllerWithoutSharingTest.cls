@isTest
private with sharing class BREGCaseControllerWithoutSharingTest {
    private static final String DOCUSIGN_ID = 'DOCUSIGN-ID-123';

    @testSetup
    static void setupTestData() {
        breg_Document__c doc = new breg_Document__c(Name = 'Test Document', breg_Docusign_Document_Id__c = DOCUSIGN_ID);
        insert doc;
        Contact testContact = new Contact(FirstName = 'Update', LastName = 'Case Contact', Email = 'update.case.contact@test.com');
        insert testContact;
        List<Case> cases = new List<Case>();
        Case caseWithoutSubscription = new Case(Subject = 'Sub False', breg_Subscribe_Owner_Free_Email_Alerts__c = false);
        cases.add(caseWithoutSubscription);

        Case caseWithSubscription = new Case(Subject = 'Sub True', breg_Subscribe_Owner_Free_Email_Alerts__c = true);
        cases.add(caseWithSubscription);

        Case caseWithDoc = new Case(Subject = 'Case With Document', breg_Document__c = doc.Id);
        cases.add(caseWithDoc);

        Case caseWithoutDoc = new Case(Subject = 'Case Without Document');
        cases.add(caseWithoutDoc);
        insert cases;
    }

    @IsTest
    static void testUpdateCaseSubscriptionCheckbox_setToTrue() {
        Case cs = [SELECT Id FROM Case WHERE Subject = 'Sub False' LIMIT 1];

        Test.startTest();
        BREGCaseControllerWithoutSharing.updateCaseSubscriptionCheckbox(cs.Id, true);
        Test.stopTest();

        Case updated = [SELECT breg_Subscribe_Owner_Free_Email_Alerts__c FROM Case WHERE Id = :cs.Id];
        System.assertEquals(true, updated.breg_Subscribe_Owner_Free_Email_Alerts__c, 'Checkbox should be set to true');
    }

    @IsTest
    static void testUpdateCaseSubscriptionCheckbox_setToFalse() {
        Case cs = [SELECT Id FROM Case WHERE Subject = 'Sub True' LIMIT 1];

        Test.startTest();
        BREGCaseControllerWithoutSharing.updateCaseSubscriptionCheckbox(cs.Id, false);
        Test.stopTest();

        Case updated = [SELECT breg_Subscribe_Owner_Free_Email_Alerts__c FROM Case WHERE Id = :cs.Id];
        System.assertEquals(false, updated.breg_Subscribe_Owner_Free_Email_Alerts__c, 'Checkbox should be set to false');
    }

    @IsTest
    static void testUpdateCaseSubscriptionCheckbox_nullCaseId_shouldFail() {
        Test.startTest();
        try {
            BREGCaseControllerWithoutSharing.updateCaseSubscriptionCheckbox(null, true);
            System.assert(false, 'Expected DMLException due to null case Id');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected AuraHandledException');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetDocumentFromCase_withValidDocument() {
        Case cs = [SELECT Id FROM Case WHERE Subject = 'Case With Document' LIMIT 1];

        Test.startTest();
        String result = BREGCaseControllerWithoutSharing.getDocumentFromCase(cs.Id);
        Test.stopTest();

        System.assertEquals(DOCUSIGN_ID, result, 'Should return the Docusign Document ID');
    }

    @IsTest
    static void testGetDocumentFromCase_withoutDocument() {
        Case cs = [SELECT Id FROM Case WHERE Subject = 'Case Without Document' LIMIT 1];

        Test.startTest();
        String result = BREGCaseControllerWithoutSharing.getDocumentFromCase(cs.Id);
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null if no document is attached');
    }

    @IsTest
    static void testGetDocumentFromCase_nullCaseId() {
        Test.startTest();
        try {
            BREGCaseControllerWithoutSharing.getDocumentFromCase(null);
            System.assert(false, 'Expected AuraHandledException for null case ID');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected AuraHandledException');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdateCasesProcessingSpeed_setsExpeditedSpeed() {
        List<Case> cases = [SELECT Id FROM Case WHERE Subject IN ('Sub False', 'Sub True')];
        List<Id> caseIds = new List<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }

        Test.startTest();
        BREGCaseControllerWithoutSharing.updateCasesProcessingSpeed(caseIds);
        Test.stopTest();

        List<Case> updated = [SELECT breg_Processing_Speed__c FROM Case WHERE Id IN :caseIds];
        for (Case c : updated) {
            System.assertEquals('Expedited', c.breg_Processing_Speed__c, 'Processing speed should be set to Expedited');
        }
    }

    @IsTest
    static void testUpdateCasesProcessingSpeed_emptyList() {
        Test.startTest();
        BREGCaseControllerWithoutSharing.updateCasesProcessingSpeed(new List<Id>());
        Test.stopTest();

        System.assert(true, 'No exception should be thrown for empty list');
    }

    @IsTest
    static void testUpdateCaseContact_updatesContactId() {
        Case cs = [SELECT Id, ContactId FROM Case WHERE Subject = 'Sub False' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE Email = 'update.case.contact@test.com' LIMIT 1];

        Test.startTest();
        BREGCaseControllerWithoutSharing.updateCaseContact(cs.Id, contact.Id);
        Test.stopTest();

        Case updated = [SELECT ContactId FROM Case WHERE Id = :cs.Id];
        System.assertEquals(contact.Id, updated.ContactId, 'Case contact should be updated');
    }

    @IsTest
    static void testUpdateCaseContact_nullCaseId_shouldFail() {
        Contact contact = [SELECT Id FROM Contact WHERE Email = 'update.case.contact@test.com' LIMIT 1];
        Boolean thrown = false;

        Test.startTest();
        try {
            BREGCaseControllerWithoutSharing.updateCaseContact(null, contact.Id);
            System.assert(false, 'Expected AuraHandledException for null caseId');
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Expected AuraHandledException for null caseId');
    }
}