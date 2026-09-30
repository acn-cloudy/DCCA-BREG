/*
 * ___________________________________________________________________________________
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL09302020 - Created for
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 9/30/2020
 * __________________________________________________________________________________
 */
@IsTest
private class EarnedCETriggerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
        License__c lic = [SELECT Id FROM License__c LIMIT 1];
        lic.EffectiveExpireDate__c = Date.today();
        update lic;

        Earned_Continuing_Education__c ece = new Earned_Continuing_Education__c();
        ece.CourseType__c = 'Core';
        ece.Biennium__c = String.valueOf(Date.today().year());
        ece.License__c = lic.Id;
        ece.Credits__c = 1;
        insert ece;
    }

    @IsTest
    static void testUpdate() {
        Test.startTest();
        Earned_Continuing_Education__c ece = [SELECT Id, License__c FROM Earned_Continuing_Education__c LIMIT 1];
        update ece;
        Test.stopTest();
    }

    @IsTest
    static void testDelete() {
        Test.startTest();
        Earned_Continuing_Education__c ece = [SELECT Id, License__c FROM Earned_Continuing_Education__c LIMIT 1];
        Earned_Continuing_Education__c ece2 = new Earned_Continuing_Education__c();
        ece2.CourseType__c = 'Core';
        ece2.Biennium__c = String.valueOf(Date.today().year());
        ece2.License__c = ece.License__c;
        ece2.Credits__c = 1;
        insert ece2;

        delete ece;
        Test.stopTest();
    }

    @isTest static void testUpdateUpdateLicenseCredits() {
        TestDataFactory.insertPrelicenseCEEnrollments();
        List<LicenseType__c> licenseTypes = [Select Id, PreviousLicensePeriodExpireDate__c from LicenseType__c];
        for(LicenseType__c licenseType: licenseTypes){
            licenseType.PreviousLicensePeriodExpireDate__c = Date.today();
        }
        update licenseTypes;
        Test.startTest();
        List<PrelicenseCEEnrollment__c> priceCEEnrollments = [Select Id, Credits__c from PrelicenseCEEnrollment__c];
        List<Course__c> courses = [Select Id from Course__c];
        List<License__c> licenses = [Select Id, CurrentBiennium__c, PreviousBiennium__c,
            ElectiveCreditsPreviousLicPeriod__c, CoreCreditsPreviousLicensePeriod__c,
            ElectiveCreditsThisLicensePeriod__c, CoreCreditsThisLicensePeriod__c
            from License__c ];
        
        List<Earned_Continuing_Education__c> educations = new List<Earned_Continuing_Education__c>();
        for(Integer i = 0;i < courses.size(); i++) {
            Course__c course = courses.get(i);
            PrelicenseCEEnrollment__c priceCEEnrollment = priceCEEnrollments.get(i);
            Earned_Continuing_Education__c ece = new Earned_Continuing_Education__c();
            ece.Course__c = course.Id;
            ece.Credits__c = priceCEEnrollment.Credits__c;
            ece.ContinuingEducation__c = priceCEEnrollment.Id;
            ece.Biennium__c = String.valueOf(Date.today().year());
            ece.License__c = licenses.get(0).Id;
            educations.add(ece);
        }
        insert educations;
        Test.stopTest();
    }
}