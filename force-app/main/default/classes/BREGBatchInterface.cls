public abstract class BREGBatchInterface {
    // Properties
    public String cronExp { get; set; }
    public Date lastRunDate { get; set; }
    public List<String> logs { get; set; }
    public String className { get; set; }
    
    // Instance initializer to ensure logs is always a new list by default
    public BREGBatchInterface() {
        logs = new List<String>();
    }
    
    // Methods
    public virtual Boolean isRunningToday() {
        Date today = Date.today();
        
        // Use cron interpreter to determine if we should run today
        Date nextRunDate = BREGBatchCronInterpreter.getNextRunDate(cronExp, lastRunDate);
        
        // If no valid next run date calculated, don't run
        if (nextRunDate == null) {
            logs.add('No valid next run date calculated for cron expression "' + cronExp + '"');
            return false;
        }
        
        return nextRunDate <= today;
    }
    
    public abstract BatchProcessingResult processRecords(Map<Id, SObject> recordsMap, String sObjectType);

    // Result wrapper
    public class BatchProcessingResult {
        public Map<Id, SObject> recordsToUpsert { get; set; }
        public List<Task> tasksToUpsert { get; set; }

        public BatchProcessingResult() {
            recordsToUpsert = new Map<Id, SObject>();
            tasksToUpsert = new List<Task>();
        }
    }
}