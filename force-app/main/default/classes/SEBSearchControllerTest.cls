@isTest
private class SEBSearchControllerTest {

    @isTest
    static void test_searchSEBCaseContacts() {
        Test.startTest();
        SEBSearchController.searchSEBCaseContacts('Test', 1, 10);
        Test.stopTest();
    }

    @isTest
    static void test_getContactSEBCases() {
        Test.startTest();
        SEBSearchController.getContactSEBCases('');
        SEBSearchController.getContactSEBCases('Test');
        Test.stopTest();
    }

    @isTest
    static void test_shareDocument() {
        SpringCMApiManagerMock mock = new SpringCMApiManagerMock();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        SEBSearchController.SpringCMShareDocumentControllerInput input = new SEBSearchController.SpringCMShareDocumentControllerInput();
        input.documentId = '00000000-0000-0000-0000-000000000000';
        SEBSearchController.SpringCMShareDocumentControllerInput[] inputs = new SEBSearchController.SpringCMShareDocumentControllerInput[]{input};
        SEBSearchController.shareDocument(inputs);
        Test.stopTest();
    }
}