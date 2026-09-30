/*
 * ─────────────────────────────────────────────────────────
 * class for the Transaction to deal with business logics
 * ─────────────────────────────────────────────────────────
 * PacPoint-AZ210819 - Created for PVL phase 1
 * ───────────────────────────────────────────────────────────
 * Initial implementation
 *
 * @author Alvin Zhou - PacificPointCorp
 *
 * @created 2019-08-21
 * ───────────────────────────────────────────────────────────
 * Changes
 * ───────────────────────────────────────────────────────────
 */
public without sharing class TransactionService {
    public static Boolean isGroupTransaction = false;
    public static Boolean isRenewalTransaction = false;
    private static Set<String> appIdsForCalculation = new Set<String>();
    /*
     * Used for renewal transaction Generation Only
     */
    private static Map<Id, Application__c> applicationMapForRenewal;

    public static void shareTalendUserRecordsToGroup(
        List<Transaction__c> transactions,
        String publicGroup
    ) {
        User talendUser;
        if (Test.isRunningTest()) {
            String uId = UserInfo.getUserId();
            talendUser = [SELECT Id FROM User WHERE Id != :uId AND IsActive = TRUE LIMIT 1];
        } else {
            talendUser = [
                SELECT Id
                FROM User
                WHERE FirstName = 'Talend' AND LastName = 'User' AND IsActive = TRUE
            ];
        }

        Group g = [SELECT Id FROM Group WHERE DeveloperName = :publicGroup];

        List<Transaction__Share> recordsShare = new List<Transaction__Share>();

        for (Transaction__c t : transactions) {
            if (t.OwnerId == talendUser.Id) {
                Transaction__Share share = new Transaction__Share();
                share.AccessLevel = 'Edit';
                share.UserOrGroupId = g.Id;
                share.ParentId = t.Id;
                recordsShare.add(share);
            }
        }

        if (!recordsShare.isEmpty()) {
            insert recordsShare;
        }
    }

    public static void cacheRecordsForAppAmtCal(SObject oldSo, SObject so) {
        
        Transaction__c oldTransaction = (Transaction__c) oldSo;
        Transaction__c record = (Transaction__c) so;
        if (
            record.AmountOutstanding__c != oldTransaction.AmountOutstanding__c &&
            record.Application__c != null
        ) {
            appIdsForCalculation.add(record.Application__c);
        } else if(isGroupTransaction 
            && record.Application__c != null 
            && record.Status__c != oldTransaction.Status__c 
            && record.Status__c == 'Completed') {
            appIdsForCalculation.add(record.Application__c);
        }
    }

    public static void cacheRecordsForAppAmtCal(SObject so) {
        Transaction__c record = (Transaction__c) so;
        if (record.AmountOutstanding__c != 0 && record.Application__c != null) {
            appIdsForCalculation.add(record.Application__c);
        }
    }

    //case 00032255
    public static void generateRenewalFeeTransactions(List<Application__c> applications) {
        Map<Id, Transaction__c> applicationTransactionMap = new Map<Id, Transaction__c>();

        for (Application__c app : applications) {
            if(app.LicensePeriod__c != 'This License Period + Renewal') {
                continue;
            }

            if(app.LicenseType__r.LicenseFees__c && app.Phase__c != 'L - License Review') {
                continue;
            }

            Transaction__c trxn = new Transaction__c();
            trxn.Application__c = app.Id;
            trxn.Account__c = app.Applicant__c;
            trxn.Date__c = System.today();
            trxn.Status__c = 'New';
            trxn.TransactionType__c = 'Payment';
            trxn.Description__c = 'Renewal Fees for ' +
                app.Applicant__r.Name + ', ' +
                app.LicenseType__r.Name +
                ', Application: ' + app.Name;
            applicationTransactionMap.put(app.Id, trxn);
        }

        TransactionService.isRenewalTransaction = true;
        insert applicationTransactionMap.values();
        TransactionService.isRenewalTransaction = false;

        List<TransactionLine__c> transactionLinesToInsert = generateRenewalTransactionLines(applications, applicationTransactionMap);
        insert transactionLinesToInsert;
    }

    //case 00032255
    private static List<TransactionLine__c> generateRenewalTransactionLines(List<Application__c> applications, Map<Id, Transaction__c> applicationTransactionMap) {
        Map<Id, Application__c> applicationMap = new Map<Id, Application__c>(applications);
        Map<String, List<LicenseTypeCashierCode__c>> keyToLtcc = new Map<String, List<LicenseTypeCashierCode__c>>();
        Map<String, Map<String, LicenseTypeCashierCode__c>> mvdKeyToLtccMap = new Map<String, Map<String, LicenseTypeCashierCode__c>>();
        List<TransactionLine__c> transactionLinesToInsert = new List<TransactionLine__c>();
        List<String> mvdApplications = new List<String>();
		Set<String> appLicenseTypes = new Set<String>();     

        for(Application__c app: applications) {
            appLicenseTypes.add(app.LicenseType__c);
			if(app?.LicenseType__r?.Name == 'MVD' || app?.LicenseType__r?.Name == 'MVD - Sole Proprietor'){
				mvdApplications.add(app.Id);
			}
        }

        List<LicenseTypeCashierCode__c> renewalCashierCodes = LicenseTypeCashierCodeSelector.getLicenseTypeCashierCodesRenewal(appLicenseTypes);
		Map<Id, ApplicationClassifications__c> appClassifications = new Map<Id, ApplicationClassifications__c>();
		if(!mvdApplications.isEmpty()){
			List<String> allowedClassification = new List<String>{'N','M','U'};
			for(ApplicationClassifications__c appClassification:ApplicationClassificationsSelector.getApplicationClassifications(mvdApplications)){
				ApplicationClassifications__c currentAppClassification = appClassifications.get(appClassification.Application__c);
				if(
					allowedClassification.contains(appClassification.Classification__r.Name)
					&& (currentAppClassification == null || appClassification.Classification__r.Name == 'N')
				){
					appClassifications.put(appClassification.Application__c, appClassification);
				}
			}
		}
		
		if(!appClassifications.isEmpty()){
			List<String> filters = new List<String>();
			for(Id appId:appClassifications.keySet()){
				Application__c currentApp = applicationMap.get(appId);
				ApplicationClassifications__c currentAppClassification = appClassifications.get(appId);
				String filter = '';
				filter += currentApp.Island__c != null ? 'Island__c = \''+ currentApp.Island__c +'\' ' : 'Island__c = null ';
				filter += 'AND LicenseType__c = \''+ currentApp.LicenseType__c +'\' ';
				filter += 'AND (Classification__c = \''+ currentAppClassification.Classification__c +'\' OR Classification__c = null)';
                filters.add('(' + filter + ')');
			}

			if(!filters.isEmpty()){
                for (LicenseTypeCashierCode__c ltcc : LicenseTypeCashierCodeSelector.getLicenseTypeCashierCodesRenewal('(' + String.join(filters, ' OR ') + ')')) {
                    String islandKey = ltcc.Island__c == null ? '' : ltcc.Island__c;
                    String ltccActiveInactive = ltcc.ActiveInactive__c != 'Inactive' ? '' : ltcc.ActiveInactive__c;    
                    String key = ltcc.LicenseType__c + ltccActiveInactive + islandKey;
                    if (!mvdKeyToLtccMap.containsKey(key)) {
                        mvdKeyToLtccMap.put(key, new Map<String, LicenseTypeCashierCode__c>());
                    }
        
                    mvdKeyToLtccMap.get(key).put(ltcc.CashierCode__r.CashierCode__c, ltcc);
                }
			}
		}

        Map<String, List<LicenseTypeCashierCode__c>> mvdKeyToLtcc = new Map<String, List<LicenseTypeCashierCode__c>>();
        for(String key:mvdKeyToLtccMap.keySet()){
            mvdKeyToLtcc.put(key, mvdKeyToLtccMap.get(key).values());
        }

        for (LicenseTypeCashierCode__c ltcc : renewalCashierCodes) {
            String islandKey = ltcc.Island__c == null ? '' : ltcc.Island__c;
            String ltccActiveInactive = ltcc.ActiveInactive__c != 'Inactive' ? '' : ltcc.ActiveInactive__c;
            String key = ltcc.LicenseType__c + ltccActiveInactive + islandKey;
            if (!keyToLtcc.containsKey(key)) {
                keyToLtcc.put(key, new List<LicenseTypeCashierCode__c>());
            }

            keyToLtcc.get(key).add(ltcc);
        }

        for (Id appId : applicationTransactionMap.keySet()) {
            Transaction__c trxn = applicationTransactionMap.get(appId);
            if (trxn.Application__c != null) {
                Application__c a = applicationMap.get(trxn.Application__c);

                if (a.LicensePeriod__c != 'This License Period + Renewal') {
                    continue;
                }

                if (a.LicenseType__r.LicenseFees__c && a.Phase__c != 'L - License Review') {
                    continue;
                }

                String tempKey = a.LicenseType__c;
                String activeInactiveKey = a.ActiveInactive__c;
                if (activeInactiveKey != 'Inactive') {
                    tempKey += '';
                } else {
                    tempKey += a.ActiveInactive__c;
                }

                tempKey += a.Island__c == null ? '' : a.Island__c;

                Map<String, List<LicenseTypeCashierCode__c>> ltccMap = mvdApplications.contains(appId) ? mvdKeyToLtcc : keyToLtcc;
                if (ltccMap.containsKey(tempKey) || keyToLtcc.containsKey(tempKey)) {
                    List<LicenseTypeCashierCode__c> ltccs = ltccMap.containsKey(tempKey) ? ltccMap.get(tempKey) : keyToLtcc.get(tempKey);
                    for(LicenseTypeCashierCode__c ltcc : ltccs){
                        TransactionLine__c tempTL = new TransactionLine__c();                            
                        tempTL.CashierCode__c = ltcc.CashierCode__c;
                        tempTL.Amount__c = ltcc.FeeAmount__c;
                        tempTL.Transaction__c = trxn.Id;
                        transactionLinesToInsert.add(tempTL);
                    }
                }
            }
        }

        return transactionLinesToInsert;
    }

    // 00008048
    public static void reGenerateTransactionLines(List<Transaction__c> transactions) {
        // Delete transaction Lines
        List<String> transactionIds = (new TransactionDomain(transactions)).getIds();
        // Query Transaction Lines
        delete TransactionLineSelector.getTransactionLinesByIds(transactionIds);
        // Reset the status of transaction to be new
        (new TransactionDomain(transactions)).updateStatus('New');

        setTransactionDescription(transactions);

        update transactions;
        // Re generate Transactions lines
        generateTransactionLines(transactions);
    }

    public static void setTransactionDescription(List <Transaction__c> transactions) {
        for (Transaction__c trxn : transactions) {
            if (trxn.Description__c != null && trxn.Application__r.LicensePeriod__c != null) {
                if (trxn.Application__r.LicensePeriod__c == 'This License Period + Renewal') {
                    trxn.Description__c = trxn.Description__c.replace('License Fees', 'License + Renewal Fees');
                    trxn.Description__c = trxn.Description__c.replace('Application Fees', 'Application + Renewal Fees');
                } else {
                    trxn.Description__c = trxn.Description__c.replace('License + Renewal Fees', 'License Fees');
                    trxn.Description__c = trxn.Description__c.replace('Application + Renewal Fees', 'Application Fees');
                }
            }
        }
    }

    public static void populateApplicationMapForRenewal(List<Application__c> applications) {
        applicationMapForRenewal = new Map<Id, Application__c>();
        for(Application__c app: applications) {
            applicationMapForRenewal.put(app.Id, app);
        }
    }

    public static void generateTransactionLines(List<Transaction__c> transactions, List<Application__c> applicationRecords, Map<String, Set<String>> appId2ClassificationIds) {
        Map<String, Transaction__c> appIdToTransaction_M = (new TransactionDomain(transactions)).getApp2Transaction();

        List<TransactionLine__c> insertTransactionLine_L = new List<TransactionLine__c>();
        Set<String> appType_L = new Set<String>();
        Set<String> appStatus_L = new Set<String>();
        Set<String> appLicenseType_L = new Set<String>();
        Set<String> appCurrentLicenseYear_L = new Set<String>();


        //reference for setting transaction lines based off License.Privilege__c.
        //for now this logic is exclusively applicable for DT license types only
        //see case 00015682
        populateApplicationMapForRenewal(applicationRecords);

        // 00012212 If Application__c.Type__c = "LICF - New License after Forfeiture",
        // then find the Cashier Codes where LicenceTypeCashierCode__c.Type__c = "LICN - New License"
        // in other words, treat LICF - New License after Forfeiture as the same as LICN - New License for fees.
        (new ApplicationDomain(applicationRecords)).massageApplications();
        
        
        Map<String, List<LicenseTypeCashierCode__c>> keyToLTCC_M1 = (new ApplicationDomain(applicationRecords)).initiateKeys_M(false);
        Map<String, List<LicenseTypeCashierCode__c>> keyToLTCC_M2 = (new ApplicationDomain(applicationRecords)).initiateKeys_M(true);

        Map<String, List<Transaction__c>> keyToTransaction_M1 
            = (new ApplicationDomain(applicationRecords)).getApp2Transactions(appIdToTransaction_M, false);
        System.debug('##############keyToTransaction_M1##########' + keyToTransaction_M1);
        Map<String, List<Transaction__c>> keyToTransaction_M2 
            = (new ApplicationDomain(applicationRecords)).getApp2Transactions(appIdToTransaction_M, true);

        Map<String, Set<String>> key2ClassificationIds_M1 = (new ApplicationDomain(applicationRecords)).convertToKey2ClassIds(appId2ClassificationIds, false);
        Map<String, Set<String>> key2ClassificationIds_M2 = (new ApplicationDomain(applicationRecords)).convertToKey2ClassIds(appId2ClassificationIds, true);

        for (Application__c app : applicationRecords) {
            if (app.Type__c != null && app.Status__c != null && app.LicenseType__c != null) {
                appType_L.add(app.Type__c);
                appStatus_L.add(app.Status__c);
                appLicenseType_L.add(app.LicenseType__c);
                if(app.CurrentLicenseYear__c != null) {
                    appCurrentLicenseYear_L.add(app.CurrentLicenseYear__c);
                }
            }
        }

        //1.Find all the Application Fees:
        List<LicenseTypeCashierCode__c> licenseTypeCashierCode_L1 
            = LicenseTypeCashierCodeSelector.getLicenseTypeCashierCodes(appType_L, appStatus_L, appLicenseType_L);
        keyToLTCC_M1 = (new LicenseTypeCashierCodeDomain(licenseTypeCashierCode_L1)).updateCashierCode(
            key2ClassificationIds_M1, keyToLTCC_M1, false);

        //2.Find all the Renewal License Fees (if they exist):
        List<LicenseTypeCashierCode__c> licenseTypeCashierCode_L2 
            = LicenseTypeCashierCodeSelector.getLicenseTypeCashierCodes(appType_L, appStatus_L, 
                appLicenseType_L, appCurrentLicenseYear_L);
        keyToLTCC_M2 = (new LicenseTypeCashierCodeDomain(licenseTypeCashierCode_L2)).updateCashierCode(
            key2ClassificationIds_M2, keyToLTCC_M2, true);

        System.debug('##############licenseTypeCashierCode_L1##########' + licenseTypeCashierCode_L1);
        System.debug('##############LicenseTypeCashierCode_L2##########' + LicenseTypeCashierCode_L2);
        System.debug('##############keyToLTCC_M1##########' + keyToLTCC_M1);
        System.debug('##############keyToLTCC_M2##########' + keyToLTCC_M2);

        List<TransactionLine__c> insertTransactionLine_L1 = covertIntoTransactionLines(
            keyToLTCC_M1,
            keyToTransaction_M1
        );
        if (insertTransactionLine_L1.size() > 0) {
            insertTransactionLine_L.addAll(insertTransactionLine_L1);
        }

        List<TransactionLine__c> insertTransactionLine_L2 = covertIntoTransactionLines(
            keyToLTCC_M2,
            keyToTransaction_M2
        );
        if (insertTransactionLine_L2.size() > 0) {
            insertTransactionLine_L.addAll(insertTransactionLine_L2);
        }

        //3. Find all the renewal license fees for License Period = 'This License Period + Renewal'
        Map<Id, Transaction__c> applicationTransactionMap = new Map<Id, Transaction__c>();

        //This License Period + Renewal transaction lines
        for (Transaction__c trxn : transactions) {
            if (trxn.Application__c != null && applicationMapForRenewal.containsKey(trxn.Application__c)) {
                applicationTransactionMap.put(trxn.Application__c, trxn);
            }
        }

        List<TransactionLine__c> renewalTransactionLinesToInsert = generateRenewalTransactionLines(applicationRecords, applicationTransactionMap);
        insertTransactionLine_L.addAll(renewalTransactionLinesToInsert);

        // 00041666
        // Permit and Permanent RN and LPN licens
        List<LicenseTypeCashierCode__c> permitCodes = new LicenseTypeCashierCodeDomain(LicenseTypeCashierCodeSelector.cashierCodes).filterPermitCodes();
        insertTransactionLine_L.addAll((new ApplicationDomain(applicationRecords)).getTransactionsWithCashierCodes(appIdToTransaction_M, permitCodes));


        if (insertTransactionLine_L.size() > 0) {
            // System.debug(
            //     '##############Transaction##########' +
            //     [
            //         SELECT Id, Status__c
            //         FROM Transaction__c
            //         WHERE Id = :insertTransactionLine_L.get(0).Transaction__c
            //     ]
            // );
            insert insertTransactionLine_L;
        }
        
    }
    //00005478 : Trigger to populate Transaction Lines
    public static void generateTransactionLines(List<Transaction__c> transactions) {
        Map<String, Transaction__c> accountIdToTransaction_M = (new TransactionDomain(transactions)).getApp2Transaction();
        
        List<String> applicationIds = new List<String>();
        applicationIds.addAll(accountIdToTransaction_M.keySet());

        List<Application__c> applicationRecords = ApplicationSelector.getApplications(applicationIds);

        // Get the appId => Classification ids
        List<ApplicationClassifications__c> appClassifications 
            = ApplicationClassificationsSelector.getApplicationClassifications(applicationIds);
        Map<String, Set<String>> appId2ClassificationIds 
            = (new ApplicationClassificationsDomain(appClassifications)).getAppClassificationMap();


        generateTransactionLines(transactions, applicationRecords, appId2ClassificationIds);
        
    }

    //00005478 : Trigger to populate Transaction Lines
    public static List<TransactionLine__c> covertIntoTransactionLines(
        Map<String, List<LicenseTypeCashierCode__c>> ltcc_M,
        Map<String, List<Transaction__c>> keyToTransaction_M
    ) {
        List<TransactionLine__c> returnTL = new List<TransactionLine__c>();
        for (String key : ltcc_M.keySet()) {
            List<LicenseTypeCashierCode__c> ltcc_L = ltcc_M.get(key);
            List<Transaction__c> transactions = keyToTransaction_M.get(key);
            System.debug('##############transactions##########' + transactions);
            System.debug('##############ltcc_L##########' + ltcc_L);
            if (transactions != null)
                returnTL.addAll(getTransactionLines(ltcc_L, transactions));
        }
        return returnTL;
    }

    public static List<TransactionLine__c> getTransactionLines(
        List<LicenseTypeCashierCode__c> cashierCodes,
        List<Transaction__c> transactions
    ) {
        List<TransactionLine__c> returnTL = new List<TransactionLine__c>();
        for (LicenseTypeCashierCode__c ltcc : cashierCodes) {
            for (Transaction__c tc : transactions) {
                if (applicationMapForRenewal.containsKey(tc.Application__c)) {
                    //@see case 00015682
                    Application__c app = applicationMapForRenewal.get(tc.Application__c);

                    //the following logic could be written in single if statement by grouping and using OR.
                    //this was purposely broken to multiple ifs for better readability
                    if (app.LicenseType__r.Name == 'DT') {
                        if (
                            app.CurrentLicense__r.Privilege__c ==
                            'A - Deep Sedation or General Anesthesia' &&
                            ltcc.Privilege__c != null &&
                            ltcc.Privilege__c != 'A - DEEP SEDATION OR GENERAL ANESTHESIA'
                        ) {
                            continue;
                        }

                        if (
                            app.CurrentLicense__r.Privilege__c == 'B - Moderate Sedation' &&
                            ltcc.Privilege__c != null &&
                            ltcc.Privilege__c != 'B - Moderate Sedation'
                        ) {
                            continue;
                        }

                        if (
                            app.CurrentLicense__r.Privilege__c == null &&
                            (ltcc.Privilege__c == 'A - DEEP SEDATION OR GENERAL ANESTHESIA' ||
                            ltcc.Privilege__c == 'B - Moderate Sedation')
                        ) {
                            continue;
                        }
                    }
                }

                TransactionLine__c tempTL = new TransactionLine__c();
                tempTL.CashierCode__c = ltcc.CashierCode__c;
                tempTL.Amount__c = ltcc.FeeAmount__c;
                tempTL.Transaction__c = tc.Id;
                returnTL.add(tempTL);
            }
        }
        return returnTL;
    }

    public static Map<String, Decimal> getTransactionsWithTotalAmount(List<String> applicationIds) {
        List<Transaction__c> transactions = TransactionSelector.getTransactionsByAppIds(
            applicationIds
        );
        Map<String, Decimal> sumAmtPerApp = (new TransactionDomain(transactions)).getSumAmtPerApp();
        return sumAmtPerApp;
    }

    public static void calculateParentAccountsOutstandingAmount(List<Transaction__c> transactions) {
        Set<Id> accountIds = new Set<Id>();
        for (Transaction__c t : transactions) {
            if (t.Account__c != null) {
                accountIds.add(t.Account__c);
            }
        }

        String query = 'SELECT Account__c, SUM(AmountOutstanding__c) am FROM Transaction__c WHERE Account__c IN :accountIds GROUP BY Account__c';
        List<AggregateResult> agrs = Database.query(query);
        List<Account> accountsToUpdate = new List<Account>();

        for (AggregateResult agr : agrs) {
            Account acc = new Account();
            acc.Id = (String) agr.get('Account__c');
            acc.OutstandingAmountOwed__c = (Decimal) agr.get('am');
            accountsToUpdate.add(acc);
        }

        //update code to exculde the guest user
        if (!accountsToUpdate.isEmpty() && !Auth.CommunitiesUtil.isGuestUser()) {
            update accountsToUpdate;
        }
    }

    public static void calculateGroupTransactionTotalAmount(List<Transaction__c> groupTransactions) {
        Map<Id, Transaction__c> groupTransactionMap = new Map<Id, Transaction__c>(groupTransactions);
        List<Transaction__c> transactionsWithRelated = [
            SELECT
                Id,
                (SELECT Id, Amount__c FROM TransactionLines__r),
                (SELECT Id, TransactionGroup__c FROM Transactions__r)
            FROM Transaction__c
            WHERE Id IN :groupTransactions
        ];

        Set<Id> childTransactionIds = new Set<Id>();
        Map<Id, Id> childTransactionIdParentIdMap = new Map<Id, Id>();
        for (Transaction__c t : transactionsWithRelated) {
            groupTransactionMap.get(t.Id).TotalAmount__c = 0;
            for (Transaction__c c : t.Transactions__r) {
                childTransactionIds.add(c.Id);
                childTransactionIdParentIdMap.put(c.Id, t.Id);
            }

            for (TransactionLine__c tl : t.TransactionLines__r) {
                groupTransactionMap.get(t.Id).TotalAmount__c += tl.Amount__c;
            }
        }

        List<TransactionLine__c> childTransactionLines = [
            SELECT
                Id,
                Amount__c,
                Transaction__c
            FROM TransactionLine__c
            WHERE Transaction__c IN :childTransactionIds
        ];

        for (TransactionLine__c tl : childTransactionLines) {
            groupTransactionMap.get(childTransactionIdParentIdMap.get(tl.Transaction__c)).TotalAmount__c+= tl.Amount__c;
        }
    }

    public static void runFinally(List<Transaction__c> transactions) {
        if (Trigger.isAfter != null && Trigger.isAfter) {
            // if(Auth.CommunitiesUtil.isGuestUser()){
            //     PVLRenewApp.runSync = true;
            // }
            if (!appIdsForCalculation.isEmpty()) {
                PVLRenewApp.calculate(appIdsForCalculation);
                appIdsForCalculation.clear();
            }
        }
    }
}