/**
 * VPVL-219: Test for RollingLicenseExpiredStatusBatch.
 */
@IsTest
private class RollingLicenseExpiredStatusBatchTest {

    private static final String TARGET_STATUS = 'F - Terminated; Needs to Reapply';

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Rolling License Test Account');
        insert acc;

        LicenseType__c lt = new LicenseType__c(
            Name = 'Test Rolling License Type',
            RollingLicensePeriod__c = true,
            Status__c = 'Active'
        );
        insert lt;

        License__c licC = new License__c(
            LicenseType__c = lt.Id,
            Licensee__c = acc.Id,
            Status__c = 'C - Current, Valid & In Good Standing',
            EffectiveExpireDate__c = Date.today().addDays(-1)
        );
        License__c licCM = new License__c(
            LicenseType__c = lt.Id,
            Licensee__c = acc.Id,
            Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
            EffectiveExpireDate__c = Date.today().addDays(-2)
        );
        License__c licZ = new License__c(
            LicenseType__c = lt.Id,
            Licensee__c = acc.Id,
            Status__c = 'Z - Current & Valid, But Subject To Disciplinary Requirement',
            EffectiveExpireDate__c = Date.today().addDays(-3)
        );
        License__c licZM = new License__c(
            LicenseType__c = lt.Id,
            Licensee__c = acc.Id,
            Status__c = 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            EffectiveExpireDate__c = Date.today().addDays(-4)
        );
        insert new List<License__c>{ licC, licCM, licZ, licZM };
    }

    @IsTest
    static void testBatchUpdatesEligibleLicenses() {
        Test.startTest();
        Database.executeBatch(new RollingLicenseExpiredStatusBatch(), 200);
        Test.stopTest();

        List<License__c> updated = [
            SELECT Id, Status__c
            FROM License__c
            WHERE LicenseType__r.RollingLicensePeriod__c = true
              AND EffectiveExpireDate__c < TODAY
        ];

        System.assert(updated.size() >= 4, 'Should have at least 4 eligible licenses');
        for (License__c lic : updated) {
            System.assertEquals(TARGET_STATUS, lic.Status__c, 'Status should be updated to F - Terminated; Needs to Reapply');
        }
    }

    @IsTest
    static void testSchedulable() {
        Test.startTest();
        String jobId = System.schedule(
            'Rolling License Expired Status Test',
            '0 0 1 * * ?',
            new RollingLicenseExpiredStatusBatch()
        );
        Test.stopTest();

        List<CronTrigger> triggers = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, triggers.size(), 'Scheduled job should exist');
        System.assertEquals('WAITING', triggers[0].State, 'Job should be waiting');
    }
}