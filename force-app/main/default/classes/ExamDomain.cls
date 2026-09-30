/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: ExamDomainTest
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
public with sharing class ExamDomain extends SObjectDomain{
    public ExamDomain(List<Exam__c> records) {
        super(records);
    }

    public void validateEditPermission() {
        for (Exam__c exam : (List<Exam__c>) records) {
            Exam__c oldExam = (Exam__c) Trigger.oldMap.get(exam.Id);
            Exam__c newExam = (Exam__c) Trigger.newMap.get(exam.Id);

            if (!ExamService.validateEditPermission(exam)) {
                if (Trigger.isExecuting) {
                    if (oldExam.SkipCustomEditValidation__c && !newExam.SkipCustomEditValidation__c) {
                        //don't validate when only setting Skip flag to false
                        continue;
                    }

                    Trigger.newMap.get(exam.Id).addError('Only the Owner and Assistant Examiner can edit this Exam.');
                    continue;
                }

                exam.addError('Only the Owner and Assistant Examiner can edit this Exam.');
            }

            //Handle scenario where the byPass flag is not updated to false via process builder "Exam:Immediate Actions"
            if (exam.SkipCustomEditValidation__c && oldExam.ExamStatus__c != 'New') {
                exam.SkipCustomEditValidation__c = false;
            }
        }
    }

    /*
     * Share exam and related file detail records to the exam's assistant examiner
     */
    public void updateAssistantExaminerSharing() {
        ExamSharer.shareWithAssistantExaminer(records);
    }
}