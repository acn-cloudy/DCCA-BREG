public class DocusignNavigation {
    private final Account acct;
    
    public DocusignNavigation(ApexPages.StandardController stdController) {
        this.acct = (Account)stdController.getRecord();
    }
    
    public PageReference Router() 
    { 
        return new PageReference('/apex/dsfs__CreateEnvelopeFromAccount?id=' + this.acct.Id); 
    } 
}