public without sharing class BREGAgentSearchBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    private static final String AGENT_ROLE = 'Agent';

    List<Id> agentSearchListIds;
    breg_Agent_Search_List__c currentAgentSearchList;
    Set<Id> agentAccountIds;
    String csvContent;
    String baseUrl;

    public BREGAgentSearchBatch(List<Id> agentSearchListIds) {
        Id currentId = agentSearchListIds.remove(0);
        this.currentAgentSearchList = [
            SELECT Id, Name, breg_Agent_Account_Ids__c, breg_Total_Price__c
            FROM breg_Agent_Search_List__c
            WHERE Id = :currentId
        ];
        this.agentSearchListIds = agentSearchListIds;
        this.agentAccountIds = parseAgentAccountIds(currentAgentSearchList.breg_Agent_Account_Ids__c);
        this.baseUrl = BREGUtils.getBaseUrl();
        initCsv();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String agentRole = AGENT_ROLE;
        return Database.getQueryLocator([
            SELECT
                breg_Entity__c,
                breg_Entity__r.Name,
                breg_Entity__r.breg_File__c,
                breg_Entity__r.breg_Entity_Status__c,
                breg_Affiliation_Name__c
            FROM breg_Account_Affiliation__c
            WHERE
                breg_Account__c IN :agentAccountIds
                AND breg_Role__c = :agentRole
                AND breg_Entity__c != NULL
                AND breg_Start_Date__c != NULL
                AND breg_End_Date__c = NULL
                AND breg_Status__c != 'I'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<breg_Account_Affiliation__c> scope) {
        for (breg_Account_Affiliation__c aff : scope) {
            csvContent += formatCsvValue(aff.breg_Entity__r?.Name) + ',';
            csvContent += formatCsvValue(aff.breg_Entity__r?.breg_File__c) + ',';
            csvContent += formatCsvValue(aff.breg_Entity__r?.breg_Entity_Status__c) + ',';
            csvContent += formatCsvValue(aff.breg_Affiliation_Name__c) + ',';
            csvContent += formatCsvValue(baseUrl + '/search-and-buy?entityId=' + aff.breg_Entity__c);
            csvContent += '\n';
        }
    }

    public void finish(Database.BatchableContext bc) {
        Boolean isError = false;
        String fileHref;
        try {
            fileHref = Test.isRunningTest()
                ? 'https://docusignapi.com/v2/folderId/documents/documentId'
                : DocuSignAPI.uploadAgentSearchFile(currentAgentSearchList.Id, csvContent);
        } catch (Exception ex) {
            isError = true;
            // insert new Application_Log__c(
            //     Debug_Level__c = 'Error',
            //     Message__c = ex.getMessage(),
            //     Reference_Id__c = currentAgentSearchList.Id,
            //     Stack_Trace__c = ex.getStackTraceString(),
            //     Status__c = 'New'
            // );
        }
        if (!isError) {
            updateRecords(fileHref, currentAgentSearchList.Name);
        }
        if (!agentSearchListIds.isEmpty()) {
            Database.executeBatch(new BREGAgentSearchBatch(agentSearchListIds), 200);
        }
    }

    private void initCsv() {
        csvContent = '';
        csvContent += formatCsvValue('Master Name') + ',';
        csvContent += formatCsvValue('File Number') + ',';
        csvContent += formatCsvValue('Status') + ',';
        csvContent += formatCsvValue('Agent Name') + ',';
        csvContent += formatCsvValue('Detail link');
        csvContent += '\n';
    }

    private static String formatCsvValue(Object rawValue) {
        String value = rawValue == null ? '' : String.valueOf(rawValue);
        value = value.replace('"', '""');
        value = value.replace('\r\n', ' ');
        value = value.replace('\n', ' ');
        value = value.replace('\r', ' ');
        return '"' + value + '"';
    }

    private static Set<Id> parseAgentAccountIds(String idsString) {
        Set<Id> ids = new Set<Id>();
        if (String.isBlank(idsString)) {
            return ids;
        }
        for (String idStr : idsString.split(';')) {
            String trimmed = idStr.trim();
            if (String.isNotBlank(trimmed)) {
                ids.add(Id.valueOf(trimmed));
            }
        }
        return ids;
    }

    private void updateRecords(String fileHref, String agentSearchListName) {
        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Document__c, Amount__c, Description__c, Payment__c, Payment__r.LastModifiedDate
            FROM TransactionLine__c
            WHERE breg_Agent_Search_List__c = :currentAgentSearchList.Id
            LIMIT 1
        ];
        if (transLines.isEmpty()) {
            return;
        }
        TransactionLine__c agentSearchLine = transLines[0];

        breg_Agent_Search_Result__c searchResult = new breg_Agent_Search_Result__c();
        searchResult.breg_Download_Link__c = fileHref;
        searchResult.breg_Docusign_Document_Id__c = fileHref?.substringAfterLast('/');
        searchResult.breg_Agent_Search_List__c = currentAgentSearchList.Id;
        searchResult.breg_Purchase_Date__c = agentSearchLine.Payment__r?.LastModifiedDate?.date();
        insert searchResult;

        breg_Document__c newDocument = new breg_Document__c();
        newDocument.Name = agentSearchListName;
        newDocument.breg_Availability__c = 'Available Now';
        newDocument.breg_Docusign_Document_Id__c = fileHref?.substringAfterLast('/');
        newDocument.breg_Type__c = 'Digital';
        insert newDocument;

        agentSearchLine.breg_Document__c = newDocument.Id;
        update agentSearchLine;

        if (!Test.isRunningTest()) {
            System.enqueueJob(new BREGStartDocusignWorkflow('BREG AgentSearch Download Document', currentAgentSearchList.Id, null, 'Agent Search Batch', false));
        }
    }

    @InvocableMethod(label='Run Agent Search Batch' category='Account')
    public static void runBatch(List<Id> agentSearchListIds) {
        Database.executeBatch(new BREGAgentSearchBatch(agentSearchListIds), 200);
    }
}