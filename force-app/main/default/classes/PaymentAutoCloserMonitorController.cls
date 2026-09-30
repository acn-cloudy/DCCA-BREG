/*
 * ___________________________________________________________________________________
 * Controller for PaymentAutoCloserMonitor lighting component
 * Covered by: PaymentAutoCloserMonitorTest
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
public class PaymentAutoCloserMonitorController {
    public void runBatch() {
        List<AsyncApexJob> jobs = [SELECT Id,
                Status,
                ApexClass.Name
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'PaymentAutoCloserBatch'
        ORDER BY CreatedDate DESC LIMIT 1];

        if (jobs.size() > 0) {
            if (jobs[0].Status != 'Queued' &&
                            jobs[0].Status != 'Processing' &&
                            jobs[0].Status != 'Holding') {
                Database.executeBatch(new PaymentAutoCloserBatch(), 200);
            } else {
                ApexPages.Message errMsg =
                        new ApexPages.Message(ApexPages.Severity.ERROR, 'The batch is already running.');
                ApexPages.addMessage(errMsg);
            }
        } else {
            Database.executeBatch(new PaymentAutoCloserBatch(), 200);
        }
    }

    public PageReference gotoPayments() {
        Schema.DescribeSObjectResult destination = pymt__PaymentX__c.sObjectType.getDescribe();
        PageReference pageRef = new PageReference('/' + destination.getKeyPrefix());
        pageRef.setRedirect(true);

        return pageRef;
    }

}