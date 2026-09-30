/*
 * ___________________________________________________________________________________
 * Scheduled Job to Run PaymentAutoCloserBatch class
 * Covered by: PaymentAutoCloserSchedulerTest
 * __________________________________________________________________________________
 * PacPoint-CL031319 - Created for Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/13/2019
 * __________________________________________________________________________________
 */
public class PaymentAutoCloserScheduler implements Schedulable{
    public void execute(System.SchedulableContext sc) {
        Database.executeBatch(new PaymentAutoCloserBatch());
    }
}