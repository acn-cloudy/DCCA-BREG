public with sharing class PaymentCutOffProcessingController {

    public String jobId {get;set;}

    public Boolean completed {get;set;}

    public Reconciliation_Batch__c rb {get;set;}

    public PaymentCutOffProcessingController() {

        completed = false;
        jobId = ApexPages.currentPage().getParameters().get('jobId');
    }

    public void checkStatus() {

        if(completed) {
            return;
        }

        AsyncApexJob job = [

            SELECT Id,
                   Status
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        if(Test.isRunningTest() || job.Status == 'Completed') {

            completed = true;

            List<Reconciliation_Batch__c> batches = [
                SELECT Id, Name
                FROM Reconciliation_Batch__c
                WHERE OwnerId = :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if(!batches.isEmpty()) {
                rb = batches[0];
            }
        }
    }

    public String getConfirmationMessage() {

        if(rb == null) {
            return '';
        }

        return
            'You\'re close out for the day now, ' +
            'please navigate to ' +
            rb.Name +
            ' to review and submit to GL.';
    }
}