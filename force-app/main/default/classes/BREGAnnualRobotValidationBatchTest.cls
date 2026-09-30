@IsTest
private class BREGAnnualRobotValidationBatchTest {
    @TestSetup
    private static void setupData() {
        BREGTestDataFactory.createEntityAccounts(1);
        BREGTestDataFactory.createFormConfigurations();
        upsert new breg_Docusign_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        upsert new BREG_Setting__c(
            SetupOwnerId = UserInfo.getUserId(),
            Annual_Robot_Enabled__c = true,
            Global_Data_Migration_Triggers_Disabled__c = false
        );
    }

    @IsTest
    static void executeWritesCsvWithMatchAndMismatchedCases() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('11111-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('Validation');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annual = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());
        String filingYear = String.valueOf(Date.today().year());

        Case matchingCase = BREGAnnualRobotTestHelper.createAnnualCase(
            BREGAnnualRobotTestHelper.buildAnnualCaseInput(entity, contactRecord, annualFormId, annual.Id, filingYear, '0001', false, null, false)
        );

        Case mismatchedCase = BREGAnnualRobotTestHelper.createAnnualCase(
            BREGAnnualRobotTestHelper.buildAnnualCaseInput(entity, contactRecord, annualFormId, annual.Id, filingYear, '0002', false, null, false)
        );
        mismatchedCase.breg_Entity_Nature_Of_Business__c = 'Completely Different Purpose';
        update mismatchedCase;

        Test.startTest();
        Database.executeBatch(new BREGAnnualRobotValidationBatch(), 50);
        Test.stopTest();

        List<ContentVersion> results = [SELECT Id, VersionData FROM ContentVersion WHERE Title LIKE 'BREG Annual Robot Validation Results%'];
        System.assertEquals(1, results.size(), 'Batch should create exactly one CSV result file.');

        String csvContent = results[0].VersionData.toString();
        System.assert(csvContent.contains(matchingCase.Id + ',"0001"'), 'CSV should include the matching case row.');
        System.assert(csvContent.contains(mismatchedCase.Id + ',"0002"'), 'CSV should include the mismatched case row.');

        Map<Id, String> rowByCaseId = new Map<Id, String>();
        for (String line : csvContent.split('\n')) {
            if (line.startsWith(matchingCase.Id) || line.startsWith(mismatchedCase.Id)) {
                rowByCaseId.put((Id) line.substring(0, line.indexOf(',')), line);
            }
        }
        System.assert(rowByCaseId.get(matchingCase.Id).contains(',Yes,0'), 'Matching case should be flagged as a match with zero differences.');
        System.assert(!rowByCaseId.get(mismatchedCase.Id).contains(',Yes,0'), 'Mismatched case should not be flagged as a zero-difference match.');
    }

    @IsTest
    static void executeSkipsCasesOutsideEligibleCriteria() {
        Account entity = BREGAnnualRobotTestHelper.prepareEntity('22222-D1');
        Contact contactRecord = BREGAnnualRobotTestHelper.createContact('Validation2');
        Id annualFormId = BREGAnnualRobotTestHelper.getAnnualFormId();
        breg_Annual__c annual = BREGAnnualRobotTestHelper.createAnnual(entity.Id, Date.today().year());

        Case noChangesTrueCase = BREGAnnualRobotTestHelper.createAnnualCase(
            BREGAnnualRobotTestHelper.buildAnnualCaseInput(
                entity,
                contactRecord,
                annualFormId,
                annual.Id,
                String.valueOf(Date.today().year()),
                '0003',
                true,
                null,
                false
            )
        );

        Test.startTest();
        Database.executeBatch(new BREGAnnualRobotValidationBatch(), 50);
        Test.stopTest();

        List<ContentVersion> results = [SELECT Id, VersionData FROM ContentVersion WHERE Title LIKE 'BREG Annual Robot Validation Results%'];
        System.assertEquals(1, results.size(), 'Batch should still create a CSV result file even with no eligible cases.');
        System.assert(
            !results[0].VersionData.toString().contains(noChangesTrueCase.Id),
            'Cases with breg_No_Changes__c = true are not part of the analysis and must be excluded.'
        );
    }
}