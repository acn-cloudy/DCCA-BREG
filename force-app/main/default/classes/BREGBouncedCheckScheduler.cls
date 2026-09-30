public with sharing class BREGBouncedCheckScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BREGCaseHistoryBatch(), 200);
    }
}