public without sharing class BREGWorkitemNumberGenerator {
    private static final Integer SEQUENCE_LENGTH = 4;
    private static final String INTERNAL_WORKITEM_TYPE_DIGIT = '2';
    private static final String PORTAL_WORKITEM_TYPE_DIGIT = '4';
    private static final String HAWAII_TIMEZONE = 'Pacific/Honolulu';

    /**
     * Generates breg_Workitem_Number__c for newly created cases.
     * Work Item format: "Current Date + '2' + 4 digit sequence starting from 0001" which is reset every day
     *
     * sequence = VALUE(CaseNumber) - lastDayLastCaseNumber
     * lastDayLastCaseNumber is taken from the custom setting; if the date in it is out of date, it is recalculated from the database.
     */
    public static void generateWorkitemNumbers(List<Case> cases) {
        if (cases == null || cases.isEmpty()) {
            return;
        }

        Date today = Date.valueOf(Datetime.now().format('yyyy-MM-dd', HAWAII_TIMEZONE));
        BREG_Setting__c settings = BREG_Setting__c.getOrgDefaults();

        Set<Id> newCaseIds = new Set<Id>();
        for (Case c : cases) {
            newCaseIds.add(c?.Id);
        }

        Integer lastDayLastCaseNumber = getLastDayLastCaseNumber(today, newCaseIds, settings);
        applyWorkitemNumbers(today, cases, lastDayLastCaseNumber);
    }

    @TestVisible
    private static Integer getLastDayLastCaseNumber(Date today, Set<Id> newCaseIds, BREG_Setting__c settings) {
        if (settings == null) {
            settings = new BREG_Setting__c();
        }

        Date lastDate = settings.Last_Case_Number_Date__c;

        if (lastDate == null || lastDate < today) {
            TimeZone hawaiiTz = TimeZone.getTimeZone(HAWAII_TIMEZONE);
            Datetime todayGmt = Datetime.newInstanceGmt(today.year(), today.month(), today.day(), 0, 0, 0);
            Datetime startOfToday = todayGmt.addSeconds(-(Integer)(hawaiiTz.getOffset(todayGmt) / 1000));

            List<Case> lastCases = [
                SELECT CaseNumber
                FROM Case
                WHERE breg_Received_Date__c < :startOfToday AND Id NOT IN :newCaseIds
                ORDER BY breg_Received_Date__c DESC
                LIMIT 1
            ];

            if (!lastCases.isEmpty()) {
                settings.Last_Case_Number__c = Integer.valueOf(lastCases[0].CaseNumber);
            } else {
                settings.Last_Case_Number__c = 0;
            }

            settings.Last_Case_Number_Date__c = today;
            upsert settings;
        }

        Integer lastDayLastCaseNumber = (settings.Last_Case_Number__c == null) ? 0 : Integer.valueOf(settings.Last_Case_Number__c);

        return lastDayLastCaseNumber;
    }

    @TestVisible
    private static void applyWorkitemNumbers(Date today, List<Case> cases, Integer lastDayLastCaseNumber) {
        List<Case> toUpdate = new List<Case>();

        for (Case c : cases) {
            if (c.CaseNumber == null || c.breg_Workitem_Number__c != null) {
                continue;
            }

            if (c.breg_ESWM_WFWORKITEM_ID__C != null) {
                c.breg_Workitem_Number__c = c.breg_ESWM_WFWORKITEM_ID__C;
                toUpdate.add(c);
                continue;
            }

            Integer caseNumberInt;
            try {
                caseNumberInt = Integer.valueOf(c.CaseNumber);
            } catch (Exception e) {
                system.debug('Could not convert CaseNumber to Integer: ' + e.getMessage());
                continue;
            }

            Integer sequence = caseNumberInt - lastDayLastCaseNumber;
            if (sequence <= 0) {
                sequence = 1;
            }

            String rawSeq = String.valueOf(sequence);
            if (rawSeq.length() > SEQUENCE_LENGTH) {
                rawSeq = rawSeq.substring(rawSeq.length() - SEQUENCE_LENGTH);
            }

            String datePart = Datetime.now().format('MMddyyyy', HAWAII_TIMEZONE);
            String sequenceStr = rawSeq.leftPad(SEQUENCE_LENGTH, '0');
            String workitemTypeDigit = c.Origin == 'Web' ? PORTAL_WORKITEM_TYPE_DIGIT : INTERNAL_WORKITEM_TYPE_DIGIT;
            String workitemNumber = datePart + workitemTypeDigit + sequenceStr;

            c.breg_Workitem_Number__c = workitemNumber;

            toUpdate.add(c);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}