trigger CATV_UserTrigger on User (after insert, after update) {

    String targetProfile = 'CATV Community Profile';

    List<Profile> profiles = [
        SELECT Id
        FROM Profile
        WHERE Name = :targetProfile
        LIMIT 1
    ];

    if (profiles.isEmpty()) {
        return;
    }

    Id catvProfileId = profiles[0].Id;

    List<User> catvUsers = new List<User>();

    for (User u : Trigger.new) {
        if (u.ProfileId == catvProfileId) {
            catvUsers.add(u);
        }
    }

    if (catvUsers.isEmpty()) {
        return;
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CATV_UserTriggerHandler.afterInsert(catvUsers);
        }

        if (Trigger.isUpdate) {
            CATV_UserTriggerHandler.afterUpdate(catvUsers, Trigger.oldMap);
        }
    }
}