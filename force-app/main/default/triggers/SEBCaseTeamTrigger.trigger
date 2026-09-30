trigger SEBCaseTeamTrigger on SEBCaseTeam__c(
        before insert,
        after insert,
        before update,
        after update,
        before delete,
        after delete) {
    if (Trigger.isAfter) {
        List<Id> parentSEBCases = new List<Id>();

        if (Trigger.isInsert) {
            for (SEBCaseTeam__c sebTeam : Trigger.new) {
                parentSEBCases.add(sebTeam.SEBCase__c);
            }
        }

        if (Trigger.isUpdate) {
            for (SEBCaseTeam__c sebTeam : Trigger.new) {
                if (sebTeam.Role__c != Trigger.oldMap.get(sebTeam.Id).Role__c) {
                    parentSEBCases.add(sebTeam.SEBCase__c);
                }
            }
        }

        if (Trigger.isDelete) {
            for (SEBCaseTeam__c sebTeam : Trigger.old) {
                parentSEBCases.add(sebTeam.SEBCase__c);
            }
        }

        if (!parentSEBCases.isEmpty()) {
            SEBCaseCurrentTeamSetter.setCurrentTeam(parentSEBCases);
        }
    }
}