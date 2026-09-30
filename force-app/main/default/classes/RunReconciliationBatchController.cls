/*
* ─────────────────────────────────────────────────────────
* RunReconciliationBatchController Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ171019 - Created for PVL 4Gov Integration
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-10-17
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class RunReconciliationBatchController {
    //Apex properties or variables
    public Id Id { get; set; }
    public Reconciliation_Batch__c batchObject { get; set; }
    public Boolean isDisabled { get; set; }
    private ApexPages.standardController sc = null;

    //constructor to get the Reconciliation_Batch__c record
    public RunReconciliationBatchController(ApexPages.StandardController controller) {
        batchObject =  (Reconciliation_Batch__c) controller.getRecord();
        Id = batchObject.Id;
        sc = controller;
        isDisabled = false;
        if (String.isNotEmpty(Id)) {
            batchObject = [select Id, Name, Batch_Time__c, Status__c, Type__c from Reconciliation_Batch__c where id =: Id];
        }

        if (batchObject != null && batchObject.Status__c != 'Pending Review') {
            isDisabled = true;
        }
    }

    //Method that can is called from the Visual Force page action attribute
    public PageReference reRunBatchProcess() {
        if(batchObject?.Type__c == 'Payment'){            
            String query = 'SELECT Id,NetCollectionsafterFeesAllocated__c,PaymentType__c,Payment__r.RemitToDCCA__c,Transaction__r.Account__r.Name,Transaction__r.Name,Payment__r.pymt__Date__c,CashierCode__c,Payment__r.pymt__Memo__c,Payment__r.Division__c,TransactionLine__r.CostCenter__c,AmountAllocated__c, TransactionLine__r.CashierCode__r.FAMISSrcCode__c, TransactionLine__r.CashierCode__r.FundAccount__c';
            query += ' FROM CollectionsAllocation__c WHERE Reconciliation_Batch__c = \'' + batchObject.Id + '\' AND Payment__r.Division__c != \'PUC\'';
            List<sObject> sobjList = Database.query(query);

            ReconciliationBatchJob bj = new ReconciliationBatchJob();
            //Write each line of the csv file from the records in the CollectionsAllocation__c
            for(sObject s : sobjList) {
                CollectionsAllocation__c ca = (CollectionsAllocation__c)s;
                bj.getCSVFileDetails(ca);
            }
            bj.UpdateCSVFile(batchObject);
        } else if(batchObject?.Type__c == 'Adjustment'){
            // Run PaymentAdjustmentBatchJob
            Database.executeBatch(new PaymentAdjustmentBatchJob(batchObject.Id), 200);
        }

        PageReference pageRef = new PageReference('/'+Id);
        pageRef.setRedirect(true);
        return pageRef; 
    }
    
    public PageReference doCancel() {
        return sc.cancel();
    }
}