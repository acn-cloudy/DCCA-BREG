@IsTest
public class BREGBatchCronInterpreterTest {

    @TestSetup
    static void setup() {
        // Setup test data if needed
    }

    // Test traditional cron expressions - Monthly patterns
    @IsTest
    static void testTraditionalCronMonthlyFirst() {
        Date lastRun = Date.newInstance(2024, 1, 15);
        Date expected = Date.newInstance(2024, 2, 1);
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 1 * *', lastRun);
        
        Assert.areEqual(expected, result, 'Monthly cron on 1st should return next month 1st');
    }

    // Test traditional cron expressions - Weekly patterns
    @IsTest
    static void testTraditionalCronWeeklyMonday() {
        Date lastRun = Date.newInstance(2024, 1, 15); // Monday
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 * * 1', lastRun);
        Date expected = Date.newInstance(2024, 1, 22); // Next Monday
        
        Assert.areEqual(expected, result, 'Weekly cron for Monday should return next Monday');
    }

    @IsTest
    static void testTraditionalCronWeeklyNumericDays() {
        Date lastRun = Date.newInstance(2024, 1, 15); // Monday
        
        // Test Sunday (0)
        Date resultSun = BREGBatchCronInterpreter.getNextRunDate('0 0 * * 0', lastRun);
        Date expectedSun = Date.newInstance(2024, 1, 21); // Next Sunday
        Assert.areEqual(expectedSun, resultSun, 'Weekly cron for day 0 (Sunday) should work');
        
        // Test Wednesday (3)
        Date resultWed = BREGBatchCronInterpreter.getNextRunDate('0 0 * * 3', lastRun);
        Date expectedWed = Date.newInstance(2024, 1, 17); // Wednesday
        Assert.areEqual(expectedWed, resultWed, 'Weekly cron for day 3 (Wednesday) should work');
    }

    // Test bi-annual patterns
    @IsTest
    static void testTraditionalCronBiAnnual() {
        Date lastRun = Date.newInstance(2024, 3, 15); // March
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 1 6,12 *', lastRun);
        Date expected = Date.newInstance(2024, 6, 1); // June 1st
        
        Assert.areEqual(expected, result, 'Bi-annual cron should return next target month');
    }

    @IsTest
    static void testTraditionalCronBiAnnualNextYear() {
        Date lastRun = Date.newInstance(2024, 8, 15); // August (after June)
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 1 6,12 *', lastRun);
        Date expected = Date.newInstance(2024, 12, 1); // December 1st same year
        
        Assert.areEqual(expected, result, 'Bi-annual cron should return December when after June');
    }

    @IsTest
    static void testTraditionalCronBiAnnualWrapToNextYear() {
        Date lastRun = Date.newInstance(2024, 12, 15); // December (after both target months)
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 1 6,12 *', lastRun);
        
        // Since we're in December (month 12) and past day 1 (currently day 15),
        // and our target months are 6 and 12, we should go to the next occurrence
        // which is June 1st of next year
        Date expected = Date.newInstance(2025, 6, 1); // June 1st next year
        
        Assert.areEqual(expected, result, 'Bi-annual cron should wrap to next year when past all target months. Expected: ' + expected + ', Actual: ' + result);
    }

    // Test edge cases and error handling
    @IsTest
    static void testNullLastRunDate() {
        Date today = Date.today();
        Date expected = today; // Should use today.addDays(-1) as reference, then add 1 day
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 * * *', null);
        
        Assert.areEqual(expected, result, 'Null last run date should use today as reference');
    }

    @IsTest
    static void testBlankCronExpression() {
        Date lastRun = Date.newInstance(2024, 1, 15);
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('', lastRun);
        
        Assert.isNull(result, 'Blank cron expression should return null');
    }

    @IsTest
    static void testNullCronExpression() {
        Date lastRun = Date.newInstance(2024, 1, 15);
        
        Date result = BREGBatchCronInterpreter.getNextRunDate(null, lastRun);
        
        Assert.isNull(result, 'Null cron expression should return null');
    }

    @IsTest
    static void testInvalidCronExpression() {
        Date lastRun = Date.newInstance(2024, 1, 15);
        
        Date result = BREGBatchCronInterpreter.getNextRunDate('INVALID_EXPRESSION', lastRun);
        
        Assert.isNull(result, 'Invalid cron expression should return null');
    }

    @IsTest
    static void testIncompleteCronExpression() {
        Date lastRun = Date.newInstance(2024, 1, 15);
        
        // Only 3 parts instead of 6-7
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 0', lastRun);
        
        Assert.isNull(result, 'Incomplete cron expression should return null');
    }

    @IsTest
    static void testTraditionalCronDefaultDaily() {
        Date lastRun = Date.newInstance(2024, 1, 15);
        Date expected = Date.newInstance(2024, 1, 16);
        
        // Cron with wildcards should default to daily
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 * * *', lastRun);
        
        Assert.areEqual(expected, result, 'Traditional cron with wildcards should default to daily');
    }

    // Test leap year handling
    @IsTest
    static void testLeapYearHandling() {
        Date lastRun = Date.newInstance(2024, 1, 15); // 2024 is a leap year
        
        // Monthly on 29th in February of leap year
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 29 * *', lastRun);
        Date expected = Date.newInstance(2024, 2, 29);
        
        Assert.areEqual(expected, result, 'Should handle leap year February 29th correctly');
    }

    @IsTest
    static void testNonLeapYearHandling() {
        Date lastRun = Date.newInstance(2023, 1, 15); // 2023 is not a leap year
        
        // Monthly on 29th should adjust to 28th in February of non-leap year
        Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 29 * *', lastRun);
        Date expected = Date.newInstance(2023, 2, 28);
        
        Assert.areEqual(expected, result, 'Should adjust to last day of month in non-leap year');
    }

        // Test various day of week formats
    @IsTest
    static void testAllDayOfWeekFormats() {
        Date lastRun = Date.newInstance(2024, 1, 15); // Monday = 1
        
        // Test all day abbreviations
        Map<String, Integer> dayMappings = new Map<String, Integer>{
            'SUN' => 0, 'MON' => 1, 'TUE' => 2, 'WED' => 3, 
            'THU' => 4, 'FRI' => 5, 'SAT' => 6
        };
        
        for (String dayAbbr : dayMappings.keySet()) {
            Date result = BREGBatchCronInterpreter.getNextRunDate('0 0 * * ' + dayAbbr, lastRun);
            Assert.isNotNull(result, 'Day abbreviation ' + dayAbbr + ' should be parsed successfully');
        }
    }    
}