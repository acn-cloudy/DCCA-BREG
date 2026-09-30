@IsTest
private class BREGCaseDefaultOwnerReassignmentTest {
    @IsTest
    static void enqueueReassignment_shouldMoveCaseToTargetQueue() {
        BREG_Case_Owner_Reassignment__mdt setting =
            BREG_Case_Owner_Reassignment__mdt.getInstance('Case_owner_for_reassignment');

        User defaultOwner = [
            SELECT Id
            FROM User
            WHERE Name = :setting.breg_Case_Owner_Name__c
            AND IsActive = true
            LIMIT 1
        ];

        Group targetQueue = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = :setting.breg_Target_Queue_Developer_Name__c
            LIMIT 1
        ];

        Case c = new Case(
            Subject = 'Test default owner reassignment',
            Status = 'New',
            Origin = 'Web',
            OwnerId = defaultOwner.Id
        );
        insert c;

        Test.startTest();
        BREGCaseDefaultOwnerReassignment.enqueueReassignment(new List<Case>{ c });
        Test.stopTest();

        c = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(targetQueue.Id, c.OwnerId);
    }

    @IsTest
    static void reassignFromDefaultOwner_shouldSkipWhenOwnerDidNotChange() {
        BREG_Case_Owner_Reassignment__mdt setting =
            BREG_Case_Owner_Reassignment__mdt.getInstance('Case_owner_for_reassignment');

        User defaultOwner = [
            SELECT Id
            FROM User
            WHERE Name = :setting.breg_Case_Owner_Name__c
            AND IsActive = true
            LIMIT 1
        ];

        Case c = new Case(
            Subject = 'Test skip default owner reassignment',
            Status = 'New',
            Origin = 'Web',
            OwnerId = defaultOwner.Id
        );
        insert c;

        Map<Id, Case> oldMap = new Map<Id, Case>{
            c.Id => new Case(
                Id = c.Id,
                OwnerId = defaultOwner.Id
            )
        };

        Test.startTest();
        BREGCaseDefaultOwnerReassignment.reassignFromDefaultOwner(
            new List<Case>{ c },
            oldMap
        );
        Test.stopTest();

        c = [
            SELECT OwnerId
            FROM Case
            WHERE Id = :c.Id
        ];

        System.assertEquals(defaultOwner.Id, c.OwnerId);
    }
}