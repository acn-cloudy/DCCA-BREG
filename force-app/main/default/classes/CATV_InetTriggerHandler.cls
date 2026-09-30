public with sharing class CATV_InetTriggerHandler {
    public static void afterInsert(List<INET_Request__c> newList){
        String newListJSON = JSON.serialize(newList);
        shareInetApplication(newListJSON);
    }

    public static void beforeUpdate(List<INET_Request__c> newList, Map<Id, INET_Request__c> oldMap){
        User currUser = [SELECT Id, Name, UserRole.DeveloperName, Profile.Name 
                         FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        if(currUser.Profile.Name  == 'CATV Community Profile') {
            validateRecordUpdation(newList, oldMap);
        }
    }

    public static void validateRecordUpdation(List<INET_Request__c> newList, Map<Id, INET_Request__c> oldMap){
        Map<String, Schema.SObjectField> mapFields = Schema.SObjectType.INET_Request__c.fields.getMap();
        List<String> validationFieldsList = new List<String>{'approval_comments__c', 'approval_status__c','completed_date__c','rejection_comments__c','request_date__c','site_name__c','target_date__c','work_completed_date__c'}; 
        
        for(INET_Request__c request : newList){
            if(oldMap.get(request.Id).Status__c == 'Submitted' || oldMap.get(request.Id).Status__c == 'Resubmitted' || oldMap.get(request.Id).Status__c == 'Completed'){
                
                for(String appField : mapFields.keyset()){
                    appField = appField.toLowerCase();
                    if (validationFieldsList.contains(appField) && request.get(appField) != oldMap.get(request.Id).get(appField)) {
                        request.addError('Application cannot be updated in this status');
                        break; 
                    } else {
                        continue;
                    }
                }
            }
        }
    }
    
    @future
    public static void shareInetApplication(String newListJSON){
        Map<Id, List<Id>> accIdToAllContactsMap = new Map<Id, List<Id>>();
        Map<Id, Id> reqIdToRequesterMap = new Map<Id, Id>();
        Map<Id, Id> reqIdToProviderMap = new Map<Id, Id>();
        Map<Id, Id> conIdToUserIdMap = new Map<Id, Id>();
        Set<Id> allAccountIdSet = new Set<Id>();
        Set<Id> allContactSet = new Set<Id>();
        List<INET_Request__Share> shareList = new List<INET_Request__Share>();
        
        List<INET_Request__c> newList = (List<INET_Request__c>) JSON.deserialize(newListJSON, List<INET_Request__c>.class);
        
        for(INET_Request__c req : newList){
            if(req.Requestor__c != null){
                reqIdToRequesterMap.put(req.Id, req.Requestor__c);
            }
            
            if(req.Provider__c != null){
                reqIdToProviderMap.put(req.Id, req.Provider__c);
            }
            
            allAccountIdSet.add(req.Requestor__c);
            allAccountIdSet.add(req.Provider__c);
        }
        
        for(AccountContactRelation acr : CATV_WithoutSharingUtility.fetchAcrRecords(allAccountIdSet)){
            allContactSet.add(acr.ContactId);
            if(!accIdToAllContactsMap.containsKey(acr.AccountId)){
                accIdToAllContactsMap.put(acr.AccountId, new List<Id>());
            }
            accIdToAllContactsMap.get(acr.AccountId).add(acr.ContactId);
        }
        
        for(User u : CATV_WithoutSharingUtility.fetchUserFromContactSet(allContactSet))
        {
            conIdToUserIdMap.put(u.ContactId, u.Id);
        }
        
        for(INET_Request__c req : newList){
            if(!accIdToAllContactsMap.isEmpty()){
                if (accIdToAllContactsMap.containsKey(req.Requestor__c) && accIdToAllContactsMap.get(req.Requestor__c) != null) {
                    for(Id reqConId : accIdToAllContactsMap.get(req.Requestor__c)){
                        if(conIdToUserIdMap.containsKey(reqConId)){
                            INET_Request__Share shareRec = new INET_Request__Share();
                            shareRec.UserOrGroupId = conIdToUserIdMap.get(reqConId);
                            shareRec.ParentId = req.Id;
                            shareRec.AccessLevel = 'Edit';
                            shareRec.RowCause = Schema.INET_Request__Share.RowCause.Requestor__c;                            
                            if(shareRec.UserOrGroupId != NULL){
                                shareList.add(shareRec);
                            }
                        }
                    }
                }
                
                if (accIdToAllContactsMap.containsKey(req.Provider__c) && accIdToAllContactsMap.get(req.Provider__c) != null) {
                    for(Id provConId : accIdToAllContactsMap.get(req.Provider__c)){
                        if(conIdToUserIdMap.containsKey(provConId)){
                            INET_Request__Share shareRec = new INET_Request__Share();
                            shareRec.UserOrGroupId = conIdToUserIdMap.get(provConId);
                            shareRec.ParentId = req.Id;
                            shareRec.AccessLevel = 'Edit';
                            shareRec.RowCause = Schema.INET_Request__Share.RowCause.Provider__c;                            
                            if(shareRec.UserOrGroupId != NULL){
                                shareList.add(shareRec);
                            }
                        }
                    }
                }    
            }
        }
        
        if(!shareList.isEmpty()){
            CATV_WithoutSharingUtility.doInsert(shareList);
        }
    }
}