public with sharing class TDRFormController {
    public List<Map<String, Object>> allRecords {
        set;get;
    }
    public List<FiscalFormFeed> values {
        set;get;
    }
    public String copyStr {
        set;get;
    }
    public String userName{
        get;set;
    }
    public List<String> copies {
        set;get;
    }
    public TDRFormController() {
        userName = UserInfo.getName();
        values = new List<FiscalFormFeed>();

        String recordId = System.currentPageReference().getParameters().get('recordId');
        String copy = System.currentPageReference().getParameters().get('copy');
        if (copy == null) copyStr = 'COPY #1 - STATE TREASURY';
        if (copy == '1') copyStr = 'COPY #1 - STATE TREASURY';
        if (copy == '2') copyStr = 'COPY #2 - STATE COMPTROLLER';
        if (copy == '3') copyStr = 'COPY #3 - DEPARTMENT FISCAL OFFICE';
        if (copy == '4') copyStr = 'COPY #4 - DEPARTMENT FISCAL OFFICE (FOLLOW-UP COPY)';
        if (recordId != null) {
            FiscalForm__c record = [Select Id, StartDate__c, EndDate__c, Request__c
            from FiscalForm__c where Id =: recordId];
            String request = record.Request__c;
            values = (List<FiscalFormFeed>)JSON.deserialize(request, List<FiscalFormFeed>.class);
        } else {

            FiscalFormFeed formFeed = new FiscalFormFeed();
            formFeed.bankDeposit = '99.01';
            formFeed.electronicFundTransfer = '99.01';
            formFeed.creditCardProcessing = '99.01';
            formFeed.others = '99.01';
            formFeed.dateStr = '99/99/9999';
            formFeed.detailFund = 'detailFund REGISTRATION - CRF';
            formFeed.fundName = 'fundName';
            formFeed.remarks = '02/25.26.27 First Hawaii';
            formFeed.remarks = 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis,';
            formFeed.totalDeposit = '99.01';
            formFeed.totalDeposit2 = '99.01';

            FiscalFormFeed.DataFeed dataFeed = new FiscalFormFeed.DataFeed();
            dataFeed.indexValue = '99';
            dataFeed.tcValue = '999';
            dataFeed.sValue = 'S';
            dataFeed.yrValue = '99';
            dataFeed.appValue = '999';
            dataFeed.dValue = 'P';
            dataFeed.sourceObjValue = '9999';
            dataFeed.costCenterValue = '9999';
            dataFeed.amount = 99.01;
            dataFeed.revValue = 'R';

            List<FiscalFormFeed.DataFeed> fundsList = new List<FiscalFormFeed.DataFeed>();
            FiscalFormFeed.DataFeed dataFeed2 = (FiscalFormFeed.DataFeed) dataFeed.clone();
            dataFeed2.amount = 99;
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed2);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);
            fundsList.add(dataFeed);

            formFeed.funds = fundsList;

            values.add(formFeed);
            values.add(formFeed);
        }

        this.copies = new List<String>{'COPY #1 - STATE TREASURY', 'COPY #2 - STATE COMPTROLLER',
            'COPY #3 - DEPARTMENT FISCAL OFFICE', 'COPY #4 - DEPARTMENT FISCAL OFFICE (FOLLOW-UP COPY)'};


    }

    @AuraEnabled(cacheable = true)
    public static List<Map<String, String>> getTdrDepositOptions() {
        List<Map<String, String>> result = new List<Map<String, String>>();

        for (Deposits__c deposit : [SELECT Id, Name FROM Deposits__c WHERE Notes__c = 'Pending TDR' AND PUCDeposit__c = false ORDER BY Name ASC]) {
            Map<String, String> opt = new Map<String, String>();
            opt.put('label', deposit.Name);
            opt.put('value', deposit.Id);
            result.add(opt);
        }

        return result;
    }

    @AuraEnabled
    public static void saveAsFile(String recordId) {
        Map<String, Blob> files = new Map<String, Blob>();
        for (Integer i = 1;i < 5; i++) {
            PageReference pageRef = Page.TDR;
            pageRef.getParameters().put('recordId', recordId);
            pageRef.getParameters().put('copy', i + '');
            Blob content = Test.isRunningTest() ? Blob.valueOf('test') : pageRef.getContent();
            String docName = 'TDRFile(COPY' + i + ').pdf';
            files.put(docName, content);
        }

        PageReference pageCopyRef = Page.TDRCopies;
        pageCopyRef.getParameters().put('recordId', recordId);
        Blob docCopyContent = Test.isRunningTest() ? Blob.valueOf('test') : pageCopyRef.getContent();
        files.put('TDRFile.pdf', docCopyContent);

        List<SpringCMDocument> result = SpringCMConnector.createFiles(recordId, files);


    }

    @AuraEnabled
    public static String submitForFile(String str, String recordId, String recordTypeId, String feedStr) {
        FiscalFormFeed.SearchFeed feed = (FiscalFormFeed.SearchFeed) JSON.deserialize(feedStr, FiscalFormFeed.SearchFeed.class);
        List<FiscalForm__c> records = new List<FiscalForm__c>();

        if (!String.isBlank(recordId)) {
            records = [Select Id, Request__c, PaymentType__c, FundType__c, StartDate__c, EndDate__c, Division__c from FiscalForm__c where Id =: recordId limit 1];
            for (FiscalForm__c record : records) {
                record.Request__c = str;
                recordId = record.Id;
                record.PaymentType__c = feed.paymentType;
                record.Division__c = feed.division;
                record.FundType__c = feed.fundType;
                record.StartDate__c = feed.startDate;
                record.EndDate__c = feed.cutOffDate;
            }
            update records;
        } else {
            FiscalForm__c record = new FiscalForm__c();
            record.RecordTypeId = recordTypeId;
            record.Request__c = str;
            record.PaymentType__c = feed.paymentType;
            record.Division__c = feed.division;
            record.FundType__c = feed.fundType;
            record.StartDate__c = feed.startDate;
            record.EndDate__c = feed.cutOffDate;
            insert record;
            recordId = record.Id;
        }


        return recordId;

    }

    @AuraEnabled
    public static string searchData(String feedStr) {
        FiscalFormFeed.SearchFeed feed = (FiscalFormFeed.SearchFeed) JSON.deserialize(feedStr, FiscalFormFeed.SearchFeed.class);
        DateTime cutOffDate;
        DateTime startDate;
        String division;
        Boolean isCreditCard = feed.paymentType == 'Credit Card';
        List<String> paymentTypes = new List<String>();
        Set<String> excludedUserIds = new Set<String>();

        String query = 'Select Id, CutOffBatchDate__c, NetCollectionsafterFeesAllocated__c,  TransactionLine__r.CashierCode__c, AmountAllocated__c, AmountfromTransactionLine__c, AmountfromPayment__c, ' +
            ' TransactionLine__r.CashierCode__r.CostCenter__c, TransactionLine__r.CashierCode__r.FundAccount__c, ' +
            ' TransactionLine__r.CashierCode__r.Division__c, TransactionLine__r.CashierCode__r.FAMISSrcCode__c, ' +
            ' TransactionLine__r.CashierCode__r.FeeCode__c, PaymentType__c from CollectionsAllocation__c ' +
            ' where Payment__r.pymt__Status__c IN (\'Completed\',\'BCF\') ';

        if (isCreditCard) {
            query += ' AND (Payment__r.pymt__Transaction_Type__c = \'Payment\' OR Payment__r.pymt__Transaction_Type__c = \'Refund\') ';
        } else {
            query += ' AND Payment__r.pymt__Transaction_Type__c = \'Payment\' ';
        }

        if (String.isNotBlank(feed.paymentType) && feed.paymentType == 'Cash') {
            for (PermissionSetAssignment psa : [
                SELECT
                    Id,
                    AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSet.Name = 'ExcludeFromFiscalTDRForm'
            ]) {
                excludedUserIds.add(psa.AssigneeId);
            }

            query += ' AND Payment__r.CreatedById NOT IN :excludedUserIds ';
        }

        DateTime serviceDateTime = System.now();
        Integer offsetHours = UserInfo.getTimeZone().getOffset(serviceDateTime) / 1000 / 60 / 60;

        if (feed.cutOffDate != null) {
            cutOffDate = feed.cutOffDate;
            cutOffDate = cutOffDate.addDays(1);
            cutOffDate = cutOffDate.addHours(-(offsetHours));

            query += ' and CutOffBatchDate__c <: cutOffDate ';
        }

        if (feed.startDate != null) {
            startDate = feed.startDate;
            startDate = startDate.addHours(-(offsetHours));
            query += ' and CutOffBatchDate__c >=: startDate ';
        }

        if (!String.isBlank(feed.division)) {
            division = feed.division;
            if (division == 'PUC') {
                query += ' AND Division__c = :division ';
            } else {
                query += ' AND Division__c <> \'PUC\' ';
            }
        } else {
            query += ' AND Division__c <> \'PUC\' ';
        }

        List<String> trustAccountFilter;
        String tempFilterFundAccount = feed.fundAccounts;
        if (String.isNotBlank(feed.fundType)) {
            if (feed.fundType != 'Trust') {
                query += ' and TransactionLine__r.CashierCode__r.FundAccount__c = :tempFilterFundAccount';
            } else {
                trustAccountFilter = (List<String>) JSON.deserialize(tempFilterFundAccount, List<String>.class);
                query += ' and TransactionLine__r.CashierCode__r.FundAccount__c IN :trustAccountFilter';
            }
        }

        Boolean hasPaymentTypeFilter = false;
        List<String> depositIds;
        if (!String.isBlank(feed.paymentType)) {
            hasPaymentTypeFilter = true;
            if (isCreditCard) {
                paymentTypes.add('Credit Card');
                paymentTypes.add('ECheck');

                if (String.isNotBlank(feed.selectedDeposits)) {
                    depositIds = (List<String>) JSON.deserialize(feed.selectedDeposits, List<String>.class);
                    query += ' and Deposit__c IN :depositIds ';
                }

            } else if (feed.paymentType == 'Cash') {
                paymentTypes.add('Cash');
                paymentTypes.add('Money Order');
                paymentTypes.add('Cashier\'s Check');
                paymentTypes.add('Check');
            } else if (feed.paymentType == 'EFT') {
                paymentTypes.add('Electronic Funds Transfer');
            }
            query += ' and PaymentType__c in: paymentTypes ';

            if (!isCreditCard) {
                query += ' AND AmountAllocated__c >= 0 ';
            }
        }

        query += ' ORDER BY TransactionLine__r.CashierCode__r.FundAccount__c';

        List<CollectionsAllocation__c> collectionAllocations = Database.query(query);

        if (!hasPaymentTypeFilter) {
            collectionAllocations = removeNegativeAllocation(collectionAllocations);
        }

        List<String> cRecordIds = new List<String>();

        Map<String, Decimal> cashierCodeAmount = (new CollectionsAllocationDomain(collectionAllocations))
            .summarizeAllocationRecordAmount(feed.paymentType);

        String yearStr = '00';
        if ((cutOffDate != null || isCreditCard) && feed.fundType != 'General') {
            cutOffDate = cutOffDate == null ? System.today() : cutOffDate;
            Integer month = cutOffDate.month();
            Integer year = cutOffDate.year();
            if (month > 6) {
                year++;
            }
            yearStr = '' + year;
            yearStr = yearStr.substring(2, 4);
        }

        List<FiscalFormFeed.DataFeed> feeds = (new CollectionsAllocationDomain(collectionAllocations)).getDataFeeds(cashierCodeAmount, yearStr);
        feeds.sort();

        Integer index = 1;
        for (FiscalFormFeed.DataFeed f : feeds) {
            String indexValue = '' + index;

            if (indexValue.length() == 1) {
                indexValue = '0' + indexValue;
            }

            f.indexValue = indexValue;
            f.elemKey = f.appValue;
            index++;
            if (index == 15) {
                index = 1;
            }
        }
        return JSON.serialize(feeds);
    }

    //case 00028187
    private static List<CollectionsAllocation__c> removeNegativeAllocation(List<CollectionsAllocation__c> collectionsAllocations) {
        List<CollectionsAllocation__c> result = new List<CollectionsAllocation__c>();
        for (collectionsAllocation__c c : collectionsAllocations) {
            if (c.PaymentType__c != 'Credit Card' && c.AmountAllocated__c < 0) {
                continue;
            }

            result.add(c);
        }

        return result;
    }
}