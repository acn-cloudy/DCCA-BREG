/*
* ─────────────────────────────────────────────────────────
* Controller Test for the BatchJobExecution Lightning Component 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ250919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* 
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
@isTest
private class BatchJobExecutionControllerTest {
    public static testMethod void testLoadBatchClassesAsButtons() {
        System.assert(BatchJobExecutionController.loadBatchClassesAsButtons().size() > 0);

    }

    public static testMethod void testFetchProfile() {
        System.assert(BatchJobExecutionController.fetchProfile() != null);
    } 

    public static testMethod void testRunBatchClass() {
        
        for(BatchJob_Setting__mdt batchsetting: BatchJobExecutionController.loadBatchClassesAsButtons()) {
            BatchJobExecutionController.runBatchClass(batchsetting);
        }
        List<CronTrigger> cronJobs = [SELECT Id, CronJobDetail.Id, CronJobDetail.Name, CronJobDetail.JobType FROM CronTrigger ORDER BY CreatedDate DESC];
        System.assert(cronJobs.size() > 0);
    }    
}