/**
 * Test class for BREGAccountAffiliationValidator
 */
@isTest
public with sharing class BREGAccountAffiliationValidatorTest {
    @TestSetup
    static void setup() {
        List<breg_Form_Configuration__c> testFormConfigs = new List<breg_Form_Configuration__c>();
        Map<String, String> configs = new Map<String, String>{
            'G5' => 'GP-1',
            'S1' => 'SBC-1',
            'C5' => 'LLC-1',
            'P1' => 'PC-1',
            'C1' => 'CONS-1',
            'F1' => 'FC-1',
            'D9' => 'SOLE-1',
            'L5' => 'LP-1'
        };
        for (String suffixCode : configs.keySet()) {
            testFormConfigs.add(new breg_Form_Configuration__c(breg_Suffix_Code__c = suffixCode, breg_Form_Code__c = configs.get(suffixCode)));
        }
        insert testFormConfigs;

        // Create test cases
        List<Case> testCases = new List<Case>();
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();
        for (breg_Form_Configuration__c form : testFormConfigs) {
            Case testCase = new Case(
                Subject = 'Test Case',
                Status = 'New',
                Origin = 'Web',
                RecordTypeId = bregCaseRecordTypeId,
                breg_Form_Configuration__c = form.Id,
                breg_Form_Code__c = form.breg_Form_Code__c,
                breg_Name_of_the_Entity__c = 'Test Incorporated cooperative' + form.breg_Form_Code__c,
                breg_Stock_Type__c = 'Without Stock'
            );
            testCases.add(testCase);
        }
        insert testCases;
    }

    /**
     * Test the number of partners for GP-1
     */
    @isTest
    static void testNumberOfPartnersGP1() {
        Case testCase = getTestCase('GP-1');
        testCase.Status = 'Pending Submission';
        update testCase;
        breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);

        Test.startTest();
        Database.SaveResult sr = Database.insert(accAffiliation, false);
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 2 partners')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 2 partners');
    }

    /**
     * Test the director Office Held for SBC-1
     */
    // @isTest
    // static void testDirectorOfficeHeldSBC1() {
    //     Case testCase = getTestCase('SBC-1');
    //     testCase.Status = 'Pending Submission';
    //     update testCase;
    //     breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);
    //     accAffiliation.breg_Role__c = 'Director';
    //     accAffiliation.breg_Officer_Director_Titles__c = 'Test';

    //     Test.startTest();
    //     Database.SaveResult sr = Database.insert(accAffiliation, false);
    //     Test.stopTest();
    //     Boolean missingMembers = false;
    //     for (Database.Error err : sr.getErrors()) {
    //         System.debug(err.getMessage());
    //         if (err.getMessage().contains('Office Held position must be "Benefit Director"')) {
    //             missingMembers = true;
    //         }
    //     }
    //     Assert.isTrue(missingMembers, 'Office Held position must be "Benefit Director"');
    // }

    /**
     * Test the number of members for LLC-1
     */
    @isTest
    static void testNumberOfMembersLLC1() {
        Case testCase = getTestCase('LLC-1');
        testCase.Status = 'Pending Submission';
        update testCase;
        breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);

        Test.startTest();
        Database.SaveResult sr = Database.insert(accAffiliation, false);
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 1 member to proceed.')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 1 member to proceed.');
    }

    /**
     * Test the number of directors for PC-1
     */
    @isTest
    static void testNumberOfDirectorsPC1() {
        Case testCase = getTestCase('PC-1');
        testCase.Status = 'Pending Submission';
        update testCase;

        breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);
        accAffiliation.breg_Role__c = 'Officer';

        Test.startTest();
        Database.SaveResult sr = Database.insert(accAffiliation, false);
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 1 director to proceed.')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 1 director to proceed.');
    }

    /**
     * Test the number directors for CONS-1
     */
    @isTest
    static void testNumberOfDirectorsCONS1() {
        Case testCase = getTestCase('CONS-1');
        testCase.Status = 'Pending Submission';
        update testCase;

        breg_Account_Affiliation__c accAffiliationDirector = getTestAccountAffiliation(testCase.Id);
        accAffiliationDirector.breg_Role__c = 'Director';
        breg_Account_Affiliation__c accAffiliationOfficer = getTestAccountAffiliation(testCase.Id);
        accAffiliationOfficer.breg_Role__c = 'Officer';

        Test.startTest();
        Database.SaveResult sr = Database.insert(new List<breg_Account_Affiliation__c>{ accAffiliationDirector, accAffiliationOfficer }, false)[0];
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 3 directors to proceed.')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 3 directors to proceed.');
    }

    /**
     * Test the number of directors/officers for FC-1
     */
    @isTest
    static void testNumberOfDirectorsOfficersFC1() {
        Case testCase = getTestCase('FC-1');
        testCase.Status = 'Pending Submission';
        update testCase;

        breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);

        Test.startTest();
        Database.SaveResult sr = Database.insert(accAffiliation, false);
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 1 officer/director to proceed.')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 1 officer/director to proceed.');
    }

    /**
     * Test the number of partners for LP-1
     */
    @isTest
    static void testNumberOfDirectorsOfficersLP1() {
        Case testCase = getTestCase('LP-1');
        testCase.Status = 'Pending Submission';
        update testCase;

        breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);
        accAffiliation.breg_Role__c = 'Officer';

        Test.startTest();
        Database.SaveResult sr = Database.insert(accAffiliation, false);
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 1 partner to proceed.')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 1 partner to proceed.');
    }

    /**
     * Test the number of officers for SOLE-1
     */
    @isTest
    static void testNumberOfDirectorsOfficersSOLE1() {
        Case testCase = getTestCase('SOLE-1');
        testCase.Status = 'Pending Submission';
        update testCase;

        breg_Account_Affiliation__c accAffiliation = getTestAccountAffiliation(testCase.Id);

        Test.startTest();
        Database.SaveResult sr = Database.insert(accAffiliation, false);
        Test.stopTest();
        Boolean missingMembers = false;
        for (Database.Error err : sr.getErrors()) {
            System.debug(err.getMessage());
            if (err.getMessage().contains('Add at least 1 officer to proceed.')) {
                missingMembers = true;
            }
        }
        Assert.isTrue(missingMembers, 'Add at least 1 officer to proceed.');
    }

    private static Case getTestCase(String formCode) {
        return [
            SELECT
                Id,
                breg_TN_TM_SM__c,
                breg_Form_Code__c,
                breg_Company_Address__CountryCode__s,
                breg_Company_Address__Street__s,
                breg_Company_Address__StateCode__s,
                breg_Company_Address__City__s,
                breg_Company_Address__PostalCode__s,
                breg_TNTMSM_First_Used_Anywhere__c,
                breg_TNTMSM_First_Used_Hawaii__c,
                breg_Expiration_Date__c,
                breg_Effective_Date__c,
                breg_TNTMSM_Registration_Type__c
            FROM Case
            WHERE breg_Form_Code__c = :formCode
            LIMIT 1
        ][0];
    }

    private static breg_Account_Affiliation__c getTestAccountAffiliation(Id caseId) {
        breg_Account_Affiliation__c accAffiliation = new breg_Account_Affiliation__c();
        accAffiliation.breg_Case__c = caseId;
        accAffiliation.breg_Role__c = 'Partner';
        accAffiliation.breg_Type__c = 'Entity';
        accAffiliation.breg_First_Name__c = 'FirstName';
        accAffiliation.breg_Last_Name__c = 'LastName';
        accAffiliation.breg_Entity_Name__c = 'Corporation Company LLC';
        accAffiliation.breg_Address__CountryCode__s = 'US';
        accAffiliation.breg_Address__Street__s = 'Mart rd, 134';
        accAffiliation.breg_Address__StateCode__s = 'HI';
        accAffiliation.breg_Address__City__s = 'Honolulu';
        accAffiliation.breg_Address__PostalCode__s = '1234';
        return accAffiliation;
    }
}