trigger StatusHistoryTrigger on StatusHistory__c(after insert) {
    if (Trigger.isAfter) {
        /*
        if (Trigger.isInsert) {
            List<Id> parentSebCaseIds = new List<Id>();
            List<Id> parentInvestigationIds = new List<Id>();
            List<Id> parentExamIds = new List<Id>();
            List<Id> parentFilingIds = new List<Id>();

            for (StatusHistory__c statusHistory : Trigger.new) {
                if (statusHistory.SEBCase__c != null) {
                    parentSebCaseIds.add(statusHistory.SEBCase__c);
                }

                if (statusHistory.Investigation__c != null) {
                    parentInvestigationIds.add(statusHistory.Investigation__c);
                }

                if (statusHistory.Exam__c != null) {
                    parentExamIds.add(statusHistory.Exam__c);
                }

                if (statusHistory.Filing__c != null) {
                    parentFilingIds.add(statusHistory.Filing__c);
                }
            }

            if (!parentSebCaseIds.isEmpty()) {
                AgeDaysSumCalculator.calculate('SEBCase__c', 'SEBCase__c', parentSebCaseIds);
            }

            if (!parentInvestigationIds.isEmpty()) {
                AgeDaysSumCalculator.calculate('Investigation__c', 'Investigation__c', parentInvestigationIds);
            }

            if (!parentExamIds.isEmpty()) {
                AgeDaysSumCalculator.calculate('Exam__c', 'Exam__c', parentExamIds);
            }

            if (!parentFilingIds.isEmpty()) {
                AgeDaysSumCalculator.calculate('Filing__c', 'Filing__c', parentFilingIds);
            }
        }
			*/
    }
}