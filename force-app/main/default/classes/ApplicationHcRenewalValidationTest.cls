@IsTest
private class ApplicationHcRenewalValidationTest {
    private static final String APP_PREFIX = Application__c.SObjectType.getDescribe().getKeyPrefix();

    @IsTest
    private static void testHcRenewalInsuranceCoverageDateScenarios() {
        LicenseType__c lt = new LicenseType__c();
        lt.Name = 'Test LT HC Coverage';
        lt.RequiresInsurance__c = true;
        lt.InsuranceBondTypesRequired__c =
            'LP - Liability / Property Damage;WC - Workers Compensation';
        insert lt;

        Id ctEntityRt = Schema.SObjectType.License__c.getRecordTypeInfosByName()
            .get('PVL - CT - Entity').getRecordTypeId();
        List<License__c> licenses = new List<License__c>();
        for (Integer i = 0; i < 6; i++) {
            licenses.add(new License__c(
                Name = 'Lic HC ' + i,
                ActiveInactive__c = 'Active',
                LicenseType__c = lt.Id,
                Status__c = 'CP - Current Pending',
                RecordTypeId = ctEntityRt,
                EffectiveExpireDate__c = Date.newInstance(2028, 9, 30)
            ));
        }
        insert licenses;

        List<InsuranceBond__c> bonds = new List<InsuranceBond__c>{
            buildBond(licenses[0].Id, 'LP - Liability / Property Damage', Date.newInstance(2026, 10, 7)),
            buildBond(licenses[0].Id, 'SI - Exclusion from Workers Comp.', null),
            buildBond(licenses[1].Id, 'SI - Exclusion from Workers Comp.', null),
            buildBond(licenses[2].Id, 'LP - Liability / Property Damage', Date.today().addDays(30)),
            buildBond(licenses[2].Id, 'SI - Exclusion from Workers Comp.', null),
            buildBond(licenses[3].Id, 'LP - Liability / Property Damage', Date.today().addDays(-30)),
            buildBond(licenses[3].Id, 'SI - Exclusion from Workers Comp.', null),
            buildBond(licenses[4].Id, 'BD - Bond', null),
            buildBond(licenses[4].Id, 'LP - Liability / Property Damage', Date.newInstance(2026, 11, 20)),
            buildBond(licenses[4].Id, 'WC - Workers Compensation', Date.newInstance(2026, 11, 20)),
            buildBond(licenses[5].Id, 'LP - Liability / Property Damage', Date.newInstance(2027, 1, 17)),
            buildBond(licenses[5].Id, 'SW - Workers Comp Thru Leasing Co.', Date.newInstance(2027, 3, 25))
        };
        insert bonds;

        List<License__c> lics = LicenseSelector.getLicenses(new List<String>{
            licenses[0].Id, licenses[1].Id, licenses[2].Id,
            licenses[3].Id, licenses[4].Id, licenses[5].Id
        });
        Map<Id, License__c> licById = new Map<Id, License__c>(lics);

        Application__c rnewPass = buildApp(
            '001', 'RNEW - Renewal', licenses[0].Id, Date.newInstance(2026, 9, 30)
        );
        Application__c rnewFail = buildApp(
            '002', 'RNEW - Renewal', licenses[1].Id, Date.newInstance(2026, 9, 30)
        );
        Application__c rstrPass = buildApp(
            '003', 'RSTR - Restore - No A/I Status', licenses[2].Id, Date.newInstance(2028, 12, 31)
        );
        Application__c rstrFail = buildApp(
            '004', 'RSTR - Restore - No A/I Status', licenses[3].Id, Date.newInstance(2028, 12, 31)
        );
        Application__c openBondPass = buildApp(
            '005', 'RNEW - Renewal', licenses[4].Id, Date.newInstance(2026, 9, 30)
        );
        Application__c swPass = buildApp(
            '006', 'RNEW - Renewal', licenses[5].Id, Date.newInstance(2026, 9, 30)
        );

        Test.startTest();
        Map<String, Boolean> result = ApplicationService.isHcRenewalValidationFail(
            new List<Application__c>{ rnewPass, rnewFail, rstrPass, rstrFail, openBondPass, swPass },
            new List<License__c>{
                licById.get(licenses[0].Id),
                licById.get(licenses[1].Id),
                licById.get(licenses[2].Id),
                licById.get(licenses[3].Id),
                licById.get(licenses[4].Id),
                licById.get(licenses[5].Id)
            }
        );
        Test.stopTest();

        System.assertEquals(false, result.get(rnewPass.Id),
            'Valid LP past CompleteApplicationBy__c must pass even when license expire date is rolled forward');
        System.assertEquals(true, result.get(rnewFail.Id),
            'Missing required LP coverage must still fail HC renewal validation');
        System.assertEquals(false, result.get(rstrPass.Id),
            'A restoration must only require coverage current today, not through the restoration deadline');
        System.assertEquals(true, result.get(rstrFail.Id),
            'A restoration with lapsed LP coverage must still fail HC validation');
        System.assertEquals(false, result.get(openBondPass.Id),
            'An open-ended BD Bond must not hide dated LP and WC that cover CompleteApplicationBy__c');
        System.assertEquals(false, result.get(swPass.Id),
            'SW must count as WC coverage and dated LP must pass against CompleteApplicationBy__c');
    }

    private static InsuranceBond__c buildBond(Id licenseId, String bondType, Date termDate) {
        return new InsuranceBond__c(
            Type__c = bondType,
            Amount__c = 1,
            License__c = licenseId,
            Status__c = 'Active',
            EffectiveDate__c = Date.newInstance(2020, 1, 1),
            TermDate__c = termDate
        );
    }

    private static Application__c buildApp(
        String suffix,
        String appType,
        Id licenseId,
        Date completeBy
    ) {
        return new Application__c(
            Id = Id.valueOf(APP_PREFIX + '00000000000'.substring(0, 12 - suffix.length()) + suffix),
            Type__c = appType,
            CurrentLicense__c = licenseId,
            CompleteApplicationBy__c = completeBy
        );
    }
}