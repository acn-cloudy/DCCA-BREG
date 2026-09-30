@isTest
private class SuspenseDomainTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.createSuspenses();
    }

    @isTest
    static void testFunc() {
        List<Suspense__c> suspenses = [Select Id, License__c, InsuranceType__c from Suspense__c];
        System.assert((new SuspenseDomain(suspenses)).getLicenseId2InsuranceBondsTypes() != null);
        System.assert((new SuspenseDomain(suspenses)).getLicenseId2Suspenses() != null);
        
    }
    
}