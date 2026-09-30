/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10212022 - Created for
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/21/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class RbEntityRbBrokerRnewalDependencyTest {
    @TestSetup
    static void setup() {
        Date licTypeEffectiveDate = Date.today().toStartOfMonth();
        Date licTypeExpireDate = licTypeEffectiveDate.addMonths(1).addDays(-1);

        LicenseType__c licTypeRbEntity = new LicenseType__c();
        licTypeRbEntity.Name = 'RB - Entity';
        licTypeRbEntity.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeRbEntity.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeRbEntity.DurationofLicenseInMonths__c = 1;
        licTypeRbEntity.AbleToInactivate__c = true;

        LicenseType__c licTypeRbBroker = new LicenseType__c();
        licTypeRbBroker.Name = 'RB - Broker';
        licTypeRbBroker.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeRbBroker.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeRbBroker.DurationofLicenseInMonths__c = 1;
        licTypeRbBroker.AbleToInactivate__c = true;

        LicenseType__c licTypeRbo = new LicenseType__c();
        licTypeRbo.Name = 'RBO';
        licTypeRbo.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeRbo.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeRbo.DurationofLicenseInMonths__c = 1;
        licTypeRbo.AbleToInactivate__c = true;

        insert new LicenseType__c[]{licTypeRbEntity, licTypeRbBroker, licTypeRbo};

        License__c licRbEntity = new License__c();
        licRbEntity.LicenseType__c = licTypeRbEntity.Id;
        licRbEntity.EffectiveExpireDate__c = licTypeExpireDate;

        License__c licRbBroker = new License__c();
        licRbBroker.LicenseType__c = licTypeRbBroker.Id;
        licRbBroker.EffectiveExpireDate__c = licTypeExpireDate;

        License__c licRbo = new License__c();
        licRbo.LicenseType__c = licTypeRbo.Id;
        licRbo.EffectiveExpireDate__c = licTypeExpireDate;

        insert new License__c[]{licRbEntity, licRbBroker, licRbo};

        licRbEntity.Status__c = 'C - Current, Valid & In Good Standing';
        licRbEntity.ActiveInactive__c = 'Active';
        licRbEntity.ThisLicenseRenewed__c = true;

        licRbBroker.Status__c = 'C - Current, Valid & In Good Standing';
        licRbBroker.ActiveInactive__c = 'Active';
        licRbBroker.ThisLicenseRenewed__c = true;

        update new License__c[]{licRbEntity, licRbBroker};

        AssociatedLicense__c rbEntityRbBrokerAssoc = new AssociatedLicense__c();
        rbEntityRbBrokerAssoc.EntityLicense__c = licRbEntity.Id;
        rbEntityRbBrokerAssoc.EmployeeLicense__c = licRbBroker.Id;
        rbEntityRbBrokerAssoc.EmploymentStatus__c = 'Employed';
        rbEntityRbBrokerAssoc.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';

        AssociatedLicense__c rboRbEntityAssoc = new AssociatedLicense__c();
        rboRbEntityAssoc.EntityLicense__c = licRbo.Id;
        rboRbEntityAssoc.EmployeeLicense__c = licRbEntity.Id;
        rboRbEntityAssoc.EmploymentStatus__c = 'Employed';
        insert new AssociatedLicense__c[]{rbEntityRbBrokerAssoc, rboRbEntityAssoc};

        Date nextLicensePeriodEffectiveDate = licTypeExpireDate.addDays(1);
        Date nextLicensePeriodExpireDate = nextLicensePeriodEffectiveDate.addMonths(1).addDays(-1);
        String appLicensePeriodRnew = String.valueOf(nextLicensePeriodEffectiveDate.month()) + '/' +
            String.valueOf(nextLicensePeriodEffectiveDate.day()) + '/' +
            String.valueOf(nextLicensePeriodEffectiveDate.year()) + ' - ' +
            String.valueOf(nextLicensePeriodExpireDate.month()) + '/' +
            String.valueOf(nextLicensePeriodExpireDate.day()) + '/' +
            String.valueOf(nextLicensePeriodExpireDate.year());

        Id appPvlRnewRtId = APplication__c.getSObjectType()
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PVLRNEW')
            .getRecordTypeId();

        Application__c appRbo = new Application__c();
        appRbo.CurrentLicense__c = licRbo.Id;
        appRbo.Type__c = 'RNEW - Renewal';
        appRbo.LicenseType__c = licTypeRbo.Id;
        appRbo.Status__c = 'D1 - Awaiting Dependency Review';
        appRbo.Phase__c = 'D - Dependency Review';
        appRbo.LicensePeriodRNEW__c = appLicensePeriodRnew;
        appRbo.RecordTypeId = appPvlRnewRtId;

        Application__c appRbBroker = new Application__c();
        appRbBroker.CurrentLicense__c = licRbBroker.Id;
        appRbBroker.Type__c = 'RNEW - Renewal';
        appRbBroker.LicenseType__c = licTypeRbBroker.Id;
        appRbBroker.Status__c = 'D1 - Awaiting Dependency Review';
        appRbBroker.Phase__c = 'D - Dependency Review';
        appRbBroker.LicensePeriodRNEW__c = appLicensePeriodRnew;
        appRbBroker.RecordTypeId = appPvlRnewRtId;
        insert new Application__c[]{appRbo, appRbBroker};
    }

    @IsTest
    static void doBrokerTest() {
        List<RbEntityRbBrokerRnewalDependency.Input> params = new List<RbEntityRbBrokerRnewalDependency.Input>();
        RbEntityRbBrokerRnewalDependency.Input param = new RbEntityRbBrokerRnewalDependency.Input();
        param.inputLicense = [
            SELECT
                Id,
                LicenseTypeName__c,
                LicenseTypeExpireDate__c
            FROM License__c
            WHERE LicenseTypeName__c = 'RB - Broker'
            LIMIT 1
        ];
        param.inputApplication = null;
        params.add(param);
        RbEntityRbBrokerRnewalDependency.runRenewalDependency(params);
    }

    @IsTest
    static void doEntityTest() {
        List<RbEntityRbBrokerRnewalDependency.Input> params = new List<RbEntityRbBrokerRnewalDependency.Input>();
        RbEntityRbBrokerRnewalDependency.Input param = new RbEntityRbBrokerRnewalDependency.Input();
        License__c rbBroker = [SELECT Id FROM License__c WHERE LicenseTypeName__c = 'RB - Broker' LIMIT 1];
        rbBroker.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        rbBroker.ActiveInactive__c = 'Active';
        rbBroker.ThisLicenseRenewed__c = false;
        update rbBroker;

        param.inputLicense = [
            SELECT
                Id,
                LicenseTypeName__c,
                LicenseTypeExpireDate__c
            FROM License__c
            WHERE LicenseTypeName__c = 'RB - Entity'
            LIMIT 1
        ];
        param.inputApplication = null;
        params.add(param);
        RbEntityRbBrokerRnewalDependency.runRenewalDependency(params);
    }

    @IsTest
    static void doEntityWthNoRenewedRbBrokerTest() {
        List<RbEntityRbBrokerRnewalDependency.Input> params = new List<RbEntityRbBrokerRnewalDependency.Input>();
        RbEntityRbBrokerRnewalDependency.Input param = new RbEntityRbBrokerRnewalDependency.Input();
        param.inputLicense = [
            SELECT
                Id,
                LicenseTypeName__c,
                LicenseTypeExpireDate__c
            FROM License__c
            WHERE LicenseTypeName__c = 'RB - Entity'
            LIMIT 1
        ];
        param.inputApplication = null;
        params.add(param);
        RbEntityRbBrokerRnewalDependency.runRenewalDependency(params);
    }
}