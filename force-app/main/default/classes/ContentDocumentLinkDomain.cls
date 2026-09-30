public class ContentDocumentLinkDomain extends SobjectDomain{
    public ContentDocumentLinkDomain(List<ContentDocumentLink> links) {
        super(links);
    }
    public void captureError(Map<String, String> fileIdErrors) {
        for(ContentDocumentLink record: (List<ContentDocumentLink>)records) {
            if(fileIdErrors.containsKey(record.LinkedEntityId)) {
                record.addError(fileIdErrors.get(record.LinkedEntityId));
            }
        }
    }

    public Map<String, String> convertContentId2Error(Map<String, String> fileIdErrors ) {
        Map<String, String> contentId2Error = new Map<String, String>();
        for(ContentDocumentLink record: (List<ContentDocumentLink>) records) {
            if(fileIdErrors.containsKey(record.linkedEntityId) ) {
                contentId2Error.put(record.ContentDocumentId, fileIdErrors.get(record.linkedEntityId));
            }
        }
        return contentId2Error;
    }

    public List<String> getFileDetailIds () {
        List<String> fileDetailIds = new List<String>();
        for(ContentDocumentLink record: (List<ContentDocumentLink>) records) {
            String recordId = record.LinkedEntityId;
            String sobjectType = GlobalUtilities.getPrefixObjMap().get(recordId.substring(0, 3));
            if(sobjectType == GlobalConstants.FILEDETAILS) {
                fileDetailIds.add(record.LinkedEntityId);
            }
        }
        return fileDetailIds;
    }
}