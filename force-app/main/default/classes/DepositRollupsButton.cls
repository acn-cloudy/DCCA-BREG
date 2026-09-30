public class DepositRollupsButton {

    private final Deposits__c dep;

    public DepositRollupsButton(ApexPages.StandardController stdController) {
        this.dep = (Deposits__c)stdController.getRecord();
    }

    public PageReference StartRollupBatch() {

        List<Id> depositId=new List<Id>();
        depositId.add(dep.Id);
        DepositPaymentsRolluper.rollup(depositId);
        //Id batchJobId = Database.executeBatch(new DepositRollupsBatch());
        
        PageReference pageRef = new PageReference('/'+dep.Id);
        pageRef.setRedirect(true);
        return pageRef;
        
    }
}