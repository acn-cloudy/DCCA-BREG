/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: RboRenewalDependencyTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL09212022 - Created for case 00023742
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 09/21/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public without sharing class RboRenewalDependency {
    @InvocableMethod
    public static void runRenewalDependency(List<Input>inputs) {
        License__c inputLicense = inputs[0].inputLicense;
        Application__c inputApplication = inputs[0].inputApplication;

        List<AssociatedLicense__c> associatedRbEntityLicenses = [
            SELECT
                Id,
                EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EmploymentStatus__c = 'Employed'
            AND EntityLicense__c = :inputLicense.Id
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND EmployeeLicenseType__c = 'RB - Entity'
            AND EmployeeLicense__r.Status__c = 'C - Current, Valid & In Good Standing'
            AND EmployeeLicense__r.ThisLicenseRenewed__c = true
        ];

        if (associatedRbEntityLicenses.isEmpty()) {
            if(System.isBatch() ) {
                setAppToD1AndLaunchFlow(inputApplication.Id, inputLicense.Id);
            } else {
                setAppToD1AndLaunchFlowFuture(inputApplication.Id, inputLicense.Id);
            }
            
            return;
        }

        //find BIC

        Set<Id> rbEntityIds = new Set<Id>();
        for (AssociatedLicense__c al : associatedRbEntityLicenses) {
            rbEntityIds.add(al.EmployeeLicense__c);
        }

        List<AssociatedLicense__c> associatedBics = [
            SELECT
                Id
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :rbEntityIds
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND EmployeeLicense__r.Status__c = 'C - Current, Valid & In Good Standing'
            AND EmployeeLicense__r.ThisLicenseRenewed__c = true
            AND Position__c='BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)'
        ];

        if (associatedBics.isEmpty()) {
            if(system.isBatch()) {
                setAppToD1AndLaunchFlow(inputApplication.Id, inputLicense.Id);
            } else {
                setAppToD1AndLaunchFlowFuture(inputApplication.Id, inputLicense.Id);
            }
            
            return;
        }

        Map<String, Object> params = new Map<String, Object>();
        params.put('InputApplication', inputApplication);
        params.put('InputLicense', inputLicense);
        Flow.Interview.PVL_RNEW_RSTR_Updater f = new Flow.Interview.PVL_RNEW_RSTR_Updater(params);
        f.start();
    }

    
    private static void setAppToD1AndLaunchFlowFuture(String applicationId, String licenseId) {
        System.enqueueJob(new QueueClass(applicationId, licenseId));
    }
    public class QueueClass implements Queueable {
        private String applicationId;
        private String licenseId;
        //accepts a set of records to update and their new batch number
        public QueueClass(String applicationId, String licenseId) {
            this.applicationId = applicationId;
            this.licenseId = licenseId;
        }
        public void execute(QueueableContext context) {
            setAppToD1AndLaunchFlow(applicationId, licenseId);
        }    
    }

    
    private static void setAppToD1AndLaunchFlow(String applicationId, String licenseId) {
        Application__c inputApplication = [
            SELECT
                Id,
                Type__c,
                ApplicationReceivedDate__c,
                DateofLicensure__c
            FROM Application__c
            WHERE Id = :applicationId
        ];

        inputApplication.Id = applicationId;
        inputApplication.Status__c = 'D1 - Awaiting Dependency Review';
        inputApplication.Phase__c = 'D - Dependency Review';

        License__c inputLicense = [
            SELECT
                Id,
                LicenseType__r.NextLicensePeriodEffectiveDate__c,
                LicenseType__r.NextLicensePeriodExpireDate__c
            FROM License__c
            WHERE Id = :licenseId
        ];

        inputLicense.Id = licenseId;
        inputLicense.ThisLicenseRenewed__c = true;

        update new SObject[]{inputApplication, inputLicense};

        Map<String, Object> params = new Map<String, Object>();
        params.put('InputApplication', inputApplication);
        params.put('InputLicense', inputLicense);
        Flow.Interview.Create_License_History f = new Flow.Interview.Create_License_History(params);
        f.start();
    }

    public class Input{
        @InvocableVariable(required = true)
        public License__c inputLicense;

        @InvocableVariable(required = true)
        public Application__c inputApplication;
    }
}