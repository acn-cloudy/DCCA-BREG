/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Test class
 * Unit testing for LicenseExpire
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Chris Zhuang - PacificPointCorp 
 *  @created      PacPoint-CZ082619 - Created for PVL Phase 1
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
@IsTest
private class LicenseExpireTest {
    @TestSetup
    static void setup() {
        Date today = Date.today();

        Account dummyAccount = new Account();
        dummyAccount.Name = 'Account Name';
        insert dummyAccount;

        LicenseType__c dummyLT = new LicenseType__c();
        dummyLT.StartofRenewalPeriod__c = today;
        dummyLT.StatusDuetoNonRenewal__c = 'D - Forfeited; Needs to Restore';
        dummyLT.Status__c = 'Active';
        dummyLT.Name = 'Dummy License Type';        
        insert dummyLT;

        License__c dummyLicense1 = new License__c();
        dummyLicense1.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        dummyLicense1.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense1.LicenseType__c = dummyLT.Id;
        dummyLicense1.Licensee__c = dummyAccount.Id;

        License__c dummyLicense2 = new License__c();
        dummyLicense2.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
        dummyLicense2.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense2.LicenseType__c = dummyLT.Id;
        dummyLicense2.Licensee__c = dummyAccount.Id;

        License__c dummyLicense3 = new License__c();
        dummyLicense3.Status__c =
                'Z1 - Susp Due To 1)Loss Of Bond By Licensee And/Or Dependent Or 2)Loss of RME, If Def Not Cured by Renewal, Must Re-Apply';
        dummyLicense3.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense3.LicenseType__c = dummyLT.Id;
        dummyLicense3.Licensee__c = dummyAccount.Id;

        License__c dummyLicense4 = new License__c();
        dummyLicense4.Status__c = 'Z - Current & Valid, But Subject To Disciplinary Requirement';
        dummyLicense4.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense4.LicenseType__c = dummyLT.Id;
        dummyLicense4.Licensee__c = dummyAccount.Id;

        License__c dummyLicense5 = new License__c();
        dummyLicense5.Status__c = 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement';
        dummyLicense5.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense5.LicenseType__c = dummyLT.Id;
        dummyLicense5.Licensee__c = dummyAccount.Id;
        insert new List<License__c>{dummyLicense1, dummyLicense2, dummyLicense3, dummyLicense4, dummyLicense5};

        dummyLicense1.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense2.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense3.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense4.EffectiveExpireDate__c = today.addDays(-29);
        dummyLicense5.EffectiveExpireDate__c = today.addDays(-29);
        update new List<License__c>{dummyLicense1, dummyLicense2, dummyLicense3, dummyLicense4, dummyLicense5};

        Application__c dummyApplication = new Application__c();
        dummyApplication.CurrentLicense__c = dummyLicense1.Id;
        dummyApplication.Type__c = 'RNEW - Renewal';
        dummyApplication.Phase__c = 'A - Application Received';

        insert dummyApplication;
    }

    @IsTest
    static void test_LicenseExpire() {
        Test.startTest();
        LicenseExpire scheduler = new LicenseExpire();
        String sch = '0 0 23 * * ?';
        System.schedule('testLicenseExpire', sch, scheduler);
        Test.stopTest();
        
    }
    @isTest 
    static void testLicense() {
        LicenseExpire ins = new LicenseExpire();
        (new LicenseExpire()).execute(null, Database.query(ins.query));
        Test.getEventBus().deliver();      

        Test.startTest();
        License__c lic = [SELECT EffectiveExpireDate__c, LicenseType__r.NextLicensePeriod__c FROM License__c WHERE Status__c = 'ZD - Forfeited Disciplined License; Needs To Restore' LIMIT 1];
        List<LicenseHistory__c> licHis = [SELECT TransactionType__c, EffectiveDate__c, LicensePeriod__c, Remarks__c FROM LicenseHistory__c WHERE License__c = :lic.ID];
        Test.stopTest();

        System.assert(licHis.size() > 0, 'License History was not created');
        System.assertEquals(1, licHis.size());

        System.assertEquals(LicenseExpire.transactionType, licHis[0].TransactionType__c);
        System.assertEquals(lic.EffectiveExpireDate__c + 1, licHis[0].EffectiveDate__c);
        System.assertEquals(lic.LicenseType__r.NextLicensePeriod__c, licHis[0].LicensePeriod__c);
        System.assertEquals(LicenseExpire.remarks, licHis[0].Remarks__c);
        
    }
}