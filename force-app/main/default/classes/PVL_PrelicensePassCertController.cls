public class PVL_PrelicensePassCertController {
    public String enrollmentIds;

    public PVL_PrelicensePassCertController() {
        enrollmentIds = System.currentPageReference()
                .getParameters()
                .get('q');
    }

    public List<PrelicenseCEEnrollment__c> getEnrollments() {
        List<String> filterIds = enrollmentIds.split(' ');
        List<PrelicenseCEEnrollment__c> enrollments = [
                SELECT
                        Id,
                        Course__r.Account__r.Name,
                        Course__r.Subject__r.PrelicenseType__c,
                        PassDate__c,
                        Account__r.Name,
                        Account__r.AccountSequenceId__c,
                        License__r.LicenseType__r.LicensePrefix__c,
                        CertificateNumberFormula__c
                FROM PrelicenseCEEnrollment__c
                WHERE Id IN : filterIds
        ];

        for (PrelicenseCEEnrollment__c r : enrollments) {
            if (r.PassDate__c != null) {
                r.PassDate__c = r.PassDate__c.addYears(2);
            }
        }

        return enrollments;
    }
}