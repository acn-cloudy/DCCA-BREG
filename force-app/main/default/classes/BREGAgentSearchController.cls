public without sharing class BREGAgentSearchController {
    private static final String AGENT_ROLE = 'Agent';
    private static final String ACTIVE_STATUS = 'Active (A)';
    private static final Decimal PRICE_PER_RECORD = 0.05;
    private static final String SUBSCRIBER_PROFILE_NAME = 'DCCA BREG - Subscriber Login';
    private static final Integer AGENT_SEARCH_DEFAULT_LIMIT = 50000;

    /**
     * @description Search for agents and return their business record counts
     * @param searchValue The agent name to search for
     * @param searchType The search type ('active' or 'all')
     * @param limitCount The limit count
     * @return List of AgentSearchResult wrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<AgentSearchResult> searchAgents(String searchValue, String searchType) {
        try {
            validateSearchInput(searchValue);

            List<breg_Account_Affiliation__c> affiliations = queryAffiliations(searchValue, searchType, AGENT_SEARCH_DEFAULT_LIMIT);
            if (affiliations.isEmpty()) {
                return new List<AgentSearchResult>();
            }

            return buildSearchResults(affiliations);
        } catch (Exception e) {
            throw new AuraHandledException('Error searching agents: ' + e.getMessage());
        }
    }

    /**
     * @description Validate search input parameters
     * @param searchValue The search value to validate
     */
    private static void validateSearchInput(String searchValue) {
        if (String.isBlank(searchValue)) {
            throw new AuraHandledException('Search value cannot be empty');
        }
    }

    /**
     * @description Query account affiliations filtered by agent account name and search type
     * @param searchValue The agent name to search for
     * @param searchType The search type ('active' or 'all')
     * @param limitCount The maximum number of affiliation records to return
     * @return List of account affiliations matching the criteria
     */
    private static List<breg_Account_Affiliation__c> queryAffiliations(String searchValue, String searchType, Integer limitCount) {
        String searchPattern = '%' + searchValue + '%';
        String queryString = 'SELECT Id, breg_Entity__c, breg_Account__c, breg_Account__r.Id, breg_Account__r.Name,'
            + ' breg_Entity__r.Name, breg_Entity__r.breg_File__c, breg_Entity__r.breg_Entity_Status__c,'
            + ' breg_Affiliation_Name__c'
            + ' FROM breg_Account_Affiliation__c'
            + ' WHERE breg_Account__r.Name LIKE :searchPattern'
            + ' AND breg_Role__c = :AGENT_ROLE'
            + ' AND breg_Entity__c != NULL'
            + ' AND breg_Start_Date__c != NULL'
            + ' AND breg_End_Date__c = NULL'
            + ' AND breg_Status__c != \'I\'';

        if (searchType == 'active') {
            queryString += ' AND breg_Account__r.breg_Entity_Status__c = :ACTIVE_STATUS';
        }

        queryString += ' ORDER BY breg_Account__r.Name ASC LIMIT :limitCount';
        return Database.query(queryString);
    }

    /**
     * @description Build search results by grouping affiliations per agent and counting business records
     * @param affiliations List of account affiliations with agent account relationship fields
     * @return List of AgentSearchResult wrapper objects
     */
    private static List<AgentSearchResult> buildSearchResults(List<breg_Account_Affiliation__c> affiliations) {
        Map<Id, Integer> businessCountMap = new Map<Id, Integer>();
        Map<Id, String> agentNameMap = new Map<Id, String>();

        for (breg_Account_Affiliation__c affiliation : affiliations) {
            Id agentId = affiliation.breg_Account__c;
            agentNameMap.put(agentId, affiliation.breg_Account__r.Name);

            Integer currentCount = businessCountMap.containsKey(agentId) ? businessCountMap.get(agentId) : 0;
            businessCountMap.put(agentId, currentCount + 1);
        }

        List<AgentSearchResult> results = new List<AgentSearchResult>();
        for (Id agentId : businessCountMap.keySet()) {
            Integer businessRecordsCount = businessCountMap.get(agentId);
            Decimal price = calculatePrice(businessRecordsCount);
            results.add(new AgentSearchResult(agentId, agentNameMap.get(agentId), businessRecordsCount, price));
        }

        return results;
    }

    /**
     * @description Calculate price based on business record count
     * @param businessRecordsCount Number of business records
     * @return Calculated price
     */
    private static Decimal calculatePrice(Integer businessRecordsCount) {
        return businessRecordsCount * PRICE_PER_RECORD;
    }

    /**
     * @description Creates a breg_Agent_Search_List__c record with the selected agent Account IDs.
     * Called from the LWC before adding the cart item, mirroring the Entity List Builder pattern.
     * @param agentIds List of selected agent Account IDs
     * @param searchValue The search value used
     * @param searchType The search type used ('active' or 'all')
     * @param totalAgentRecords Number of selected agents
     * @param totalBusinessRecords Total number of business records across selected agents
     * @param totalPrice Total calculated price
     * @return The Id of the created breg_Agent_Search_List__c record
     */
    @AuraEnabled
    public static Id insertAgentSearchList(List<String> agentIds, String searchValue, String searchType, Decimal totalAgentRecords, Decimal totalBusinessRecords, Decimal totalPrice) {
        try {
            breg_Agent_Search_List__c agentSearchList = new breg_Agent_Search_List__c();
            agentSearchList.breg_Search_Value__c = searchValue;
            agentSearchList.breg_Search_Type__c = searchType;
            agentSearchList.breg_Total_Agent_Records__c = totalAgentRecords;
            agentSearchList.breg_Total_Business_Records__c = totalBusinessRecords;
            agentSearchList.breg_Total_Price__c = totalPrice;
            agentSearchList.breg_Email_Address__c = getEmailAddressFromUser();
            agentSearchList.breg_Agent_Account_Ids__c = String.join(agentIds, ';');
            insert agentSearchList;
            return agentSearchList.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating agent search list: ' + e.getMessage());
        }
    }

    private static String getEmailAddressFromUser() {
        String emailAddress = null;
        List<User> currentUser = [SELECT Contact.Email, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (!currentUser.isEmpty()) {
            if (currentUser[0].Contact?.Email != null) {
                emailAddress = currentUser[0].Contact.Email;
            } else if (currentUser[0].Email != null) {
                emailAddress = currentUser[0].Email;
            }
        }
        return emailAddress;
    }

    /**
     * @description Check if the current user has the subscriber profile
     * @return Boolean true if user has subscriber profile, false otherwise
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasSubscriberProfile() {
        try {
            User currentUser = [
                SELECT Profile.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            return currentUser.Profile.Name == SUBSCRIBER_PROFILE_NAME;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking user profile: ' + e.getMessage());
        }
    }

    /**
     * @description Wrapper class for agent search results
     */
    public class AgentSearchResult {
        @AuraEnabled
        public String agentId { get; set; }
        @AuraEnabled
        public String agentName { get; set; }
        @AuraEnabled
        public Integer businessRecords { get; set; }
        @AuraEnabled
        public Decimal price { get; set; }

        public AgentSearchResult(String agentId, String agentName, Integer businessRecords, Decimal price) {
            this.agentId = agentId;
            this.agentName = agentName;
            this.businessRecords = businessRecords;
            this.price = price;
        }
    }
}