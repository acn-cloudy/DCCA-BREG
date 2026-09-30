/*
 * ___________________________________________________________________________________
 * Creation of a trigger on the SEB Case Team object, that will update the "Current Attorney", "Current Clerk" & "Current Investigator" on the SEB Case.
 * The trigger needs to update the fields on the SEB Case based on the most current record with that role, consider deletions as well.
 * Covered by: SEBCaseCurrentTeamSetterTest
 * __________________________________________________________________________________
 * PacPoint-CL082019 - Created for BREG Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 8/20/2019
 * __________________________________________________________________________________
 */
public class SEBCaseCurrentTeamSetter {
    public static void setCurrentTeam(List<Id> sebCasesIds) {
        List<SEBCase__c> sebCasesWithSebCaseTeam = [
                SELECT Id,
                        CurrentAttorney__c,
                        CurrentClerk__c,
                        CurrentInvestigator__c,
                        (SELECT Id,
                                 Name,
                                 Role__c,
                                 TeamMember__c
                        FROM SEBCaseTeams__r
                        ORDER BY CreatedDate DESC)
                FROM SEBCase__c
                WHERE Id IN:sebCasesIds
        ];

        for (SEBCase__c sebCase : sebCasesWithSebCaseTeam) {
            sebCase.CurrentAttorney__c = null;
            sebCase.CurrentClerk__c = null;
            sebCase.CurrentInvestigator__c = null;

            for (SEBCaseTeam__c sebTeam : sebCase.SEBCaseTeams__r) {
                if (sebCase.CurrentAttorney__c == null && sebTeam.Role__c == 'Attorney') {
                    sebCase.CurrentAttorney__c = sebTeam.TeamMember__c;
                }

                if (sebCase.CurrentClerk__c == null && sebTeam.Role__c == 'Clerk') {
                    sebCase.CurrentClerk__c = sebTeam.TeamMember__c;
                }

                if (sebCase.CurrentInvestigator__c == null && sebTeam.Role__c == 'Investigator') {
                    sebCase.CurrentInvestigator__c = sebTeam.TeamMember__c;
                }
            }
        }

        update sebCasesWithSebCaseTeam;
    }

}