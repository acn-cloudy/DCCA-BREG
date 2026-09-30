/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Group transactions 2 component - Allows the user to group multiple transactions
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
public class GroupTransactions2 {

    @AuraEnabled
    public static InitValues getInitialValues() {
        InitValues toReturn = new InitValues();

        toReturn.colspanNoResults = 3; //To Center the No Results Message; Table format
        toReturn.recTypes = [SELECT Id, Name FROM RecordType WHERE sObjectType = 'Account'];

        User myUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        List<string> divisions = new List<string>();
        if (myuser.Division__c != null)
            divisions = myUser.Division__c.split(';');
        toReturn.showPVL = divisions.contains('PVL');
        toReturn.showFile = divisions.contains('BREG');
        toReturn.showOAH = divisions.contains('OAH');
        toReturn.showPrjNo = divisions.contains('PVL Real Estate');
        toReturn.colspanNoResults += (toReturn.showPVL ? 1 : 0) + (toReturn.showFile ? 1 : 0) + (toReturn.showOAH ? 1 : 0) + (toReturn.showPrjNo ? 1 : 0);

        toReturn.accountColumnFields = new List<SearchFields>(); //List of Fields for the columns on the account list

        //Field for the columns on the account list
        SearchFields acctNameField = new SearchFields();
        acctNameField.label = 'Name';
        acctNameField.name = 'Name';
        toReturn.accountColumnFields.add(acctNameField);

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

        return toReturn;
    }

    @AuraEnabled
    public static String saveTransactions(String accId, List<string> transIds) {
        Savepoint sp = Database.setSavepoint();

        try {
            Transaction__c transToInsert = new Transaction__c();
            transToInsert.Account__c = accId;
            transToInsert.ParentTotalAmount__c = 0;
            transToInsert.TotalAmount__c = 0;
            transToInsert.TransactionType__c = 'Group';
            transToInsert.Date__c = Date.Today();
            List<Transaction__c> xlines = [SELECT Id, TotalAmount__c, Division__c FROM Transaction__c WHERE Id IN :transIds];
            for (Transaction__c line : xlines) {
                transToInsert.Division__c = line.Division__c;
                // sum all the amounts and add the total on the parent record
                if (line.TotalAmount__c != null) {
                    transToInsert.ParentTotalAmount__c += line.TotalAmount__c;
                    transToInsert.TotalAmount__c += line.TotalAmount__c;
                }
            }
            insert transToInsert;

            for (Transaction__c line : xlines) {
                line.TransactionGroup__c = transToInsert.Id;
            }
            update xlines;

            return transToInsert.Id;
        } catch (Exception ex) {
            Database.rollback(sp);
            return 'Error : ' + ex.getMessage() + ex.getStackTraceString();
        }

    }

    @AuraEnabled
    public static List<Transaction__c> searchLines(string name,
                                                   string fileId,
                                                   string pvlbpId,
                                                   string workItemId,
                                                   string crdNumber,
                                                   string refNum
                                                   ) {

        string query = 'WHERE (Status__c = \'New\' OR Status__c = \'Pending\')';

        //Check if Name is Not Null or Not Empty
        if (name != null && name != '') {
            query += ' AND (';
            List<String> nameSeparatedBySpace = name.split(' '); //Initialize list
            Integer startingValue = 1;
            for(String nameValue : nameSeparatedBySpace){
                query += 'Account__r.Name LIKE \'%'+nameValue+'%\' '; //Insert the value for Like Query
                if(startingValue != nameSeparatedBySpace.size()){
                    query += 'OR ';
                }
                startingValue++;
            }
            query += ')';
        }
        if (fileId != null && fileId != '') {
            query += ' AND Account__r.FileID__c = :fileId';
        }
        if (pvlbpId != null && pvlbpId != '') {
            query += ' AND Account__r.BPID__c = :pvlbpId';
        }
        if (workItemId != null && workItemId != '') {
            query += ' AND WorkitemID__c = :workItemId';
        }
        if (crdNumber != null && crdNumber != '') {
            query += ' AND Account__r.CRD__c = :crdNumber';
        }
        if (refNum != null && refNum != '') {
            if(refNum.length() < 9){
                Integer index = 9-refNum.length();
                for(Integer i=0;i<index; i++ ) {
                    refNum = '0' + refNum;
                }
            }
            query += ' AND Name = :refNum';
        }

        query = 'SELECT Id, Name, Account__r.Name, AmountOutstanding__c, WorkitemID__c, TotalAmount__c FROM Transaction__c ' + query + ' LIMIT 10';
        System.debug(query);
        return Database.query(query);

    }

    @AuraEnabled(cacheable=true)
    public static List<Account> searchLines1(string name, string fileId, string pvlbpId, string oah, string prjNo, string crdNumber, Integer accountsPerPage, Integer pageNumber) {
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
            }
            query += 'OAH_Case_Number__c = :oah';
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
        List<Account> accounts = new List<Account>(); //Initialize list of accounts to return
        Set<Id> accountIds = new Set<Id>(); //Account Ids Set. Purpose is to check if the account (from the second query) is already existing on the list.

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
        query = 'SELECT Id, Name, FileID__c, BPID__c, OAH_Case_Number__c, ProjectNumber__c, CRD__c, LicenseNumbers__c FROM Account ' + (query == 'WHERE ' ? 'WHERE ' : query + ' AND') + ' Id !=:accountIds ' + sortByField + ' LIMIT ' + accountsPerPage + ' OFFSET ' + offSetValue;
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
        public Integer colspanNoResults { get; set; }
        @AuraEnabled
        public List<SearchFields> accountColumnFields { get; set; }
    }

    public class SearchFields {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String name { get; set; }
    }
}