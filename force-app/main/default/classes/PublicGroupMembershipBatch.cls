global class PublicGroupMembershipBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    // Custom metadata type for mapping public groups to permission sets
    public class PublicGroupPermissionMapping {
        public String PublicGroupDevName;
        public String PermissionSetDevName;
    }

    Set<String> groupDeveloperNames; // Declare the variable here

    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Query for the custom metadata type records containing the mappings
        PublicGroupPermissionMapping__mdt[] mappings = 
            [SELECT PublicGroupDevName__c, PermissionSetDevName__c
            FROM PublicGroupPermissionMapping__mdt
        ];

        // Convert the mappings to a map for efficient lookups
        Map<String, String> publicGroupToPermissionSetMap = new Map<String, String>();
        for (PublicGroupPermissionMapping__mdt mapping : mappings) {
            publicGroupToPermissionSetMap.put(mapping.PublicGroupDevName__c, mapping.PermissionSetDevName__c);
        }

        // Set the variable with the developer names
        groupDeveloperNames = publicGroupToPermissionSetMap.keySet();

        // Query for all Group records with the specific Public Group Dev Names
        String query = 'SELECT Id, DeveloperName, Type FROM Group WHERE DeveloperName IN :groupDeveloperNames AND Type' ;
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Group> groupAssignments = (List<Group>) scope;
        List<PermissionSetAssignment> permissionSetAssignmentsToUpdate = new List<PermissionSetAssignment>();

        // Fetch the mapping between public groups and permission sets
        Map<String, String> publicGroupToPermissionSetMap = new Map<String, String>();
        for (PublicGroupPermissionMapping__mdt mapping : [
            SELECT PublicGroupDevName__c, PermissionSetDevName__c
            FROM PublicGroupPermissionMapping__mdt
            WHERE PublicGroupDevName__c IN :groupDeveloperNames
        ]) {
            publicGroupToPermissionSetMap.put(mapping.PublicGroupDevName__c, mapping.PermissionSetDevName__c);
        }

        for (Group assignment : groupAssignments) {
            String permissionSetDevName = publicGroupToPermissionSetMap.get(assignment.DeveloperName);

            if (permissionSetDevName != null) {
                // Check if user is added to or removed from the public group
                if (assignment.Type == 'Regular') {
                    // Add Permission Set assignment
                    permissionSetAssignmentsToUpdate.add(new PermissionSetAssignment(
                        AssigneeId = assignment.Id,
                        PermissionSetId = permissionSetDevName
                    ));
                } else if (assignment.Type == 'Regular' && assignment.DeveloperName != null) {
                    // Remove Permission Set assignment if user is removed from the public group
                    permissionSetAssignmentsToUpdate.add(new PermissionSetAssignment(
                        Id = null, // This will be set to the correct Id in the next step
                        AssigneeId = assignment.Id,
                        PermissionSetId = null // Set PermissionSetId to null to remove the assignment
                    ));
                }
            }
        }

        // Update the Permission Set assignments based on the changes
        if (!permissionSetAssignmentsToUpdate.isEmpty()) {
            upsert permissionSetAssignmentsToUpdate;
        }
    }

    global void finish(Database.BatchableContext BC) {
        // 
    }
}