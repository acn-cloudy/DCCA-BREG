global class PublicGroupMembershipScheduled implements Schedulable {
    global void execute(SchedulableContext ctx) {
        this.execute();
    }
    
    @testVisible
    private void execute(){
         Map<String, String> groupToPermissionSetMap = new Map<String, String>();
        Map<Id, String> userIdToGroupMap = new Map<Id, String>();
        Set<Id> currentGroupMemberUserIds = new Set<Id>();

        // Retrieve all mappings from Custom Metadata
        List<PublicGroupPermissionMapping__mdt> mappings = [
            SELECT PublicGroupDevName__c, PermissionSetDevName__c 
            FROM PublicGroupPermissionMapping__mdt
        ];

        // Populate Group Name to Permission Set Name mapping
        for (PublicGroupPermissionMapping__mdt mapping : mappings) {
            groupToPermissionSetMap.put(mapping.PublicGroupDevName__c, mapping.PermissionSetDevName__c);
        }

        // Retrieve all Groups based on mappings
        List<Group> groups = [
            SELECT Id, DeveloperName 
            FROM Group 
            WHERE DeveloperName IN :groupToPermissionSetMap.keySet()
        ];

        // Map of Group Developer Name to Group ID for lookup
        Map<String, Id> groupNameToGroupId = new Map<String, Id>();
        for (Group grp : groups) {
            groupNameToGroupId.put(grp.DeveloperName, grp.Id);
        }

        // Retrieve current group members for relevant groups
        List<GroupMember> groupMembers = [
            SELECT UserOrGroupId, Group.DeveloperName 
            FROM GroupMember 
            WHERE GroupId IN :groupNameToGroupId.values()
        ];

        for (GroupMember member : groupMembers) {
            userIdToGroupMap.put(member.UserOrGroupId, member.Group.DeveloperName);
            currentGroupMemberUserIds.add(member.UserOrGroupId);
        }
        

        // Retrieve all users with permission sets linked to the groups in mappings
        List<PermissionSetAssignment> allAssignments = [
            SELECT Id, AssigneeId, PermissionSetId, PermissionSet.Name 
            FROM PermissionSetAssignment 
            WHERE PermissionSet.Name IN :groupToPermissionSetMap.values()
        ];

        // Prepare lists for insert and delete
        List<PermissionSetAssignment> assignmentsToAdd = new List<PermissionSetAssignment>();
        List<PermissionSetAssignment> assignmentsToRemove = new List<PermissionSetAssignment>();

        Map<Id, PermissionSetAssignment> userIdToPermissionSetAssignmentMap = new Map<Id, PermissionSetAssignment>();
        for (PermissionSetAssignment assignment : allAssignments) {
            userIdToPermissionSetAssignmentMap.put(assignment.AssigneeId, assignment);
        }

        // Assign permission sets to users based on current group memberships
        for (Id userId : userIdToGroupMap.keySet()) {
            String groupName = userIdToGroupMap.get(userId);
            String permissionSetDevName = groupToPermissionSetMap.get(groupName);

            if (!userIdToPermissionSetAssignmentMap.containsKey(userId)) {
                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetDevName LIMIT 1];
                PermissionSetAssignment newAssignment = new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
                assignmentsToAdd.add(newAssignment);
            }
        }

        // Identify permission sets to remove if user is not in the corresponding group anymore
        for (PermissionSetAssignment assignment : allAssignments) {
            if (!currentGroupMemberUserIds.contains(assignment.AssigneeId) || 
                !groupToPermissionSetMap.values().contains(assignment.PermissionSet.Name)) {
                assignmentsToRemove.add(assignment);
            }
        }

        // Apply changes
        if (!assignmentsToAdd.isEmpty()) {
            insert assignmentsToAdd;
        }
        if (!assignmentsToRemove.isEmpty()) {
            delete assignmentsToRemove;
        }
    }
}