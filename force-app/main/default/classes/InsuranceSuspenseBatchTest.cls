@IsTest
private class InsuranceSuspenseBatchTest { 
    @TestSetup
    static void makeData() {
        TestDataFactory.insertInsuranceBonds();
    }

    @IsTest
    static void testExecute() {
        List<LicenseType__c> types = [Select Id, InsuranceBondTypesRequired__c from LicenseType__c];
        for (LicenseType__c t : types) {
            t.InsuranceBondTypesRequired__c = 'LP - Liability / Property Damage;WC - Workers Compensation ';
        }

        update types;
        Test.startTest();
        String query = 'Select Id, InsuranceBondLossDuringRenewal__c, Ins_Expire_Cancel_Date__c, InsuranceBondTermDate__c, Insurance_Bond_Cancel_Date__c, ' +
            ' EffectiveExpireDate__c, LicenseType__r.StatusDuetoRequiredINSInactive__c, LicenseType__r.NumberOfDaysUntilInsAutoForfeiture__c, GenerateLossOfINSBondNotification__c, Status__c, ' +
            ' LicenseType__r.InsuranceBondTypesRequired__c, LicenseType__r.StatusDueToLossOfInsurance__c,  LicenseType__r.BreakinInsuranceCoverageAllowed__c ' +
            ' from License__c ';
        InsuranceSuspenseBatch b = new InsuranceSuspenseBatch();
        b.query = query;
        Database.executeBatch(b, 100);
        Test.stopTest();
    }

    @IsTest
    static void testExecute2() {
        List<InsuranceBond__c> bonds = [Select Id, Type__c, CancelDate__c, TermDate__c
        from InsuranceBond__c where Type__c = 'LI - Liability'];
        for (InsuranceBond__c record : bonds) {
            record.CancelDate__c = Date.today().addDays(2);
            record.TermDate__c = Date.today().addDays(3);
        }
        update bonds;

        List<License__c> records = [Select Id, EffectiveExpireDate__c from License__c];
        for (License__c record : records) {
            record.EffectiveExpireDate__c = Date.today().addDays(5);
            record.Status__c = 'C - Current, Valid & In Good Standing';
        }
        update records;
        List<LicenseType__c> types = [Select Id, InsuranceBondTypesRequired__c from LicenseType__c];
        for (LicenseType__c t : types) {
            t.InsuranceBondTypesRequired__c = 'LI - Liability';
        }
        update types;
        Test.startTest();
        String query = 'Select Id, InsuranceBondLossDuringRenewal__c, EffectiveExpireDate__c, LicenseType__r.StatusDuetoRequiredINSInactive__c, LicenseType__r.NumberOfDaysUntilInsAutoForfeiture__c, GenerateLossOfINSBondNotification__c, Status__c, ' +
            ' LicenseType__r.InsuranceBondTypesRequired__c, LicenseType__r.StatusDueToLossOfInsurance__c,  LicenseType__r.BreakinInsuranceCoverageAllowed__c, LicenseType__r.NumberofDaysUntilAutoForfeiture__c, ' +
            ' InsuranceBondTermDate__c, Insurance_Bond_Cancel_Date__c ' +
            ' from License__c ';
        InsuranceSuspenseBatch b = new InsuranceSuspenseBatch();
        b.query = query;
        Database.executeBatch(b, 100);
        Test.stopTest();
    }

    @IsTest
    static void testExecute3() {
        List<InsuranceBond__c> bonds = [Select Id, Type__c, CancelDate__c, TermDate__c
        from InsuranceBond__c where Type__c = 'LI - Liability'];
        for (InsuranceBond__c record : bonds) {
            record.CancelDate__c = Date.today().addDays(2);
            record.TermDate__c = Date.today().addDays(3);
        }
        update bonds;

        List<License__c> records = [Select Id, EffectiveExpireDate__c from License__c];
        for (License__c record : records) {
            record.EffectiveExpireDate__c = Date.today().addDays(5);
        }
        update records;
        List<LicenseType__c> types = [Select Id, InsuranceBondTypesRequired__c from LicenseType__c];
        for (LicenseType__c t : types) {
            t.InsuranceBondTypesRequired__c = 'LI - Liability';
        }
        update types;
        Test.startTest();
        String query = 'Select Id, InsuranceBondLossDuringRenewal__c, EffectiveExpireDate__c, LicenseType__r.StatusDuetoRequiredINSInactive__c, LicenseType__r.NumberOfDaysUntilInsAutoForfeiture__c, GenerateLossOfINSBondNotification__c, Status__c, ' +
            ' LicenseType__r.InsuranceBondTypesRequired__c, LicenseType__r.StatusDueToLossOfInsurance__c,  LicenseType__r.BreakinInsuranceCoverageAllowed__c ' +
            ' from License__c ';
        InsuranceSuspenseBatch b = new InsuranceSuspenseBatch();
        b.query = query;
        Database.executeBatch(b, 100);
        Test.stopTest();
    }

    @IsTest
    static void testRMStatusForfeitsOnMissingInsurance() {
        List<LicenseType__c> types = [SELECT Id FROM LicenseType__c];
        for (LicenseType__c t : types) {
            t.RequiresInsurance__c = true;
            t.InsuranceBondTypesRequired__c = 'LI - Liability';
            t.StatusDuetoRequiredINSInactive__c = GlobalUtilities.STATUSZI;
        }
        update types;

        License__c lic = [SELECT Id FROM License__c WHERE Name = 'acc' LIMIT 1];
        delete [SELECT Id FROM InsuranceBond__c WHERE License__c = :lic.Id];
        lic.ActiveInactive__c = 'Active';
        lic.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
        update lic;

        Test.startTest();
        Database.executeBatch(new InsuranceSuspenseBatch(), 100);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Suspense__c WHERE License__c = :lic.Id]);
        System.assertEquals(GlobalUtilities.STATUSZI, [SELECT Status__c FROM License__c WHERE Id = :lic.Id].Status__c);
    }
}