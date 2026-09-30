/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the New Transaction component - Allows the user to create a transaction
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint-LC040819 - Created for DCCA phase 1
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class NewTransaction {
    
    @AuraEnabled
    public static InitValues getInitialValues() {
        InitValues toReturn = new InitValues();
        
        toReturn.recTypes = [SELECT Id, Name FROM RecordType WHERE sObjectType = 'Account'];
        toReturn.colspanNoResults = 3; //To Center the No Results Message; Table format
        toReturn.accountColumnFields = new List<SearchFields>(); //List of Fields for the columns on the account list

        //Field for the columns on the account list
        SearchFields acctNameField = new SearchFields();
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
        toReturn.colspanNoResults += (toReturn.showPVL ? 1 : 0) + (toReturn.showFile ? 1 : 0) + (toReturn.showOAH ? 1 : 0) + (toReturn.showPrjNo ? 1 : 0);

        //Fields for the columns on the account list
        if(toReturn.showPVL) {
            SearchFields acctField = new SearchFields();
            acctField.label = 'PVL BP Id';
            acctField.name = 'BPID__c';
            toReturn.accountColumnFields.add(acctField);
        }
        SearchFields licenseNumber = new SearchFields();
        licenseNumber.label = 'License Number';
        licenseNumber.name = 'LicenseNumbers__c';
        toReturn.accountColumnFields.add(licenseNumber);
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

        SearchFields acctField = new SearchFields();
        acctField.label = 'CRD Number';
        acctField.name = 'CRD__c';
        toReturn.accountColumnFields.add(acctField);


        return toReturn;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Account> searchLines(string name, string fileId, string pvlbpId, string oah, string prjNo, string crdNumber, Integer accountsPerPage, Integer pageNumber) {
        pageNumber -= 1;
        String sortByField = 'ORDER BY NAME ASC';

        string query = 'WHERE ';
        String queryName = 'WHERE '; //Items for the closest match. Closest match will be the first ones on the list

        //Check if Name is Not Null or Not Empty
        if (name != null && name != '') {
            query += '(';
            queryName += '(';
            List<String> nameSeparatedBySpace = name.split(' '); //Initialize list
            Integer startingValue = 1;
            for(String nameValue : nameSeparatedBySpace){
                query += 'Name LIKE \'%'+nameValue+'%\' '; //Insert the value for Like Query
                queryName += 'Name LIKE \'%'+nameValue+'%\' '; //Insert the value for Like Query
                if(startingValue != nameSeparatedBySpace.size()){
                    query += 'OR ';
                    queryName += 'AND ';
                }
                startingValue++;
            }
            query += ')';
            queryName += ')';
        }

        if (fileId != null && fileId != '') {
            if (query != 'WHERE ') {
                query += ' AND ';
                queryName += ' AND ';
            }
            query += 'FileID__c = :fileId';
            queryName += 'FileID__c = :fileId';
        }
        if (pvlbpId != null && pvlbpId != '') {
            if (query != 'WHERE ') {
                query += ' AND ';
                queryName += ' AND ';
            }
            query += 'BPID__c = :pvlbpId';
            queryName += 'BPID__c = :pvlbpId';
        }
        if (oah != null && oah != '') {
            if (query != 'WHERE ') {
                query += ' AND ';
                queryName += ' AND ';
            }
            query += 'OAH_Case_Number__c = :oah';
            queryName += 'OAH_Case_Number__c = :oah';
        }
        if (prjNo != null && prjNo != '') {
            if (query != 'WHERE ') {
                query += ' AND ';
                queryName += ' AND ';
            }
            query += 'ProjectNumber__c = :prjNo';
            queryName += 'ProjectNumber__c = :prjNo';
        }
        if (crdNumber != null && crdNumber != '') {
            if (query != 'WHERE ') {
                query += ' AND ';
                queryName += ' AND ';
            }
            query += 'CRD__c = :crdNumber';
            queryName += 'CRD__c = :crdNumber';
        }

        Integer offSetValue = (accountsPerPage * pageNumber);
        Set<Id> accountIds = new Set<Id>(); //Account Ids Set. Purpose is to check if the account (from the second query) is already existing on the list.
        List<Account> accounts = new List<Account>(); //Initialize list of accounts to return

         //Query for the closest match
        if(queryName != 'WHERE '){
            queryName = 'SELECT Id, Name, FileID__c, BPID__c, OAH_Case_Number__c, ProjectNumber__c, CRD__c, LicenseNumbers__c FROM Account ' + queryName + ' ' + sortByField + ' LIMIT ' + accountsPerPage + ' OFFSET ' + offSetValue;
            System.debug(queryName);
            for(Account acc : Database.query(queryName)){
                accounts.add(acc); //Add to the Accounts list
                accountIds.add(acc.Id); //Add the ids to the set for checking on the 2nd query
            }
        }

        accountsPerPage -= accounts.size();
        query = 'SELECT Id, Name, FileID__c, BPID__c, OAH_Case_Number__c, ProjectNumber__c, CRD__c, LicenseNumbers__c FROM Account ' + (query == 'WHERE ' ? 'WHERE ' : query + ' AND ') + ' Id !=:accountIds ' + sortByField + ' LIMIT ' + accountsPerPage + ' OFFSET ' + offSetValue;
        System.debug(query);

        for(Account acc : Database.query(query)){
            accounts.add(acc); //Add to the Accounts list
        }

        return accounts;
        
    }
    
    @AuraEnabled
    public static String saveNewAccount(string accType, string name, string firstname, string lastname, string fileId, string pvlbpId, string oah, string prjNo, string licenses) {
        
        try {
            Account acc = new Account();
            acc.RecordTypeId = accType;
            if (accType == '012t0000000PLy1AAG') {
            	acc.Name = name;
            } else {
            	acc.FirstName = firstname;
            	acc.LastName = lastname;
            }
            acc.FileID__c = fileId;
            acc.BPID__c = pvlbpId;
            acc.OAH_Case_Number__c = oah;
            acc.ProjectNumber__c = prjNo;
            acc.LicenseNumbers__c = licenses;
            insert acc;
            
            return acc.Id;
        } catch (Exception ex) {
            return ex.getMessage();
        }
        
    }
    
    @AuraEnabled
    public static List<string> getLicenseCodes(string accId) {
        Account acc = [SELECT LicenseNumbers__c FROM Account WHERE Id = :accId];
        List<string> toReturn = new List<string>();
        if (acc.LicenseNumbers__c != null) {
            for (String lincenseNo1 : acc.LicenseNumbers__c.split(',')) {
                for (String lincenseNo : lincenseNo1.split(' ')) {
                    string lNo = lincenseNo.trim();
                    if (lNo != '') {
                        toReturn.add(lNo);
                    }
                }
            }
        }
        return toReturn;
    }

    @AuraEnabled
    public static String saveTransaction(string accId, string lines, string licenseNo) {
        List<LineWrapper> linesList = (List<LineWrapper>)JSON.deserialize(lines, List<LineWrapper>.class);
        
        Set<Id> ccSet = new Set<Id>();
        for (LineWrapper lw : linesList) {
            if (lw.code != null && lw.code != '') {
                ccSet.add(lw.code);
            }
        }
        Map<Id, CashierCode__c> ccMap = new Map<Id, CashierCode__c>([SELECT Amount__c, Division__c FROM CashierCode__c WHERE Id IN :ccSet]);
        
        List<TransactionLine__c> linesToInsert = new List<TransactionLine__c>();
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
                linesToInsert.add(lineToInsert);
            }
        }
        
        if (linesToInsert.size() > 0) {
            CashierCode__c cc = ccMap.values()[0];
        	Account acc = [SELECT LicenseNumbers__c  FROM Account WHERE Id = :accId];
        
            Savepoint sp = Database.setSavepoint();
            
            try {
                Transaction__c trans = new Transaction__c();
                trans.Date__c = Date.today();
                trans.Status__c = 'New';
                trans.TransactionType__c = 'Payment';
                trans.Account__c = accId;
                trans.Division__c = cc.Division__c;
                trans.LicenseNumbers__c = licenseNo;
                insert trans;
                
                for (TransactionLine__c lineToInsert : linesToInsert) {
                    lineToInsert.Transaction__c = trans.Id;
                }
                insert linesToInsert;
                
                return trans.Id;
            } catch (Exception ex) {
                Database.rollback(sp);
                return 'Error : ' + ex.getMessage();
            }
        } else {
            return 'Error : Please add at least one cashier code.';
        }
    }
    
    public class InitValues {
        @AuraEnabled
        public List<RecordType> recTypes { get; set; }
        @AuraEnabled
        public boolean showPVL { get; set; }
        @AuraEnabled
        public boolean showFile { get; set; }
        @AuraEnabled
        public boolean showOAH { get; set; }
        @AuraEnabled
        public boolean showPrjNo { get; set; }
        @AuraEnabled
        public Integer colspanNoResults{ get; set; }
        @AuraEnabled
        public List<SearchFields> accountColumnFields { get; set; }
    }

    public class SearchFields {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String name { get; set; }
    }
    
    public class LineWrapper {
        public string code { get; set; }
        public string amount { get; set; }
        public string description { get; set; }
    }
}