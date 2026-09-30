global class ReconciliationBatchJob implements schedulable, Database.Batchable<SObject>, Database.Stateful {

    /*
     * variables
     */
    public Integer batchSize;
    public List<CollectionsAllocation__c> updateCA;
    String csv;
    String creditCardCsv;
    String nonCreditCardCsv;

    // NEW
    public Boolean isCloseOutMode;
    public Id runningUserId;

    /*
     * construction
     */
    global ReconciliationBatchJob() {
        this(false, UserInfo.getUserId());
    }

    // NEW CONSTRUCTOR
    global ReconciliationBatchJob(Boolean isCloseOutMode, Id userId) {
        this.batchSize = 50;
        this.updateCA = new List<CollectionsAllocation__c>();
        this.csv = '';
        this.creditCardCsv = '';
        this.nonCreditCardCsv = '';
        this.isCloseOutMode = isCloseOutMode;
        this.runningUserId = userId;
    }

    /*
     * collect the batches
     */
    global Database.QueryLocator Start(Database.BatchableContext context) {

        String query = 'SELECT Id, ' +
            'NetCollectionsafterFeesAllocated__c, ' +
            'PaymentType__c, ' +
            'Payment__r.RemitToDCCA__c, ' +
            'Payment__r.pymt__Payment_Type__c, ' +
            'Payment__r.pymt__Status__c, ' +
            'Payment__r.CreatedById, ' +
            'Payment__r.CreatedBy.Name, ' +
            'Payment__r.OwnerId, ' +
            'Payment__r.Owner.Name, ' +
            'Transaction__r.Account__r.Name, ' +
            'Transaction__r.Name, ' +
            'Payment__r.pymt__Date__c, ' +
            'CashierCode__c, ' +
            'Payment__r.pymt__Memo__c, ' +
            'Payment__r.Division__c, ' +
            'TransactionLine__r.CostCenter__c, ' +
            'AmountAllocated__c, ' +
            'CutOffBatchDate__c, ' +
            'TransactionLine__r.CashierCode__r.FAMISSrcCode__c, ' +
            'TransactionLine__r.CashierCode__r.FundAccount__c ';

        if (Test.isRunningTest()) {
            query += 'FROM CollectionsAllocation__c ';
        } else {

            query += 'FROM CollectionsAllocation__c WHERE Reconciliation_Batch__c = null ';

            if (isCloseOutMode) {
                query +=
                    'AND PaymentType__c IN (\'Cash\', \'Check\', \'Cashier\\\'s Check\', \'Money Order\') ' +
                    'AND CutOffBatchDate__c = TODAY ' +
                    'AND Payment__r.OwnerId = \'' + String.escapeSingleQuotes(runningUserId) + '\' ' +
                    'AND Payment__r.pymt__Status__c = \'Completed\' ' + 
                    'AND AmountAllocated__c >= 0 ';
            } else {
                query +=
                    'AND Payment__r.pymt__Date__c = Yesterday ' +
                    'AND Payment__r.Division__c != \'PUC\' ' +
                    'AND Division__c != \'PUC\'';
            }
        }

        return Database.getQueryLocator(query);
    }

    /*
     * scheduler
     */
    global void execute(SchedulableContext context) {
        Database.executeBatch(new ReconciliationBatchJob(), batchSize);
    }

    /*
     * batch execute
     */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        for (sObject s : scope) {
            CollectionsAllocation__c ca = (CollectionsAllocation__c)s;
            getCSVFileDetails(ca);
        }
    }

    global void finish(Database.BatchableContext bc) {
        CreateCSVFile();
    }

    /*
     * CSV builder
     */
    global void getCSVFileDetails(CollectionsAllocation__c ca) {

        String accountName = checkNull(ca.Transaction__r.Account__r.Name);
        String csvContent = '';
        csvContent += accountName.replace('"', '');

        csvContent += '\t' + checkNull(ca.Transaction__r.Name);

        if (ca.Payment__r.pymt__Date__c != null) {
            DateTime outputDate = DateTime.newInstance(
                ca.Payment__r.pymt__Date__c.year(),
                ca.Payment__r.pymt__Date__c.month(),
                ca.Payment__r.pymt__Date__c.day()
            );
            csvContent += '\t' + outputDate.format('yyyyMMdd');
        } else {
            csvContent += '\t';
        }

        csvContent += '\t' + checkNull(ca.CashierCode__c);
        csvContent += '\t';
        csvContent += '\t';

        if (ca.CashierCode__c == '999') {
            if (ca.Payment__r.pymt__Memo__c != null && ca.Payment__r.pymt__Memo__c.length() >= 3) {
                csvContent += '\t' + checkNull(ca.Payment__r.pymt__Memo__c.right(3));
            }
        } else {
            csvContent += '\t';
        }

        csvContent += '\t';
        csvContent += '\t' + '00' + checkNull(ca.TransactionLine__r.CostCenter__c);
        csvContent += '\t';
        csvContent += '\t';

        csvContent += '\t' + checkNull(ca.TransactionLine__r.CashierCode__r.FAMISSrcCode__c);

        if (ca.CashierCode__c == '999') {
            csvContent += '\t' + checkNull(ca.TransactionLine__r.CashierCode__r.FundAccount__c);
        } else {
            csvContent += '\t';
        }

        Boolean isCC = (ca.PaymentType__c == 'Credit Card' || ca.PaymentType__c == 'ECheck');

        if (isCC) {
            csvContent += '\t' + String.valueOf(ca.NetCollectionsafterFeesAllocated__c);
        } else {
            csvContent += '\t' + (ca.AmountAllocated__c != null
                ? String.valueOf(ca.AmountAllocated__c)
                : '');
        }

        this.csv += csvContent + '\n';
        updateCA.add(ca);

        if (isCC) {
            this.creditCardCsv += csvContent + '\n';
        } else {
            this.nonCreditCardCsv += csvContent + '\n';
        }
    }

    /*
     * FINAL PROCESSING
     */
    global void CreateCSVFile() {

        Savepoint sp = Database.setSavepoint();

        try {
            Reconciliation_Batch__c rb = new Reconciliation_Batch__c();
            rb.Batch_Time__c = System.now();
            rb.Status__c = 'Pending Review';
            rb.Type__c = 'Payment';

            // SAFE FIELD SET (no compile error if field missing)
            if (isCloseOutMode) {
                rb.OwnerId = runningUserId;

                if (Schema.sObjectType.Reconciliation_Batch__c.fields.getMap().containsKey('CashierSession__c')) {
                    User runningUser = [
                        SELECT Name
                        FROM User
                        WHERE Id = :runningUserId
                        LIMIT 1
                    ];

                    String cashierSession = runningUser.Name + ' ~ ' + System.now().format('M/d/yyyy h:mma');
                    rb.put('CashierSession__c', cashierSession);
                }
            }

            insert rb;

            Integer numOfRecord = 0;
            Decimal sumCC = 0;
            Decimal sumNonCC = 0;

            Map<String, wrapCashierCode> cashierCode_M = new Map<String, wrapCashierCode>();

            for (CollectionsAllocation__c ca : updateCA) {

                ca.Reconciliation_Batch__c = rb.Id;

                Boolean isCC = (ca.PaymentType__c == 'Credit Card' || ca.PaymentType__c == 'ECheck');

                if (isCC && ca.NetCollectionsafterFeesAllocated__c != null) {
                    sumCC += ca.NetCollectionsafterFeesAllocated__c;
                } else if (!isCC && ca.AmountAllocated__c != null) {
                    sumNonCC += ca.AmountAllocated__c;
                }

                if (!cashierCode_M.containsKey(ca.CashierCode__c)) {
                    cashierCode_M.put(ca.CashierCode__c, new wrapCashierCode(0, 0));
                }

                if (isCC) {
                    cashierCode_M.get(ca.CashierCode__c).credit += ca.NetCollectionsafterFeesAllocated__c;
                } else {
                    cashierCode_M.get(ca.CashierCode__c).cash += ca.AmountAllocated__c;
                }

                numOfRecord++;
            }

            if (updateCA.size() > 0) {
                update updateCA;
            }

            rb.Number_of_Collection_Allocations__c = numOfRecord;

            if (isCloseOutMode) {
                rb.Sum_of_Non_Credit_Card_Payments__c = sumNonCC;
            } else {
                rb.Sum_of_Credit_Card_Payments__c = sumCC;
                rb.Sum_of_Non_Credit_Card_Payments__c = sumNonCC;
                rb.All_Payment_Summary__c = sumCC + sumNonCC;
            }

            // UPDATED CASHIER FORMAT
            if (cashierCode_M.size() > 0) {
                String tempString = '';
                for (String key : cashierCode_M.keySet()) {
                    wrapCashierCode wcc = cashierCode_M.get(key);
                    Decimal total = isCloseOutMode ? wcc.cash : (wcc.credit + wcc.cash);
                    tempString += key + ':$' + total + '\r\n';
                }
                rb.Sum_of_Cashier_Code__c = tempString;
            }

            update rb;

            // attach files
            Reconciliation_Batch__c rbNew = [SELECT Id, Name FROM Reconciliation_Batch__c WHERE Id = :rb.Id];

            List<ContentVersion> cvs = new List<ContentVersion>();
            if(!isCloseOutMode) cvs.add(csvCvRecord(rbNew, true));
            if(!isCloseOutMode) cvs.add(csvCvRecord(rbNew, false));
            if(!isCloseOutMode) insert cvs;

            List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
            for (ContentVersion cv : cvs) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
                cdl.LinkedEntityId = rbNew.Id;
                cdl.ShareType = 'I';
                cdls.add(cdl);
            }
            if(!isCloseOutMode) insert cdls;

        } catch (DMLException e) {
            Database.rollback(sp);
            System.debug('Something happened:' + e.getMessage());
        }
    }

    /*
     * CSV file builder
     */
    private ContentVersion csvCvRecord(Reconciliation_Batch__c rbNew, Boolean isCreditCard) {
        String csvHeader = 'DESCRIPTION\tTREAS. REC. NO.\tTREAS. REC. DATE\tCashier Code\tORG\tACCOUNT\tTASK\tOPTION\tCOST CENTER\tCOLLECTING UNIT\tBANK ACCOUNT\tFAMIS SOURCE CODE\tFUND ACCOUNT\tAMOUNT\n';

        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = Blob.valueOf(csvHeader + (isCreditCard ? this.creditCardCsv : this.nonCreditCardCsv));
        cv.Title = rbNew.Name + '-' + (isCreditCard ? 'CreditCard' : 'NonCreditCard') + '.csv';
        cv.PathOnClient = rbNew.Name;

        return cv;
    }

    /*
     * RETAINED METHOD (UNCHANGED)
     */
    global void UpdateCSVFile(Reconciliation_Batch__c rb) {
        String csvHeader = 'DESCRIPTION,TREAS. REC. NO.,TREAS. REC. DATE,Cashier Code,ORG,ACCOUNT,TASK,OPTION,COST CENTER,COLLECTING UNIT,BANK ACCOUNT,FAMIS SOURCE CODE,FUND ACCOUNT,AMOUNT\n';

        Savepoint sp = Database.setSavepoint();
        try {
            Integer numOfRecord = 0;
            Decimal sumOfCreditCardPayment = 0;
            Decimal sumOfNonCreditCardPayment = 0;
            Map<String, wrapCashierCode> cashierCode_M = new Map<String, wrapCashierCode>();

            if (updateCA.size() > 0) {
                for (CollectionsAllocation__c ca : updateCA) {
                    ca.Reconciliation_Batch__c = rb.Id;

                    if (ca.PaymentType__c == 'Credit Card') {
                        sumOfCreditCardPayment += ca.NetCollectionsafterFeesAllocated__c;
                    } else if (ca.AmountAllocated__c != null) {
                        sumOfNonCreditCardPayment += ca.AmountAllocated__c;
                    }

                    if (!cashierCode_M.containsKey(ca.CashierCode__c)) {
                        if (ca.PaymentType__c == 'Credit Card' && ca.NetCollectionsafterFeesAllocated__c != null) {
                            cashierCode_M.put(ca.CashierCode__c, new wrapCashierCode(ca.NetCollectionsafterFeesAllocated__c, 0));
                        } else if (ca.AmountAllocated__c != null) {
                            cashierCode_M.put(ca.CashierCode__c, new wrapCashierCode(0, ca.AmountAllocated__c));
                        }
                    } else {
                        if (ca.PaymentType__c == 'Credit Card' && ca.NetCollectionsafterFeesAllocated__c != null) {
                            cashierCode_M.get(ca.CashierCode__c).credit += ca.NetCollectionsafterFeesAllocated__c;
                        } else if (ca.AmountAllocated__c != null) {
                            cashierCode_M.get(ca.CashierCode__c).cash += ca.AmountAllocated__c;
                        }
                    }
                    numOfRecord++;
                }
                update updateCA;
            }

            rb.Number_of_Collection_Allocations__c = numOfRecord;
            rb.Sum_of_Non_Credit_Card_Payments__c = sumOfNonCreditCardPayment;
            rb.Sum_of_Credit_Card_Payments__c = sumOfCreditCardPayment;
            rb.All_Payment_Summary__c = sumOfNonCreditCardPayment + sumOfCreditCardPayment;

            if (cashierCode_M.size() > 0) {
                String tempString = '';
                for (String key : cashierCode_M.keySet()) {
                    wrapCashierCode wcc = cashierCode_M.get(key);
                    Decimal tempTotal = wcc.credit + wcc.cash;
                    tempString += key + ',$' + tempTotal +
                        '($' + wcc.credit + ' Credit Card + $' + wcc.cash + ' Non Credit Card)\r\n';
                }
                rb.Sum_of_Cashier_Code__c = tempString;
            }

            update rb;

            ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.VersionData = Blob.valueOf(csvHeader + this.csv);
            cv.Title = rb.Name + '.csv';
            cv.PathOnClient = rb.Name;
            insert cv;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            cdl.LinkedEntityId = rb.Id;
            cdl.ShareType = 'I';
            insert cdl;

        } catch (DMLException e) {
            Database.rollback(sp);
            System.debug('Something happened:' + e.getMessage());
        }
    }

    private String checkNull(String inString) {
        return inString == null ? '' : inString;
    }

    public class wrapCashierCode {
        public Decimal credit { get; set; }
        public Decimal cash { get; set; }

        public wrapCashierCode(Decimal credit, Decimal cash) {
            this.credit = credit;
            this.cash = cash;
        }
    }
}