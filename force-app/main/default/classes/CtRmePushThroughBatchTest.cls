/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10192022 - Created for case 00024031
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
private class CtRmePushThroughBatchTest {
    @TestSetup
    static void setup() {
        Date licTypeEffectiveDate = Date.today().toStartOfMonth();
        Date licTypeEffectiveExpireDate = licTypeEffectiveDate.addMonths(1).addDays(-1);

        LicenseType__c licTypeCtEntity = new LicenseType__c();
        licTypeCtEntity.Name = 'CT - Entity';
        licTypeCtEntity.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeCtEntity.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeCtEntity.DurationofLicenseInMonths__c = 1;

        LicenseType__c licTypeCtRme = new LicenseType__c();
        licTypeCtRme.Name = 'CT - RME';
        licTypeCtRme.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeCtRme.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeCtRme.DurationofLicenseInMonths__c = 1;

        insert new LicenseType__c[]{licTypeCtEntity, licTypeCtRme};

        License__c licCtEntity = new License__c();
        licCtEntity.LicenseType__c = licTypeCtEntity.Id;

        License__c licCtRme = new License__c();
        licCtRme.LicenseType__c = licTypeCtRme.Id;

        License__c licCtRmeNoAssoc = new License__c();
        licCtRmeNoAssoc.LicenseType__c = licTypeCtRme.Id;

        insert new License__c[]{licCtEntity, licCtRme, licCtRmeNoAssoc};

        licCtEntity.Status__c = 'C - Current, Valid & In Good Standing';
        licCtEntity.ActiveInactive__c = 'Active';
        licCtEntity.ThisLicenseRenewed__c = true;

        licCtRme.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtRme.ActiveInactive__c = 'Active';
        licCtRme.ThisLicenseRenewed__c = true;

        licCtRmeNoAssoc.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtRmeNoAssoc.ActiveInactive__c = 'Active';
        licCtRmeNoAssoc.ThisLicenseRenewed__c = true;

        update new License__c[]{licCtEntity, licCtRme, licCtRmeNoAssoc};

        AssociatedLicense__c ctEntityAssoc = new AssociatedLicense__c();
        ctEntityAssoc.EntityLicense__c = licCtEntity.Id;
        ctEntityAssoc.EmployeeLicense__c = licCtRme.Id;
        ctEntityAssoc.EmploymentStatus__c = 'Employed';
        // ctEntityAssoc.EntityPrincipal__c = true;
        ctEntityAssoc.PositionStatus__c = 'P - PRINCIPAL';
        insert ctEntityAssoc;

        String appLicensePeriodRnew = String.valueOf(licTypeEffectiveDate.month()) + '/' +
            String.valueOf(licTypeEffectiveDate.day()) + '/' +
            String.valueOf(licTypeEffectiveDate.year()) + ' - ' +
            String.valueOf(licTypeEffectiveExpireDate.month()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate.day()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate.year());

        Application__c appCtRme = new Application__c();
        appCtRme.CurrentLicense__c = licCtRme.Id;
        appCtRme.Type__c = 'RNEW - Renewal';
        appCtRme.LicenseType__c = licTypeCtRme.Id;
        appCtRme.Status__c = 'D1 - Awaiting Dependency Review';
        appCtRme.Phase__c = 'D - Dependency Review';
        appCtRme.LicensePeriodRNEW__c = appLicensePeriodRnew;

        insert appCtRme;
    }

    @IsTest
    static void batchTest() {
        Test.startTest();
        (new CtRmePushThroughBatch()).execute(null);
        Test.stopTest();
    }
}