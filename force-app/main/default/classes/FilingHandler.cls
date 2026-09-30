/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: FilingHandlerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL11122021 - Created for Phase #
 * -----------------------------------------------------------------------------------
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/12/2021
 * __________________________________________________________________________________
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class FilingHandler implements ITrigger{
    public void bulkBefore() {
        if (Trigger.isUpdate) {
            List<Filing__c> forEditValidation = new List<Filing__c>();
            for (Filing__c f : (List<Filing__c>)Trigger.new) {
                Filing__c oldFiling = (Filing__c) Trigger.oldMap.get(f.Id);
                // Skip the record if skip for the validation
                if(f.FlagToSkipValidation__c != oldFiling.FlagToSkipValidation__c) {
                    continue;
                }
                //don't validate when the reviewer is populated
                if (f.Reviewer__c != null && oldFiling.Reviewer__c == null) {
                    f.SkipReviewerEditValidation__c = true;
                    forEditValidation.add(f);
                    continue;
                }

                //allow current reviewer to blank the reviewer field
                if (f.Reviewer__c == null && oldFiling.Reviewer__c != null) {
                    forEditValidation.add(oldFiling);
                    continue;
                }

                //allow current reviewer to assign new reviewer
                if (f.Reviewer__c != null && oldFiling.Reviewer__c != null &&
                                oldFiling.Reviewer__c != f.Reviewer__c &&
                                UserInfo.getUserId() == oldFiling.Reviewer__c) {
                    f.SkipReviewerEditValidation__c = true;
                    forEditValidation.add(f);
                    continue;
                }

                //don't allow currently logged in user to change reviewer to themselves
                if (f.Reviewer__c != null &&
                                oldFiling.Reviewer__c != null &&
                                oldFiling.Reviewer__c != f.Reviewer__c &&
                                f.Reviewer__c == UserInfo.getUserId()) {
                    forEditValidation.add(oldFiling);
                    continue;
                }

                forEditValidation.add(f);
            }
            new FilingDomain(forEditValidation).validateEditPermission();
        }
    }

    public void bulkAfter() {
    }

    public void beforeInsert(SObject so) {
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
    }

    public void beforeDelete(SObject so) {
    }

    public void beforeUnDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
    }

    public void afterUpdate(SObject oldSo, SObject so) {
    }

    public void afterDelete(SObject so) {
    }

    public void afterUnDelete(SObject so) {
    }

    public void andFinally() {
    }
}