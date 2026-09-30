@isTest
private class BREGAgentSearchControllerTest {

    @testSetup
    static void setupTestData() {
        List<Account> agentAccounts = new List<Account>();

        Account agent1 = new Account(
            Name = 'Test Agent One',
            breg_Registrant_Type__c = 'CRA',
            breg_Entity_Status__c = 'Active (A)'
        );
        agentAccounts.add(agent1);

        Account agent2 = new Account(
            Name = 'Test Agent Two',
            breg_Registrant_Type__c = 'CRA',
            breg_Entity_Status__c = 'New (Y)'
        );
        agentAccounts.add(agent2);

        Account agent3 = new Account(
            Name = 'Another Test',
            breg_Registrant_Type__c = 'CRA',
            breg_Entity_Status__c = 'Active (A)'
        );
        agentAccounts.add(agent3);

        insert agentAccounts;

        // Create business entities linked as affiliations
        List<Account> businessAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            businessAccounts.add(new Account(
                Name = 'Business ' + i,
                breg_Registrant_Type__c = 'Entity'
            ));
        }
        insert businessAccounts;

        // breg_Account__c = agent (CRA), breg_Entity__c = business entity
        List<breg_Account_Affiliation__c> affiliations = new List<breg_Account_Affiliation__c>();

        // Agent 1 — 3 business affiliations
        for (Integer i = 0; i < 3; i++) {
            affiliations.add(new breg_Account_Affiliation__c(
                breg_Account__c = agent1.Id,
                breg_Entity__c = businessAccounts[i].Id,
                breg_Role__c = 'Agent',
                breg_Start_Date__c = Date.today()
            ));
        }

        // Agent 2 — 2 business affiliations
        for (Integer i = 3; i < 5; i++) {
            affiliations.add(new breg_Account_Affiliation__c(
                breg_Account__c = agent2.Id,
                breg_Entity__c = businessAccounts[i].Id,
                breg_Role__c = 'Agent',
                breg_Start_Date__c = Date.today()
            ));
        }

        insert affiliations;
    }

    @isTest
    static void testSearchAgentsActiveOnly() {
        Test.startTest();
        List<BREGAgentSearchController.AgentSearchResult> results =
            BREGAgentSearchController.searchAgents('Test Agent', 'active');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should find only the active agent');
        Assert.areEqual('Test Agent One', results[0].agentName, 'Should find Test Agent One');
        Assert.areEqual(3, results[0].businessRecords, 'Agent should have 3 business records');
    }

    @isTest
    static void testSearchAgentsAllStatuses() {
        Test.startTest();
        List<BREGAgentSearchController.AgentSearchResult> results =
            BREGAgentSearchController.searchAgents('Test Agent', 'all');
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should find both active and inactive agents');

        BREGAgentSearchController.AgentSearchResult agent1Result;
        BREGAgentSearchController.AgentSearchResult agent2Result;

        for (BREGAgentSearchController.AgentSearchResult result : results) {
            if (result.agentName == 'Test Agent One') {
                agent1Result = result;
            } else if (result.agentName == 'Test Agent Two') {
                agent2Result = result;
            }
        }

        Assert.isNotNull(agent1Result, 'Should find Test Agent One');
        Assert.areEqual(3, agent1Result.businessRecords, 'Agent One should have 3 business records');

        Assert.isNotNull(agent2Result, 'Should find Test Agent Two');
        Assert.areEqual(2, agent2Result.businessRecords, 'Agent Two should have 2 business records');
    }

    @isTest
    static void testSearchAgentsNoResults() {
        Test.startTest();
        List<BREGAgentSearchController.AgentSearchResult> results =
            BREGAgentSearchController.searchAgents('NonExistent Agent', 'active');
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Should return empty list when no agents match');
    }

    @isTest
    static void testSearchAgentsPartialMatch() {
        Test.startTest();
        List<BREGAgentSearchController.AgentSearchResult> results =
            BREGAgentSearchController.searchAgents('One', 'active');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should find agent by partial name match');
        Assert.areEqual('Test Agent One', results[0].agentName, 'Should find Test Agent One');
        Assert.areEqual(3, results[0].businessRecords, 'Agent should have 3 business records');
    }

    @isTest
    static void testSearchAgentsEmptySearchValue() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            BREGAgentSearchController.searchAgents('', 'active');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Should throw AuraHandledException for blank search value');
    }

    @isTest
    static void testInsertAgentSearchList() {
        List<Account> agents = [SELECT Id FROM Account WHERE breg_Registrant_Type__c = 'CRA'];
        List<String> agentIds = new List<String>();
        for (Account a : agents) {
            agentIds.add(a.Id);
        }

        Test.startTest();
        Id resultId = BREGAgentSearchController.insertAgentSearchList(
            agentIds,
            'Test Agent',
            'active',
            3,
            5,
            2.25
        );
        Test.stopTest();

        Assert.isNotNull(resultId, 'Should return a valid breg_Agent_Search_List__c Id');

        breg_Agent_Search_List__c savedRecord = [
            SELECT
                breg_Search_Value__c,
                breg_Search_Type__c,
                breg_Total_Agent_Records__c,
                breg_Total_Business_Records__c,
                breg_Total_Price__c,
                breg_Agent_Account_Ids__c
            FROM breg_Agent_Search_List__c
            WHERE Id = :resultId
            LIMIT 1
        ];

        Assert.areEqual('Test Agent', savedRecord.breg_Search_Value__c, 'Search value should match');
        Assert.areEqual('active', savedRecord.breg_Search_Type__c, 'Search type should match');
        Assert.areEqual(3, savedRecord.breg_Total_Agent_Records__c, 'Total agent records should match');
        Assert.areEqual(5, savedRecord.breg_Total_Business_Records__c, 'Total business records should match');
        Assert.areEqual(2.25, savedRecord.breg_Total_Price__c, 'Total price should match');
        Assert.isTrue(savedRecord.breg_Agent_Account_Ids__c.contains(agentIds[0]), 'Agent IDs should be stored');
    }

    @isTest
    static void testInsertAgentSearchListEmptyIds() {
        Test.startTest();
        Id resultId = BREGAgentSearchController.insertAgentSearchList(
            new List<String>(),
            'No Agents',
            'all',
            0,
            0,
            0
        );
        Test.stopTest();

        Assert.isNotNull(resultId, 'Should still create a record with empty agent list');

        breg_Agent_Search_List__c savedRecord = [
            SELECT breg_Total_Agent_Records__c, breg_Total_Business_Records__c
            FROM breg_Agent_Search_List__c
            WHERE Id = :resultId
            LIMIT 1
        ];
        Assert.areEqual(0, savedRecord.breg_Total_Agent_Records__c, 'Zero agent records expected');
        Assert.areEqual(0, savedRecord.breg_Total_Business_Records__c, 'Zero business records expected');
    }

    @isTest
    static void testHasSubscriberProfile() {
        Test.startTest();
        Boolean result = BREGAgentSearchController.hasSubscriberProfile();
        Test.stopTest();

        // Running as a standard test user — not a subscriber profile, so result should be false
        Assert.isNotNull(result, 'Should return a non-null boolean');
        Assert.isFalse(result, 'Test user should not have the subscriber profile');
    }
}