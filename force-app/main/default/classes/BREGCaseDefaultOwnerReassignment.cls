public without sharing class BREGCaseDefaultOwnerReassignment {
    private static final String SETTING_DEVELOPER_NAME = 'Case_owner_for_reassignment';
    private static Boolean isRunning = false;

    public static void reassignFromDefaultOwner(List<Case> newCases, Map<Id, Case> oldMap) {
        if (isRunning || newCases == null || newCases.isEmpty()) {
            return;
        }

        BREG_Case_Owner_Reassignment__mdt setting =
            BREG_Case_Owner_Reassignment__mdt.getInstance(SETTING_DEVELOPER_NAME);

        if (
            setting == null ||
            String.isBlank(setting.breg_Case_Owner_Name__c) ||
            String.isBlank(setting.breg_Target_Queue_Developer_Name__c)
        ) {
            return;
        }

        List<User> defaultOwners = [
            SELECT Id
            FROM User
            WHERE Name = :setting.breg_Case_Owner_Name__c
            AND IsActive = true
            LIMIT 1
        ];

        if (defaultOwners.isEmpty()) {
            return;
        }

        List<Group> targetQueues = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = :setting.breg_Target_Queue_Developer_Name__c
            LIMIT 1
        ];

        if (targetQueues.isEmpty()) {
            return;
        }

        Id defaultCaseOwnerId = defaultOwners[0].Id;
        Id bregAdminQueueId = targetQueues[0].Id;

        List<Case> casesToUpdate = new List<Case>();

        for (Case c : newCases) {
            if (c == null || c.Id == null || c.OwnerId == null) {
                continue;
            }

            Boolean ownerChanged =
                oldMap == null ||
                !oldMap.containsKey(c.Id) ||
                oldMap.get(c.Id).OwnerId != c.OwnerId;

            if (
                ownerChanged &&
                c.OwnerId == defaultCaseOwnerId &&
                c.OwnerId != bregAdminQueueId
            ) {
                casesToUpdate.add(new Case(
                    Id = c.Id,
                    OwnerId = bregAdminQueueId
                ));
            }
        }

        if (!casesToUpdate.isEmpty()) {
            isRunning = true;
            update casesToUpdate;
            isRunning = false;
        }
    }

    public static void enqueueReassignment(List<Case> newCases) {
        Set<Id> caseIds = new Set<Id>();

        for (Case c : newCases) {
            if (c != null && c.Id != null) {
                caseIds.add(c.Id);
            }
        }

        if (!caseIds.isEmpty()) {
            System.enqueueJob(new ReassignmentQueueable(caseIds));
        }
    }

    private class ReassignmentQueueable implements Queueable {
        private Set<Id> caseIds;

        private ReassignmentQueueable(Set<Id> caseIds) {
            this.caseIds = caseIds;
        }

        public void execute(QueueableContext context) {
            List<Case> casesToCheck = [
                SELECT Id, OwnerId
                FROM Case
                WHERE Id IN :caseIds
            ];

            BREGCaseDefaultOwnerReassignment.reassignFromDefaultOwner(casesToCheck, null);
        }
    }
}