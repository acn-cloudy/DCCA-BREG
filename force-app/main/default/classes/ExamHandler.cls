/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: ExamHandlerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL11112021 - Created for Phase #
 * -----------------------------------------------------------------------------------
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/11/2021
 * __________________________________________________________________________________
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class ExamHandler implements ITrigger{
    public void bulkBefore() {
        if (Trigger.isUpdate) {
            List<Exam__c> forEditValidation = new List<Exam__c>();
            for (Exam__c e : (List<Exam__c>)Trigger.new) {
                Exam__c oldExam = (Exam__c) Trigger.oldMap.get(e.Id);

                //don't validate when the assistant examiner is populated
                if (e.AssistantExaminer__c != null && oldExam.AssistantExaminer__c == null) {
                    e.SkipCustomEditValidation__c = true;
                    forEditValidation.add(e);
                    continue;
                }

                //allow current assistant examiner to blank the assistant examiner field
                if (e.AssistantExaminer__c == null &&
                                oldExam.AssistantExaminer__c != null &&
                                oldExam.AssistantExaminer__c == UserInfo.getUserId()) {
                    forEditValidation.add(oldExam);
                    continue;
                }

                //allow current AssistantExaminer or owner to assign new AssistantExaminer
                if (e.AssistantExaminer__c != null &&
                                oldExam.AssistantExaminer__c != null &&
                                oldExam.AssistantExaminer__c != e.AssistantExaminer__c &&
                        (UserInfo.getUserId() == oldExam.AssistantExaminer__c ||
                                        UserInfo.getUserId() == e.OwnerId)) {
                    e.SkipCustomEditValidation__c = true;
                    forEditValidation.add(e);
                    continue;
                }

                //allow current owner/assistant examiner to assign new owner
                if (oldExam.OwnerId != e.OwnerId &&
                        (UserInfo.getUserId() == e.AssistantExaminer__c ||
                                        UserInfo.getUserId() == oldExam.OwnerId)) {
                    e.SkipCustomEditValidation__c = true;
                    forEditValidation.add(e);
                    continue;
                }

                //don't allow other users to blanked out assistant examiner
                if (e.AssistantExaminer__c == null && oldExam.AssistantExaminer__c != null &&
                                oldExam.AssistantExaminer__c != UserInfo.getUserId() &&
                                oldExam.OwnerId != UserInfo.getUserId()) {
                    forEditValidation.add(oldExam);
                    continue;
                }

                //don't allow currently logged in user to change assistant examiner to themselves
                if (e.AssistantExaminer__c != null &&
                                oldExam.AssistantExaminer__c != null &&
                                oldExam.AssistantExaminer__c != e.AssistantExaminer__c &&
                                e.AssistantExaminer__c == UserInfo.getUserId()) {
                    forEditValidation.add(oldExam);
                    continue;
                }

                //don't allow currently logged in user to change owner to themselves
                if (oldExam.OwnerId != e.OwnerId &&
                                e.OwnerId == UserInfo.getUserId()) {
                    forEditValidation.add(oldExam);
                    continue;
                }

                forEditValidation.add(e);
            }

            new ExamDomain(forEditValidation).validateEditPermission();
        }
    }

    public void bulkAfter() {
        if (Trigger.isUpdate) {
            List<Exam__c> examsWithExaminerChanged = new List<Exam__c>();
            Map<Id, Exam__c> newMap = (Map<Id, Exam__c>)Trigger.newMap;
            Map<Id, Exam__c> oldMap = (Map<Id, Exam__c>)Trigger.oldMap;
            for (Exam__c e : newMap.values()) {
                if (e.AssistantExaminer__c != oldMap.get(e.Id).AssistantExaminer__c ||
                                e.OwnerId != oldMap.get(e.Id).OwnerId) {
                    examsWithExaminerChanged.add(e);
                }
            }

            if (!examsWithExaminerChanged.isEmpty()) {
                new ExamDomain(examsWithExaminerChanged).updateAssistantExaminerSharing();
            }
        }
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