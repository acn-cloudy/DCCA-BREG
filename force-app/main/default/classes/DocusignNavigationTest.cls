@isTest
public with sharing class DocusignNavigationTest {

    public static testMethod void testContorller() {
        Account record = TestDataFactory.createAccountUnit('asdfksd sadf', '2343242341');
        insert record;
        ApexPages.StandardController stdController = new ApexPages.StandardController(record);
        DocusignNavigation nav = new DocusignNavigation(stdController);
        nav.Router();
    }
}