public class PaymentAllocateBatchProgress {

    public PaymentAllocateBatchProgress(Apexpages.StandardSetController ctrl) {}
    
    public void StartPaymentAllocationBatch(){
        List<AsyncApexJob> aaj = [SELECT Id, Status, ApexClass.Name FROM AsyncApexJob WHERE ApexClass.Name = 'PaymentAllocateTransactionLinesBatch' ORDER BY CreatedDate desc LIMIT 1];
        if(aaj.size() > 0)
        {
            if(aaj[0].Status != 'Queued' && aaj[0].Status != 'InProgress' && aaj[0].Status != 'Holding'){
                Id batchJobId = Database.executeBatch(new PaymentAllocateTransactionLinesBatch(), 200);
            } else {
                 ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'The batch is already running.');
                 ApexPages.addMessage(myMsg);
            } 
        } else {
            Id batchJobId = Database.executeBatch(new PaymentAllocateTransactionLinesBatch(), 200);
        }
    }
    
    public PageReference BacktolistView() {
        Schema.DescribeSObjectResult destination = pymt__PaymentX__c.sObjectType.getDescribe();
        PageReference pageRef = new PageReference('/' + destination.getKeyPrefix() );
        pageRef.setRedirect(true);
        return pageRef;
    }
    
}