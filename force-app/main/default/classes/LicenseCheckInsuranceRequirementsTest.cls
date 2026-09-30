@isTest
private class LicenseCheckInsuranceRequirementsTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.insertInsuranceBonds();
        
    }
    // @isTest
    // static void testCheckInsuranceRequirementException() {
    //     Test.startTest();
    //     String licenseIdErrorMessage;
    //     try{
    //         LicenseCheckInsuranceRequirements.checkInsuranceRequirements(new List<String>());
    //     } catch(LicenseCheckInsuranceRequirements.CustomFlowException ex) {
    //         licenseIdErrorMessage = ex.getMessage();
    //     }
    //     String errorMessage;
    //     try{
    //         LicenseCheckInsuranceRequirements.checkInsuranceRequirements(new List<String>{'test'});
    //     } catch(LicenseCheckInsuranceRequirements.CustomFlowException ex) {
    //         errorMessage = ex.getMessage();
    //     }
        
    //     Test.stopTest();
    //     System.assert(errorMessage != null);
    //     System.assert(licenseIdErrorMessage != null);
    // }

    @isTest
    static void testCheckInsuranceRequirementsTrue() {
        License__c record = [Select Id from License__c limit 1];
        List<InsuranceBond__c> bonds = [Select Id, Type__c,License__c, License__r.LicenseType__r.Id, License__r.LicenseType__r.InsuranceBondTypesRequired__c , CurrentGapInInsurance__c from InsuranceBond__c where License__c =: record.Id];
        Set<String> types = new Set<String>();
        LicenseType__c licenseType;
        for(InsuranceBond__c bond: bonds) {
            bond.CurrentGapInInsurance__c = 0;
            types.add(bond.Type__c);
            licenseType = bond.License__r.LicenseType__r;
        }
        List<String> typeList = new List<String>();
        typeList.addAll(types);
        String requiredTypes = String.join(typeList, ';');
        licenseType.InsuranceBondTypesRequired__c = requiredTypes;
        update licenseType;
        update bonds;

        

        Test.startTest();
        List<Boolean> results = LicenseCheckInsuranceRequirements.checkInsuranceRequirements(new List<String> {record.Id});
        Test.stopTest();
        System.assertEquals(results.get(0), true);
        
    }

    @isTest
    static void testCheckInsuranceRequirementsFalse() {
        List<InsuranceBond__c> bonds = [Select Id, Type__c,License__c, License__r.LicenseType__r.Id, License__r.LicenseType__r.InsuranceBondTypesRequired__c , CurrentGapInInsurance__c from InsuranceBond__c];
        String type;
        LicenseType__c licenseType;
        for(InsuranceBond__c bond: bonds) {
            bond.CurrentGapInInsurance__c = 0;
            type = bond.Type__c;
            licenseType = bond.License__r.LicenseType__r;
        }
        licenseType.InsuranceBondTypesRequired__c = type;
        update licenseType;
        update bonds;

        License__c record = [Select Id from License__c limit 1];


        Test.startTest();
        List<Boolean> results = LicenseCheckInsuranceRequirements.checkInsuranceRequirements(new List<String> {record.Id});
        Test.stopTest();
        System.assertEquals(results.get(0), false);
        
    }
    
}