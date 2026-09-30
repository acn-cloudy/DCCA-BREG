public with sharing class InvestigationCallsController {
    public Id Id { get; set; }
    public Investigation__c inv { get; set; }
    public List<CallItem> calls { get; set; }

    public InvestigationCallsController(){
        Id  = ApexPages.CurrentPage().getparameters().get('id');
        calls = new List<CallItem>();

        if(Id != null && String.isNotBlank(Id)){
            inv = [
                    SELECT  Id, Name, (SELECT Id, Subject, Description, CreatedDate FROM Tasks WHERE TaskSubtype = 'Call' ORDER BY CreatedDate DESC) 
                    FROM Investigation__c
                    WHERE Id =:Id
                ];

            if(inv.Tasks != null){
                for(Task task:inv.Tasks){   
                    CallItem ci = new CallItem();       
                    ci.title = task.Subject;
                    ci.createdDate = task.CreatedDate.format('MM/dd/yyyy');          
                    ci.subject = task.Description;
                    calls.add(ci);
                }
            }
        }
    }

    //constructor to get the Investigation__c record
    public InvestigationCallsController(ApexPages.StandardController controller) {
        inv =  (Investigation__c) controller.getRecord();
        Id = inv.Id;
    }

    //Method that can is called from the Visual Force page action attribute
    public PageReference generateInvestigationCalls() {
        // Instanciate Batch for SpringCM upload
        InvestigationCallsBatch batch = new InvestigationCallsBatch(Id);
        Database.executeBatch(batch);

        PageReference pageRef = new PageReference('/'+Id);
        pageRef.setRedirect(true);
        return pageRef; //Returns to the Investigation page
    }

    public class CallItem{
        public String title { get; set; }
        public String createdDate { get; set; }
        public String subject { get; set; }
    }
}