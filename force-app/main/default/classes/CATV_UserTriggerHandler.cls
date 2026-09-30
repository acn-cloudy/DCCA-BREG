public with sharing class CATV_UserTriggerHandler {
	public static void afterInsert(List<User> newList){
        addUserToGroup(newList, null);
        assignUserPermission(newList, null);
    }
    
    public static void afterUpdate(List<User> newList, Map<Id, User> oldMap){
        assignUserPermission(newList, oldMap);
    }
    
    public static void addUserToGroup(List<User> newList, Map<Id, User> oldMap){
        List<User> allPortalUser = new List<User>();
        List<GroupMember> memberList = new List<GroupMember>();
        Set<Id> allConIdSet = new Set<Id>();
        Set<Id> allCatvConSet = new Set<Id>();
            
        Map<Id, UserRole> roleMap = new Map<Id, UserRole>([SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName IN ('CATV_Staff_Admin', 'CATV_Staff_Read_Only', 'CATV_Staff_Reviewer')]);
        Id internalGroupId = [SELECT Id FROM Group WHERE DeveloperName = 'CATV_Internal_Staff'].Id;
        Id portalGroupId = [SELECT Id FROM Group WHERE DeveloperName = 'CATV_Portal_User'].Id;
        
        for(User u : newList){
            if(u.ContactId != null){
                allPortalUser.add(u);
                allConIdSet.add(u.ContactId);
            }else if(roleMap.keySet().contains(u.UserRoleId)){
                GroupMember member = new GroupMember();
                member.UserOrGroupId = u.Id;
                member.GroupId = internalGroupId;
                memberList.add(member);
            }
        }
        
        for(Contact con : [SELECT Id, Type__c FROM Contact WHERE Id IN :allConIdSet AND Type__c IN ('Requestor', 'Provider')]){
            allCatvConSet.add(con.Id);
        }
        
        for(User u : allPortalUser){
            if(allCatvConSet.contains(u.ContactId)){
                GroupMember member = new GroupMember();
                member.UserOrGroupId = u.Id;
                member.GroupId = portalGroupId;
                memberList.add(member);
            }
        }
        
        if(!memberList.isEmpty()){
            insertGroupAssignment(JSON.serialize(memberList));
        }
        
    }
    
    public static void assignUserPermission(List<User> newList, Map<Id, User> oldMap){
        Map<Id, UserRole> roleMap = new Map<Id, UserRole>([SELECT Id, DeveloperName FROM UserRole WHERE DeveloperName IN ('CATV_Staff_Admin', 'CATV_Staff_Read_Only', 'CATV_Staff_Reviewer')]);
		Set<Id> internalUserIdSet = new Set<Id>();
        Set<Id> permSetDeleteUserSet = new Set<Id>();
        Map<String, Id> psMap = new Map<String, Id>();
        List<PermissionSetAssignment> psInsertList = new List<PermissionSetAssignment>();
        
        for(User u : newList){
            if((oldMap == null || (u.UserRoleId != oldMap.get(u.Id).UserRoleId)) && roleMap.keySet().contains(u.UserRoleId) ){
                internalUserIdSet.add(u.Id);
            }
            if(oldMap != null && roleMap.keySet().contains(u.UserRoleId) && (u.UserRoleId != oldMap.get(u.Id).UserRoleId)){
                permSetDeleteUserSet.add(u.Id);
            }
        }
        
        if(!permSetDeleteUserSet.isEmpty()){
            List<PermissionSetAssignment> psDeleteList = [SELECT Id FROM PermissionSetAssignment 
                                                          WHERE AssigneeId IN :permSetDeleteUserSet
                                                          AND PermissionSet.Name IN ('Internal_CATV_Staff_Admin', 'Internal_CATV_Staff_Reviewer', 'Internal_CATV_Staff_Read_Only')];
            CATV_WithoutSharingUtility.doDelete(psDeleteList);
        }
        
        for(PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name IN ('Internal_CATV_Staff_Admin', 'Internal_CATV_Staff_Reviewer', 'Internal_CATV_Staff_Read_Only')]){
            psMap.put(ps.Name, ps.Id);
        }
        
        for(User u : [SELECT Id, UserRole.DeveloperName FROM User WHERE Id IN :internalUserIdSet]){
            PermissionSetAssignment psa;
            if(u.UserRole.DeveloperName == 'CATV_Staff_Admin'){
                psa = new PermissionSetAssignment(PermissionSetId = psMap.get('Internal_CATV_Staff_Admin'), AssigneeId = u.Id );
            }else if(u.UserRole.DeveloperName == 'CATV_Staff_Read_Only'){
                psa = new PermissionSetAssignment(PermissionSetId = psMap.get('Internal_CATV_Staff_Read_Only'), AssigneeId = u.Id );
            }else if(u.UserRole.DeveloperName == 'CATV_Staff_Reviewer'){
                psa = new PermissionSetAssignment(PermissionSetId = psMap.get('Internal_CATV_Staff_Reviewer'), AssigneeId = u.Id );
            }
            
            if(psa != null){
                psInsertList.add(psa);
            }
        }
        
        if(!psInsertList.isEmpty()){
            insertPermAssignment(JSON.serialize(psInsertList));
        }
    }
    
    @future
    private static void insertGroupAssignment(String inputJson){
        List<GroupMember> memberList = (List<GroupMember>) JSON.deserialize(inputJson, List<GroupMember>.class);
        insert memberList;
    }
    
    @future
    private static void insertPermAssignment(String inputJson){
        List<PermissionSetAssignment> assignmentList = (List<PermissionSetAssignment>) JSON.deserialize(inputJson, List<PermissionSetAssignment>.class);
        insert assignmentList;
    }
}