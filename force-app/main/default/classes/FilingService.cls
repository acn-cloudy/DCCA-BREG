/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: FilingServiceTest
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
public with sharing class FilingService {

    private static final Set<String> EDIT_PERMISSION_EXEMPTED_PROFILE_NAMES = new Set<String>{'System Administrator',
                                                                                              'DCCA SEC/SEB System Administrator',
                                                                                              'DCCA BREG - CustomerCommunityLogin',
                                                                                              'DCCA SEC Reviewer/Examiner',
                                                                                              'DCCA BREG - CustomerCommunityLogin',
                                                                                              'DCCA SEC Exam Supervisor'
                                                                                              };
    private static Map<Id, Profile> editPermissionExemptedProfilesMap;

    /*
     * Check if current user is allowed to edit the filing record
     */
    public static Boolean validateEditPermission(Filing__c filing) {
        if (editPermissionExemptedProfilesMap == null) {
            editPermissionExemptedProfilesMap = new Map<Id, Profile>([
                    SELECT
                            Id
                    FROM Profile
                    WHERE Name IN :EDIT_PERMISSION_EXEMPTED_PROFILE_NAMES
            ]);
        }
        if(filing.AllowUserToPerformReviewer__c) {
            return true;
        } else if (filing.Reviewer__c != null) {
            return filing.Reviewer__c == UserInfo.getUserId() ||
                    editPermissionExemptedProfilesMap.containsKey(UserInfo.getProfileId()) ||
                    filing.SkipReviewerEditValidation__c;
        } else {
            return true;
        }

        
    }
}