/****
 * Description: 27880
 * Created by: pacificpointcorpaz000027880
 * ******/
public class LicenseCheckInsuranceRequirements {
    public static final List<String> dedicatedStatus = new List<String>{'Active', 'Waived', 'Pending'};
    public class CustomFlowException extends Exception {}

    @InvocableMethod(label='License: Check Insurance Requirements' description='This method can be called from a flow.')
    public static List<Boolean> checkInsuranceRequirements(List<String> inputStrings) {
        List<String> insuranceType_S = new List<String>();
        // // Your method implementation will go here
        // // Assuming that the license Id has been attached.
        // if(inputStrings.isEmpty()) {
        //     throw new CustomFlowException('Please make sure the license Id can be attached.');
        // }

        //
        List<License__c> licenses = [Select Id, LicenseType__r.InsuranceBondTypesRequired__c, 
            LicenseType__r.BreakinInsuranceCoverageAllowed__c from License__c where Id in: inputStrings];
        Map<Id, License__c> licenseMap = new Map<Id, License__c>(licenses);
        // if(licenses.isEmpty()) {
        //     throw new CustomFlowException('Please make sure the license Id is valid.');
        // }
        List<String> licenseIds = (new LicenseDomain(licenses)).getIds();
        List<InsuranceBond__c> insuranceBonds = InsuranceBondSelector.getInsuranceBonds(licenseIds);
        Map<String, List<InsuranceBond__c>> insuranceBondsMap = (new InsuranceBondDomain(insuranceBonds)).getLicenseId2InsuranceBonds();
        List<Boolean> results = new List<Boolean>();
        for(String licenseId: inputStrings) {
            Boolean isValid = true;
            License__c record = licenseMap.get(licenseId);
            List<InsuranceBond__c> bonds = insuranceBondsMap.get(licenseId);
            if(bonds != null && !bonds.isEmpty() && record != null) {
                Set<String> typeSetRequired = (new InsuranceBondDomain(bonds)).getMissingRequiredTypes(record);
                if(!typeSetRequired.isEmpty()) isValid = false;
            }
            results.add(isValid);
        }
        // typeSetRequired is empty means all the required license types are met under the insurance bond type value.
        return results;
    }
}