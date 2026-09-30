public class InsuranceBondSelector {
    public static List<InsuranceBond__c>  getInsuranceBonds(List<String> licenseIds) {
        return [Select Id, License__c, Type__c, Status__c, 
            CancelDate__c, TermDate__c, CurrentGapinInsurance__c, INSAbouttoExpire__c
            from InsuranceBond__c where License__c in: licenseIds];
    }
}