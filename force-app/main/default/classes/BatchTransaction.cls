/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the batch Transaction component - Allows the user to create multiple transactions
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint-LC040819 - Created for DCCA phase 1
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* PacPoint-IC061019 - Created for phase 1
* Dynamic Search Criteria for Accounts and flexible print fields (Accounts)
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class BatchTransaction {

    @AuraEnabled
    public static InitValues getInitialValues(String location) {
        InitValues toReturn = new InitValues();
        toReturn.searchAccountFields = new List<SearchFields>(); //For Search Account Filter
        toReturn.printAccountFields = new List<SearchFields>();//For Print Account Filter
        toReturn.accountColumnFields = new List<SearchFields>(); //For the list of columns on the account list
        toReturn.columnAccountFields = new List<SearchFields>(); //For the list of columns on the account list

        SearchFields acctNameField = new SearchFields(); //Field for the columns on the account list
        acctNameField.label = 'Name';
        acctNameField.name = 'Name';
        toReturn.accountColumnFields.add(acctNameField);

        User myUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        List<string> divisions = new List<string>();
        if (myuser.Division__c != null)
            divisions = myUser.Division__c.split(';');
        toReturn.showPVL = divisions.contains('PVL');
        toReturn.showFile = divisions.contains('BREG');
        toReturn.showOAH = divisions.contains('OAH');
        toReturn.showPrjNo = divisions.contains('PVL Real Estate');

        //Fields for the columns on the account list
        if(toReturn.showPVL) {
            SearchFields acctField = new SearchFields();
            acctField.label = 'PVL BP Id';
            acctField.name = 'BPID__c';
            toReturn.accountColumnFields.add(acctField);
        }
        if(toReturn.showFile) {
            SearchFields acctField = new SearchFields();
            acctField.label = 'File Id';
            acctField.name = 'FileID__c';
            toReturn.accountColumnFields.add(acctField);
        }
        if(toReturn.showOAH) {
            SearchFields acctField = new SearchFields();
            acctField.label = 'OAH Case Number';
            acctField.name = 'OAH_Case_Number__c';
            toReturn.accountColumnFields.add(acctField);
        }
        if(toReturn.showPrjNo) {
            SearchFields acctField = new SearchFields();
            acctField.label = 'Project Number';
            acctField.name = 'ProjectNumber__c';
            toReturn.accountColumnFields.add(acctField);
        }

        //Retrieve Account Fields and field data
        Schema.SObjectType accountsObjType = Schema.getGlobalDescribe().get('Account');
        Map<String, Schema.SobjectField> fieldMap = accountsObjType.getDescribe().fields.getMap();


        //Retrieve for Result Columns from Metadata
        List<NewBatchTransactionComponentConfig__mdt> batchTransactionComponentColumnList = [SELECT Id, Value__c FROM
        NewBatchTransactionComponentConfig__mdt
        WHERE Division__c = :divisions AND Location__c = :location AND Type__c = 'Result Columns'];
        Set<String> columnFieldsList = new Set<String>();

        //Check if the config is empty for the search criteria
        if(!batchTransactionComponentColumnList.isEmpty()){
            for(NewBatchTransactionComponentConfig__mdt batchTransConfig : batchTransactionComponentColumnList){
                //fields are separated by comma on the metadata. Split them into a list
                List<String> batchConfigFieldList = batchTransConfig.Value__c.split(',');
                for(String configField : batchConfigFieldList){
                    //Add field to the search Fields list and check if the field is already existing on it
                    if(!columnFieldsList.contains(configField)){
                        columnFieldsList.add(configField);
                    }
                }
            }
        }else{
            //Default Search Criteria if none is found
            columnFieldsList.add('Name');
        }

        //Add the search Fields retrieved to search field wrapper for the label, name and value
        for (String field : columnFieldsList){
            SearchFields searchField = new SearchFields();
            searchField.label = fieldMap.get(field).getDescribe().getLabel();
            searchField.name = field;
            toReturn.columnAccountFields.add(searchField);
        }

        //Retrieve for Search Criteria from Metadata
        List<NewBatchTransactionComponentConfig__mdt> batchTransactionComponentConfigList = [SELECT Id, Value__c FROM
        NewBatchTransactionComponentConfig__mdt
        WHERE Division__c = :divisions AND Location__c = :location AND Type__c = 'Search Criteria'];
        Set<String> searchFieldsList = new Set<String>();

        //Check if the config is empty for the search criteria
        if(!batchTransactionComponentConfigList.isEmpty()){
            for(NewBatchTransactionComponentConfig__mdt batchTransConfig : batchTransactionComponentConfigList){
                //fields are separated by comma on the metadata. Split them into a list
                List<String> batchConfigFieldList = batchTransConfig.Value__c.split(',');
                for(String configField : batchConfigFieldList){
                    //Add field to the search Fields list and check if the field is already existing on it
                    if(!searchFieldsList.contains(configField)){
                        searchFieldsList.add(configField);
                    }
                }
            }
        }else{
            //Default Search Criteria if none is found
            searchFieldsList.add('Name');
        }

        //Add the search Fields retrieved to search field wrapper for the label, name and value
        for (String field : searchFieldsList){
            SearchFields searchField = new SearchFields();
            searchField.label = fieldMap.get(field).getDescribe().getLabel();
            searchField.name = field;
            searchField.value = '';
            toReturn.searchAccountFields.add(searchField);
        }


        //Retrieve for Print Page from metadata
        List<NewBatchTransactionComponentConfig__mdt> batchTransactionComponentPrintList = [SELECT Id, Value__c FROM
        NewBatchTransactionComponentConfig__mdt
        WHERE Division__c = :divisions AND Location__c = :location AND Type__c = 'Print Page'];
        Set<String> printFieldsList = new Set<String>();

        String unserializedFields = '';
        Integer currentPrintListRecord = 1;
        String printFieldsByObject = '';
        //Check if the config is empty for the print criteria
        Map<String, Set<String>> mapObjFields = new Map<String, Set<String>>();
        if(!batchTransactionComponentPrintList.isEmpty()){
            for(NewBatchTransactionComponentConfig__mdt batchTransConfigPrint : batchTransactionComponentPrintList){
                printFieldsByObject += batchTransConfigPrint.Value__c;
                String unserializedValue = '{"data": ['+ batchTransConfigPrint.Value__c +']}';
                Map<String, Object> objectFieldsMap = (Map<String, Object>)JSON.deserializeUntyped(unserializedValue);
                List<Map<String, Object>> objectFieldsList = new List<Map<String, Object>>();
                for (Object instance : (List<Object>)objectFieldsMap.get('data')) {
                    objectFieldsList.add((Map<String, Object>)instance);
                }
                for(Map<String, Object> obj : objectFieldsList) {
                    for (String relationshipName : obj.keySet()) {
                        if(!mapObjFields.containsKey(relationshipName)){
                            mapObjFields.put(relationshipName, new Set<String>());
                        }
                        String currentFields = (String) obj.get(relationshipName);
                        //fields are separated by comma on the metadata. Split them into a list
                        List<String> fieldsList = currentFields.split(',');

                        for(String fieldName : fieldsList){
                            if(!mapObjFields.get(relationshipName).contains(fieldName)){
                                mapObjFields.get(relationshipName).add(fieldName);
                            }
                        }
                    }
                }
            }

            unserializedFields += '';
            Integer currentMapObjFields = 1;
            for(String objectName : mapObjFields.keySet()){
                unserializedFields += '{"' + objectName + '":"';
                Integer currentfieldObjName = 1;
                for(String fieldObjName : mapObjFields.get(objectName)){
                    unserializedFields += fieldObjName;
                    if(currentfieldObjName < mapObjFields.get(objectName).size()){
                        unserializedFields += ',';
                    }
                    currentfieldObjName += 1;
                }
                unserializedFields += '"}';
                if(currentMapObjFields < mapObjFields.size()){
                    unserializedFields += ',';
                }
                currentMapObjFields += 1;
            }
            unserializedFields = '{"data": ['+ unserializedFields +']}';
        }else{
            unserializedFields += '{"data":[{"Transaction__c":"Name"},{"Account__r":"Name"}]}';
            //Default if no config is found
            printFieldsList.add('Name');
        }
        toReturn.printFields = unserializedFields;

        return toReturn;
    }
    
    @AuraEnabled
    public static SaveWrapper saveTransactions(string accIds, string lines, List<SearchFields> accountFields, String unserializedFields) {
        List<LineWrapper> linesList = (List<LineWrapper>)JSON.deserialize(lines, List<LineWrapper>.class);
        List<TranWrapper> tranList = (List<TranWrapper>)JSON.deserialize(accIds, List<TranWrapper>.class);
        
        Set<Id> ccSet = new Set<Id>();
        for (LineWrapper lw : linesList) {
            if (lw.code != null && lw.code != '') {
                ccSet.add(lw.code);
            }
        }
        if (ccSet.size() == 0) {
            return new SaveWrapper('Error : Please add at least one cashier code.');
        }
        if (accIds == null || tranList.size() == 0) {
            return new SaveWrapper('Error : Please add at least one account.');
        }
        
        string batchGroup = DateTime.now().format('MM-dd-yyyy') + '%';
        List<Transaction__c> batchNoTrans = [SELECT BatchNumberDigits__c FROM Transaction__c WHERE BatchNumber__c LIKE :batchGroup AND BatchNumberDigits__c != null ORDER BY BatchNumberDigits__c DESC LIMIT 1];
        integer digit = 1;
        if (batchNoTrans.size() > 0) {
            digit = (integer)batchNoTrans[0].BatchNumberDigits__c + 1;
        }
        string digitStr = string.valueOf(digit);
        while (digitStr.length() < 3)
            digitStr = '0' + digitStr;
        batchGroup = DateTime.now().format('MM-dd-yyyy') + ' ' + digitStr;
        
        Map<Id, CashierCode__c> ccMap = new Map<Id, CashierCode__c>([SELECT CashierCode__c, Amount__c, Division__c FROM CashierCode__c WHERE Id IN :ccSet]);
        
        //Map<Id, Account> accMap = new Map<Id, Account>([SELECT Id, LicenseNumbers__c FROM Account WHERE Id IN :accIds]);
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Saving Transactions
            List<Transaction__c> transactionsToInsert = new List<Transaction__c>();
            string division = null;
            if (ccMap.size() > 0)
                division = ccMap.values()[0].Division__c;
            for (TranWrapper accId : tranList) {
                Transaction__c trans = new Transaction__c();
                trans.Account__c = accId.id;
                trans.Date__c = Date.today();
                trans.Status__c = 'New';
                trans.TransactionType__c = 'Payment';
                trans.Division__c = division;
                trans.WorkitemID__c = (accId.workitem == null || accId.workitem =='undefined') ? '' : accId.workitem;
                trans.Description__c = (accId.description == null || accId.description == 'undefined') ? '' : accId.description;
                trans.BatchNumber__c = batchGroup;
                trans.BatchNumberDigits__c = digit;
                transactionsToInsert.add(trans);
            }
            insert transactionsToInsert;
            
            List<TransactionLine__c> linesToInsert = new List<TransactionLine__c>();
            for (Transaction__c trans : transactionsToInsert) {
                for (LineWrapper lw : linesList) {
                    if (lw.code != null && lw.code != '') {
                        TransactionLine__c lineToInsert = new TransactionLine__c();
                        try {
                            lineToInsert.Amount__c = ccMap.get(lw.code).Amount__c;
                        } catch (Exception ex) {}
                        try {
                            lineToInsert.Amount__c = decimal.valueOf(lw.amount);
                        } catch (Exception ex) {}
                        lineToInsert.CashierCode__c = lw.code;
                        lineToInsert.Description__c = lw.description;
                        lineToInsert.Transaction__c = trans.Id;
                        //lineToInsert.License_Numbers__c = accMap.get(trans.Account__c).LicenseNumbers__c;
                        linesToInsert.add(lineToInsert);
                    }
                }
            }
            insert linesToInsert;
            
            return new SaveWrapper(transactionsToInsert, ccMap.values(), accountFields, unserializedFields);
        } catch (Exception ex) {
            Database.rollback(sp);
            return new SaveWrapper('Error : ' + ex.getMessage());
        }
        
    }
    
    @AuraEnabled (cacheable=true)
    public static List<Account> searchLines(List<SearchFields> accountFieldValues, List<SearchFields> columnAccountFields, Integer accountsPerPage, Integer pageNumber) {
        pageNumber -= 1;
        String sortByField = '';

        Map<String, List<String>> searchItemValues = new Map<String, List<String>>(); //Separate by space on each field
        Integer searchAccountKey = 0; //Starting key for the List Search Fields
        while (searchAccountKey < accountFieldValues.size()) { //On each item on the list
            String fieldName = accountFieldValues.get(searchAccountKey).name; //Field Name
            String fieldValue = accountFieldValues.get(searchAccountKey).value; //Value of the Field
            if(fieldName == 'Name' && !String.isEmpty(fieldValue)){
                sortByField += 'ORDER BY NAME ASC';
            }else if(sortByField != 'SORT BY NAME ASC' && fieldName != 'Name' && !String.isEmpty(fieldValue)){
                sortByField = 'ORDER BY ' + fieldName + ' ASC';
            }

            if(fieldValue == null || fieldValue == '') { //If the field value is empty/null, remove from list
                accountFieldValues.remove(searchAccountKey);
            }else{
                List<String> valuesSeparatedBySpace = new List<String>(); //Initialize list
                if(fieldName == 'Name'){ //If Account Name, split the searched word(s) by space
                    valuesSeparatedBySpace = fieldValue.split(' ');
                    searchItemValues.put(fieldName, valuesSeparatedBySpace);
                }else{
                    valuesSeparatedBySpace.add(fieldValue); //Don't split the searched word(s) if not Account Name
                    searchItemValues.put(fieldName, valuesSeparatedBySpace);
                }
                searchAccountKey++;
            }
        }
        sortByField = (sortByField != '') ? sortByField : 'ORDER BY NAME ASC';

        String query = 'WHERE ';
        String queryName = ''; //Items for the closest match. Closest match will be the first ones on the list
        Integer startNumFields = 1;
        for(String field : searchItemValues.keySet()){
            query += (field == 'Name')? '(' : ''; //If Account Name, add parenthesis before the Name string for multiple Likes query
            query += field; //Add the Field Name

            queryName += (field == 'Name')? '(' : ''; //If Account Name, add parenthesis before the Name string for multiple Likes query (For the closes match)
            queryName += field; //Add the Field Name (For the closes match)

            Integer startFieldValue = 1;  //Starting number to iterate on each field.
            for (String fieldValue : searchItemValues.get(field)) {
                query += ' LIKE \'%'+fieldValue+'%\' '; //Insert the value for Like Query
                queryName += ' LIKE \'%'+fieldValue+'%\' '; //Insert the value for Like Query  (For the closes match)
                if(field == 'Name') { //If Account Name, Add OR if multiple search field values
                    if (startFieldValue != searchItemValues.get(field).size()) {
                        query += 'OR ' + field;
                        queryName += 'AND ' + field; // (For the closes match)
                    }
                    startFieldValue += 1;
                }
                //For the closing parenthesis on the Account Name
                query += (field == 'Name' && searchItemValues.get(field).size() < startFieldValue)? ') ' : '';
                queryName += (field == 'Name' && searchItemValues.get(field).size() < startFieldValue)? ') ' : ''; // (For the closes match)
            }
            if(startNumFields != searchItemValues.size()){ //Add AND for the next field if it's not the last field on the list
                query += 'AND ';
                queryName += 'AND ';
            }
            startNumFields += 1;
        }

        String selectFields = '';
        Integer currentSelectField = 1;

        for(SearchFields sf : columnAccountFields){
            selectFields += sf.name;
            if(currentSelectField < columnAccountFields.size()){
                selectFields += ', ';
            }
            currentSelectField += 1;
        }

        Integer offSetValue = (accountsPerPage * pageNumber);
        List<Account> accounts = new List<Account>(); //Initialize list of accounts to return
        Set<Id> accountIds = new Set<Id>(); //Account Ids Set. Purpose is to check if the account (from the second query) is already existing on the list.

        //Query for the closest match
        if(queryName != ''){
            queryName = 'SELECT Id, ' + selectFields + ' FROM Account WHERE ' + queryName + ' ' +sortByField + ' LIMIT ' + accountsPerPage + ' OFFSET ' + offSetValue;
            System.debug(queryName);
            for(Account acc : Database.query(queryName)){
                accounts.add(acc); //Add to the Accounts list
                accountIds.add(acc.Id); //Add the ids to the set for checking on the 2nd query
            }
        }

        accountsPerPage -= accountIds.size();

        query = 'SELECT Id, ' + selectFields + ' FROM Account ' + (query == 'WHERE ' ? 'WHERE ' : query + 'AND ') + ' Id !=:accountIds ' +sortByField + ' LIMIT ' + accountsPerPage + ' OFFSET ' + offSetValue;
        System.debug(query);

        for(Account acc : Database.query(query)){
            accounts.add(acc); //Add to the Accounts list
        }
        return accounts;
        
    }

    @AuraEnabled
    public static List<NewBatchTransactionComponentConfig__mdt> getBatchTransactionConfig(String type) {
        return [SELECT Id, Value__c, Division__c FROM NewBatchTransactionComponentConfig__mdt WHERE Type__c=:type];
    }

    public class SaveWrapper {
        @AuraEnabled
        public List<String> transactionSummaryList { get; set; }
        @AuraEnabled
        public boolean success { get; set; }
        @AuraEnabled
        public List<Transaction__c> transactions { get; set; }
        @AuraEnabled
        public integer transSize {
            get {
                if (transactions == null)
                    return 0;
                return transactions.size();
            }
        }
        @AuraEnabled
        public string batch {
            get {
                if (transactions == null)
                    return '';
                return transactions[0].BatchNumber__c;
            }
        }
        @AuraEnabled
        public List<CashierCode__c> codes { get; set; }
        @AuraEnabled
        public string error { get; set; }
        @AuraEnabled
        public Map<String, Map<String, String>> transactionAccountsMap { get; set; }

        public SaveWrapper(String error) {
            this.error = error;
            this.success = false;
        }

        public SaveWrapper(List<Transaction__c> trns, List<CashierCode__c> codes, List<SearchFields> accountSearchFields, String unserializedFields) {
            Map<String, Object> objectFieldsMap = (Map<String, Object>)JSON.deserializeUntyped(unserializedFields);
            List<Map<String, Object>> objectFieldsList = new List<Map<String, Object>>();
            for (Object instance : (List<Object>)objectFieldsMap.get('data')) {
                objectFieldsList.add((Map<String, Object>)instance);
            }

            String queryFields = '';
            Integer currentObject = 1;
            for(Map<String, Object> obj : objectFieldsList){
                for(String relationshipName : obj.keySet()){
                    String currentFields = (String) obj.get(relationshipName);

                    if(relationshipName == 'Transaction__c'){
						if(currentFields != 'BatchNumber__c'){
							queryFields += currentFields;
						}
                    }else{
                        //fields are separated by comma on the metadata. Split them into a list
                        List<String> fieldsList = currentFields.split(',');

                        Integer startNum = 1;
                        for(String fieldName : fieldsList){
                            queryFields += relationshipName + '.'+fieldName;
                            if(startNum != fieldsList.size()){
                                queryFields += ', ';
                            }
                            startNum += 1;
                        }

                    }
                    if(currentObject < objectFieldsList.size()){
                        queryFields += ', ';
                    }

                    currentObject += 1;
                }
            }

            Map<String, Map<String, String>> mappedAccount = new Map<String, Map<String, String>>();
            String query = 'SELECT Id, BatchNumber__c, ' + queryFields + ' FROM Transaction__c WHERE Id IN :trns';

            List<String> transactionSummaryList = new List<String>();
            this.transactions = Database.query(query);

            //Retrieve Object Fields and field data
            Schema.SObjectType transactionObjType = Schema.getGlobalDescribe().get('Transaction__c');
            Map<String, Schema.SobjectField> transFieldMap = transactionObjType.getDescribe().fields.getMap();

            for(Transaction__c transactionRecord : this.transactions){
                Map<String, String> accountValues = new Map<String, String>();
                for(SearchFields searchField : accountSearchFields){
                    String fieldValue = (String)transactionRecord.Account__r.get(searchField.name);
                    accountValues.put(searchField.label, (fieldValue == null ? '' : fieldValue));
                }
                mappedAccount.put(transactionRecord.Id, accountValues);

                for(Map<String, Object> obj : objectFieldsList) {
                    String transactionSummary = '';
                    for (String relationshipName : obj.keySet()) {
                        String currentFields = (String) obj.get(relationshipName);
                        List<String> fieldsList = currentFields.split(',');
                        if(relationshipName == 'Transaction__c'){
                            for(String fieldName : fieldsList){
                                Object fieldValue = transactionRecord.get(fieldName);
								fieldValue = (fieldValue == null) ? '' : fieldValue;
                                String fieldLabel = transFieldMap.get(fieldName).getDescribe().getLabel();
                                transactionSummary += fieldLabel + ': ' + fieldValue + '<br/>';
                            }
                        }else{
                            String getRelFieldname = relationshipName.replace('__r', '__c');
                            Schema.DescribeFieldResult f = Schema.getGlobalDescribe()
                                    .get('Transaction__c')
                                    .getDescribe()
                                    .fields
                                    .getMap()
                                    .get(getRelFieldname)
                                    .getDescribe();
                            String currentObjectFromRel = '';
                            for(Schema.SObjectType reference : f.getReferenceTo()) {
                                currentObjectFromRel = reference.getDescribe().getName();
                            }

                            //Retrieve Object Fields and field data
                            Schema.SObjectType currentObjType = Schema.getGlobalDescribe().get(currentObjectFromRel);
                            Map<String, Schema.SobjectField> currentObjFieldMap = currentObjType.getDescribe().fields.getMap();
                            for(String fieldName : fieldsList){
                                String fieldValue = (String) transactionRecord.getSobject(relationshipName).get(fieldName);
                                String fieldRelName = fieldName.replace(relationshipName + '.', '');
                                String fieldLabel = currentObjFieldMap.get(fieldRelName).getDescribe().getLabel();
                                fieldValue = (fieldValue == null) ? '' : fieldValue;
                                transactionSummary += fieldLabel + ': ' + fieldValue + '<br/>';
                            }

                        }
                        transactionSummaryList.add(transactionSummary);
                    }
                }
                String breakAfterRecord = '<br/>';
                transactionSummaryList.add(breakAfterRecord);
            }
            this.transactionAccountsMap = mappedAccount;
            this.codes = codes;
            this.success = true;
            this.transactionSummaryList = transactionSummaryList;
        }
    }
    
    public class TranWrapper {
        public string id { get; set; }
        public string workitem { get; set; }
        public string description { get; set; }
    }
    
    public class LineWrapper {
        public string code { get; set; }
        public string amount { get; set; }
        public string description { get; set; }
    }
    
    public class InitValues {
        @AuraEnabled
        public boolean showPVL { get; set; }
        @AuraEnabled
        public boolean showFile { get; set; }
        @AuraEnabled
        public boolean showOAH { get; set; }
        @AuraEnabled
        public boolean showPrjNo { get; set; }
        @AuraEnabled
        public List<SearchFields> searchAccountFields { get; set; }
        @AuraEnabled
        public List<SearchFields> printAccountFields { get; set; }
        @AuraEnabled
        public List<SearchFields> columnAccountFields { get; set; }
        @AuraEnabled
        public String printFields { get; set; }
        @AuraEnabled
        public List<SearchFields> accountColumnFields { get; set; }
    }

    public class SearchFields {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String value { get; set; }
    }
    
}