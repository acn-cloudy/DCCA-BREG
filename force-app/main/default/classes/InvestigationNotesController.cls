public with sharing class InvestigationNotesController {
    public Id Id { get; set; }
    public Investigation__c inv { get; set; }
    public List<NoteItem> notes { get; set; }

    public InvestigationNotesController(){
        Id  = ApexPages.CurrentPage().getparameters().get('id');
        notes = new List<NoteItem>();

        if(Id != null && String.isNotBlank(Id)){
            inv = [
                    SELECT  Id, Name, (SELECT Id, Title, TextPreview, CreatedDate FROM AttachedContentNotes ORDER BY CreatedDate DESC) 
                    FROM Investigation__c
                    WHERE Id =:Id
                ];

            if(inv.AttachedContentNotes != null){
                Map<Id, String> contentMap = new Map<Id, String>();
                List<Id> allContentDocIds = new List<Id>();
                for(AttachedContentNote acn:inv.AttachedContentNotes){
                    allContentDocIds.add(acn.Id);
                }

                if(!allContentDocIds.isEmpty()){
                    for(ContentVersion cv : [select id, ContentDocumentId,versiondata from Contentversion where ContentDocumentId IN :allContentDocIds AND IsLatest=true]){
                        Blob cvBody =cv.VersionData;
                        String cvAsString= cvBody.toString().stripHtmlTags();
                        contentMap.put(cv.ContentDocumentId, cvAsString);
                    }
                }

                for(AttachedContentNote acn:inv.AttachedContentNotes){   
                    NoteItem ni = new NoteItem();       
                    ni.title = acn.Title;
                    ni.createdDate = acn.CreatedDate.format('MM/dd/yyyy');          
                    ni.subject = contentMap.get(acn.Id) != null ? contentMap.get(acn.Id) : acn.TextPreview;
                    notes.add(ni);
                }
            }
        }
    }

    //constructor to get the Investigation__c record
    public InvestigationNotesController(ApexPages.StandardController controller) {
        inv =  (Investigation__c) controller.getRecord();
        Id = inv.Id;
    }

    //Method that can is called from the Visual Force page action attribute
    public PageReference generateInvestigationNotes() {
        // Instanciate Batch for SpringCM upload
        InvestigationNotesBatch batch = new InvestigationNotesBatch(Id);
        Database.executeBatch(batch);

        PageReference pageRef = new PageReference('/'+Id);
        pageRef.setRedirect(true);
        return pageRef; //Returns to the Investigation page
    }

    public class NoteItem{
        public String title { get; set; }
        public String createdDate { get; set; }
        public String subject { get; set; }
    }
}