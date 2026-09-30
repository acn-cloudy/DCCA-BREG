/*
 * ___________________________________________________________________________________
 * Description Controller for CEPassCertificate VF page
 * Covered by: CEPassCertificateControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL03232021 - Created for DCCA CE Portal
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/23/2021
 * __________________________________________________________________________________
 *
 * @See Case 00013927
 */
public class CEPassCertificateController {
    public String enrollmentIds;
    public String courseId;

    public CEPassCertificateController() {
        enrollmentIds = System.currentPageReference()
                .getParameters()
                .get('q');

        if (System.currentPageReference().getParameters().containsKey('cid')) {
            courseId = System.currentPageReference()
                    .getParameters()
                    .get('cid');
        }
    }

    public List<PrelicenseCEEnrollment__c> getEnrollments() {
        List<PrelicenseCEEnrollment__c> enrollments = new List<PrelicenseCEEnrollment__c>();
        String q = 'SELECT ' +
                'Id, ' +
                'EnrolleeName__c, '+
                'CompletionDate__c, '+
                'Subject__r.Type__c,' +
                'Course__r.Account__r.Name, ' +
                'Course__r.Credits__c, ' +
                'Course__r.Subject__r.Name, ' +
                'Course__r.EndDate__c, ' +
                'PassDate__c, ' +
                'Account__r.Name, ' +
                'Account__r.Certificate_Number__c, ' +
                'License__r.Name, ' +
                'License__r.LicenseType__r.StartofRenewalPeriod__c, ' +
                'License__r.LicenseType__r.EndofRenewalPeriod__c, ' +
                'CertificateNumberFormula__c, ' +
                'AttendeeCodeFormula__c ' +
                'FROM PrelicenseCEEnrollment__c ';
        if (String.isNotEmpty(courseId)) {
            q += 'WHERE Course__c = :courseId ';
        } else {
            List<String> filterIds = enrollmentIds.split(' ');
            q += 'WHERE Id IN : filterIds';
        }

        enrollments = Database.query(q);

        return enrollments;
    }
}