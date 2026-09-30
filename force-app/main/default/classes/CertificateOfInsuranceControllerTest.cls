@isTest
private class CertificateOfInsuranceControllerTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.insertInsurancePortalSubmissions();
    }
    public static testMethod void testController() {
        InsurancePortalSubmission__c record = [Select Id from InsurancePortalSubmission__c limit 1];
        ApexPages.standardController std = new ApexPages.standardController(record);
        CertificateOfInsuranceController ctrl = new CertificateOfInsuranceController(std);
        ctrl.toTitleCase('KLSDJFLSKDFJ of FLJDFL in SDKKKS at');
    }
}