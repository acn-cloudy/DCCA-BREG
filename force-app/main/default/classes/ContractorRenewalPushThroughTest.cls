@isTest
private class ContractorRenewalPushThroughTest {

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

        LicenseType__c licTypeCtSoleProprietor = new LicenseType__c();
        licTypeCtSoleProprietor.Name = 'CT - Sole Proprietor';
        licTypeCtSoleProprietor.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeCtSoleProprietor.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeCtSoleProprietor.DurationofLicenseInMonths__c = 1;

        insert new LicenseType__c[]{licTypeCtEntity, licTypeCtRme, licTypeCtSoleProprietor};

        License__c licCtEntity = new License__c();
        licCtEntity.LicenseType__c = licTypeCtEntity.Id;

        License__c licCtEntity2 = new License__c();
        licCtEntity2.LicenseType__c = licTypeCtEntity.Id;

        License__c licCtEntityNoAssoc = new License__c();
        licCtEntityNoAssoc.LicenseType__c = licTypeCtEntity.Id;

        License__c licCtRme = new License__c();
        licCtRme.LicenseType__c = licTypeCtRme.Id;

        License__c licCtRmeNoAssoc = new License__c();
        licCtRmeNoAssoc.LicenseType__c = licTypeCtRme.Id;

        License__c licCtSoleProprietor = new License__c();
        licCtSoleProprietor.LicenseType__c = licTypeCtSoleProprietor.Id;

        License__c licCtSoleProprietorNoAssoc = new License__c();
        licCtSoleProprietorNoAssoc.LicenseType__c = licTypeCtSoleProprietor.Id;

        License__c invalidLicense1 = new License__c();
        invalidLicense1.LicenseType__c = licTypeCtRme.Id;

        License__c invalidLicense2 = new License__c();
        invalidLicense2.LicenseType__c = licTypeCtRme.Id;

        insert new License__c[]{licCtEntity, licCtEntity2, licCtRme, licCtSoleProprietor, licCtEntityNoAssoc, licCtRmeNoAssoc, licCtSoleProprietorNoAssoc, invalidLicense1, invalidLicense2};

        licCtEntity.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtEntity.ActiveInactive__c = 'Active';
        licCtEntity.ThisLicenseRenewed__c = true;
        licCtEntityNoAssoc.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtEntityNoAssoc.ActiveInactive__c = 'Active';
        licCtEntityNoAssoc.ThisLicenseRenewed__c = true;

        licCtEntity2.Status__c = 'C - Current, Valid & In Good Standing';
        licCtEntity2.ActiveInactive__c = 'Active';
        licCtEntity2.ThisLicenseRenewed__c = true;

        licCtSoleProprietor.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtSoleProprietor.ActiveInactive__c = 'Active';
        licCtSoleProprietor.ThisLicenseRenewed__c = true;
        licCtSoleProprietorNoAssoc.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtSoleProprietorNoAssoc.ActiveInactive__c = 'Active';
        licCtSoleProprietorNoAssoc.ThisLicenseRenewed__c = true;

        licCtRme.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtRme.ActiveInactive__c = 'Active';
        licCtRme.ThisLicenseRenewed__c = true;
        licCtRmeNoAssoc.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtRmeNoAssoc.ActiveInactive__c = 'Active';
        licCtRmeNoAssoc.ThisLicenseRenewed__c = true;

        update new License__c[]{licCtEntity, licCtEntity2, licCtRme, licCtSoleProprietor, licCtEntityNoAssoc, licCtRmeNoAssoc, licCtSoleProprietorNoAssoc};

        AssociatedLicense__c ctSolePropAssoc1 = new AssociatedLicense__c();
        ctSolePropAssoc1.EntityLicense__c = licCtSoleProprietor.Id;
        ctSolePropAssoc1.EmployeeLicense__c = licCtRme.Id;
        ctSolePropAssoc1.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c ctSolePropAssoc2 = new AssociatedLicense__c();
        ctSolePropAssoc2.EntityLicense__c = licCtSoleProprietor.Id;
        ctSolePropAssoc2.EmployeeLicense__c = licCtEntity.Id;
        ctSolePropAssoc2.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c ctSolePropNoAssoc1 = new AssociatedLicense__c();
        ctSolePropNoAssoc1.EntityLicense__c = licCtSoleProprietorNoAssoc.Id;
        ctSolePropNoAssoc1.EmployeeLicense__c = invalidLicense1.Id;
        ctSolePropNoAssoc1.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c ctSolePropNoAssoc2 = new AssociatedLicense__c();
        ctSolePropNoAssoc2.EntityLicense__c = licCtSoleProprietorNoAssoc.Id;
        ctSolePropNoAssoc2.EmployeeLicense__c = invalidLicense2.Id;
        ctSolePropNoAssoc2.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c ctEntityAssoc = new AssociatedLicense__c();
        ctEntityAssoc.EntityLicense__c = licCtEntity.Id;
        ctEntityAssoc.EmployeeLicense__c = licCtRme.Id;
        ctEntityAssoc.EmploymentStatus__c = 'Employed';
        // ctEntityAssoc.EntityPrincipal__c = true;
        ctEntityAssoc.PositionStatus__c = 'P - PRINCIPAL';

        AssociatedLicense__c ctEntityAssoc2 = new AssociatedLicense__c();
        ctEntityAssoc2.EntityLicense__c = licCtEntity2.Id;
        ctEntityAssoc2.EmployeeLicense__c = licCtRme.Id;
        ctEntityAssoc2.EmploymentStatus__c = 'Employed';
        // ctEntityAssoc2.EntityPrincipal__c = true;
        ctEntityAssoc2.PositionStatus__c = 'P - PRINCIPAL';

        AssociatedLicense__c ctEntityNoAssoc = new AssociatedLicense__c();
        ctEntityNoAssoc.EntityLicense__c = licCtEntityNoAssoc.Id;
        ctEntityNoAssoc.EmployeeLicense__c = licCtRme.Id;
        ctEntityNoAssoc.EmploymentStatus__c = 'Employed';

        insert new AssociatedLicense__c[]{ctSolePropAssoc1, ctSolePropAssoc2, ctEntityAssoc, ctEntityNoAssoc, ctEntityAssoc2, ctSolePropNoAssoc1, ctSolePropNoAssoc2};

        String appLicensePeriodRnew = String.valueOf(licTypeEffectiveDate.month()) + '/' +
            String.valueOf(licTypeEffectiveDate.day()) + '/' +
            String.valueOf(licTypeEffectiveDate.year()) + ' - ' +
            String.valueOf(licTypeEffectiveExpireDate.month()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate.day()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate.year());

        Application__c appCtEntity = new Application__c();
        appCtEntity.CurrentLicense__c = licCtEntity.Id;
        appCtEntity.Type__c = 'RNEW - Renewal';
        appCtEntity.LicenseType__c = licTypeCtEntity.Id;
        appCtEntity.Status__c = 'D1 - Awaiting Dependency Review';
        appCtEntity.Phase__c = 'D - Dependency Review';
        appCtEntity.LicensePeriodRNEW__c = appLicensePeriodRnew;

        Application__c appCtEntity2 = new Application__c();
        appCtEntity2.CurrentLicense__c = licCtEntity2.Id;
        appCtEntity2.Type__c = 'RNEW - Renewal';
        appCtEntity2.LicenseType__c = licTypeCtEntity.Id;
        appCtEntity2.Status__c = 'HC - Application Completed';
        appCtEntity2.Phase__c = 'H - License Generation';
        appCtEntity2.LicensePeriodRNEW__c = appLicensePeriodRnew;

        Application__c appCtRme = new Application__c();
        appCtRme.CurrentLicense__c = licCtRme.Id;
        appCtRme.Type__c = 'RNEW - Renewal';
        appCtRme.LicenseType__c = licTypeCtRme.Id;
        appCtRme.Status__c = 'D1 - Awaiting Dependency Review';
        appCtRme.Phase__c = 'D - Dependency Review';
        appCtRme.LicensePeriodRNEW__c = appLicensePeriodRnew;

        Application__c appCtSoleProp = new Application__c();
        appCtSoleProp.CurrentLicense__c = licCtSoleProprietor.Id;
        appCtSoleProp.Type__c = 'RNEW - Renewal';
        appCtSoleProp.LicenseType__c = licTypeCtSoleProprietor.Id;
        appCtSoleProp.Status__c = 'D1 - Awaiting Dependency Review';
        appCtSoleProp.Phase__c = 'D - Dependency Review';
        appCtSoleProp.LicensePeriodRNEW__c = appLicensePeriodRnew;

        insert new Application__c[]{appCtEntity, appCtEntity2, appCtRme, appCtSoleProp};

        Date licTypeEffectiveDate2 = Date.today().toStartOfMonth();
        Date licTypeEffectiveExpireDate2 = licTypeEffectiveDate2.addMonths(1).addDays(-1);

        LicenseType__c licTypeCtEntity2 = new LicenseType__c();
        licTypeCtEntity2.Name = 'CT - Entity';
        licTypeCtEntity2.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeCtEntity2.LicenseTypeEffectiveDate__c = licTypeEffectiveDate2;
        licTypeCtEntity2.DurationofLicenseInMonths__c = 1;

        LicenseType__c licTypeCtRme2 = new LicenseType__c();
        licTypeCtRme2.Name = 'CT - RME';
        licTypeCtRme2.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeCtRme2.LicenseTypeEffectiveDate__c = licTypeEffectiveDate2;
        licTypeCtRme2.DurationofLicenseInMonths__c = 1;

        insert new LicenseType__c[]{licTypeCtEntity2, licTypeCtRme2};

        License__c licCtEntity3 = new License__c();
        licCtEntity3.LicenseType__c = licTypeCtEntity2.Id;

        License__c licCtRme2 = new License__c();
        licCtRme2.LicenseType__c = licTypeCtRme2.Id;

        License__c licCtRmeNoAssoc2 = new License__c();
        licCtRmeNoAssoc2.LicenseType__c = licTypeCtRme2.Id;

        insert new License__c[]{licCtEntity3, licCtRme2, licCtRmeNoAssoc2};

        licCtEntity3.Status__c = 'C - Current, Valid & In Good Standing';
        licCtEntity3.ActiveInactive__c = 'Active';
        licCtEntity3.ThisLicenseRenewed__c = true;

        licCtRme2.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtRme2.ActiveInactive__c = 'Active';
        licCtRme2.ThisLicenseRenewed__c = true;

        licCtRmeNoAssoc2.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licCtRmeNoAssoc2.ActiveInactive__c = 'Active';
        licCtRmeNoAssoc2.ThisLicenseRenewed__c = true;

        update new License__c[]{licCtEntity3, licCtRme2, licCtRmeNoAssoc2};

        AssociatedLicense__c ctEntityAssoc3 = new AssociatedLicense__c();
        ctEntityAssoc3.EntityLicense__c = licCtEntity3.Id;
        ctEntityAssoc3.EmployeeLicense__c = licCtRme2.Id;
        ctEntityAssoc3.EmploymentStatus__c = 'Employed';
        // ctEntityAssoc3.EntityPrincipal__c = true;
        ctEntityAssoc3.PositionStatus__c = 'P - PRINCIPAL';
        insert ctEntityAssoc3;

        String appLicensePeriodRnew2 = String.valueOf(licTypeEffectiveDate2.month()) + '/' +
            String.valueOf(licTypeEffectiveDate2.day()) + '/' +
            String.valueOf(licTypeEffectiveDate2.year()) + ' - ' +
            String.valueOf(licTypeEffectiveExpireDate2.month()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate2.day()) + '/' +
            String.valueOf(licTypeEffectiveExpireDate2.year());

        Application__c appCtRme2 = new Application__c();
        appCtRme2.CurrentLicense__c = licCtRme2.Id;
        appCtRme2.Type__c = 'RNEW - Renewal';
        appCtRme2.LicenseType__c = licTypeCtRme2.Id;
        appCtRme2.Status__c = 'D1 - Awaiting Dependency Review';
        appCtRme2.Phase__c = 'D - Dependency Review';
        appCtRme2.LicensePeriodRNEW__c = appLicensePeriodRnew2;

        insert appCtRme2;
    }

    @IsTest
    static void batchTest() {
        List<License__c> ls = [SELECT Id, LicenseTypeName__c, ThisLicenseRenewed__c, Status__c FROM License__c];
        Test.startTest();
        (new ContractorRenewalPushThrough()).execute(null);
        Test.stopTest();
    }

    @IsTest
    static void batchTest2() {
        List<License__c> ls = [SELECT Id, LicenseTypeName__c, ThisLicenseRenewed__c, Status__c FROM License__c];
        Test.startTest();
        (new ContractorRenewalPushThrough(true)).execute(null);
        Test.stopTest();
    }
}