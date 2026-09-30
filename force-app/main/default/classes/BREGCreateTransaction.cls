public without sharing class BREGCreateTransaction {
    private static Date getOrgDateByUserTimezone() {
        Datetime nowUtc = System.now();
        TimeZone tz = UserInfo.getTimeZone();
        Integer offset = tz.getOffset(nowUtc) / 1000;
        Datetime orgNow = nowUtc.addSeconds(offset);
        return orgNow.date();
    }

    @AuraEnabled
    public static TransactionWrapper initTransaction(Id recordId) {
        /*User cUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        string division = cUser.Division__c;
        if (division != null && division.contains(';')) {
            division = division.split(';')[0];
        }*/
        TransactionWrapper toReturn = new TransactionWrapper(recordId /*, division*/);

        return toReturn;
    }

    @AuraEnabled
    public static List<PicklistVal> getSelectOptions(string objName, string fieldName) {
        List<PicklistVal> picklistValues = new List<PicklistVal>();
        SObjectType objectType = Schema.getGlobalDescribe().get(objName);
        List<Schema.PicklistEntry> pick_list_values = objectType.getDescribe().fields.getMap().get(fieldName).getDescribe().getPickListValues();
        for (Schema.PicklistEntry aPickListValue : pick_list_values) {
            picklistValues.add(new PicklistVal(aPickListValue));
        }
        return picklistValues;
    }

    @AuraEnabled
    public static Id saveTransaction(Transaction__c trns, string lines) {
        upsert trns;
        trns = [SELECT Id, breg_Case__r.breg_Form_Code__c FROM Transaction__c WHERE Id = :trns.Id];
        Map<Id, TransactionLine__c> trLinesMap = new Map<Id, TransactionLine__c>([SELECT Id FROM TransactionLine__c WHERE Transaction__c = :trns.Id]);
        List<TransactionLine__c> xlines = (List<TransactionLine__c>) JSON.deserialize(lines, List<TransactionLine__c>.class);
        List<TransactionLine__c> trlinesToInsert = new List<TransactionLine__c>();
        String formCategory = BREGUtils.checkFormCategory(trns.breg_Case__r?.breg_Form_Code__c);
        String transactionType;
        if (String.isNotBlank(formCategory)) {
            transactionType = formCategory + ' Form';
        }
        for (TransactionLine__c line : xlines) {
            if (!trLinesMap.containsKey(line.Id)) {
                System.debug('Amount ====> ' + line.Amount__c);
                System.debug('Amount Override ====> ' + line.AmountOverride__c);
                if (line.AmountOverride__c != null && line.AmountOverride__c != 0) {
                    line.Amount__c = line.AmountOverride__c;
                    line.AmountOverride__c = null;
                }
                line.breg_Unit_Price__c = line.Amount__c;
                line.breg_Case__c = trns.breg_Case__c;
                line.breg_Type__c = transactionType;
                line.Transaction__c = trns.Id;
                trlinesToInsert.add(line);
            }
        }

        Set<Id> cashierCodeIds = new Set<Id>();
        for (TransactionLine__c lineToInsert : trlinesToInsert) {
            if (lineToInsert.breg_Fee__c == null && lineToInsert.CashierCode__c != null) {
                cashierCodeIds.add(lineToInsert.CashierCode__c);
            }
        }

        if (!cashierCodeIds.isEmpty()) {
            Map<Id, Id> feeIdByCashierCodeId = BREGPaymentController.getCashierCodeIdToFeeId(cashierCodeIds);

            for (TransactionLine__c lineToInsert : trlinesToInsert) {
                if (lineToInsert.breg_Fee__c == null && lineToInsert.CashierCode__c != null) {
                    if (feeIdByCashierCodeId.containsKey(lineToInsert.CashierCode__c)) {
                        lineToInsert.breg_Fee__c = feeIdByCashierCodeId.get(lineToInsert.CashierCode__c);
                    }
                }
            }
        }

        insert trlinesToInsert;
        List<TransactionLine__c> TrLines = [
            SELECT Id, CashierCode__c, CashierCode__r.Division__c, CashierCode__r.Name, Amount__c
            FROM TransactionLine__c
            WHERE Transaction__c = :trns.Id
        ];
        for (TransactionLine__c tl : TrLines) {
            trns.Division__c = tl.CashierCode__r.Division__c;
            tl.Description__c = tl.CashierCode__r.Name;
            System.debug('Amount ====> ' + tl.Amount__c);
        }
        update trns;
        update TrLines;
        return trns.Id;
    }

    @AuraEnabled
    public static List<CashierCode__c> getCashierCodes() {
        User myUser = [SELECT Division__c FROM User WHERE Id = :UserInfo.getUserId()];
        List<string> divisions = new List<string>();
        if (myuser.Division__c != null)
            divisions = myUser.Division__c.split(';');
        return [
            SELECT Id, Name, FeeCode__c, Amount__c, FormDescription__c, Description__c, Division__c, Category__c, CashierCode__c
            FROM CashierCode__c
            WHERE Division__c IN :divisions
            ORDER BY Division__c
        ];
    }

    public class TransactionWrapper {
        @AuraEnabled
        public Transaction__c trns { get; set; }
        @AuraEnabled
        public List<TransactionLine__c> lines { get; set; }
        @AuraEnabled
        public TransactionLine__c exampleLine { get; set; }

        public TransactionWrapper(Id recordId /*, string division*/) {
            Date orgDate = getOrgDateByUserTimezone();

            if (recordId.getSobjectType() == Schema.Account.SObjectType) {
                trns = new Transaction__c();
                trns.Account__c = recordId;
                trns.Date__c = orgDate;
                trns.Status__c = 'New';
                //trns.DCCASection__c = division;
                trns.TransactionType__c = '';

                lines = new List<TransactionLine__c>();

                exampleLine = new TransactionLine__c();
            } else if (recordId.getSobjectType() == Schema.Case.SObjectType) {
                trns = new Transaction__c();
                trns.breg_Case__c = recordId;
                trns.Date__c = orgDate;
                trns.Status__c = 'New';
                //trns.DCCASection__c = division;
                trns.TransactionType__c = '';

                Case relatedCase = [
                    SELECT Id, Origin, breg_Workitem_ID__c, RecordType.DeveloperName,
                        breg_Entity__c, Contact.AccountId, Contact.Account.IsPersonAccount
                    FROM Case
                    WHERE Id = :recordId
                    LIMIT 1
                ];

                if (relatedCase.RecordType != null
                    && relatedCase.RecordType.DeveloperName == 'BREG_Case'
                    && relatedCase.Origin != 'Web') {
                    trns.WorkitemID__c = relatedCase.breg_Workitem_ID__c;
                    trns.Account__c = relatedCase.breg_Entity__c;

                    if (relatedCase.breg_Entity__c == null
                        && relatedCase.Contact != null
                        && relatedCase.Contact.Account != null
                        && relatedCase.Contact.Account.IsPersonAccount == true) {
                        trns.Account__c = relatedCase.Contact.AccountId;
                    }
                }

                lines = new List<TransactionLine__c>();

                exampleLine = new TransactionLine__c();
            } else {
                trns = [SELECT Id, Name, Account__c, Status__c, TransactionType__c, Date__c, Description__c FROM Transaction__c WHERE Id = :recordId];

                lines = [
                    SELECT
                        Id,
                        CashierCode__c,
                        Amount__c,
                        AmountOverride__c,
                        CashierCode__r.Name,
                        CashierCode__r.FeeCode__c,
                        CashierCode__r.Category__c,
                        CashierCode__r.FormDescription__c,
                        CashierCode__r.Division__c,
                        CashierCode__r.Description__c
                    FROM TransactionLine__c
                    WHERE Transaction__c = :recordId
                ];
                exampleLine = new TransactionLine__c();
            }
        }
    }

    public class PicklistVal {
        @AuraEnabled
        public string value { get; set; }
        @AuraEnabled
        public string label { get; set; }

        public PicklistVal(Schema.PicklistEntry pe) {
            value = pe.getValue();
            label = pe.getLabel();
        }
    }
}