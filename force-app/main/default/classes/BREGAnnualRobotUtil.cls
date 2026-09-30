public with sharing class BREGAnnualRobotUtil {
    public static Integer parseInteger(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        try {
            return Integer.valueOf(value);
        } catch (Exception ex) {
            return null;
        }
    }

    public static Integer getAnnualProcessingYear(Case currentCase) {
        if (currentCase == null || !hasAnnual(currentCase)) {
            return null;
        }
        return parseInteger(currentCase.breg_Annual__r.breg_Filing_Year__c);
    }

    public static Boolean hasAnnual(Case currentCase) {
        return currentCase != null && currentCase.breg_Annual__c != null && currentCase.breg_Annual__r != null;
    }

    public static Boolean hasEntity(Case currentCase) {
        return currentCase != null && currentCase.breg_Entity__c != null && currentCase.breg_Entity__r != null;
    }

    public static Boolean isResolvedRelatedAnnualCase(Case relatedAnnualCase) {
        return relatedAnnualCase != null &&
            (relatedAnnualCase.Status == 'Completed' || relatedAnnualCase.breg_Annual_Robot_Status__c == 'Completed');
    }

    public static Boolean isFinalBlockedRobotStatus(String robotStatus) {
        return robotStatus == 'Routed for manual' || robotStatus == 'Error';
    }
}