/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10212022 - Created for case 00023742
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
private class RboRenewalDependencyTest {
    @TestSetup
    static void setup() {
        LicenseType__c licTypeRbEntity = new LicenseType__c();
        licTypeRbEntity.Name = 'RB - Entity';
        licTypeRbEntity.DurationofLicenseInMonths__c = 1;
        licTypeRbEntity.AbleToInactivate__c = true;

        LicenseType__c licTypeRbo = new LicenseType__c();
        licTypeRbo.Name = 'RBO';
        licTypeRbo.DurationofLicenseInMonths__c = 1;
        licTypeRbo.AbleToInactivate__c = true;

        LicenseType__c licTypeRbBroker = new LicenseType__c();
        licTypeRbBroker.Name = 'RB - Broker';
        licTypeRbBroker.DurationofLicenseInMonths__c = 1;
        licTypeRbBroker.AbleToInactivate__c = true;

        insert new LicenseType__c[]{licTypeRbEntity, licTypeRbBroker, licTypeRbo};

        License__c licRbEntity = new License__c();
        licRbEntity.Name = 'RB-1-0';
        licRbEntity.LicenseType__c = licTypeRbEntity.Id;

        License__c licRbBroker = new License__c();
        licRbBroker.LicenseType__c = licTypeRbBroker.Id;

        License__c licRbo = new License__c();
        licRbo.Name = 'RB0-1-1';
        licRbo.LicenseType__c = licTypeRbo.Id;


        License__c invalidLicRbo1 = new License__c();
        invalidLicRbo1.Name = 'RB0-2-1';
        invalidLicRbo1.LicenseType__c = licTypeRbo.Id;

        insert new License__c[]{licRbEntity, licRbBroker, licRbo, invalidLicRbo1};

        licRbEntity.Status__c = 'C - Current, Valid & In Good Standing';
        licRbEntity.ActiveInactive__c = 'Active';
        licRbEntity.ThisLicenseRenewed__c = true;
        licRbo.Name = 'RB0-1-1';


        update new License__c[]{licRbEntity};

        AssociatedLicense__c rbEntityRboRbEntityAssoc = new AssociatedLicense__c();
        rbEntityRboRbEntityAssoc.EntityLicense__c = licRbo.Id;
        rbEntityRboRbEntityAssoc.EmployeeLicense__c = licRbEntity.Id;
        rbEntityRboRbEntityAssoc.EmploymentStatus__c = 'Employed';

        AssociatedLicense__c rbEntityRbBrokerAssoc = new AssociatedLicense__c();
        rbEntityRbBrokerAssoc.EntityLicense__c = licRbEntity.Id;
        rbEntityRbBrokerAssoc.EmployeeLicense__c = licRbBroker.Id;
        rbEntityRbBrokerAssoc.EmploymentStatus__c = 'Employed';
        rbEntityRbBrokerAssoc.Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';

        insert new AssociatedLicense__c[]{rbEntityRboRbEntityAssoc, rbEntityRbBrokerAssoc};

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
        appRbo.RecordTypeId = appPvlRnewRtId;

        insert new Application__c[]{appRbo};
    }

    @IsTest
    static void runRenewalDependencySuccessTest() {
        List<RboRenewalDependency.Input> params = new List<RboRenewalDependency.Input>();
        RboRenewalDependency.Input param = new RboRenewalDependency.Input();
        param.inputLicense = [
            SELECT
                Id,
                Status__c,
                LicenseNumberFormula__c,
                LicenseTypeName__c,
                EffectiveExpireDate__c,
                LicenseTypeExpireDate__c,
                LicenseType__r.ClassStatusDuetoNonRenewal__c,
                LicenseType__r.NextLicensePeriodEffectiveDate__c,
                LicenseType__r.NextLicensePeriodExpireDate__c,
                NonRenewalDate__c
            FROM License__c
            WHERE LicenseTypeName__c = 'RBO'
            LIMIT 1
        ];
        param.inputApplication = [
            SELECT
                Id,
                RNEWRSTRDate__c,
                ActiveInactive__c,
                ApplicationRenewingInactive__c,
                ApplicationReceivedDate__c,
                LicensePeriodRNEW__c,
                Type__c
            FROM Application__c
            WHERE LicenseType__r.Name = 'RBO'
            LIMIT 1
        ];
        params.add(param);

        License__c rbBroker = [SELECT Id FROM License__c WHERE LicenseTypeName__c = 'RB - Broker' LIMIT 1];
        rbBroker.Status__c = 'C - Current, Valid & In Good Standing';
        rbBroker.ThisLicenseRenewed__c = true;
        update rbBroker;
        System.debug('Input Application' + param.inputApplication);
        System.debug('Input License' + param.inputLicense);
        Test.startTest();
        RboRenewalDependency.runRenewalDependency(params);
        Test.stopTest();
    }

    @IsTest
    static void runRenewalDependencySetToD1Test1() {
        List<RboRenewalDependency.Input> params = new List<RboRenewalDependency.Input>();
        RboRenewalDependency.Input param = new RboRenewalDependency.Input();
        param.inputLicense = [
            SELECT
                Id,
                Status__c,
                LicenseNumberFormula__c,
                LicenseTypeName__c,
                LicenseTypeExpireDate__c,
                LicenseType__r.ClassStatusDuetoNonRenewal__c,
                LicenseType__r.NextLicensePeriodEffectiveDate__c,
                LicenseType__r.NextLicensePeriodExpireDate__c,
                NonRenewalDate__c
            FROM License__c
            WHERE LicenseTypeName__c = 'RBO'
            LIMIT 1
        ];
        param.inputApplication = [
            SELECT
                Id,
                RNEWRSTRDate__c,
                ApplicationReceivedDate__c,
                ApplicationRenewingInactive__c,
                ActiveInactive__c,
                Type__c
            FROM Application__c
            WHERE LicenseType__r.Name = 'RBO'
            LIMIT 1
        ];
        params.add(param);

        License__c rbEntity = [SELECT Id FROM License__c WHERE LicenseTypeName__c = 'RB - Entity' LIMIT 1];
        rbEntity.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        rbEntity.ThisLicenseRenewed__c = false;
        update rbEntity;

        Test.startTest();
        RboRenewalDependency.runRenewalDependency(params);
        Test.stopTest();
    }

    @IsTest
    static void runRenewalDependencySetToD1Test2() {
        List<RboRenewalDependency.Input> params = new List<RboRenewalDependency.Input>();
        RboRenewalDependency.Input param = new RboRenewalDependency.Input();
        param.inputLicense = [
            SELECT
                Id,
                Status__c,
                LicenseNumberFormula__c,
                LicenseTypeName__c,
                LicenseTypeExpireDate__c,
                LicenseType__r.ClassStatusDuetoNonRenewal__c,
                LicenseType__r.NextLicensePeriodEffectiveDate__c,
                LicenseType__r.NextLicensePeriodExpireDate__c,
                NonRenewalDate__c
            FROM License__c
            WHERE LicenseTypeName__c = 'RBO'
            LIMIT 1
        ];
        param.inputApplication = [
            SELECT
                Id,
                RNEWRSTRDate__c,
                ActiveInactive__c,
                ApplicationReceivedDate__c,
                ApplicationRenewingInactive__c,
                Type__c
            FROM Application__c
            WHERE LicenseType__r.Name = 'RBO'
            LIMIT 1
        ];
        params.add(param);
        
        Test.startTest();
        RboRenewalDependency.runRenewalDependency(params);
        Test.stopTest();
    }
}