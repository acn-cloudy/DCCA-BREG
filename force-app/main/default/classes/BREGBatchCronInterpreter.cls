public with sharing class BREGBatchCronInterpreter {
    
    /**
     * Calculates the next run date based on a cron expression and last run date
     * Supports common cron patterns for scheduling batch jobs
     * 
     * @param cronExp Cron expression (supports simplified patterns)
     * @param lastRun Last execution date (if null, assumes first run)
     * @return Next scheduled run date
     */
    public static Date getNextRunDate(String cronExp, Date lastRun) {
        if (String.isBlank(cronExp)) {
            return null; // No schedule defined
        }
        
        // If no last run date, calculate next run from today
        Date referenceDate = (lastRun != null) ? lastRun : Date.today().addDays(-1);
        
        try {
            return parseCronExpression(cronExp, referenceDate);
        } catch (Exception e) {
            System.debug('Error parsing cron expression "' + cronExp + '": ' + e.getMessage());
            // Default fallback
            return null;
        }
    }
    
    /**
     * Parses cron expression and calculates next run date
     * Supports standard cron syntax (5 fields):
     * Minute (0-59) Hour (0-23) Day_of_month (1-31) Month (1-12) Day_of_week (0-6)
     * - Daily: "0 0 * * *" (every day at midnight)
     * - Weekly: "0 0 * * 1" (every Monday at midnight)
     * - Monthly: "0 0 1 * *" (every 1st day of the month at midnight)
     * - Bi-annual: "0 0 1 6,12 *" (every 1st day of June and December at midnight)
     */
    private static Date parseCronExpression(String cronExp, Date referenceDate) {
        cronExp = cronExp.trim().toUpperCase();
        
        // Handle standard 5-field cron expressions
        List<String> cronParts = cronExp.split('\\s+');
        if (cronParts.size() == 5) {
            return parseTraditionalCron(cronParts, referenceDate);
        }
        
        // Default fallback
        return null;
    }
    
    /**
     * Parses standard 5-field cron expressions: minute hour day_of_month month day_of_week
     */
    private static Date parseTraditionalCron(List<String> cronParts, Date referenceDate) {
        // Standard cron format: minute hour day_of_month month day_of_week
        String day = cronParts[2];      // Day of month
        String month = cronParts[3];    // Month
        String dayOfWeek = cronParts[4]; // Day of week
        
        // Bi-annual/multi-month pattern: specific months (check first)
        if (month.contains(',')) {
            List<Integer> months = new List<Integer>();
            for (String m : month.split(',')) {
                months.add(Integer.valueOf(m.trim()));
            }
            Integer dayOfMonth = (day != '*' && day != '?') ? Integer.valueOf(day) : 1;
            return getNextMultiMonthDate(referenceDate, months, dayOfMonth);
        }
        
        // Monthly pattern: specific day of month
        if (day != '*' && day != '?') {
            Integer dayOfMonth = Integer.valueOf(day);
            return getNextMonthlyDate(referenceDate, dayOfMonth);
        }
        
        // Weekly pattern: specific day of week
        if (dayOfWeek != '*' && dayOfWeek != '?') {
            Integer targetDayOfWeek = parseDayOfWeek(dayOfWeek);
            return getNextWeeklyDate(referenceDate, targetDayOfWeek);
        }
        
        // Default to daily
        return referenceDate.addDays(1);
    }
    
    /**
     * Calculates next date for monthly execution on specific day
     */
    private static Date getNextMonthlyDate(Date referenceDate, Integer dayOfMonth) {
        Date nextMonth = referenceDate.addMonths(1);
        return Date.newInstance(nextMonth.year(), nextMonth.month(), Math.min(dayOfMonth, Date.daysInMonth(nextMonth.year(), nextMonth.month())));
    }
    
    /**
     * Calculates next date for weekly execution on specific day
     */
    private static Date getNextWeeklyDate(Date referenceDate, Integer targetDayOfWeek) {
        Integer currentDayOfWeek = Math.mod(referenceDate.toStartOfWeek().daysBetween(referenceDate), 7);
        Integer daysToAdd = targetDayOfWeek - currentDayOfWeek;
        if (daysToAdd <= 0) {
            daysToAdd += 7; // Next week
        }
        return referenceDate.addDays(daysToAdd);
    }
    
    /**
     * Calculates next date for multi-month execution in specific months and day
     */
    private static Date getNextMultiMonthDate(Date referenceDate, List<Integer> targetMonths, Integer dayOfMonth) {
        Integer currentMonth = referenceDate.month();
        Integer currentDay = referenceDate.day();
        Integer currentYear = referenceDate.year();
        
        // Sort months to ensure proper order
        targetMonths.sort();
        
        // Find next target month in current year
        for (Integer targetMonth : targetMonths) {
            // If target month is after current month, or same month but target day is after current day
            if (targetMonth > currentMonth || (targetMonth == currentMonth && dayOfMonth > currentDay)) {
                Integer validDay = Math.min(dayOfMonth, Date.daysInMonth(currentYear, targetMonth));
                return Date.newInstance(currentYear, targetMonth, validDay);
            }
        }
        
        // If no target month found in current year, go to next year with first target month
        Integer validDay = Math.min(dayOfMonth, Date.daysInMonth(currentYear + 1, targetMonths[0]));
        return Date.newInstance(currentYear + 1, targetMonths[0], validDay);
    }
    
    /**
     * Converts day of week string to integer (0=Sunday, 1=Monday, etc.)
     */
    private static Integer parseDayOfWeek(String dayOfWeek) {
        switch on dayOfWeek.toUpperCase() {
            when 'SUN', '0' { return 0; }
            when 'MON', '1' { return 1; }
            when 'TUE', '2' { return 2; }
            when 'WED', '3' { return 3; }
            when 'THU', '4' { return 4; }
            when 'FRI', '5' { return 5; }
            when 'SAT', '6' { return 6; }
            when else { return Integer.valueOf(dayOfWeek); }
        }
    }
}