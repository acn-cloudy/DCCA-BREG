public inherited sharing class BREGDecreeGeneration {
    public static final Set<String> DISSOLUTION_HISTORY_STATUSES = new Set<String>{
        BREGAccountStatus2DissolutionBatch.STATUS_REVOKED,
        BREGAccountStatus2DissolutionBatch.STATUS_CANCELLED,
        BREGAccountStatus2DissolutionBatch.STATUS_DISSOLVED,
        BREGAccountStatus2DissolutionBatch.STATUS_TERMINATED
    };

    public static final String DISSOLUTION_COMBINED_DOCS_ROOT_PATH = 'Other Sources/BREG Combined Documents';
    public static final String DISSOLUTION_TEMPLATE_DOCS_ROOT_PATH = 'Other Sources/BREG Merged Documents/Decree Documents';

    public static final List<String> DISSOLUTION_TRANSACTION_CODES = new List<String>{'INCN', 'INDBX', 'INDS', 'INVR'};
    public static void generateDissolutionDecreeDocuments() {
        List<Account> dissolvedAccounts = getDissolutionAccountsFromHistoryToday();
        System.debug('Dissolved accounts retrieved for decree generation: ' + dissolvedAccounts.size());
        if (dissolvedAccounts.isEmpty()) {
            System.debug('No dissolution history entries found for the last 60 days. Skipping decree generation.');
            return;
        }

        generateDissolutionDecreeDocumentsInternal(dissolvedAccounts);
    }

    public static void generateDissolutionDecreeDocuments(List<Account> dissolvedAccounts) {
        if (dissolvedAccounts == null || dissolvedAccounts.isEmpty()) {
            System.debug('No accounts provided for decree generation. Skipping decree generation.');
            return;
        }

        generateDissolutionDecreeDocumentsInternal(dissolvedAccounts);
    }

    @TestVisible
    private static void generateDissolutionDecreeDocumentsInternal(List<Account> dissolvedAccounts) {

        DocuSignAPI.EosFolder combinedDocumentsFolder = DocuSignAPI.getFolderByPath(DISSOLUTION_COMBINED_DOCS_ROOT_PATH, false);
        if (combinedDocumentsFolder == null || String.isBlank(combinedDocumentsFolder.Href)) {
            System.debug('Could not find combined documents folder at path: ' + DISSOLUTION_COMBINED_DOCS_ROOT_PATH);
            return;
        }

        String dateFolderName = 'Decree Documents - ' + String.valueOf(Date.today());
        DocuSignAPI.EosFolder datedFolder = DocuSignAPI.ensureChildFolder(
            DISSOLUTION_COMBINED_DOCS_ROOT_PATH,
            combinedDocumentsFolder,
            dateFolderName
        );
        if (datedFolder == null || String.isBlank(datedFolder.Href)) {
            System.debug('Could not create or resolve dated folder for decree generation: ' + dateFolderName);
            return;
        }

        Map<String, List<Account>> accountsByGroup = groupAccountsByDecreeEntityType(dissolvedAccounts);
        for (String groupLabel : BREGUtils.DISSOLUTION_DECREE_GROUP_ORDER) {
            List<Account> accountsInGroup = accountsByGroup.get(groupLabel);
            if (accountsInGroup == null || accountsInGroup.isEmpty()) {
                continue;
            }

            String templateName = getDecreeTemplateName(groupLabel);
            String templateHref = DocuSignAPI.getDocumentHrefByPath(DISSOLUTION_TEMPLATE_DOCS_ROOT_PATH, templateName, false);
            if (String.isBlank(templateHref)) {
                System.debug('Could not resolve template document for group ' + groupLabel + ' and template ' + templateName);
                continue;
            }

            String dataXml = BREGXMLGenerator.getXMLforDecreeDocument(accountsInGroup, groupLabel);
            if (String.isBlank(dataXml)) {
                System.debug('Generated XML is blank for decree group ' + groupLabel);
                continue;
            }

            String destinationDocumentName = getDissolutionDocumentName(groupLabel);
            DocuSignAPI.submitDocumentXmlMerge(templateHref, datedFolder.Href, destinationDocumentName, dataXml);
        }
    }

    @TestVisible
    private static List<Account> getDissolutionAccountsFromHistoryToday() {
        Set<Id> accountIds = new Set<Id>();
        List<Account> accountsDissolvedIn2Months = new List<Account>();

        List<breg_Transaction__c> dissolutionTransactions = [
            SELECT Id, breg_Account__c, breg_Transaction_Code__c, CreatedDate
            FROM breg_Transaction__c
            WHERE breg_Transaction_Code__c IN :DISSOLUTION_TRANSACTION_CODES AND breg_Effective_Date__c = LAST_N_DAYS:60
        ];
        for (breg_Transaction__c dissolutionTransaction : dissolutionTransactions) {
            if (dissolutionTransaction.breg_Account__c != null) {
                accountIds.add(dissolutionTransaction.breg_Account__c);
            }
        }
        
        if (!accountIds.isEmpty()) {
            accountsDissolvedIn2Months = [
                SELECT Id, Name, breg_Entity_Type__c, breg_Delinquency_Due_Date__c, breg_Involuntary_Dissolution_Notice_Date__c
                FROM Account
                WHERE Id IN :accountIds AND RecordType.DeveloperName = 'BREG_Account'
                ORDER BY Name
            ];
        }
        System.debug('Accounts retrieved for decree generation based on history: ' + accountsDissolvedIn2Months);

        return accountsDissolvedIn2Months;
    }

    @TestVisible
    private static Map<String, List<Account>> groupAccountsByDecreeEntityType(List<Account> accounts) {
        Map<String, List<Account>> groupedAccounts = new Map<String, List<Account>>();
        for (String groupLabel : BREGUtils.DISSOLUTION_DECREE_GROUP_ORDER) {
            groupedAccounts.put(groupLabel, new List<Account>());
        }

        for (Account accountRecord : accounts) {
            String groupLabel = BREGUtils.getDissolutionDecreeGroupForEntityType(accountRecord.breg_Entity_Type__c);
            if (String.isBlank(groupLabel)) {
                continue;
            }

            if (!groupedAccounts.containsKey(groupLabel)) {
                groupedAccounts.put(groupLabel, new List<Account>());
            }

            groupedAccounts.get(groupLabel).add(accountRecord);
        }

        return groupedAccounts;
    }

    private static String getDecreeTemplateName(String groupLabel) {
        return BREGUtils.getDissolutionDecreeTemplateName(groupLabel);
    }

    @TestVisible
    private static String getDissolutionDocumentName(String groupLabel) {
        String templateName = BREGUtils.DISSOLUTION_DECREE_TEMPLATE_NAME_BY_GROUP.get(groupLabel);
        if (String.isBlank(templateName)) {
            return groupLabel;
        }

        String templateSuffix = ' - Template.docx';
        if (templateName.endsWith(templateSuffix)) {
            return templateName.substring(0, templateName.length() - templateSuffix.length());
        }

        if (templateName.endsWith('.docx')) {
            return templateName.substring(0, templateName.length() - 5);
        }

        return templateName;
    }
}