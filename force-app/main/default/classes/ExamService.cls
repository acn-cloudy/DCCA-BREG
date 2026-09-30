/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: ExamServiceTest
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
public with sharing class ExamService {

    private static final Set<String> EDIT_PERMISSION_EXEMPTED_PROFILE_NAMES = new Set<String>{'System Administrator',
                                                                                              'DCCA SEC/SEB System Administrator'
                                                                                              };

    private static Map<Id, Profile> editPermissionExemptedProfilesMap;

    /*
     * Check if current user is allowed to edit the exam record
     */
    public static Boolean validateEditPermission(Exam__c exam) {
        if (editPermissionExemptedProfilesMap == null) {
            editPermissionExemptedProfilesMap = new Map<Id, Profile>([
                    SELECT
                            Id
                    FROM Profile
                    WHERE Name IN :EDIT_PERMISSION_EXEMPTED_PROFILE_NAMES
            ]);
        }

        if (exam.AssistantExaminer__c != null) {
            return exam.AssistantExaminer__c == UserInfo.getUserId() ||
                            exam.OwnerId == UserInfo.getUserId() ||
                    editPermissionExemptedProfilesMap.containsKey(UserInfo.getProfileId()) ||
                    exam.SkipCustomEditValidation__c;
        }

        return true;
    }

}