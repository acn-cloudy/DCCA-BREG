public inherited sharing class CaseTeamAssignmentService {
    
    public static final CaseTeamAssignmentService INSTANCE = (CaseTeamAssignmentService)fflibe_Applicationimpl.SERVICE.newInstance(CaseTeamAssignmentService.class);

    @TestVisible
    static final string ERROR_DUPLICATE_USER = 'Cannot add the same User multiple times to the same Case';
    @TestVisible
    static final string ERROR_EXISTING_USER = 'This User is already part of the Case Team';

    /**
     * @description called before insert/update of a CTA. This method makes sure that there aren't duplicate users in the newList, 
     *              and that no users get through that are already a part of the case team.
     * @param  newList      Trigger.new
     * @param  existingCTAs CaseTeamAssignment__c records that already exist for a PUC Case Team
     * @param  oldMap       Trigger.oldMap
     */
    public void validateCTAs(CaseTeamAssignment__c[] newList, Map<Id, CaseTeamAssignment__c> oldMap) {
        CaseTeamAssignment__c[] existingCTAs = CaseTeamAssignmentsSelector.INSTANCE.selectByUserAndCase(SObjectUtil.getSetIds(newList, 'User__c'),SObjectUtil.getSetIds(newList, 'Case__c'));
        Map<String, CaseTeamAssignment__c> newCtaMap = new Map<String, CaseTeamAssignment__c>();
        for (CaseTeamAssignment__c cta : newList) {
            if (oldMap?.get(cta.Id).User__c == cta.User__c) { // user didn't change in update, so don't worry about this one
                continue;
            }
            String key = getUniqueIdentifier(cta);
            if (newCtaMap.containsKey(key)) {
                cta.addError(ERROR_DUPLICATE_USER);
            } else {
                newCtaMap.put(key, cta);
            }
        }
        for (CaseTeamAssignment__c existingCTA : existingCTAs) {
            newCtaMap.get(getUniqueIdentifier(existingCTA))?.addError(ERROR_EXISTING_USER);
        }
    }

    public CaseTeamAssignmentService addCaseShareRecords(CaseTeamAssignment__c[] caseTeamAssignments, fflib_SObjectUnitOfWork uow) {

        CaseShare[] shares = new List<CaseShare>();
        for (CaseTeamAssignment__c cta : caseTeamAssignments) {
            uow.registerNew(new CaseShare(
                CaseAccessLevel = cta.Access__c,
                CaseId = cta.Case__c,
                //RowCause = 'Case_Team__c',
                UserOrGroupId = cta.User__c
            ));
        }

        return this;
    }
    public CaseTeamAssignmentService updateCaseShareRecords(CaseTeamAssignment__c[] caseTeamAssignments, fflib_SObjectUnitOfWork uow) {
        Map<String, CaseShare> caseShares = new Map<String, CaseShare>();
        for(CaseShare share : CaseSharesSelector.INSTANCE.getSharesByParentAndOwnerIds(SObjectUtil.getSetIds(caseTeamAssignments, 'Case'), SObjectUtil.getSetIds(caseTeamAssignments, 'User__c'))) {
            caseShares.put(share.CaseId + '|' + share.UserOrGroupId, share);
        }
        CaseShare[] shares = new List<CaseShare>();
        for (CaseTeamAssignment__c cta : caseTeamAssignments) {
            String key = cta.Case__c + '|' + cta.User__c;
            if(!caseShares.containsKey(key)) continue;
            uow.registerDirty(new CaseShare(
                Id = caseShares.get(key).Id,
                CaseAccessLevel = cta.Access__c
            ));
        }
        return this;
    }

    /**
     * @description When a CaseTeamAssignment__c record is deleted, call this method to get the share records tied to the deleted record, so that the shares can be deleted.
     * @param  oldList        Trigger.old
     * @param  oldListCaseIds Set of CaseTeamAssignment__c.PUC_Case__c from oldList
     * @param  oldListUserIds Set of CaseTeamAssignment__c.User__c from oldList
     */
    public void removeShareRecords(CaseTeamAssignment__c[] caseTeamAssignments, fflib_SObjectUnitOfWork uow) {
        CaseShare[] shares = new List<CaseShare>();
        Map<String, CaseTeamAssignment__c> ctaUniqueIdentifiers = new Map<String, CaseTeamAssignment__c>();
        for (CaseTeamAssignment__c cta : caseTeamAssignments) {
            ctaUniqueIdentifiers.put(getUniqueIdentifier(cta), cta);
        }
        for (CaseShare s : CaseSharesSelector.INSTANCE.getSharesByParentAndOwnerIds(SObjectUtil.getSetIds(caseTeamAssignments, 'Case'), SObjectUtil.getSetIds(caseTeamAssignments, 'User__c'))) {
            String key = '' + s.CaseId + s.UserOrGroupId;
            if (ctaUniqueIdentifiers.containsKey(key) && ctaUniqueIdentifiers.get(key).User__c != s.Case.OwnerId) {
                shares.add(s);
            }
        }
        uow.registerDeleted(shares);
    }

    // No user can be on the same case twice, so concatenating the Case Id and User Id is a unique value for each CTA record
    public String getUniqueIdentifier(CaseTeamAssignment__c cta) {
        return '' + cta.Case__c + cta.User__c;
    }
}
// TEST CLASS: CaseTeamAssignmentHandlerTest