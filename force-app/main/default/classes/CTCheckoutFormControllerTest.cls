/*
 * -----------------------------------------------------------------------------------
 * Description
 * Test class for CTCheckoutFormController
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04082022 - Created for Case 00020872
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 04/08/2022
 * __________________________________________________________________________________
 * Changes
 */
@isTest
private class CTCheckoutFormControllerTest {
    @isTest
    static void testCTCheckoutFormControllerWithDependentApp() {
        Application__c a = TestDataFactory.createDummyApplication();
        Application__c dependentApp = [SELECT Id FROM Application__c LIMIT 1];
        License__c lic = [SELECT Id FROM License__c LIMIT 1];

        dependentApp.CurrentLicense__c = lic.Id;
        update dependentApp;

        a.DependentApplication__c = dependentApp.Id;
        insert a;

        Application__c app = [
                SELECT
                        Id,
                        Applicant__c,
                        DependentLicense__r.Licensee__c,
                        DependentApplication__c,
                        DependentApplication__r.CurrentLicense__c,
                        DependentApplication__r.CurrentLicense__r.Licensee__c
                FROM Application__c
                WHERE Id = :a.Id
        ];

        Test.startTest();
        PageReference ref = Page.CTCheckoutForm;
        ref.getParameters().put('id', app.Id);
        Test.setCurrentPage(ref);
        ApexPages.StandardController ctrl = new ApexPages.StandardController(app);
        CTCheckoutFormController extCtrl = new CTCheckoutFormController(ctrl);
        extCtrl.getApplicantLicenses();
        extCtrl.getDependentLicenseLicenses();
        extCtrl.getDependentApplicationClassifications();
        extCtrl.getDependentLicenseLicenseClassifications();
        Test.stopTest();
    }

    @isTest
    static void testCTCheckoutFormControllerWithDependentLic() {
        TestDataFactory.createLicense();
        Application__c a = [SELECT Id FROM Application__c LIMIT 1];
        String accountBusinessRti = Account.sObjectType
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('BusinessAccount')
                .getRecordTypeId();

        Account acc = [SELECT Id FROM Account WHERE RecordTypeId = :accountBusinessRti LIMIT 1];
        License__c lic = [SELECT Id FROM License__c WHERE Name ='acc3' LIMIT 1];
        lic.Licensee__c = acc.Id;
        update lic;

        a.DependentLicense__c = lic.Id;
        update a;

        Test.startTest();
        Application__c app = [
                SELECT
                        Id,
                        Applicant__c,
                        DependentLicense__r.Licensee__c,
                        DependentApplication__c,
                        DependentApplication__r.CurrentLicense__c,
                        DependentApplication__r.CurrentLicense__r.Licensee__c
                FROM Application__c
                LIMIT 1
        ];

        PageReference ref = Page.CTCheckoutForm;
        ref.getParameters().put('id', app.Id);
        Test.setCurrentPage(ref);
        ApexPages.StandardController ctrl = new ApexPages.StandardController(app);
        CTCheckoutFormController extCtrl = new CTCheckoutFormController(ctrl);
        extCtrl.getDependentLicenseLicenses();
        Test.stopTest();
    }

    @isTest
    static void testCTCheckoutFormControllerNoDependentAppAndLic() {
        TestDataFactory.createLicense();
        Application__c app = [
                SELECT
                        Id,
                        Applicant__c,
                        DependentLicense__r.Licensee__c,
                        DependentApplication__c,
                        DependentApplication__r.CurrentLicense__c,
                        DependentApplication__r.CurrentLicense__r.Licensee__c
                FROM Application__c
                LIMIT 1
        ];

        Test.startTest();
        PageReference ref = Page.CTCheckoutForm;
        ref.getParameters().put('id', app.Id);
        Test.setCurrentPage(ref);
        ApexPages.StandardController ctrl = new ApexPages.StandardController(app);
        CTCheckoutFormController extCtrl = new CTCheckoutFormController(ctrl);
        extCtrl.getDependentLicenseLicenses();
        Test.stopTest();
    }
}