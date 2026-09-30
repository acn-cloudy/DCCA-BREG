/*
 * -----------------------------------------------------------------------------------
 * Description
 * https://lucid.app/lucidchart/aaa20ac0-4780-4bce-9904-0a8391f2a01d/edit?invitationId=inv_13fa9641-cba6-4bf9-b4fc-51b6f257e626&page=-EZZCIEv3uyM#
 * -----------------------------------------------------------------------------------
 * Covered by: RbEntityRbBrokerRnewalDependencyTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10202022 - Created for case 00025296
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/20/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public without sharing class RbEntityRbBrokerRnewalDependency {

    @InvocableMethod
    public static void runRenewalDependency(List<Input>inputs) {
        License__c inputLicense = inputs[0].inputLicense;
        Application__c inputApplication = inputs[0].inputApplication;

        if (inputLicense.LicenseTypeName__c == 'RB - Broker') {
            doRbBroker(inputLicense, inputApplication);
        }

        if (inputLicense.LicenseTypeName__c == 'RB - Entity') {
            doRbEntity(inputLicense, inputApplication);
        }
    }

    private static void doRbEntity(License__c inputLicense, Application__c inputApplication) {
        //find associated RBOs
        List<AssociatedLicense__c> rbEntityRboAssoc = [
            SELECT
                Id,
                EntityLicense__c,
                EntityLicense__r.Status__c,
                EntityLicense__r.ThisLicenseRenewed__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c = :inputLicense.Id
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND EntityLicenseType__c = 'RBO'
        ];

        if (rbEntityRboAssoc.isEmpty()) {
            return;
        }

        Set<Id> rboLicenseIds = new Set<Id>();
        for (AssociatedLicense__c al : rbEntityRboAssoc) {
            rboLicenseIds.add(al.EntityLicense__c);
        }

        //find applications
        List<Application__c> rboApplications = [
            SELECT
                Id,
                CurrentLicense__c,
                CurrentLicense__r.LicenseTypeNextExpire__c,
                LicenseType__r.NextLicensePeriod__c,
                LicensePeriodRNEW__c
            FROM Application__c
            WHERE CurrentLicense__c IN :rboLicenseIds
            AND Status__c = 'D1 - Awaiting Dependency Review'
            AND (Type__c = 'RNEW - Renewal' OR Type__c = 'RSTR - Restore - No A/I Status')
        ];

        if (rboApplications.isEmpty()) {
            return;
        }

        List<Application__c> d1RboApplications = new List<Application__c>();
        for (Application__c a : rboApplications) {
            if (a.LicensePeriodRNEW__c == a.LicenseType__r.NextLicensePeriod__c) {
                d1RboApplications.add(a);
            }
        }

        if (d1RboApplications.isEmpty()) {
            return;
        }

        //find BIC RB Broker licenses
        List<AssociatedLicense__c> rbEntityRbBrokerAssoc = [
            SELECT
                Id,
                EmployeeLicense__c,
                EmployeeLicense__r.Status__c,
                EmployeeLicense__r.ThisLicenseRenewed__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c = :inputLicense.Id
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND Position__c ='BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)'
        ];

        Set<Id> rbBrokerLicenseIds = new Set<Id>();
        Boolean foundRenewedRbBroker = false;

        for (AssociatedLicense__c al : rbEntityRbBrokerAssoc) {
            if (al.EmployeeLicense__r.ThisLicenseRenewed__c && al.EmployeeLicense__r.Status__c == 'C - Current, Valid & In Good Standing') {
                foundRenewedRbBroker = true;
                break;
            }

            rbBrokerLicenseIds.add(al.EmployeeLicense__c);
        }

        if (!foundRenewedRbBroker) {
            return;
        }

        List<License__c> rboLicensesToUpdate = new List<License__c>();
        for (Application__c a : d1RboApplications) {
            a.Status__c = 'HC - Application Completed';
            a.Phase__c = 'H - License Generation';

            License__c l = new License__c();
            l.Id = a.CurrentLicense__c;
            l.Status__c = 'C - Current, Valid & In Good Standing';
            l.EffectiveExpireDate__c = a.CurrentLicense__r.LicenseTypeNextExpire__c;
            rboLicensesToUpdate.add(l);
        }

        update rboLicensesToUpdate;
        update d1RboApplications;
    }

    private static void doRbBroker(License__c inputLicense, Application__c inputApplication) {
        //find associated entities
        List<AssociatedLicense__c> rbBrokerAssociatedEntities = [
            SELECT
                Id,
                EntityLicense__c,
                EntityLicense__r.Status__c,
                EntityLicense__r.ThisLicenseRenewed__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c = :inputLicense.Id
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND EntityLicenseType__c = 'RB - Entity'
            AND Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)'
            AND EntityLicense__r.Status__c = 'C - Current, Valid & In Good Standing'
            AND EntityLicense__r.ThisLicenseRenewed__c = true
        ];

        if (rbBrokerAssociatedEntities.isEmpty()) {
            return;
        }

        Set<Id> entityLicenseIds = new Set<Id>();

        for (AssociatedLicense__c al : rbBrokerAssociatedEntities) {
            entityLicenseIds.add(al.EntityLicense__c);
        }

        //find associated RBOs
        List<AssociatedLicense__c> rbEntityRboAssoc = [
            SELECT
                Id,
                EntityLicense__c,
                EntityLicense__r.Status__c,
                EntityLicense__r.ThisLicenseRenewed__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :entityLicenseIds
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND EntityLicenseType__c = 'RBO'
        ];

        if (rbEntityRboAssoc.isEmpty()) {
            return;
        }

        Set<Id> rboLicenseIds = new Set<Id>();

        for (AssociatedLicense__c al : rbEntityRboAssoc) {
            rboLicenseIds.add(al.EntityLicense__c);
        }

        List<Application__c> rboApplications = [
            SELECT
                Id,
                CurrentLicense__c,
                CurrentLicense__r.LicenseTypeNextExpire__c,
                LicenseType__r.NextLicensePeriod__c,
                LicensePeriodRNEW__c
            FROM Application__c
            WHERE CurrentLicense__c IN :rboLicenseIds
            AND Status__c = 'D1 - Awaiting Dependency Review'
            AND (Type__c = 'RNEW - Renewal' OR Type__c = 'RSTR - Restore - No A/I Status')
        ];

        List<Application__c> rboApplicationsForUpdate = new List<Application__c>();
        List<License__c> rboLicensesForUpdate = new List<License__c>();

        for (Application__c a : rboApplications) {
            if (a.LicensePeriodRNEW__c == a.LicenseType__r.NextLicensePeriod__c) {
                a.Phase__c = 'H - License Generation';
                a.Status__c = 'HC - Application Completed';
                rboApplicationsForUpdate.add(a);

                License__c l = new License__c();
                l.Id = a.CurrentLicense__c;
                l.Status__c = 'C - Current, Valid & In Good Standing';
                l.EffectiveExpireDate__c = a.CurrentLicense__r.LicenseTypeNextExpire__c;
                rboLicensesForUpdate.add(l);
            }
        }

        if (rboApplicationsForUpdate.isEmpty()) {
            return;
        }

        update rboLicensesForUpdate;
        update rboApplicationsForUpdate;
    }

    public class Input {
        @InvocableVariable(required = true)
        public License__c inputLicense;

        @InvocableVariable(required = true)
        public Application__c inputApplication;
    }
}