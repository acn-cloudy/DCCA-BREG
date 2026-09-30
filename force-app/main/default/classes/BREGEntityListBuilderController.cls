public without sharing class BREGEntityListBuilderController {
    //Entity List Builder Controller
    //This class is used to handle the logic for the Entity List Builder component
    //public static final double PRICE_PER_ENTITY = BREG_Setting__c.getInstance().Entity_List_Builder_Price_Per_Record__c;

    //TODO: sharing settings architecture, remove WITHOUT SHARING
    //static List<Schema.PicklistEntry> ACCOUNT_ENTITY_TYPE_PICKLIST_VALUES;
    static List<String> ACCOUNT_FIELDS;
    static {
        //ACCOUNT_ENTITY_TYPE_PICKLIST_VALUES = Schema.SObjectType.Account.fields.getMap().get('breg_Entity_Type__c').getDescribe().getPicklistValues();
        ACCOUNT_FIELDS = new List<String>();
        Schema.FieldSet entityFieldSet = Schema.SObjectType.Account.fieldSets.BREG_Entity_List_Builder_Fields;
        for (Schema.FieldSetMember f : entityFieldSet.getFields()) {
            ACCOUNT_FIELDS.add(f.getFieldPath());
        }
    }

    public class SearchInput {
        @AuraEnabled
        public List<String> recordTypes { get; set; }
        @AuraEnabled
        public String zipCodes { get; set; }
        @AuraEnabled
        public String status { get; set; }
        @AuraEnabled
        public String startDate { get; set; }
        @AuraEnabled
        public String endDate { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String nameOrCompany { get; set; }
        @AuraEnabled
        public String email { get; set; }
        // @AuraEnabled
        // public String confirmEmail { get; set; }

        public SearchInput() {
        }

        public SearchInput(breg_Entity_List__c entityList) {
            this.recordTypes = entityList.breg_Entity_Type_Codes__c != null ? entityList.breg_Entity_Type_Codes__c.split(';') : new List<String>();
            this.zipCodes = entityList.breg_Zip_Code__c;
            this.status = entityList.breg_Status__c;
            this.startDate = entityList.breg_Start_Date__c != null ? String.valueOf(entityList.breg_Start_Date__c) : null;
            this.endDate = entityList.breg_End_Date__c != null ? String.valueOf(entityList.breg_End_Date__c) : null;
            this.nameOrCompany = entityList.breg_Name_Company__c;
            this.name = entityList.breg_Entity_Name__c;
            this.email = entityList.breg_Email_Address__c;
        }
    }
    public class SearchResult {
        @AuraEnabled
        public Integer RecordsFound { get; set; }
        @AuraEnabled
        public Decimal PricePerRecord { get; set; }
        @AuraEnabled
        public Decimal Total { get; set; }
        @AuraEnabled
        public String FeeId { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static Id upsertList(SearchInput input) {
        //TODO: impelemnt the logic. Create wrapper classes
        //TODO check if the record already exists for the current user
        breg_Entity_List__c newEL = new breg_Entity_List__c();
        newEL.breg_Entity_Type_Codes__c = String.join(input.recordTypes, ';');
        newEL.breg_Status__c = input.status;
        newEL.breg_Entity_Name__c = input.name;
        newEL.breg_Email_Address__c = input.email;
        if (String.isNotBlank(input.startDate))
            newEL.breg_Start_Date__c = Date.valueOf(input.startDate);
        if (String.isNotBlank(input.endDate))
            newEL.breg_End_Date__c = Date.valueOf(input.endDate);
        newEL.breg_Zip_Code__c = input.zipCodes;
        newEL.breg_Name_Company__c = input.nameOrCompany;
        insert newEL;
        return newEl.Id;
    }

    //searching the entities
    @AuraEnabled(cacheable=false)
    public static SearchResult search(SearchInput input) {
        //implement exception handling
        SearchResult result = new SearchResult();
        Integer recordsFound = Database.countQuery(getAccountQueryString(input, true));
        result.RecordsFound = recordsFound; //entities.size();
        List<breg_Fee__c> fees = BREGGetFeeForService.getFees(
            new List<String>{ 'breg_Fee_Amount__c', 'breg_Cashier_Code__c' },
            new Map<String, Object>{ 'breg_Purchase_Type_Fee_type__c' => 'Document', 'breg_Record_Type__c' => 'Entity List' },
            'breg_Cashier_Code__c',
            null
        );
        result.PricePerRecord = fees[0].breg_Fee_Amount__c;
        result.Total = result.RecordsFound * result.PricePerRecord;
        result.FeeId = fees[0].Id;
        return result;
    }

    public static String getAccountQueryString(SearchInput input, Boolean isCount) {
        List<String> zipCodes = new List<String>();
        if (String.isNotBlank(input.zipCodes))
            zipCodes = String.escapeSingleQuotes(input.zipCodes).split(',');

        String accountQueryString = 'SELECT ' + (isCount ? 'COUNT()' : String.join(ACCOUNT_FIELDS, ',').removeEnd(',')) + ' FROM Account WHERE Id!= null';
        if (!input.recordTypes.isEmpty()) {
            //System.QueryException: Variable does not exist: input.recordTypes
            accountQueryString += ' AND breg_Entity_Type__c IN (\'' + String.join(input.recordTypes, '\', \'') + '\')';
        } else
            accountQueryString += ' AND Id = null ';
        if (!zipCodes.isEmpty()) {
            accountQueryString += ' AND BillingPostalCode IN (\'' + String.join(zipCodes, '\', \'') + '\')';
        }
        if (input.name != null && !String.isEmpty(input.name)) {
            accountQueryString += ' AND Name LIKE \'%' + String.escapeSingleQuotes(input.name) + '%\'';
        }

        if (input.startDate != null) {
            accountQueryString += ' AND breg_Incorporation_Date__c > ' + input.startDate;
        }
        if (input.endDate != null) {
            accountQueryString += ' AND breg_Incorporation_Date__c < ' + input.endDate;
        }
        if (input.status != 'All') {
            if (input.status == 'Active') {
                accountQueryString += ' AND breg_Entity_Status__c = \'Active (A)\'';
            } else if (input.status == 'Inactive') {
                accountQueryString += ' AND breg_Entity_Status__c != \'Active (A)\'';
            }
        }
        //the BREGEntityListBuilderBatch runs on behalf of the Guest License - PaymentConnect Profile (PaymentConnect Site Guest User
        //) . TODO: add perm sets / sharing for Entity List/Account/Payment/TransactionLine__c objects for this user
        //accountQueryString += ' WITH SECURITY_ENFORCED';
        return accountQueryString;
    }

    /* public static List<String> getPicklistValueByLabelForAccount(List<String> labels) {
        List<String> values = new List<String>();
        List<String> normalizedLabels = new List<String>();
        for (String label : labels) {
            normalizedLabels.add(label.toLowerCase().trim());
        }
        for (Schema.PicklistEntry entry : ACCOUNT_ENTITY_TYPE_PICKLIST_VALUES) {
            if (normalizedLabels.contains(entry.getLabel().toLowerCase())) {
                values.add(entry.getValue()); // Return API value
            }
        }
        return values;
    } */
}