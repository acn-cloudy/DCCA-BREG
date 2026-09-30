/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10192022 - Created for
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/19/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
private class RealEstateLicensesInactivatorBatchTest {
    @TestSetup
    static void setup() {
        Date licTypeEffectiveDate = Date.today().toStartOfMonth();
        Date licTypeEffectiveExpireDate = licTypeEffectiveDate.addMonths(1).addDays(-1);

        LicenseType__c licTypeRbEntity = new LicenseType__c();
        licTypeRbEntity.Name = 'RB - Entity';
        licTypeRbEntity.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeRbEntity.PreviousLicensePeriodExpireDate__c = Date.today().addDays(100);
        licTypeRbEntity.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeRbEntity.DurationofLicenseInMonths__c = 1;
        licTypeRbEntity.AbleToInactivate__c = true;

        LicenseType__c licTypeRbBroker = new LicenseType__c();
        licTypeRbBroker.Name = 'RB - Broker';
        licTypeRbBroker.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeRbBroker.PreviousLicensePeriodExpireDate__c = Date.today().addDays(100);
        licTypeRbBroker.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeRbBroker.DurationofLicenseInMonths__c = 1;
        licTypeRbBroker.AbleToInactivate__c = true;

        insert new List<LicenseType__c>{licTypeRbEntity, licTypeRbBroker};

        License__c licRbEntity = new License__c();
        licRbEntity.LicenseType__c = licTypeRbEntity.Id;
        licRbEntity.EffectiveExpireDate__c = licTypeEffectiveExpireDate;

        License__c licRbEntity2 = new License__c();
        licRbEntity2.LicenseType__c = licTypeRbEntity.Id;
        licRbEntity2.EffectiveExpireDate__c = licTypeEffectiveExpireDate;

        License__c licRbEntity3 = new License__c();
        licRbEntity3.LicenseType__c = licTypeRbEntity.Id;
        licRbEntity3.EffectiveExpireDate__c = licTypeEffectiveExpireDate;

        License__c licRbBroker = new License__c();
        licRbBroker.LicenseType__c = licTypeRbBroker.Id;
        licRbBroker.EffectiveExpireDate__c = licTypeEffectiveExpireDate;

        License__c licRbBroker2 = new License__c();
        licRbBroker2.LicenseType__c = licTypeRbBroker.Id;
        licRbBroker2.EffectiveExpireDate__c = licTypeEffectiveExpireDate;

        License__c licRbBroker3 = new License__c();
        licRbBroker3.LicenseType__c = licTypeRbBroker.Id;
        licRbBroker3.EffectiveExpireDate__c = licTypeEffectiveExpireDate;


        insert new List<License__c>{licRbEntity, licRbEntity2, licRbEntity3, licRbBroker, licRbBroker2, licRbBroker3};

        licRbEntity.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licRbEntity.ActiveInactive__c = 'Active';

        licRbEntity2.Status__c = 'Z - Current & Valid, But Subject To Disciplinary Requirement';
        licRbEntity2.ActiveInactive__c = 'Active';

        licRbEntity3.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licRbEntity3.ActiveInactive__c = 'Active';

        licRbBroker.Status__c = 'C - Current, Valid & In Good Standing';
        licRbBroker.ActiveInactive__c = 'Active';

        licRbBroker2.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licRbBroker2.ActiveInactive__c = 'Active';

        licRbBroker3.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licRbBroker3.ActiveInactive__c = 'Active';

        update new List<License__c>{licRbEntity, licRbEntity2, licRbEntity3, licRbBroker, licRbBroker2, licRbBroker3};

        AssociatedLicense__c rbEntityAssoc = new AssociatedLicense__c();
        rbEntityAssoc.EntityLicense__c = licRbEntity.Id;
        rbEntityAssoc.EmployeeLicense__c = licRbBroker.Id;
        rbEntityAssoc.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c rbEntity2Assoc = new AssociatedLicense__c();
        rbEntity2Assoc.EntityLicense__c = licRbEntity2.Id;
        rbEntity2Assoc.EmployeeLicense__c = licRbBroker2.Id;
        rbEntity2Assoc.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c rbEntity3Assoc = new AssociatedLicense__c();
        rbEntity3Assoc.EntityLicense__c = licRbEntity2.Id;
        rbEntity3Assoc.EmployeeLicense__c = licRbBroker3.Id;
        rbEntity3Assoc.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c rbEntity4Assoc = new AssociatedLicense__c();
        rbEntity4Assoc.EntityLicense__c = licRbEntity3.Id;
        rbEntity4Assoc.EmployeeLicense__c = licRbBroker.Id;
        rbEntity4Assoc.EmploymentStatus__c = 'Employed';

        insert new List<AssociatedLicense__c>{rbEntityAssoc, rbEntity2Assoc, rbEntity3Assoc, rbEntity4Assoc};

        String appLicensePeriodRnew = String.valueOf(licTypeEffectiveDate.month()) + '/' +
            String.valueOf(licTypeEffectiveDate.day()) + '/' +
            String.valueOf(licTypeEffectiveDate.year()) + ' - ' +
            String.valueOf(licTypeEffectiveExpireDate.month()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate.day()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate.year());

        Id appPvlRnewRtId = APplication__c.getSObjectType()
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PVLRNEW')
            .getRecordTypeId();

        Application__c appRbEntity = new Application__c();
        appRbEntity.CurrentLicense__c = licRbEntity.Id;
        appRbEntity.Type__c = 'RNEW - Renewal';
        appRbEntity.LicenseType__c = licTypeRbEntity.Id;
        appRbEntity.Status__c = 'D1 - Awaiting Dependency Review';
        appRbEntity.Phase__c = 'D - Dependency Review';
        appRbEntity.LicensePeriodRNEW__c = appLicensePeriodRnew;
        appRbEntity.RecordTypeId = appPvlRnewRtId;

        Application__c appRbEntity3 = new Application__c();
        appRbEntity3.CurrentLicense__c = licRbEntity3.Id;
        appRbEntity3.Type__c = 'RNEW - Renewal';
        appRbEntity3.LicenseType__c = licTypeRbEntity.Id;
        appRbEntity3.Status__c = 'D2 - Continuing Education Missing';
        appRbEntity3.Phase__c = 'D - Dependency Review';
        appRbEntity3.LicensePeriodRNEW__c = appLicensePeriodRnew;
        appRbEntity3.RecordTypeId = appPvlRnewRtId;

        Application__c appRbBroker2 = new Application__c();
        appRbBroker2.CurrentLicense__c = licRbBroker2.Id;
        appRbBroker2.Type__c = 'RNEW - Renewal';
        appRbBroker2.LicenseType__c = licTypeRbBroker.Id;
        appRbBroker2.Status__c = 'D2 - Continuing Education Missing';
        appRbBroker2.Phase__c = 'D - Dependency Review';
        appRbBroker2.LicensePeriodRNEW__c = appLicensePeriodRnew;
        appRbBroker2.RecordTypeId = appPvlRnewRtId;

        Application__c appRbBroker3 = new Application__c();
        appRbBroker3.CurrentLicense__c = licRbBroker3.Id;
        appRbBroker3.Type__c = 'RNEW - Renewal';
        appRbBroker3.LicenseType__c = licTypeRbBroker.Id;
        appRbBroker3.Status__c = 'D1 - Awaiting Dependency Review';
        appRbBroker3.Phase__c = 'D - Dependency Review';
        appRbBroker3.LicensePeriodRNEW__c = appLicensePeriodRnew;
        appRbBroker3.RecordTypeId = appPvlRnewRtId;

        insert new List<Application__c>{appRbEntity, appRbEntity3, appRbBroker2, appRbBroker3};
    }

    @IsTest
    static void batchTest() {
        Test.startTest();
        (new RealEstateLicensesInactivatorBatch()).execute(null);
        Test.stopTest();
    }
}