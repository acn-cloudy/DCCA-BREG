/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Custom Record Create component - Used to create generic records using page layouts
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp
* PacPoint-LC010419 - Created for BREG phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class CustomRecordCreate 
{    
    public static Map<String, Schema.SObjectField> fMap { get; set; }
    public static List<PicklistForRecordType__mdt> availablePicklistValuesForThisRecordType {get; set;}
        
	public class MyPickListInfo
	{
		public String validFor;
	}
    @Auraenabled
        public static void saveFileDetails(String fileDetails, String recordTypeName) {
            String recordTypeId = Schema.SObjectType.FileDetails__c.getRecordTypeInfosByName().get(
                    recordTypeName).getRecordTypeId();
            List<FileDetails__c> records = (List<FileDetails__c>) JSON.deserialize(fileDetails, List<FileDetails__c>.class);
            for(FileDetails__c record: records) {
                record.DateReceived__c = Date.Today();
                record.RecordTypeId = recordTypeId;
            }
            insert records;
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for(FileDetails__c record: records) {
                ContentDocumentLink link = new ContentDocumentLink();
                link.contentDocumentID =  record.ContentDocumentId__c;
                link.LinkedEntityId =  record.Id;
                link.Sharetype = 'V';
                links.add(link);
            }
            insert links;
        }
    @AuraEnabled
    public static LayoutWrapper GetLayout(string sObjName, string layoutName, String recordType) 
    {
        String layoutObjName = sObjName;
        if(sObjName == 'PersonAccount') {
            sObjName = 'Account';
        }
        
        fMap = Schema.getGlobalDescribe().get(sObjName.toLowerCase()).getDescribe().Fields.getMap();

        availablePicklistValuesForThisRecordType = 
            [
                SELECT Id, PicklistValue__c, Field__c
                FROM PicklistForRecordType__mdt
                WHERE RecordType__c = :recordType
                AND Object__c = :sObjName
            ];
		
        
        List<String> componentNameList = new List<String>{ layoutObjName + '-' + layoutName };
        List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, componentNameList);
        system.debug(new LayoutWrapper((Metadata.Layout)components.get(0)));

        return new LayoutWrapper((Metadata.Layout)components.get(0));
    }
    
    @AuraEnabled
    public static String SaveRecord(string sObjName, string record, string recordType) {
        if(sObjName == 'PersonAccount') {
            sObjName = 'Account';
        }

        
        fMap = Schema.getGlobalDescribe().get(sObjName.toLowerCase()).getDescribe().Fields.getMap();

        try {
            sObject sObj = Schema.getGlobalDescribe().get(sObjName).newSObject();
            if (recordType != null && recordType != '') {
                List<RecordType> rts = [SELECT Id FROM RecordType WHERE SobjectType = :sObjName AND Name = :recordType];
                if (rts.size() > 0)
                    sObj.put('RecordTypeId', rts[0].Id);
            }
            
            Map<String, Object> recMap = (Map<String, Object>)JSON.deserializeUntyped(record);
            
            for (String key : recMap.keyset()) {
                boolean found = false;
                if(fMap.get(key) == null) continue;
                if (fMap.get(key).getDescribe().getType() == Schema.DisplayType.Date) {
                    sObj.put(key, Date.valueOf(((string)recMap.get(key)).substring(0,10)));
                    found = true;
                }
                if (fMap.get(key).getDescribe().getType() == Schema.DisplayType.DateTime) {
                    sObj.put(key, DateTime.valueOf(((string)recMap.get(key)).substring(0,19).replace('T', ' ')));
                    found = true;
                }
                if (!found) {
                    sObj.put(key, recMap.get(key));
                }
            }
            if(sObj.Id != null ) {
            	update sObj;    
            } else {
                insert sObj;
            }
            
        
            return '{ "status": "OK", "id": "' + sObj.Id + '" }';
            
        } catch (Exception ex) {
            //return '{ "status": "ERROR", "message": "' + ex.getMessage().replace('\"', '\'') + '" }';
            Map<String, String> results = new Map<String, String>();
            results.put('status', 'ERROR');
            results.put('message', ex.getMessage());
            return JSON.serialize(results);
        }
    }
    
    
    
    public class LayoutWrapper {
        @AuraEnabled
        public Metadata.Layout layout { get; set; }
        @AuraEnabled
        public List<SectionWrapper> sections { get; set; }
        
        public LayoutWrapper(Metadata.Layout layout) {
            this.layout = layout;
            sections = new List<SectionWrapper>();
            for (Metadata.LayoutSection section : layout.layoutSections) {
                if (section.style != Metadata.LayoutSectionStyle.CustomLinks && section.label != 'IGNORE') {
                  sections.add(new SectionWrapper(section));
                }
            }
        }
    }
    
    public class PicklistOption {
        @AuraEnabled
        public string label { get; set; }
        @AuraEnabled
        public string value { get; set; }
        
        public PicklistOption(Schema.PicklistEntry plE) {
            label = plE.getLabel();
            value = plE.getValue();
        }
        
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class FieldWrapper {
        @AuraEnabled
        public Metadata.LayoutItem field { get; set; }
        @AuraEnabled
        public string fieldAPIName {
            get {
                return field.field;
            }
        }
        @AuraEnabled
        public List<String> fieldReferenceTo {
            get {
                List<String> referenceTos = new List<String>();
                if(fieldAPIName == null ) { 
                    return referenceTos;
                }
                List<Schema.sObjectType> sobjectTypes = fMap.get(fieldAPIName.toLowerCase()).getDescribe().getReferenceTo();
                if(sobjectTypes == null || sobjectTypes.size() == 0) {
                    return referenceTos;
                } 
                for(Schema.sObjectType sobj: sobjectTypes) {
                    referenceTos.add(sobj.getDescribe().getName());
                }
                return referenceTos;
            }
        }
        
        @AuraEnabled
        public string fieldLabel {
            get {
                if (fieldAPIName == null)
                    return '';
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getLabel();
            }
        }

        @AuraEnabled
        public string fieldHelpText {
            get {
                if (fieldAPIName == null)
                    return '';
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getInlineHelpText();
            }
        }

        @AuraEnabled
        public boolean fieldIsCreatable {
            get {
                return fieldAPIName != null && field.behavior != Metadata.UiBehavior.Readonly && fMap.get(fieldAPIName.toLowerCase()).getDescribe().isCreateable();
            }
        }
        @AuraEnabled
        public boolean fieldIsMandatory {
            get {
                return field.behavior == Metadata.UiBehavior.Required;
            }
        }
        @AuraEnabled
        public string fieldType {
            get {
                if (fieldAPIName == null)
                    return '';
                return fMap.get(fieldAPIName.toLowerCase()).getDescribe().getType().name();
            }
        }
        
        @AuraEnabled
        public List<PicklistOption> statesOptions
        {
            get 
            {
                List<PicklistOption> optoReturn = new List<PicklistOption>();
                Schema.sObjectType objType = Account.getSObjectType();
                Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

                map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
                if(fieldMap.get('ShippingStateCode') == null) {
                	return optoReturn;
                }
                list<Schema.PicklistEntry> values = fieldMap.get('ShippingStateCode').getDescribe().getPickListValues();
				List<SelectOption> options = new List<SelectOption>();
                for (Schema.PicklistEntry v : values){
					if (GenericCreatePaymentCtrl.USStates.contains(v.getLabel())) {
                    	optoReturn.add(new PicklistOption(v)); 
                    }
                }
                return optoReturn;
            }    
        }
        

        
        private Set<String> usStatesPrivate;
    	public Set<String> USStates {
            get {
                if (usStatesPrivate == null) {
                    usStatesPrivate = new Set<String>(getFieldDependencies('Account', 'BillingCountryCode', 'BillingStateCode').get('US'));
                }
                return usStatesPrivate;
            }
        }
        

        
        private Map<String, List<String>> getFieldDependencies(String objectName, String controllingField, String dependentField)
    	{
        Map<String, List<String>> controllingInfo = new Map<String, List<String>>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        
        Schema.DescribeSObjectResult describeResult = objType.getDescribe();
        Schema.DescribeFieldResult controllingFieldInfo = describeResult.fields.getMap().get(controllingField).getDescribe();
        Schema.DescribeFieldResult dependentFieldInfo = describeResult.fields.getMap().get(dependentField).getDescribe();
        
        List<Schema.PicklistEntry> controllingValues = controllingFieldInfo.getPicklistValues();
        List<Schema.PicklistEntry> dependentValues = dependentFieldInfo.getPicklistValues();
        
        for(Schema.PicklistEntry currControllingValue : controllingValues)
        {
            controllingInfo.put(currControllingValue.getValue(), new List<String>());
        }
        
        for(Schema.PicklistEntry currDependentValue : dependentValues)
        {
            String jsonString = JSON.serialize(currDependentValue);
            
            MyPickListInfo info = (MyPickListInfo) JSON.deserialize(jsonString, MyPickListInfo.class);
            
            String hexString = EncodingUtil.convertToHex(EncodingUtil.base64Decode(info.validFor)).toUpperCase();
            
            Integer baseCount = 0;
            
            for(Integer curr : hexString.getChars())
            {
                Integer val = 0;
                
                if(curr >= 65)
                {
                    val = curr - 65 + 10;
                }
                else
                {
                    val = curr - 48;
                }
                
                if((val & 8) == 8)
                {
                    controllingInfo.get(controllingValues[baseCount + 0].getValue()).add(currDependentValue.getLabel());
                }
                if((val & 4) == 4)
                {
                    controllingInfo.get(controllingValues[baseCount + 1].getValue()).add(currDependentValue.getLabel());                    
                }
                if((val & 2) == 2)
                {
                    controllingInfo.get(controllingValues[baseCount + 2].getValue()).add(currDependentValue.getLabel());                    
                }
                if((val & 1) == 1)
                {
                    controllingInfo.get(controllingValues[baseCount + 3].getValue()).add(currDependentValue.getLabel());                    
                }
                
                baseCount += 4;
            }            
        } 
        
        System.debug('ControllingInfo: ' + controllingInfo);
        
        return controllingInfo;
    }
        

        
        @AuraEnabled
        public List<PicklistOption> piclistOptions 
        {
            get 
            {
                List<PicklistOption> toReturn = new List<PicklistOption>();
                List<PicklistForRecordType__mdt> availablePicklistValueForCurrentField = new List<PicklistForRecordType__mdt>();
                
                if(fieldAPIName != null) 
                {
                    // get all picklist values for this object, recordType and fieldApiName
                    for(PicklistForRecordType__mdt availablePicklistValue : availablePicklistValuesForThisRecordType)
                    {
                        if(availablePicklistValue.Field__c.toLowerCase() == fieldAPIName.toLowerCase())
                        {
                            availablePicklistValueForCurrentField.add(availablePicklistValue);
                        }
                    }

                    // if no values were found for this picklist field in the metadata type, display all existing values regardless of recordType
                    if(availablePicklistValueForCurrentField.size() == 0)
                    { 
                        for (Schema.PicklistEntry plE : fMap.get(fieldAPIName.toLowerCase()).getDescribe().getPicklistValues()) 
                        {
                            toReturn.add(new PicklistOption(plE));
                        }
                    }
                    else
                    {
                        for (Schema.PicklistEntry plE : fMap.get(fieldAPIName.toLowerCase()).getDescribe().getPicklistValues()) 
                        {
                            for(PicklistForRecordType__mdt availablePicklistValue : availablePicklistValuesForThisRecordType)
                            {
                                if(plE.getValue() == availablePicklistValue.PicklistValue__c)
                                {
                                    toReturn.add(new PicklistOption(plE));
                                }
                            }
                        }
                    }
                }

                return toReturn;
            }
        }
        
        
        @AuraEnabled
        public object defaultValue {set;get;}
        
        public FieldWrapper(Metadata.LayoutItem field) {
            this.field = field;
            if (fieldAPIName != null ) {
                if( fieldType == 'TEXTAREA') {
                    String defaultValue = fMap.get(fieldAPIName.toLowerCase()).getDescribe().getDefaultValueFormula();
                    if(defaultValue != null && defaultValue.length() > 2) {
                        this.defaultValue =defaultValue.substring(1, defaultValue.length() -2);
                    }
                     
                } else {
                    this.defaultValue = fMap.get(fieldAPIName.toLowerCase()).getDescribe().getDefaultValue();
                }
                
            }


        }
    }
    
    public class FieldGroupWrapper {
        @AuraEnabled
        public FieldWrapper field1 { get; set; }
        @AuraEnabled
        public FieldWrapper field2 { get; set; }
    }
    
    public class SectionWrapper {
        @AuraEnabled
        public Metadata.LayoutSection section { get; set; }

        @AuraEnabled
        public string label {
            get {
                if(!section.detailHeading) return '';
                return section.label;
            }
        }

        @AuraEnabled
        public integer columns {
            get {
                if (section == null || section.style == Metadata.LayoutSectionStyle.TwoColumnsTopToBottom || section.style == Metadata.LayoutSectionStyle.TwoColumnsLeftToRight) {
                    return 2;
                } else {
                    return 1;
                }
            }
        }
        @AuraEnabled
        public List<FieldGroupWrapper> fields { get; set; }
        
        public SectionWrapper(Metadata.LayoutSection section) {
            this.section = section;
            fields = new List<FieldGroupWrapper>();
            
            if (section.layoutColumns.size() == 1) {
                if(section.layoutColumns[0].layoutItems != null ){
                    for (Metadata.LayoutItem li : section.layoutColumns[0].layoutItems) {
                        FieldGroupWrapper fgw = new FieldGroupWrapper();
                        fgw.field1 = new FieldWrapper(li);
                        fields.add(fgw);
                    }
                }
            }
            if (section.layoutColumns.size() == 2) {
                for (integer i = 0; i < Math.max((section.layoutColumns[0].layoutItems == null ? 0 : section.layoutColumns[0].layoutItems.size()), (section.layoutColumns[1].layoutItems == null ? 0 : section.layoutColumns[1].layoutItems.size())); i++) {
                    FieldGroupWrapper fgw = new FieldGroupWrapper();
                    if (section.layoutColumns[0].layoutItems != null && section.layoutColumns[0].layoutItems.size() > i)
                        fgw.field1 = new FieldWrapper(section.layoutColumns[0].layoutItems[i]);
                    if (section.layoutColumns[1].layoutItems != null && section.layoutColumns[1].layoutItems.size() > i)
                        fgw.field2 = new FieldWrapper(section.layoutColumns[1].layoutItems[i]);
                    fields.add(fgw);
                }
            }
        }
    }

    /*private List<Edit_Opportunity_Settings__mdt> oppSettings;
    
    private String recordTypeId;
    private Id recordId;
    public sObject opp { get; set; }
    public List<LocationWrapper> locations { get; set; }
    private List<Product_Shipping_Location__c> toDelete;
    private integer lastIdentifier = 0;
    
    private string layoutName { get; set; }
    public LayoutWrapper opptyLayout { get; set; }
    
    public Metadata.UiBehavior MetadataUiBehaviorRequired {
        get {
            return Metadata.UiBehavior.Required;
        }
    }

    public EditOpportunity(ApexPages.StandardController ctrl) {
        
        oppSettings = [SELECT Opportunity_Record_Type__c, Opportunity_Layout_Name__c FROM Edit_Opportunity_Settings__mdt];
        
        oppId = ctrl.getId();
        recordTypeId = ApexPages.currentPage().getParameters().get('RecordType');
        
        toDelete = new List<Product_Shipping_Location__c>();
        
        locations = new List<LocationWrapper>();
        
        if (oppId == null) {
            opp = new Opportunity();
            //custom Account button logic
            if(ApexPages.currentPage().getParameters().get('acctButton')=='true'){
                opp.Name = ApexPages.currentPage().getParameters().get('opp3');
                opp.AccountId = ApexPages.currentPage().getParameters().get('acctId'); 
                opp.StageName = ApexPages.currentPage().getParameters().get('opp11');
            }             
        } else {
          opp = Database.query(getFieldsSOQL('Opportunity', 'RecordType.Name', 'Id = :oppId'));
            for (Product_Shipping_Location__c location : Database.query(getFieldsSOQL('Product_Shipping_Location__c', null, 'Opportunity__c = :oppId'))) {
                locations.add(new LocationWrapper(location, lastIdentifier));
                lastIdentifier++;
            }
            
        }
    }
    
    public PageReference LoadOrRedirect() {
        RecordType rt = null;
        if (recordTypeId != null && recordTypeId != '')
            rt = [SELECT Name FROM RecordType WHERE Id = :recordTypeId];
        if (oppId == null) {
            for (Edit_Opportunity_Settings__mdt mdt : oppSettings) {
                if (rt != null && mdt.Opportunity_Record_Type__c == rt.Name) {
                    layoutName = mdt.Opportunity_Layout_Name__c;
              LoadMetadata();
                    if (rt != null) {
                        opp.RecordTypeId = rt.Id;
                    }
                    return null;
                }
            }
            return new PageReference('/006/e?retURL=%2F006%2Fo' + (rt != null ? ('&RecordType=' + rt.Id) : '') + '&ent=Opportunity&nooverride=1');
        } else {
            string rtName = opp.RecordType.Name;
            if (rt != null) {
                rtName = rt.Name;
            }
            for (Edit_Opportunity_Settings__mdt mdt : oppSettings) {
                if (mdt.Opportunity_Record_Type__c == rtName) {
                    layoutName = mdt.Opportunity_Layout_Name__c;
              LoadMetadata();
                    if (rt != null) {
                        opp.RecordTypeId = rt.Id;
                    }
                    return null;
                }
            }
            return new PageReference('/' + opp.Id + '/e?retURL=%2F' + opp.Id + '&nooverride=1' + (rt != null ? ('&RecordType=' + rt.Id) : ''));
        }
    }
    
    public void AddLocation() {
        Product_Shipping_Location__c location = new Product_Shipping_Location__c();
        locations.add(new LocationWrapper(location, lastIdentifier));
        lastIdentifier++;
    }
    
    public void RemoveLocation() {
        string identifier = ApexPages.currentPage().getParameters().get('identifier');
        for (integer i = 0; i < locations.size(); i++) {
            if (string.valueOf(locations[i].identifier) == identifier) {
                LocationWrapper location = locations.remove(i);
                if (location.location.Id != null) {
                    toDelete.add(location.location);
                }
                return;
            }
        }
    }
    
    public PageReference SaveOpportunity() {
        Savepoint sp = Database.setSavepoint();
        
        if (locations.size() == 0) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                 'You must add all shipping locations and quantities for this product before saving this record.'));
            return null;
        }
        
        try {
          upsert opp;
            
            List<Product_Shipping_Location__c> toUpsert = new List<Product_Shipping_Location__c>();
            for (LocationWrapper location : locations) {
                if (location.location.Id == null)
                  location.location.Opportunity__c = opp.Id;
                toUpsert.add(location.location);
            }
            upsert toUpsert;
            
            if (toDelete.size() > 0) {
                delete toDelete;
            }
            
            return new PageReference('/' + opp.Id);
        } catch (Exception ex) {
            Database.rollback(sp);
            ApexPages.addMessages(ex);
            return null;
        }
    }
    
    private void LoadMetadata() {
        
        List<String> componentNameList = new List<String>{ layoutName };
        List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, componentNameList);
        
        opptyLayout = new LayoutWrapper((Metadata.Layout)components.get(0));
        
    }
    
    private string getFieldsSOQL(String objectName, String additionalFields, String whereClause){
   
        String selects = '';
         
        if (whereClause == null || whereClause == ''){ return null; }
         
        // Get a map of field name and field token
        Map<String, Schema.SObjectField> fMap = Schema.getGlobalDescribe().get(objectName.toLowerCase()).getDescribe().Fields.getMap();
        list<string> selectFields = new list<string>();
         
        if (fMap != null){
            for (Schema.SObjectField ft : fMap.values()){ // loop through all field tokens (ft)
                Schema.DescribeFieldResult fd = ft.getDescribe(); // describe each field (fd)
                selectFields.add(fd.getName());
            }
        }
         
        if (!selectFields.isEmpty()){
            for (string s:selectFields){
                selects += s + ',';
            }
            if (selects.endsWith(',')){selects = selects.substring(0,selects.lastIndexOf(','));}
             
        }
        if (additionalFields != null && additionalFields != '') {
            selects += ', ' + additionalFields;
        }
         
        return 'SELECT ' + selects + ' FROM ' + objectName + ' WHERE ' + whereClause;
         
    }
    
    public class LayoutWrapper {
        public Metadata.Layout layout { get; set; }
        public List<SectionWrapper> sections { get; set; }
      public Metadata.RelatedListItem locationRelatedList { get; set; }
        
        public LayoutWrapper(Metadata.Layout layout) {
            this.layout = layout;
            sections = new List<SectionWrapper>();
            for (Metadata.LayoutSection section : layout.layoutSections) {
                if (section.style != Metadata.LayoutSectionStyle.CustomLinks) {
                  sections.add(new SectionWrapper(section));
                }
            }
            for (Metadata.RelatedListItem rli : layout.relatedLists) {
                if (rli.relatedList == 'Product_Shipping_Location__c.Opportunity__c') {
                    locationRelatedList = rli;
                }
            }
        }
    }
    
    public class SectionWrapper {
        public Metadata.LayoutSection section { get; set; }
        public integer columns {
            get {
                if (section == null || section.style == Metadata.LayoutSectionStyle.TwoColumnsTopToBottom || section.style == Metadata.LayoutSectionStyle.TwoColumnsLeftToRight) {
                    return 2;
                } else {
                    return 1;
                }
            }
        }
        public List<Metadata.LayoutItem> fields { get; set; }
        
        public SectionWrapper(Metadata.LayoutSection section) {
            this.section = section;
            fields = new List<Metadata.LayoutItem>();
            integer fieldCnt = 0;
            
            boolean fieldFound = true;
            while (fieldFound) {
                fieldFound = false;
                for (Metadata.LayoutColumn column : section.layoutColumns) {
                    if (column.layoutItems != null && fieldCnt < column.layoutItems.size()) {
                        fieldFound = true;
                        fields.add(column.layoutItems[fieldCnt]);
                    }
                }
                fieldCnt++;
            }
        }
    }
    
    public class LocationWrapper {
        public integer identifier { get; set; }
        public Product_Shipping_Location__c location { get; set; }
        
        public LocationWrapper(Product_Shipping_Location__c location, integer identifier) {
            this.location = location;
            this.identifier = identifier;
        }
    }*/
}