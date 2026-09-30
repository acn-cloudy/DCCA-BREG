@IsTest
private class LicenseTypeExpireTest {
    @IsTest
    static void testLicenseTypeExpire() {
        Account acc = new Account();
        acc.Name = 'Test 398624';
        insert acc;

        LicenseType__c licenseTypeRecord = new LicenseType__c();
        licenseTypeRecord.Name = 'Test LT';
        licenseTypeRecord.LicenseTypeEffectiveDate__c = Date.Today();
        licenseTypeRecord.StartofRenewalPeriod__c = Date.today();
        licenseTypeRecord.DurationofLicenseInMonths__c = 5;
        insert licenseTypeRecord;
        List<LicenseType__c> licenseTypes = [
                SELECT
                        Id,
                        DurationofLicenseInMonths__c,
                        StartofRenewalPeriod__c,
                        LicenseTypeExpireDate__c,
                        LicenseTypeEffectiveDate__c,
                        LastReceivedDateAccepted__c
                FROM LicenseType__c
        ];

        (new LicenseTypeExpire()).execute(null, licenseTypes);

        Map<Id, LicenseType__c> licenseTypeMap = new Map<Id, LicenseType__c>(licenseTypes);
        List<Id> ltIds = new List<Id>();
        ltIds.addAll(licenseTypeMap.keySet());
        Database.executeBatch(new LicenseTypeExpire(ltIds));
    }

    @IsTest
    static void testBatch() {
        Database.executeBatch(new LicenseTypeExpire(), 100);
    }

    @IsTest
    static void testScheduled() {
        String CRON_EXP = '0 0 0 * * ?';
        Test.startTest();
        System.schedule('ScheduledApexTest', CRON_EXP, new LicenseTypeExpire());
        Test.stopTest();
    }
}