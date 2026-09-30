/****
 * Description: Fiscal Forms Controller
 * Date: 25/08/2020
 * Pacificpoint-AZ20200825
 * **** */
public with sharing class FiscalFormsController {
    @AuraEnabled
    public static string initFiscalForms(String recordTypeId) {
        FiscalForm__c record = new FiscalForm__c();
        record.RecordTypeId = recordTypeId;
        insert record;
        return record.Id;
    }
    @AuraEnabled
    public static String getRecordType(String recordTypeId) {
        Schema.DescribeSObjectResult d = Schema.SObjectType.FiscalForm__c; 
        Map<Id,Schema.RecordTypeInfo> rtMapById = d.getRecordTypeInfosById();
        return rtMapById.get(recordTypeId).getName();
    }

    
    @AuraEnabled
    public static void saveJVFile(String recordId) {
        PageReference pageRef = Page.JV;
        pageRef.getParameters().put('recordId', recordId);
        Blob content ;
        if(Test.isRunningTest()) {
            content = Blob.valueOf('Tet');
        } else {
            content = pageRef.getContent();
        }
        
        String docName = 'JVFile.pdf';
        List<SpringCMDocument> result = SpringCMConnector.createFile(recordId, docname, content);
        ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.VersionData = content;
            cv.Title = docName;
            cv.PathOnClient = '/'+docName;
            insert cv;
            ContentVersion cDoc = [Select ContentDocumentId from ContentVersion Where Id =: cv.Id];
            String contentDocumentId = cDoc.ContentDocumentId;
            ContentDocumentLink cDe = new ContentDocumentLink();
            cDe.ContentDocumentId = cDoc.ContentDocumentId;
            cDe.LinkedEntityId = recordId;
            cDe.ShareType = 'I';
            cDe.Visibility = 'AllUsers';
            insert cDe;
    }
    @AuraEnabled
    public static void saveAsFile(String recordId) {
        PageReference pageRef = Page.TDR;
        pageRef.getParameters().put('recordId', recordId);
        Blob content ;
        if(Test.isRunningTest()) {
            content = Blob.valueOf('test');
        } else {
            content = pageRef.getContent();
        }
        String docName = 'TDRFile.pdf';
        // List<SpringCMDocument> result = SpringCMConnector.createFile(recordId, docname, content);
        // ContentVersion cv = new ContentVersion();
        //     cv.ContentLocation = 'S';
        //     cv.VersionData = content;
        //     cv.Title = docName;
        //     cv.PathOnClient = '/'+docName;
        //     insert cv;
        //     ContentVersion cDoc = [Select ContentDocumentId from ContentVersion Where Id =: cv.Id];
        //     String contentDocumentId = cDoc.ContentDocumentId;
        //     ContentDocumentLink cDe = new ContentDocumentLink();
        //     cDe.ContentDocumentId = cDoc.ContentDocumentId;
        //     cDe.LinkedEntityId = recordId;
        //     cDe.ShareType = 'I';
        //     cDe.Visibility = 'AllUsers';
        //     insert cDe;
    }
    public static String getFormName(FiscalForm__c record) {
        String recordTypeId = record.RecordTypeId;
        String recordTypeName = getRecordType(recordTypeId);
        String name = '';
        if(record.StartDate__c != null && record.EndDate__c != null) {
            Integer startMonth = record.StartDate__c.month();
            Integer endMonth = record.EndDate__c.month();
            Integer startDay = record.StartDate__c.day();
            Integer endDay = record.EndDate__c.day();
            Integer startYear = record.StartDate__c.year();
            Integer endYear = record.EndDate__c.year();
            name = recordTypeName + ': ' + startMonth + '/' + startDay + '/' + startYear 
                + ' - ' + endMonth + '/' + endDay + '/' + endYear ;
        } else {
            Date d = System.today();
            Integer month = d.month();
            Integer day = d.day();
            Integer year = d.year();
            
            name = recordTypeName + ': ' + month + '/' + day + '/' + year;
        }
        return name;
    }
    @AuraEnabled
    public static String submitForFile(String str, String recordId, String recordTypeId, String feedStr) {
        FiscalFormFeed.SearchFeed feed = (FiscalFormFeed.SearchFeed) JSON.deserialize(feedStr, FiscalFormFeed.SearchFeed.class);
        List<FiscalForm__c> records = new List<FiscalForm__c>();
        
        if(!String.isBlank(recordId)) {
            records = [Select Id, Request__c,PaymentType__c , FundType__c, StartDate__c, EndDate__c, Division__c from FiscalForm__c where Id =: recordId limit 1];
            for(FiscalForm__c record: records) {
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
            record.Name = getFormName(record);
            insert record;
            recordId = record.Id;
        }
        String rtId = Schema.SObjectType.FiscalForm__c.getRecordTypeInfosByDeveloperName().get('JV').getRecordTypeId();
        if(recordTypeId == rtId) {
            // to create Data
            List<FiscalFormFeed> feeds = (List<FiscalFormFeed>)JSON.deserialize(str, List<FiscalFormFeed>.class);
            List<String> allocationIds = new List<String>();
            for(FiscalFormFeed formFeed: feeds) {
                for(FiscalFormFeed.DataFeed dFeed: formFeed.funds)
                    allocationIds.add(dFeed.recordId);
            }
            List<CollectionsAllocation__c> allocations = [Select Id, JVProcessed__c from CollectionsAllocation__c where Id =: allocationIds];
            (new CollectionsAllocationDomain(allocations)).checkJVProcessed();
            update allocations;
        }
        
        
        return recordId;

    }
    @AuraEnabled
    public static string searchJVData(String feedStr) {
        FiscalFormFeed.SearchFeed feed = (FiscalFormFeed.SearchFeed) JSON.deserialize(feedStr, FiscalFormFeed.SearchFeed.class);
        String fundTypeFL ;
        Date cutOffDate;
        Date startDate;
        Date lastWeekDate;
        String division;
        List<String> paymentTypes = new List<String>();
        String query = 'Select Id, CutOffBatchDate__c, NetCollectionsafterFeesAllocated__c, Payment__r.Name, Transaction__c, AmountAllocated__c, TransactionLine__r.CashierCode__c, AmountfromTransactionLine__c, '
        + 'TransactionLine__r.CashierCode__r.CostCenter__c, JVProcessed__c, TransactionLine__r.CashierCode__r.FundAccount__c, TransactionLine__r.CashierCode__r.Division__c, '
        +' TransactionLine__r.CashierCode__r.FAMISSrcCode__c, TransactionLine__r.CashierCode__r.FeeCode__c, PaymentType__c, AmountfromPayment__c, '
        +' TransactionLine__r.CashierCode__r.CashierCode__c from CollectionsAllocation__c '
        +' Where Payment__r.pymt__Status__c = \'BCF\' and JVProcessed__c != true and AmountAllocated__c < 0';

        if(feed.cutOffDate != null) {
            cutOffDate = feed.cutOffDate;
            // lastWeekDate = cutOffDate.addDays(-7);
            query += ' and CutOffBatchDate__c <=: cutOffDate ';
            // +'and CutOffBatchDate__c >=: lastWeekDate '; 
        }
        if(feed.startDate != null) {
            startDate = feed.startDate;
            query += ' and CutOffBatchDate__c >=: startDate ';
        }
        if(!String.isBlank(feed.division)) {
            division = feed.division;
            query += ' and TransactionLine__r.CashierCode__r.Division__c =: division ';
        }
        if(!String.isBlank(feed.fundType) && feed.fundType != 'Special') {
            fundTypeFL = feed.fundType.substring(0, 1);
            fundTypeFL = fundTypeFL + '%';
            query += ' and TransactionLine__r.CashierCode__r.FundAccount__c like: fundTypeFL ';
        }

        if(!String.isBlank(feed.paymentType)) {
            if(feed.paymentType == 'Credit Card') {
                paymentTypes.add('Credit Card');
                paymentTypes.add('ECheck');
            } else if(feed.paymentType == 'Cash') {
                paymentTypes.add('Cash');
                paymentTypes.add('Money Order');
                paymentTypes.add('Cashier\'s Check');
                paymentTypes.add('Check');
                paymentTypes.add('Journal Voucher (JV)');
            } else if(feed.paymentType == 'EFT') {
                paymentTypes.add('Electronic Funds Transfer');
            }
            query += ' and PaymentType__c in: paymentTypes ';
        }
        query  += ' order by Transaction__c';
        System.debug('######query######' + query);
        List<CollectionsAllocation__c> collectionAllocations = Database.query(query);
        String yearStr = cutOffDate.year() + '';
        List<FiscalFormFeed.DataFeed> feeds = (new CollectionsAllocationDomain(
            collectionAllocations)).getJVFeeds(yearStr.substring(2, 4));
        return JSON.serialize(feeds);
        // return null;

    }
}