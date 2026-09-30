public with sharing class CATV_AccessRequestController {
    @AuraEnabled
    public static void checkRequestForValidation(String obj){
        obj = String.escapeSingleQuotes(obj);
        
        Map<String, object> field = (Map<String, object>) JSON.deserializeUntyped(obj);
        String accountAccessRequestId = (String)field.get('recordId');
        
        Account_Access_Request__c existingAccountAccessReq = [SELECT Id, Contact__c, Account__c, Status__c
                                                                FROM Account_Access_Request__c
                                                                WHERE Id = :accountAccessRequestId 
                                                                WITH USER_MODE];

        if(existingAccountAccessReq.Status__c != 'Pending'){
            throw new AuraHandledException('Request already approved/rejected.');
        }
    }

    @AuraEnabled
    public static void handleRequestAction(String obj){
        obj = String.escapeSingleQuotes(obj);

        Map<String, object> field = (Map<String, object>) JSON.deserializeUntyped(obj);
        String accountAccessRequestId = (String)field.get('recordId');
        String comments = (String)field.get('comments');
        String targetAction = (String)field.get('targetAction');
        String conId, accId;

        Account_Access_Request__c existingAccountAccessReq = [SELECT Id, Contact__c, Account__c, Status__c,
                                                                Contact_Email__c, Contact__r.Type__c,
                                                                Contact__r.FirstName, Contact__r.LastName,
                                                                Contact__r.MiddleName, Contact__r.Phone,
                                                                Contact__r.Title, Contact__r.Suffix
                                                                FROM Account_Access_Request__c
                                                                WHERE Id = :accountAccessRequestId 
                                                                WITH SECURITY_ENFORCED];
        conId = existingAccountAccessReq.Contact__c;
        accId = existingAccountAccessReq.Account__c;

        List<AccountContactRelation> accConRelationship = [SELECT Id, ContactId, AccountId
                                                            FROM AccountContactRelation 
                                                            WHERE ContactId = :conId
                                                            AND AccountId = :accId];

        if(existingAccountAccessReq.Status__c != 'Pending'){
            throw new AuraHandledException('Request already approved/rejected.');
        }
        
        Account_Access_Request__c accountAccessRequest = new Account_Access_Request__c();
        accountAccessRequest.Id = accountAccessRequestId;

        if(targetAction == 'approveAction'){
            accountAccessRequest.Status__c = 'Approved';

            if(accConRelationship == null || accConRelationship.isEmpty()){
                Contact conUpdate = new Contact(Id = conId);
                conUpdate.AccountId = accId;
                update as user conUpdate;
            }

            List<User> userList = CATV_WithoutSharingUtility.fetchUserFromContactId(conId);
            
            if(userList.isEmpty()){
                Map<Id, Id> accIdToConIdMap = new Map<Id, Id>();

                accIdToConIdMap.put(accId, conId);
                Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'CATV Community Profile' LIMIT 1];

                String nickname = ((existingAccountAccessReq.Contact__r.FirstName != null && existingAccountAccessReq.Contact__r.FirstName.length() > 0) ? existingAccountAccessReq.Contact__r.FirstName.substring(0,1) : '' ) + existingAccountAccessReq.Contact__r.LastName.substring(0,1);
                nickname += String.valueOf(Crypto.getRandomInteger()).substring(1,7);
                    
                User communityUser = new User(
                    UserName = existingAccountAccessReq.Contact_Email__c,
                    FirstName = existingAccountAccessReq.Contact__r.FirstName,
                    LastName = existingAccountAccessReq.Contact__r.LastName,
                    MiddleName = existingAccountAccessReq.Contact__r.MiddleName,
                    Phone = existingAccountAccessReq.Contact__r.Phone,
                    Suffix = existingAccountAccessReq.Contact__r.Suffix,
                    Alias = nickname,
                    email = existingAccountAccessReq.Contact_Email__c,
                    ContactId = conId,
                    ProfileId = portalProfile.Id,
                    EmailEncodingKey = 'UTF-8',
                    TimeZoneSidKey = 'Pacific/Honolulu',
                    LocaleSidKey = 'en_US',
                    LanguageLocaleKey = 'en_US'
                );
                CATV_WithoutSharingUtility.doInsert(communityUser);

                shareInetRecordWithUser(accIdToConIdMap, communityUser.Id, existingAccountAccessReq.Contact__r.Type__c);
                addUserToCommunityPermissionSet(communityUser.Id, existingAccountAccessReq.Contact__r.Type__c);
            }
        } else if(targetAction == 'rejectAction'){
            accountAccessRequest.Status__c = 'Rejected';
        }

        accountAccessRequest.Comments__c = comments;
        update as user accountAccessRequest;

        sendRequestEmail(targetAction, existingAccountAccessReq.Contact_Email__c, conId, existingAccountAccessReq.Id);
    }

    private static void shareInetRecordWithUser(Map<Id, Id> accIdToConIdMap, String userId, String type){
        List<INET_Request__c> inetList = new List<INET_Request__c>();
        List<INET_Request__Share> shareList = new List<INET_Request__Share>();
        
        if (type == 'Requestor') {
            inetList = [SELECT Id, Requestor__c, Provider__c FROM INET_Request__c WHERE Requestor__c IN :accIdToConIdMap.keySet()];
        } else if(type == 'Provider'){
            inetList = [SELECT Id, Requestor__c, Provider__c FROM INET_Request__c WHERE Provider__c IN :accIdToConIdMap.keySet()];
        }

        if(!inetList.isEmpty()){
            for(INET_Request__c req : inetList){
                INET_Request__Share shareRec = new INET_Request__Share();
                shareRec.UserOrGroupId = userId;
                shareRec.ParentId = req.Id;
                shareRec.AccessLevel = 'Edit';
                shareRec.RowCause = type == 'Requestor' ? Schema.INET_Request__Share.RowCause.Requestor__c : Schema.INET_Request__Share.RowCause.Provider__c;                            
                if(shareRec.UserOrGroupId != NULL){
                    shareList.add(shareRec);
                }
            }
        }

        if(!shareList.isEmpty()){
            CATV_WithoutSharingUtility.doInsert(shareList);
        }
    }

    private static void sendRequestEmail(String targetAction, String contactEmail, String conId, String reqId){
        OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'DCCA CATV' LIMIT 1];
        EmailTemplate accountAccessApproveTemplate = [SELECT Id FROM EmailTemplate 
                                                      WHERE DeveloperName = 'Account_Access_Request_Approved'];
        EmailTemplate accountAccessRejectTemplate = [SELECT Id FROM EmailTemplate 
                                                     WHERE DeveloperName = 'Account_Access_Request_Rejected'];

        List<Messaging.SingleEmailMessage> emailMessageList = new List<Messaging.SingleEmailMessage>();

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 

        if (targetAction == 'approveAction') {
            email.setTemplateId(accountAccessApproveTemplate.Id);
        } else if(targetAction == 'rejectAction') {
            email.setTemplateId(accountAccessRejectTemplate.Id);
        }

        email.setToAddresses(new List<String>{contactEmail});
        email.setOrgWideEmailAddressId(owea.Id);
        email.setTargetObjectId(conId);
        email.setTreatTargetObjectAsRecipient(false);
        email.setWhatId(reqId);
        email.setSaveAsActivity(true);
        emailMessageList.add(email);
        Messaging.SendEmailResult[] results = Messaging.sendEmail(emailMessageList);
    }

    @future
    public static void addUserToCommunityPermissionSet(Id userId, String type){
        Set<String> permissionSetNameSet = new Set<String>();
        
        if (type == 'Requestor') {
            permissionSetNameSet.add('External_CATV_Requestor');
        } else if(type == 'Provider'){
            permissionSetNameSet.add('External_CATV_Provider');
        }

        List<PermissionSet> permissionSetList = [SELECT Id, Name FROM PermissionSet WHERE Name IN :permissionSetNameSet];
        List<PermissionSetAssignment> psAssignmentList = new List<PermissionSetAssignment>();
        
        for(PermissionSet permissionSet : permissionSetList){
            psAssignmentList.add(new PermissionSetAssignment
            (PermissionSetId = permissionSet.Id, AssigneeId = userId));
        }
            
        CATV_WithoutSharingUtility.doInsert(psAssignmentList);
    }
}