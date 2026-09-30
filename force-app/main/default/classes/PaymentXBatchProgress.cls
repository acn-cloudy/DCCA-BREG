/********************************************************************************************************
*    Name:  PaymentXBatchProgress.cls
*    Author: PacificPoint 
*    Date:  10/25/2018
*    
*    Test Class: PaymentXBatchProgressTest.cls
*    VF Page: PaymentXBatchProgress.page
********************************************************************************************************/

public class PaymentXBatchProgress {
    
    public PaymentXBatchProgress() {}
    
    public void StartPaymentXBatch(){
        List<AsyncApexJob> aaj = [SELECT Id, Status, ApexClass.Name FROM AsyncApexJob WHERE ApexClass.Name = 'PaymentXBatch' ORDER BY CreatedDate desc LIMIT 1];
        if(aaj.size() > 0)
        {
            if(aaj[0].Status != 'Queued' && aaj[0].Status != 'InProgress' && aaj[0].Status != 'Holding'){
                Id batchJobId = Database.executeBatch(new PaymentXBatch(), 200);
            } else {
                 ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'The batch is already running.');
                 ApexPages.addMessage(myMsg);
            } 
        } else {
            Id batchJobId = Database.executeBatch(new PaymentXBatch(), 200);
        }
    }
    
    public PageReference BacktolistView() {
        Schema.DescribeSObjectResult destination = FeeSchedule__c.sObjectType.getDescribe();
        PageReference pageRef = new PageReference('/' + destination.getKeyPrefix() );
        pageRef.setRedirect(true);
        return pageRef;
    }

}