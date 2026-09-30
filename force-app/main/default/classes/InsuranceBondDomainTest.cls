@isTest
private class InsuranceBondDomainTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.insertInsurancePortalSubmissions();
        TestDataFactory.insertInsuranceBonds();
    }
    private static testMethod void testUpdateInsuranceBondForCancellation() {
        String query = 'Select Id, AdditionalComments__c, AuthorizedRepresentative__c, Email__c, Insurance__c, '
        +'ErrorReason__c, InsuranceType__c, InsurerAffordingCoverage__c, License__c, LimitEachOccurrence__c, '
        +'PolicyCancellationDate__c, PolicyCancellationDateDay__c, PolicyCancellationDateMonth__c, PolicyCancellationDateYear__c,'
        +' PolicyEffectiveDate__c, PolicyEffectiveDateDay__c, PolicyEffectiveDateMonth__c, PolicyEffectiveDateYear__c, '
        +'PolicyExpirationDate__c, PolicyExpirationDateDay__c, PolicyExpirationDateMonth__c, PolicyExpirationDateYear__c, '
        +'PolicyNumber__c, PVLLicenseNumber__c, PVLLicenseType__c, PVLPortalUser__c, Status__c, SubmitterType__c,'
        +' TransactionType__c from InsurancePortalSubmission__c ';
        List<InsurancePortalSubmission__c> records = Database.query(query);
        Map<String, List<InsurancePortalSubmission__c>> insurancePortalSubmissionMap = (new InsurancePortalSubmissionDomain(
            records)).convertLicenseIdToInsurancePortalSubmission();
        List<String> licenseIds = (List<String>) (new InsurancePortalSubmissionDomain(records)).getFieldValues('License__c');
        List<InsuranceBond__c> insuranceBondForCancellation = InsuranceBondSelector.getInsuranceBonds(licenseIds);
        List<InsuranceBond__c> bondsForUpdate = (new InsuranceBondDomain(
            insuranceBondForCancellation)).updateInsuranceBondForCancellation(insurancePortalSubmissionMap);
    }

    private static testMethod void testUpdateInsuranceSubmissionStatus() {
        String query = 'Select Id, AdditionalComments__c, AuthorizedRepresentative__c, Email__c, Insurance__c, '
        +'ErrorReason__c, InsuranceType__c, InsurerAffordingCoverage__c, License__c, LimitEachOccurrence__c, '
        +'PolicyCancellationDate__c, PolicyCancellationDateDay__c, PolicyCancellationDateMonth__c, PolicyCancellationDateYear__c,'
        +' PolicyEffectiveDate__c, PolicyEffectiveDateDay__c, PolicyEffectiveDateMonth__c, PolicyEffectiveDateYear__c, '
        +'PolicyExpirationDate__c, PolicyExpirationDateDay__c, PolicyExpirationDateMonth__c, PolicyExpirationDateYear__c, '
        +'PolicyNumber__c, PVLLicenseNumber__c, PVLLicenseType__c, PVLPortalUser__c, Status__c, SubmitterType__c,'
        +' TransactionType__c from InsurancePortalSubmission__c ';
        List<InsurancePortalSubmission__c> records = Database.query(query);
        Map<String, List<InsurancePortalSubmission__c>> insurancePortalSubmissionMap = (new InsurancePortalSubmissionDomain(
            records)).convertLicenseIdToInsurancePortalSubmission();
        List<String> licenseIds = (List<String>) (new InsurancePortalSubmissionDomain(records)).getFieldValues('License__c');
        List<InsuranceBond__c> insuranceBonds = InsuranceBondSelector.getInsuranceBonds(licenseIds);
        Map<String, String> messageMap = new Map<String, String>();
        for(InsuranceBond__c insuranceBond: insuranceBonds) {
            messageMap.put(insuranceBond.Id, 'test');
        }
        List<InsurancePortalSubmission__c> insuranceSubmissions = (new InsuranceBondDomain(
            insuranceBonds)).updateInsuranceSubmissionStatus(insurancePortalSubmissionMap, messageMap);
        
    }
    private static testMethod void testFilterRecordsByIdSet() {
        List<InsuranceBond__c> insuranceBonds = [Select Id, Type__c from InsuranceBond__c ];
        (new InsuranceBondDomain(insuranceBonds)).filterRecordsByIdSet(new Set<String>());
    }
    private static testMethod void testGetInsuranceTypes() {
        List<InsuranceBond__c> insuranceBonds = [Select Id, Type__c from InsuranceBond__c ];
        (new InsuranceBondDomain(insuranceBonds)).getInsuranceTypes();
    }
    private static testMethod void testGetLicenseId2InsuranceBonds() {
        List<InsuranceBond__c> insuranceBonds = [Select Id, Type__c, License__c from InsuranceBond__c ];
        (new InsuranceBondDomain(insuranceBonds)).getLicenseId2InsuranceBonds();
    }
    private static testMethod void testFilterInsuranceBonds() {
        List<License__c> records = [Select Id, LicenseType__r.BreakinInsuranceCoverageAllowed__c from License__c limit 1];
        List<InsuranceBond__c> insuranceBonds = [Select Id, Type__c, License__c, Status__c, CurrentGapinInsurance__c from InsuranceBond__c ];

        (new InsuranceBondDomain(insuranceBonds)).filterInsuranceBonds(records.get(0), new Set<String>());
    }

    private static testMethod void testGetActiveInsurancebondsByCoverageDate() {
        List<InsuranceBond__c> bonds = [
            SELECT Id, Status__c, TermDate__c, CancelDate__c
            FROM InsuranceBond__c
            LIMIT 2
        ];
        if (bonds.isEmpty()) {
            return;
        }

        InsuranceBond__c bond = bonds[0];
        bond.Status__c = 'Active';
        bond.TermDate__c = Date.newInstance(2026, 10, 7);
        bond.CancelDate__c = null;
        update bond;

        InsuranceBondDomain domain = new InsuranceBondDomain(new List<InsuranceBond__c>{ bond });
        List<InsuranceBond__c> activeBeforePeriodEnd =
            domain.getActiveInsurancebonds(Date.newInstance(2026, 9, 30));
        List<InsuranceBond__c> activeAfterPeriodEnd =
            domain.getActiveInsurancebonds(Date.newInstance(2028, 9, 30));

        System.assertEquals(1, activeBeforePeriodEnd.size(),
            'Bond with term after coverage date should be active');
        System.assertEquals(0, activeAfterPeriodEnd.size(),
            'Bond with term before coverage date should be inactive');
    }

    private static testMethod void testGetActiveInsurancebondsWrappersAndNullDate() {
        Date coverageDate = Date.newInstance(2026, 9, 30);
        InsuranceBond__c activeBond = new InsuranceBond__c(
            Status__c = 'Active',
            TermDate__c = Date.newInstance(2026, 10, 7),
            CancelDate__c = null
        );
        InsuranceBondDomain domain = new InsuranceBondDomain(new List<InsuranceBond__c>{ activeBond });

        System.assertEquals(0, domain.getActiveInsurancebonds((Date) null).size(),
            'Null coverage date should return no bonds');

        License__c license = new License__c(EffectiveExpireDate__c = coverageDate);
        System.assertEquals(1, domain.getActiveInsurancebonds(license).size(),
            'License wrapper should use EffectiveExpireDate__c');

        Application__c app = new Application__c(CompleteApplicationBy__c = coverageDate);
        System.assertEquals(1, domain.getActiveInsurancebonds(app).size(),
            'Application wrapper should use CompleteApplicationBy__c');
    }

    private static testMethod void testGetActiveInsurancebondsInactiveCancelAndOpenEnded() {
        Date coverageDate = Date.newInstance(2026, 9, 30);
        List<InsuranceBond__c> bonds = new List<InsuranceBond__c>{
            new InsuranceBond__c(
                Status__c = 'Inactive',
                TermDate__c = Date.newInstance(2026, 10, 7)
            ),
            new InsuranceBond__c(
                Status__c = 'Active',
                TermDate__c = null,
                CancelDate__c = Date.newInstance(2026, 9, 1)
            ),
            new InsuranceBond__c(
                Status__c = 'Active',
                TermDate__c = null,
                CancelDate__c = null
            )
        };

        List<InsuranceBond__c> activeBonds =
            (new InsuranceBondDomain(bonds)).getActiveInsurancebonds(coverageDate);
        System.assertEquals(1, activeBonds.size(),
            'Only the open-ended active bond should survive the coverage filter');
    }

    private static testMethod void testGetMissingRequiredTypesWithSubstituteAndBlank() {
        License__c blankRequired = new License__c();
        blankRequired.LicenseType__r = new LicenseType__c(
            InsuranceBondTypesRequired__c = null,
            BreakinInsuranceCoverageAllowed__c = 0
        );
        Set<String> blankResult = (new InsuranceBondDomain(new List<InsuranceBond__c>())).getMissingRequiredTypes(blankRequired);
        System.assertEquals(true, blankResult.isEmpty(),
            'Blank required types should return no missing types');

        License__c typedLicense = new License__c();
        typedLicense.LicenseType__r = new LicenseType__c(
            InsuranceBondTypesRequired__c = 'LP - Liability / Property Damage;WC - Workers Compensation',
            BreakinInsuranceCoverageAllowed__c = 0
        );
        List<InsuranceBond__c> coveredBonds = new List<InsuranceBond__c>{
            new InsuranceBond__c(
                Type__c = 'LP - Liability / Property Damage',
                Status__c = 'Active',
                CurrentGapinInsurance__c = null
            ),
            new InsuranceBond__c(
                Type__c = 'SI - Exclusion from Workers Comp.',
                Status__c = 'Active',
                CurrentGapinInsurance__c = null
            )
        };
        Set<String> missingCovered =
            (new InsuranceBondDomain(coveredBonds)).getMissingRequiredTypes(typedLicense);
        System.assertEquals(true, missingCovered.isEmpty(),
            'LP plus SI exclusion should satisfy LP and WC');

        List<InsuranceBond__c> lpOnly = new List<InsuranceBond__c>{
            new InsuranceBond__c(
                Type__c = 'LP - Liability / Property Damage',
                Status__c = 'Active',
                CurrentGapinInsurance__c = null
            )
        };
        Set<String> missingWc =
            (new InsuranceBondDomain(lpOnly)).getMissingRequiredTypes(typedLicense);
        System.assertEquals(true, missingWc.contains('WC - Workers Compensation'),
            'WC without a substitute should remain missing');
    }

    private static testMethod void testFilterInsuranceBondsReplacesExpiredSameType() {
        License__c license = new License__c(EffectiveExpireDate__c = Date.newInstance(2026, 9, 30));
        license.LicenseType__r = new LicenseType__c(BreakinInsuranceCoverageAllowed__c = null);

        InsuranceBond__c expired = new InsuranceBond__c(
            Type__c = 'LP - Liability / Property Damage',
            Status__c = 'Active',
            CurrentGapinInsurance__c = null,
            TermDate__c = Date.newInstance(2026, 9, 1)
        );
        InsuranceBond__c current = new InsuranceBond__c(
            Type__c = 'LP - Liability / Property Damage',
            Status__c = 'Active',
            CurrentGapinInsurance__c = null,
            TermDate__c = Date.newInstance(2026, 10, 7)
        );
        InsuranceBond__c skippedGap = new InsuranceBond__c(
            Type__c = 'WC - Workers Compensation',
            Status__c = 'Active',
            CurrentGapinInsurance__c = 10
        );

        List<InsuranceBond__c> filtered = (new InsuranceBondDomain(
            new List<InsuranceBond__c>{ expired, current, skippedGap }
        )).filterInsuranceBonds(
            license,
            new Set<String>{ 'LP - Liability / Property Damage', 'WC - Workers Compensation' }
        );
        System.assertEquals(1, filtered.size(),
            'Expired same-type bond should be replaced and over-gap WC skipped');
        System.assertEquals(Date.newInstance(2026, 10, 7), filtered[0].TermDate__c);

        List<InsuranceBond__c> statusFiltered = (new InsuranceBondDomain(
            new List<InsuranceBond__c>{
                new InsuranceBond__c(Type__c = 'LP - Liability / Property Damage', Status__c = 'Waived', CurrentGapinInsurance__c = null),
                new InsuranceBond__c(Type__c = 'BD - Bond', Status__c = 'Inactive', CurrentGapinInsurance__c = null)
            }
        )).filterInsuranceBonds(license);
        System.assertEquals(1, statusFiltered.size(),
            'Single-arg filter should keep Waived and drop Inactive');
    }

    private static testMethod void testFilterRecordsByIdSetMatchAndCancellationSkipPaths() {
        List<InsuranceBond__c> insuranceBonds = [
            SELECT Id, Type__c, Status__c, License__c
            FROM InsuranceBond__c
            LIMIT 1
        ];
        if (insuranceBonds.isEmpty()) {
            return;
        }

        List<InsuranceBond__c> matched = (new InsuranceBondDomain(insuranceBonds))
            .filterRecordsByIdSet(new Set<String>{ insuranceBonds[0].Id });
        System.assertEquals(1, matched.size());

        InsuranceBond__c inactive = new InsuranceBond__c(
            Status__c = 'Inactive',
            Type__c = 'LP - Liability / Property Damage',
            License__c = insuranceBonds[0].License__c
        );
        InsuranceBond__c unknownType = new InsuranceBond__c(
            Status__c = 'Active',
            Type__c = 'BD - Bond',
            License__c = insuranceBonds[0].License__c
        );
        Map<String, List<InsurancePortalSubmission__c>> emptyMap =
            new Map<String, List<InsurancePortalSubmission__c>>();
        (new InsuranceBondDomain(new List<InsuranceBond__c>{ inactive, unknownType }))
            .updateInsuranceBondForCancellation(emptyMap);
        (new InsuranceBondDomain(new List<InsuranceBond__c>{ inactive, unknownType }))
            .updateInsuranceSubmissionStatus(emptyMap, new Map<String, String>());
    }

}