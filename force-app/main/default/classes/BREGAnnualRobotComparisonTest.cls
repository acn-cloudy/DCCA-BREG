@IsTest
private class BREGAnnualRobotComparisonTest {

    @IsTest
    static void normalizeValueStripsFormattingForNumericLikeFields() {
        System.assertEquals(
            '123450',
            BREGAnnualRobotComparison.normalizeValue('breg_Paid_Shares__c', '1,234.50'),
            'Numeric-like field values should ignore formatting separators before comparison.'
        );
    }

    @IsTest
    static void compareAnnualDataReturnsEmptyDiffsForMatchingCaseAndEntity() {
        Case caseRecord = new Case(
            breg_Name_of_the_Entity__c = 'Acme Ltd',
            breg_Entity_Type__c = 'A1',
            breg_Entity_Nature_Of_Business__c = 'Software Development'
        );
        Account accountRecord = new Account(
            Name = 'Acme Ltd',
            breg_Entity_Type__c = 'A1',
            breg_Purpose__c = 'Software Development'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualCaseToEntity(
            caseRecord,
            accountRecord
        );

        System.assertEquals(0, result.diffs.size(), 'Matching fields should produce no diffs.');
        System.assertEquals(false, result.hasDifferences, 'hasDifferences should be false when records match.');
    }

    @IsTest
    static void compareAnnualDataDetectsCaseEntityDifferences() {
        Case caseRecord = new Case(
            breg_Name_of_the_Entity__c = 'New Acme Ltd',
            breg_Entity_Type__c = 'A1',
            breg_Entity_Nature_Of_Business__c = 'Software Development'
        );
        Account accountRecord = new Account(
            Name = 'Old Acme Ltd',
            breg_Entity_Type__c = 'A1',
            breg_Purpose__c = 'Software Development'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualCaseToEntity(
            caseRecord,
            accountRecord
        );

        System.assertEquals(1, result.diffs.size(), 'Differing Name should produce 1 diff.');
        System.assertEquals('Name', result.diffs[0].label, 'The label should identify the Name field.');
        System.assertEquals(true, result.hasDifferences, 'hasDifferences should be true.');
    }

    @IsTest
    static void compareAnnualDataChecksInitialMembersOnlyForSupportedEntityTypes() {
        Case caseRecord = new Case(
            breg_Name_of_the_Entity__c = 'Member Org',
            breg_Entity_Type__c = 'A1',
            breg_Number_of_initial_members__c = 10
        );
        Account accountRecord = new Account(
            Name = 'Member Org',
            breg_Entity_Type__c = 'A1',
            breg_Number_of_initial_members__c = 20
        );

        BREGAnnualRobotComparison.ComparisonResult a1Result = BREGAnnualRobotComparison.compareAnnualCaseToEntity(
            caseRecord,
            accountRecord
        );
        System.assertEquals(0, a1Result.diffs.size(), 'A1 entity type should ignore initial members difference.');

        caseRecord.breg_Entity_Type__c = 'A2';
        accountRecord.breg_Entity_Type__c = 'A2';

        BREGAnnualRobotComparison.ComparisonResult a2Result = BREGAnnualRobotComparison.compareAnnualCaseToEntity(
            caseRecord,
            accountRecord
        );
        System.assertEquals(1, a2Result.diffs.size(), 'A2 entity type should evaluate initial members difference.');
        System.assertEquals('NumberOfInitialMembers', a2Result.diffs[0].label, 'Diff label should be NumberOfInitialMembers.');
    }

    @IsTest
    static void compareAffiliationsHandlesIndividualAndEntityKeysSuccessfully() {
        breg_Account_Affiliation__c caseIndividual = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe',
            breg_Address__Street__s = '123 Main St'
        );
        breg_Account_Affiliation__c entityIndividual = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe',
            breg_Address__Street__s = '123 Main St'
        );

        breg_Account_Affiliation__c caseEntity = new breg_Account_Affiliation__c(
            breg_Role__c = 'Member',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Holding Corp',
            breg_Address__Street__s = '456 Market St'
        );
        breg_Account_Affiliation__c entityEntity = new breg_Account_Affiliation__c(
            breg_Role__c = 'Member',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Holding Corp',
            breg_Address__Street__s = '456 Market St'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualData(
            new Case(),
            new Account(),
            new List<breg_Account_Affiliation__c>{ caseIndividual, caseEntity },
            new List<breg_Account_Affiliation__c>{ entityIndividual, entityEntity },
            new List<breg_Stock__c>(),
            new List<breg_Stock__c>()
        );

        System.assertEquals(0, result.diffs.size(), 'Matching individual and entity affiliations should produce no diffs.');
    }

    @IsTest
    static void compareAffiliationsReportsAgentDetailChange() {
        breg_Account_Affiliation__c caseAgent = new breg_Account_Affiliation__c(
            breg_Role__c = 'Agent',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Registered Agent LLC',
            breg_Entity_Location__c = 'Honolulu',
            breg_Entity_Location_Country__c = 'US'
        );
        breg_Account_Affiliation__c entityAgentDiffLocation = new breg_Account_Affiliation__c(
            breg_Role__c = 'Agent',
            breg_Type__c = 'Entity',
            breg_Entity_Name__c = 'Registered Agent LLC',
            breg_Entity_Location__c = 'Hilo',
            breg_Entity_Location_Country__c = 'US'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualData(
            new Case(),
            new Account(),
            new List<breg_Account_Affiliation__c>{ caseAgent },
            new List<breg_Account_Affiliation__c>{ entityAgentDiffLocation },
            new List<breg_Stock__c>(),
            new List<breg_Stock__c>()
        );

        System.assertEquals(1, result.diffs.size(), 'Different agent location should produce one agent detail change.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Agent_Details_Changed, result.diffs[0].label, 'The agent change should have a business-level label.');
    }

    @IsTest
    static void compareAffiliationsIgnoresBlankCaseTitleWhenAccountHasValue() {
        breg_Account_Affiliation__c caseDirector = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith',
            breg_Officer_Director_Titles__c = null
        );
        breg_Account_Affiliation__c entityDirector = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith',
            breg_Officer_Director_Titles__c = 'President, Secretary'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualData(
            new Case(),
            new Account(),
            new List<breg_Account_Affiliation__c>{ caseDirector },
            new List<breg_Account_Affiliation__c>{ entityDirector },
            new List<breg_Stock__c>(),
            new List<breg_Stock__c>()
        );

        System.assertEquals(0, result.diffs.size(), 'Blank case title should not differ from a populated account title.');
    }

    @IsTest
    static void compareAffiliationsReportsDiffWhenCaseTitlesArePopulatedAndDiffer() {
        breg_Account_Affiliation__c caseDirector = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith',
            breg_Officer_Director_Titles__c = 'Treasurer'
        );
        breg_Account_Affiliation__c entityDirector = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Smith',
            breg_Officer_Director_Titles__c = 'President, Secretary'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualData(
            new Case(),
            new Account(),
            new List<breg_Account_Affiliation__c>{ caseDirector },
            new List<breg_Account_Affiliation__c>{ entityDirector },
            new List<breg_Stock__c>(),
            new List<breg_Stock__c>()
        );

        System.assertEquals(1, result.diffs.size(), 'Different populated titles should produce a diff.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Affiliation_Details_Changed, result.diffs[0].label, 'Diff should have a business-level affiliation label.');
    }

    @IsTest
    static void compareStocksHandlesMatchingAndMissingStocks() {
        breg_Stock__c caseStockMatch = new breg_Stock__c(
            breg_Stock_Class__c = 'Common',
            breg_Number_of_Issued_Shares__c = '1000',
            breg_Paid_Shares__c = '1000'
        );
        breg_Stock__c entityStockMatch = new breg_Stock__c(
            breg_Stock_Class__c = 'Common',
            breg_Number_of_Issued_Shares__c = '1000',
            breg_Paid_Shares__c = '1000'
        );

        breg_Stock__c caseStockOnly = new breg_Stock__c(
            breg_Stock_Class__c = 'Preferred',
            breg_Number_of_Issued_Shares__c = '500'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualData(
            new Case(),
            new Account(),
            new List<breg_Account_Affiliation__c>(),
            new List<breg_Account_Affiliation__c>(),
            new List<breg_Stock__c>{ caseStockMatch, caseStockOnly },
            new List<breg_Stock__c>{ entityStockMatch }
        );

        System.assertEquals(1, result.diffs.size(), 'Matching stock should pass and unmatched stock should produce 1 diff.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Stock_Added, result.diffs[0].label, 'Diff label should identify an added stock.');
    }

    @IsTest
    static void compareAffiliationsReportsRemovalAndStillComparesRemainingRecords() {
        breg_Account_Affiliation__c caseChangedAffiliation = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'New Name'
        );
        breg_Account_Affiliation__c caseRemovedAffiliation = new breg_Account_Affiliation__c(
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe',
            breg_To_Remove__c = true
        );
        breg_Account_Affiliation__c entityChangedAffiliation = new breg_Account_Affiliation__c(
            breg_Role__c = 'Director',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'Jane',
            breg_Last_Name__c = 'Old Name'
        );
        breg_Account_Affiliation__c entityRemovedAffiliation = new breg_Account_Affiliation__c(
            breg_Role__c = 'Officer',
            breg_Type__c = 'Individual',
            breg_First_Name__c = 'John',
            breg_Last_Name__c = 'Doe'
        );

        BREGAnnualRobotComparison.ComparisonResult result = BREGAnnualRobotComparison.compareAnnualData(
            new Case(),
            new Account(),
            new List<breg_Account_Affiliation__c>{ caseChangedAffiliation, caseRemovedAffiliation },
            new List<breg_Account_Affiliation__c>{ entityChangedAffiliation, entityRemovedAffiliation },
            new List<breg_Stock__c>(),
            new List<breg_Stock__c>()
        );

        System.assertEquals(3, result.diffs.size(), 'The changed, marked-for-removal, and remaining account affiliation differences must be reported.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Affiliation_Name_Changed, result.diffs[0].label, 'The remaining affiliation should still be compared.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Affiliation_Marked_For_Removal, result.diffs[1].label, 'The removal marker should be reported.');
        System.assertEquals(System.Label.BREG_AnnualRobot_Affiliation_Removed, result.diffs[2].label, 'The account affiliation removed by the filing should be reported.');
    }
}