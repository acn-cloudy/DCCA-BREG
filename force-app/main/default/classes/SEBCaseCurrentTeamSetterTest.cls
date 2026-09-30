/*
 * ___________________________________________________________________________________
 * Code coverage for: SEBCaseCurrentTeamSetter
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
@IsTest
private class SEBCaseCurrentTeamSetterTest {
    @TestSetup
    static void setup() {
         Account acct = new Account(
            Name = 'Test Accont',
            SEBSEC__c = true
        );
        insert acct;

        SEBCase__c sebCase = new SEBCase__c();
        // sebCase.Name = 'test';
        sebCase.Account__c = acct.Id;
        insert sebCase;

        SEBCaseTeam__c sebCaseTeamAttorney = new SEBCaseTeam__c();
        sebCaseTeamAttorney.Role__c = 'Attorney';
        sebCaseTeamAttorney.TeamMember__c = UserInfo.getUserId();
        sebCaseTeamAttorney.SEBCase__c = sebCase.Id;
        insert sebCaseTeamAttorney;

        SEBCaseTeam__c sebCaseTeamClerk = new SEBCaseTeam__c();
        sebCaseTeamClerk.Role__c = 'Clerk';
        sebCaseTeamClerk.TeamMember__c = UserInfo.getUserId();
        sebCaseTeamClerk.SEBCase__c = sebCase.Id;
        insert sebCaseTeamClerk;

        SEBCaseTeam__c sebCaseTeamInvestigator = new SEBCaseTeam__c();
        sebCaseTeamInvestigator.Role__c = 'Investigator';
        sebCaseTeamInvestigator.TeamMember__c = UserInfo.getUserId();
        sebCaseTeamInvestigator.SEBCase__c = sebCase.Id;
        insert sebCaseTeamInvestigator;

        Profile p = [SELECT ID FROM Profile WHERE Name='System Administrator'];
        User u1 = new User(Alias = 'standt1',
                Email = 'dummy@user.test',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'dummy@user.test');
        insert u1;
    }

    @IsTest
    static void testAttorneyInsert() {
        SEBCase__c sebCase = [SELECT Id, CurrentAttorney__c FROM SEBCase__c LIMIT 1];

        System.assert(sebCase.CurrentAttorney__c == UserInfo.getUserId());

        User u1 = [SELECT Id FROM User WHERE Username = 'dummy@user.test'];

        SEBCaseTeam__c sebCaseTeamAttorney = new SEBCaseTeam__c();
        sebCaseTeamAttorney.Role__c = 'Attorney';
        sebCaseTeamAttorney.SEBCase__c = sebCase.Id;
        sebCaseTeamAttorney.TeamMember__c = u1.Id;
        insert sebCaseTeamAttorney;

        SEBCase__c updatedSebCase = [SELECT Id, CurrentAttorney__c FROM SEBCase__c LIMIT 1];

        System.assert(updatedSebCase.CurrentAttorney__c == u1.Id);
    }

    @IsTest
    static void testAttorneyDelete() {
        SEBCase__c sebCase = [SELECT Id, CurrentAttorney__c FROM SEBCase__c LIMIT 1];

        System.assert(sebCase.CurrentAttorney__c == UserInfo.getUserId());

        User u1 = [SELECT Id FROM User WHERE Username = 'dummy@user.test'];

        SEBCaseTeam__c sebCaseTeamAttorney = new SEBCaseTeam__c();
        sebCaseTeamAttorney.Role__c = 'Attorney';
        sebCaseTeamAttorney.SEBCase__c = sebCase.Id;
        sebCaseTeamAttorney.TeamMember__c = u1.Id;
        insert sebCaseTeamAttorney;

        SEBCase__c updatedSebCase = [SELECT Id, CurrentAttorney__c FROM SEBCase__c LIMIT 1];

        System.assert(updatedSebCase.CurrentAttorney__c == u1.Id);

        delete sebCaseTeamAttorney;

        SEBCase__c updatedSebCase2 = [SELECT Id, CurrentAttorney__c FROM SEBCase__c LIMIT 1];

        System.assert(updatedSebCase2.CurrentAttorney__c == UserInfo.getUserId());
    }

    @IsTest
    static void testUpdateRole() {
        SEBCaseTeam__c sebCaseTeamAttorney = [SELECT Id FROM SEBCaseTeam__c WHERE Role__c='Attorney' LIMIT 1];
        sebCaseTeamAttorney.Role__c = 'Clerk';
        update sebCaseTeamAttorney;

        SEBCase__c updatedSebCase = [SELECT Id, CurrentAttorney__c, CurrentClerk__c FROM SEBCase__c LIMIT 1];

        System.assert(updatedSebCase.CurrentAttorney__c == null);
        System.assert(updatedSebCase.CurrentClerk__c == UserInfo.getUserId());
    }
}