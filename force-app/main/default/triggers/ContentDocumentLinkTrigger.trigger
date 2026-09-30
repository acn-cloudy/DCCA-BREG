trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert, before update, before delete, after insert, after update, after delete) {


    TriggerFactory.createAndExecuteHandler(ContentDocumentLink.SobjectType);

    // List<ContentDocumentLink> links = trigger.new;
    // Map<String,String> prefix2SobjType = GlobalUtilities.getPrefixToSObjectType();
    // Map<String, String> docusignStatusIdMap = new Map<String, String>();
    // for(ContentDocumentLink link: links) {
    //     String recordId = link.LinkedEntityId;
    //     String sobjectType = prefix2SobjType.get(recordId.substring(0, 3));
    //     if(sobjectType == 'dsfs__docusign_status__c') {
    //         docusignStatusIdMap.put(link.ContentDocumentId, recordId);
    //     }
    // }
    // if(!docusignStatusIdMap.isEmpty()) {
    //     DocusignStatusService.createStatusFiles(docusignStatusIdMap);
    // }

}