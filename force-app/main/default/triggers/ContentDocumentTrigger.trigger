trigger ContentDocumentTrigger on ContentDocument (before delete) {
    
    If(trigger.isBefore && trigger.isDelete) {
        List<String> recordIds = new List<String>();
        for(ContentDocument record: Trigger.old) {
            recordIds.add(record.Id);
        }
        //
        List<ContentDocumentLink> links = [Select Id, ContentDocumentId, LinkedEntityId from ContentDocumentLink where ContentDocumentId=: recordIds];
        List<String> fileDetailIds = ContentDocumentLinkService.captureInvalidCapture(links);
        if(!fileDetailIds.isEmpty()) {
            // Convert to linkedEntity Id => errors 
            Map<String, String> fileIdErrors 
                    = FileDetailService.checkFilePermissions(fileDetailIds);
            
            Map<String, String> contentId2Error = (new ContentDocumentLinkDomain(links)).convertContentId2Error(fileIdErrors);
            for(ContentDocument document: Trigger.old) {
                if(contentId2Error.containsKey(document.Id)) {
                    document.addError(contentId2Error.get(document.Id));
                }
            }
            
        }
        
    }


}