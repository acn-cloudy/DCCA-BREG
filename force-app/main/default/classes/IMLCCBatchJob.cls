/*
 * ----------------------------------------------------------------------
 * Description: For Case 00040974
 * 
 * Integration - Getting Pending Licenses List from Compact
 * ----------------------------------------------------------------------
 *
 * 
 * @author emel.l.agarao@pacificpointcorp.com
 * created 12/03/2024
 */
global without sharing class IMLCCBatchJob implements Schedulable, Database.AllowsCallouts {  
    /* method to execute the schedulable context */
    global void execute(SchedulableContext context) {
        System.enqueueJob(new IMLCCQueueable(1));
    }
}