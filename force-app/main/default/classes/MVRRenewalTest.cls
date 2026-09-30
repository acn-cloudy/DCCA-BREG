/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * PacPoint-EA03092023 - Created for case 00027705
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 03/09/2023
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
@IsTest
public with sharing class MVRRenewalTest {
    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAccountUnit('Test Account 1', '222222');
        insert acc;
        List<LicenseType__c> licenseTypes 
            = TestDataFactory.createLicenseTypes(new List<String>{'RDS', 'RD', 'MRC', 'MC', 'MR'});

        List<License__c> licenses = new List<License__c>();
        Set<String> mrcTypes = new Set<String>{'MRC', 'MC', 'MR'};
        for(LicenseType__c licenseType: licenseTypes) {
            License__c lic = new License__c();
            lic.Name = licenseType.Name + '-1';
            lic.Licensee__c = acc.Id;
            lic.LicenseType__c = licenseType.Id;
            lic.ActiveInactive__c  = 'Active';
            if(licenseType.Name == 'RD'){
                lic.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
            } else if(mrcTypes.contains(licenseType.Name) ) {
                lic.Status__c = 'C - Current, Valid & In Good Standing';
            } else {
                lic.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
            }
            
            licenses.add(lic);
        }

        insert licenses;

        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();
        License__c entityLicense = [Select Id from License__c where LicenseType__r.Name = 'RDS' limit 1];
        License__c entityLicense2 = [Select Id from License__c where LicenseType__r.Name = 'MRC' limit 1];
        for(License__c license: licenses) {
            if(license.Name.contains('MRC') || license.Name.contains('MC') || license.Name.contains('MR')) {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.PositionStatus__c = 'D - Designated';
                assLicenses.add(al);
            }
            if(!license.Name.contains('MRC')) {
                AssociatedLicense__c al = new AssociatedLicense__c();
                al.EntityLicense__c = entityLicense2.Id;
                al.EmployeeLicense__c = license.Id;
                al.EmploymentStatus__c = 'Employed';
                al.PositionStatus__c = 'D - Designated';
                assLicenses.add(al);
            }
        }
        if(assLicenses.size() > 0){
            insert assLicenses;
        }
        
        List<String> appTypes = new List<String>{'RNEW - Renewal', 'RSTR - Restore - No A/I Status'};
        List<Application__c> apps = new List<Application__c>();
        
        for(License__c record: [Select Id, LicenseType__c, LicenseType__r.NextLicensePeriod__c from License__c ]) {
            for(String appType: appTypes) {
                Application__c app = new Application__c();
                app.CurrentLicense__c = record.Id;
                app.Type__c = appType;
                app.Status__c = 'D1 - Awaiting Dependency Review' ;
                app.LicenseType__c = record.LicenseType__c;
                app.ApplicationReceivedDate__c = System.today();
                app.LicensePeriodRNEW__c = record.LicenseType__r.NextLicensePeriod__c;

                apps.add(app);
            }
        }
        
        insert apps; 
    }

    @isTest
    private static void testRDSRenewApplication() {
        License__c lRecord = [Select Id from License__c where LicenseType__r.Name = 'RDS' limit 1];
        Application__c appRecord = [Select Id from Application__c where Type__c = 'RNEW - Renewal'
        and CurrentLicense__c =: lRecord.Id  limit 1];
        
        List<AssociatedLicense__c> assLicenses = [
            SELECT Id, EmployeeLicense__c, EmployeeLicense__r.Id
            FROM AssociatedLicense__c ];
        List<String> employeeIds = (List<String>)(new AssociatedLicenseDomain(assLicenses)).getFieldValues('EmployeeLicense__c');
        List<License__c> employeeLicenses = LicenseSelector.getLicenses(employeeIds);
        for(License__c record: employeeLicenses) {
            record.Status__c = 'C - Current, Valid & In Good Standing';
        }
        update employeeLicenses;
        Test.startTest();            
        List<MVRRenewal.Input> params = getParams(lRecord.Id, appRecord.Id);
        MVRRenewal.runMVRRenewal(params);
        Test.stopTest();
    }

    @isTest
    private static void testRDSRestoreApplication() {
        License__c lRecord = [Select Id from License__c where LicenseType__r.Name = 'RDS' limit 1];
        Application__c appRecord = [Select Id from Application__c where Type__c = 'RSTR - Restore - No A/I Status' 
        and CurrentLicense__c =: lRecord.Id  limit 1];
        Test.startTest();        
        List<MVRRenewal.Input> params = getParams(lRecord.Id, appRecord.Id);      
        MVRRenewal.runMVRRenewal(params);
        Test.stopTest();
    }

    @isTest
    private static void testMRCRestoreApplication() {
        License__c lRecord = [Select Id from License__c where LicenseType__r.Name = 'MRC' limit 1];
        Application__c appRecord = [Select Id from Application__c where Type__c = 'RNEW - Renewal'
        and CurrentLicense__c =: lRecord.Id  limit 1];
        List<AssociatedLicense__c> assLicenses = [
            SELECT Id, EmployeeLicense__c, EmployeeLicense__r.Id
            FROM AssociatedLicense__c ];
        List<String> employeeIds = (List<String>)(new AssociatedLicenseDomain(assLicenses)).getFieldValues('EmployeeLicense__c');
        List<License__c> employeeLicenses = LicenseSelector.getLicenses(employeeIds);
        for(License__c record: employeeLicenses) {
            record.Status__c = 'C - Current, Valid & In Good Standing';
        }
        update employeeLicenses;
        List<MVRRenewal.Input> params = getParams(lRecord.Id, appRecord.Id);
        System.debug('Test code start review here');

        Test.startTest();        
        MVRRenewal.runMVRRenewal(params);
        Test.stopTest();
    }

    
    @isTest
    private static void testMRCSoleApplication() {
        License__c lRecord = [Select Id, SoleOwner__c from License__c where LicenseType__r.Name = 'MRC' limit 1];
        Application__c appRecord = [Select Id from Application__c where Type__c = 'RNEW - Renewal' 
            and CurrentLicense__c =: lRecord.Id limit 1];
        lRecord.SoleOwner__c = true;
        update lRecord;
        Test.startTest();        
        List<MVRRenewal.Input> params = getParams(lRecord.Id, appRecord.Id);      
        MVRRenewal.runMVRRenewal(params);
        Test.stopTest();
    }

    @isTest
    private static void testGetAssociatedMRCLicenses() {
        License__c lRecord = [Select Id from License__c where LicenseType__r.Name = 'MRC' limit 1];
        Test.startTest();        
        MVRRenewal.getAssociatedMRCLicenses(lRecord.Id, true);
        MVRRenewal.getAssociatedMRCLicenses(lRecord.Id, false);
        Test.stopTest();
    }


    @isTest
    private static void testClassificationsComplete() {
        License__c lRecord = [Select Id from License__c where LicenseType__r.Name = 'MRC' limit 1];
        Test.startTest();        
        MVRRenewal.classificationsComplete(lRecord.Id);
        Test.stopTest();
    }


    public static List<MVRRenewal.Input> getParams(String licId, String appId) {
        List<MVRRenewal.Input> params = new List<MVRRenewal.Input>();
        MVRRenewal.Input param = new MVRRenewal.Input();

        param.inputLicense = MVRRenewal.getLicense(licId);
        param.inputApplication = MVRRenewal.getApplication(appId);
        params.add(param);
        return params;
    }

    

   
}