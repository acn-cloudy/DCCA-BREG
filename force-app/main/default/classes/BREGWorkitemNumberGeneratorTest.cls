@isTest
public with sharing class BREGWorkitemNumberGeneratorTest {
    private static final String HAWAII_TIMEZONE = 'Pacific/Honolulu';

    private static final Integer SEQUENCE_LENGTH = 4;
    private static final String WORKITEM_TYPE_DIGIT = '2';

    // Builds prefix directly from the Hawaii Date value — avoids org-timezone formatting drift.
    private static String getTodayWorkitemPrefix(Date today) {
        String month = String.valueOf(today.month()).leftPad(2, '0');
        String day   = String.valueOf(today.day()).leftPad(2, '0');
        String year  = String.valueOf(today.year());
        return month + day + year + WORKITEM_TYPE_DIGIT;
    }

    private static String expectedWorkitem(Integer caseNumberInt, Integer lastDayLastCaseNumber, Date today) {
        Integer sequence = caseNumberInt - (lastDayLastCaseNumber == null ? 0 : lastDayLastCaseNumber);

        if (sequence <= 0) {
            sequence = 1;
        }

        String rawSeq = String.valueOf(sequence);

        if (rawSeq.length() > SEQUENCE_LENGTH) {
            rawSeq = rawSeq.substring(rawSeq.length() - SEQUENCE_LENGTH);
        }

        String sequenceStr = rawSeq.leftPad(SEQUENCE_LENGTH, '0');
        String month = String.valueOf(today.month()).leftPad(2, '0');
        String day   = String.valueOf(today.day()).leftPad(2, '0');
        String year  = String.valueOf(today.year());
        String datePart = month + day + year;
        return datePart + WORKITEM_TYPE_DIGIT + sequenceStr;
    }

    @TestSetup
    static void setupData() {
        Id bregCaseRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId();

        List<Case> newCases = new List<Case>{
            new Case(Origin = 'Email', Status = 'New', Subject = 'Test Case', RecordTypeId = bregCaseRecordTypeId),
            new Case(Origin = 'Email', Status = 'New', Subject = 'Test Case', RecordTypeId = bregCaseRecordTypeId),
            new Case(Origin = 'Email', Status = 'New', Subject = 'Test Case with custom workitem number', RecordTypeId = bregCaseRecordTypeId)
        };

        insert newCases;
    }

    @IsTest
    static void testBasicGeneration() {

        Date today = Date.valueOf(Datetime.now().format('yyyy-MM-dd', HAWAII_TIMEZONE));

        List<Case> updatedCases = [
            SELECT Id, CaseNumber, breg_Workitem_Number__c
            FROM Case
            WHERE Subject = 'Test Case'
        ];

        String prefix = getTodayWorkitemPrefix(today);

        for (Case c : updatedCases) {
            System.assertNotEquals(null, c.breg_Workitem_Number__c, 'Workitem must be generated');
            System.assertEquals(13, c.breg_Workitem_Number__c.length(), 'Workitem must be exactly 13 chars');
            System.assert(c.breg_Workitem_Number__c.startsWith(prefix), 'Workitem must start with today date + "2"');
        }
    }

    @IsTest
    static void testAssignNumbersWhenLastCaseNumberZero() {
        Date today = Date.valueOf(Datetime.now().format('yyyy-MM-dd', HAWAII_TIMEZONE));

        List<Case> casesToProcess = [
            SELECT Id, CaseNumber, breg_Workitem_Number__c, breg_ESWM_WFWORKITEM_ID__c, Origin
            FROM Case
            WHERE Subject = 'Test Case'
            ORDER BY CreatedDate ASC
        ];

        for (Case c : casesToProcess) {
            c.breg_Workitem_Number__c = null;
        }

        Test.startTest();
        BREGWorkitemNumberGenerator.applyWorkitemNumbers(today, casesToProcess, 0);
        Test.stopTest();

        for (Case c : casesToProcess) {
            Integer caseNumInt = Integer.valueOf(c.CaseNumber);
            String expected = expectedWorkitem(caseNumInt, 0, today);
            System.assertEquals(expected, c.breg_Workitem_Number__c, 'Workitem number should match the expected one when setting is empty');
        }
    }

    @isTest
    static void testGenerateWithCustomWorkitemNumber() {
        Date today = Date.valueOf(Datetime.now().format('yyyy-MM-dd', HAWAII_TIMEZONE));
        String custmoWorkitemNumber = '123456789012';

        List<Case> casesToProcess = [
            SELECT Id, CaseNumber, breg_Workitem_Number__c
            FROM Case
            WHERE Subject = 'Test Case with custom workitem number'
            ORDER BY CreatedDate ASC
        ];

        casesToProcess[0].breg_Workitem_Number__c = custmoWorkitemNumber;

        Test.startTest();
        BREGWorkitemNumberGenerator.generateWorkitemNumbers(null);
        BREGWorkitemNumberGenerator.applyWorkitemNumbers(today, casesToProcess, 0);
        Test.stopTest();

        System.assertEquals(custmoWorkitemNumber, casesToProcess[0].breg_Workitem_Number__c,
        'Workitem should not change when called with null or an empty list.');
    }

    @isTest
    static void testGenerateWhenSettingsNull() {
        Date today = Date.valueOf(Datetime.now().format('yyyy-MM-dd', HAWAII_TIMEZONE));

        List<BREG_Setting__c> allSettings = [SELECT Id FROM BREG_Setting__c];
        if (!allSettings.isEmpty()) {
            delete allSettings;
        }

        Test.startTest();
        BREGWorkitemNumberGenerator.getLastDayLastCaseNumber(today, null, null);
        Test.stopTest();

        BREG_Setting__c created = BREG_Setting__c.getOrgDefaults();
        System.assertNotEquals(null, created, 'org-default setting must exist');
        System.assertNotEquals(null, BREG_Setting__c.Last_Case_Number__c, 'org-default Last_Case_Number__c must exist');
        System.assertNotEquals(null, BREG_Setting__c.Last_Case_Number_Date__c, 'org-default Last_Case_Number_Date__c must exist');
    }

    /**
     * Core regression: verifies that cases processed on the same Hawaii calendar day
     * all receive (a) the correct Hawaii date prefix and (b) unique, sequential numbers.
     *
     * Without the Hawaii-timezone fix, cases created after UTC midnight but before
     * 10:00 UTC (= still the previous Hawaii day) would get tomorrow's date prefix,
     * causing the sequence counter to reset and producing duplicate workitem numbers.
     */
    @isTest
    static void testNoDuplicatesInSameHawaiiDay() {
        Date today = Date.valueOf(Datetime.now().format('yyyy-MM-dd', HAWAII_TIMEZONE));
        String expectedPrefix = getTodayWorkitemPrefix(today);

        List<Case> casesToProcess = [
            SELECT Id, CaseNumber, breg_Workitem_Number__c, breg_ESWM_WFWORKITEM_ID__c, Origin
            FROM Case
            WHERE Subject = 'Test Case'
            ORDER BY CaseNumber ASC
        ];

        // Clear any workitem numbers so applyWorkitemNumbers assigns fresh ones.
        for (Case c : casesToProcess) {
            c.breg_Workitem_Number__c = null;
        }

        Test.startTest();
        BREGWorkitemNumberGenerator.applyWorkitemNumbers(today, casesToProcess, 0);
        Test.stopTest();

        System.assert(casesToProcess.size() > 1, 'Need at least 2 cases to verify uniqueness');

        Set<String> seen = new Set<String>();
        for (Case c : casesToProcess) {
            System.assertNotEquals(null, c.breg_Workitem_Number__c,
                'Every case must receive a workitem number');
            System.assert(
                c.breg_Workitem_Number__c.startsWith(expectedPrefix),
                'Workitem must use Hawaii date prefix "' + expectedPrefix + '", got: ' + c.breg_Workitem_Number__c
            );
            System.assert(
                !seen.contains(c.breg_Workitem_Number__c),
                'Duplicate workitem number detected: ' + c.breg_Workitem_Number__c
            );
            seen.add(c.breg_Workitem_Number__c);
        }
        System.assertEquals(casesToProcess.size(), seen.size(),
            'All workitem numbers within the same Hawaii day must be unique');
    }
}