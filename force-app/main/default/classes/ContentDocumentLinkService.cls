public class ContentDocumentLinkService {
    
    
    private static Map<String, String> docusignStatusIdMap = new Map<String, String>();
    public static List<String> fileDetailIds = new List<String>();
    
    public static List<String> captureInvalidCapture(List<SObject> records) {
        fileDetailIds = (new ContentDocumentLinkDomain(records)).getFileDetailIds();
        return fileDetailIds;
    }


    public static void captureDocusignStatusIdMap(SObject so) {
        ContentDocumentLink record = (ContentDocumentLink) so;
        String recordId = record.LinkedEntityId;
        String sobjectType = GlobalUtilities.getPrefixObjMap().get(recordId.substring(0, 3));
        if(sobjectType == GlobalConstants.DOCUSIGNSTATUS) {
            docusignStatusIdMap.put(record.ContentDocumentId, record.LinkedEntityId);
        }
        
    }

    public static void runFinally() {
        if(Trigger.isBefore) {
            List<ContentDocumentLink> records = new List<ContentDocumentLink>();
            if(Trigger.isInsert) {
                records = trigger.new;
            } else if(Trigger.isDelete) {
                records = trigger.old;
            }
            
            if(!fileDetailIds.isEmpty()) {
                
                // check for the file Id to Error 
                Map<String, String> fileIdErrors 
                    = FileDetailService.checkFilePermissions(fileDetailIds);
                fileDetailIds.clear();
                (new ContentDocumentLinkDomain(records)).captureError(fileIdErrors);
            }
        }
        if(Trigger.isAfter) {
            if(!docusignStatusIdMap.isEmpty()) {
                DocusignStatusService.createStatusFiles(docusignStatusIdMap);
                docusignStatusIdMap.clear();
            }
        }
    }
    
}