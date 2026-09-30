public without sharing class BREGEntityListBuilderBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
    //the BREGEntityListBuilderBatch runs on behalf of the Guest License - PaymentConnect Profile (PaymentConnect Site Guest User
    //) . TODO: add perm sets / sharing for Entity List/Account/Payment/TransactionLine__c objects for this user
    String query;
    List<Id> entityListIds;
    breg_Entity_List__c currentEntityList;
    String csvContent;
    List<String> accountFields;
    Integer totalRecordsCount;
    String baseUrl;

    public BREGEntityListBuilderBatch(List<Id> entityListIds) {
        Id currentEntityListId = entityListIds.remove(0);
        this.currentEntityList = [
            SELECT
                Id,
                Name,
                breg_Entity_Type_Codes__c,
                breg_Zip_Code__c,
                breg_Status__c,
                breg_Start_Date__c,
                breg_End_Date__c,
                breg_Name_Company__c,
                breg_Entity_Name__c,
                breg_Email_Address__c
            FROM breg_Entity_List__c
            WHERE Id = :currentEntityListId
        ];
        this.entityListIds = entityListIds;
        totalRecordsCount = 0;
        this.baseUrl = BREGUtils.getBaseUrl();
        //get query
        query = BREGEntityListBuilderController.getAccountQueryString(new BREGEntityListBuilderController.SearchInput(currentEntityList), false);
        initCSV();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        totalRecordsCount += scope.size();
        for (Account nextAcc : scope) {
            for (String nextFieldApiName : accountFields) {
                csvContent += formatCsvValue(nextAcc.get(nextFieldApiName)) + ',';
            }
            csvContent += formatCsvValue(baseUrl + '/search-and-buy?entityId=' + nextAcc.Id);
            csvContent += '\n';
        }
    }

    public void finish(Database.BatchableContext bc) {
        Boolean isError = false;
        String fileHref;
        try {
            fileHref = Test.isRunningTest()
                ? 'https://docusignapi.com/v2/folderId/documents/documentId'
                : DocuSignAPI.uploadEntityListFile(currentEntityList.Id, csvContent);
        } catch (Exception ex) {
            isError = true;
            // insert new Application_Log__c(
            //     Debug_Level__c = 'Error',
            //     Message__c = ex.getMessage(),
            //     Reference_Id__c = currentEntityList.Id,
            //     Stack_Trace__c = ex.getStackTraceString(),
            //     Status__c = 'New'
            // );
        }
        if (!isError) {
            updateRecords(fileHref, currentEntityList.name);
        }
        //Call next batch anyways, despite errors
        if (!entityListIds.isEmpty()) {
            Database.executeBatch(new BREGEntityListBuilderBatch(entityListIds), 200);
        }
    }

    private void initCSV() {
        csvContent = '';
        accountFields = new List<String>();
        List<Schema.FieldSetMember> accountFieldSet = Schema.SObjectType.Account.fieldSets.BREG_Entity_List_Builder_Fields.getFields();
        for (Schema.FieldSetMember nextField : accountFieldSet) {
            csvContent += formatCsvValue(nextField.getLabel()) + ',';
            accountFields.add(nextField.getFieldPath());
        }
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

    @TestVisible
    private static String formatCsvValueForTest(Object rawValue) {
        return formatCsvValue(rawValue);
    }

    private void updateRecords(String fileHref, String entityListName) {
        //get payment and transaction line with document lookup
        // pymt__PaymentX__c payment = [
        //     SELECT Id, LastModifiedDate
        //     FROM pymt__PaymentX__c
        //     WHERE breg_Entity_List__c = :currentEntityList.Id
        // ];
        List<TransactionLine__c> transLines = [
            SELECT Id, breg_Document__c, Amount__c, breg_Case__c, Description__c, Payment__c, Payment__r.LastModifiedDate
            FROM TransactionLine__c
            WHERE breg_Entity_List__c = :currentEntityList.Id
            LIMIT 1
        ];
        if (transLines.isEmpty()) {
            return;
        }
        TransactionLine__c entityListLine = transLines[0];
        // for (TransactionLine__c nextLine : transLines) {
        //     if (nextLine.Description__c.contains('Entity List')) {
        //         entityListLine = nextLine;
        //         break;
        //     }
        // }

        //Createe breg_Entity_List_Result__c
        breg_Entity_List_Result__c searchResult = new breg_Entity_List_Result__c();
        searchResult.Approximate_Record_Count__c = totalRecordsCount;
        searchResult.breg_Cost_of_List__c = entityListLine.Amount__c;
        searchResult.breg_Download_Link__c = fileHref;
        searchResult.breg_Docusign_Document_Id__c = fileHref?.substringAfterLast('/');
        searchResult.breg_Entity_List__c = currentEntityList.Id;
        searchResult.breg_Purchase_Date__c = entityListLine.Payment__r?.LastModifiedDate?.date();
        searchResult.breg_Expiration_Date__c = entityListLine.Payment__r?.LastModifiedDate?.addMonths(6)?.date();
        insert searchResult;
        //Create breg_Document__c
        breg_Document__c newDocument = new breg_Document__c();
        newDocument.Name = entityListName;
        newDocument.breg_Availability__c = 'Available Now';
        newDocument.breg_Docusign_Document_Id__c = fileHref?.substringAfterLast('/');
        newDocument.breg_Type__c = 'Digital';
        insert newDocument;

        //Update Transaction Line with Document link
        entityListLine.breg_Document__c = newDocument.Id;
        update entityListLine;

        //send email to user with csv file attached from docusign
        String docusignParam = '<recordId>' + currentEntityList.Id + '</recordId><transactionLineId>' + entityListLine.Id + '</transactionLineId>';

        if (!Test.isRunningTest()) {
            System.enqueueJob(new BREGStartDocusignWorkflow('BREG EntityList Download Document', currentEntityList.Id, docusignParam, 'Entity List Batch', false)); //TODO add param for related case for log record
        }
    }

    @InvocableMethod(label='Run Entity List Batch' category='Account')
    public static void runBatch(List<Id> entitityListIds) {
        Database.executeBatch(new BREGEntityListBuilderBatch(entitityListIds), 200);
    }
}