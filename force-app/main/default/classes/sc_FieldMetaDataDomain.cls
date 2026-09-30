public without sharing class sc_FieldMetaDataDomain extends SObjectDomain {
    public sc_FieldMetaDataDomain(List<Field_Meta_Data__c> fieldMetaData){
        super(fieldMetaData);
    }
    /***
        Used to get field value
    ***/
    public List<sc_SummaryFeeds.Feed> getFieldValues(Map<String, Object> valueMap){
        List<sc_SummaryFeeds.Feed> feeds = new List<sc_SummaryFeeds.Feed>();
        for(SObject record: records) {
            sc_SummaryFeeds.Feed unit;
            Field_Meta_Data__c fieldMeta = (Field_Meta_Data__c) record;
            String apiName = fieldMeta.Name__c;
            if(!valueMap.containsKey(apiName)) {
                continue;
            }
            if(fieldMeta.Type__c == 'info') {
                continue;
            }
            String valueRaw = valueMap.get(apiName)+'';
            if(valueRaw == null ) {
                continue;
            }
            String value = valueRaw.removeEnd(',false').removeEnd(',true');
            
            String label = fieldMeta.Label__c;
            if (value.contains('null')){
                continue;
            }
            if(fieldMeta.Type__c == 'inputtable' ) {
                // Conditions for the table.
                String colStr = fieldMeta.input_table_cols__c;
                if(colStr != null && value.contains('#')){
                    List<String> cols = colStr.split(',');
                    unit = new sc_SummaryFeeds.Feed(label, value, cols);
                }
            }
            if(fieldMeta.Type__c == 'clm-file' ) {
                if(value != null && value.length() > 3) {
                    value = 'File uploaded';
                }
            }
            if(fieldMeta.Type__c == 'table' && !String.isBlank(value) ) {
                System.debug('####fieldMeta.Type__c####' + fieldMeta.Type__c);
                sc_SummaryFeeds.Feed feed = new sc_SummaryFeeds.Feed(label);

                List<SObject> listOfData = (List<SObject>)JSON.deserialize(value, 
                    List<SObject>.class);
                String colsTable = fieldMeta.input_table_cols__c;
                List<sc_SummaryFeeds.FieldInfo> fields = (List<sc_SummaryFeeds.FieldInfo>)JSON.deserialize(colsTable, 
                        List<sc_SummaryFeeds.FieldInfo>.class);
                List<String> extraColumns = new List<String>();
                List<sc_SummaryFeeds.Row> rows = new List<sc_SummaryFeeds.Row>();
                for(SObject data: listOfData) {
                    sc_SummaryFeeds.Row row = new sc_SummaryFeeds.Row();
                    List<sc_SummaryFeeds.Column> columns = new List<sc_SummaryFeeds.Column>();
                    for(sc_SummaryFeeds.FieldInfo field: fields ) {
                        String fieldLabel = field.label;
                        String fieldApiName = field.apiName;
                        String type = field.type;
                        String unitStr = '';
                        try{
                            
                            if(data != null && data.get(fieldApiName) != null) {
                                unitStr = String.valueOf(data.get(fieldApiName));
                                if(type == 'datetime') {
                                    DateTime dt = DateTime.ValueofGmt(unitStr.replace('T', ' ')); 
                                    unitStr =  dt.format('MM/dd/yyyy hh:mm');
                                } else if(type == 'date') {
                                    unitStr = unitStr.split(' ')[0];
                                }
                            }
                        } catch (Exception ex) {
                            // Make sure that the field is correctly populated. 
                        }
                        sc_SummaryFeeds.Column column 
                            = new sc_SummaryFeeds.Column(fieldLabel, unitStr);
                        columns.add(column);
                        extraColumns.add(field.label);
                    }
                    row.columns = columns;
                    rows.add(row);
                }
                feed.rows = rows;
                feed.sortOrder = fieldMeta.Sort_Order__c;
                feed.cols = extraColumns;
                feeds.add(feed);
                continue;
            }

            if(fieldMeta.Type__c == 'checkbox') {
                if(value == 'true' ){
                    value = 'Yes';
                } else {
                    value = 'No';
                }
            }
            if(fieldMeta.Type__c == 'datetime') {
                DateTime dt = DateTime.ValueofGmt(value.replace('T', ' ')); 
                value =  dt.format('dd/MM/yyyy hh:mm');
            }
            if(unit == null )
                unit = new sc_SummaryFeeds.Feed(label, value);
            unit.sortOrder = fieldMeta.Sort_Order__c;
            feeds.add(unit);    
        }
        feeds.sort();
        return feeds;
    }
    /***
        Used to return Name__c => fields if there are Quality_Check value
    ***/
    public Map<String, Field_Meta_Data__c> getQualityCheckData() {
        Map<String, Field_Meta_Data__c> fieldMeta = new Map<String, Field_Meta_Data__c>();
        for(SObject record: records) {
            Field_Meta_Data__c field = (Field_Meta_Data__c) record;
            if(field.Quality_Check__c != null && field.Quality_Check__c.length() > 0) {
                fieldMeta.put(field.Name__c, field);
            }
        }
        return fieldMeta;
    }
    /***
     * Description: get card id to fields map
     * Used by: sc_CardMetaDataService.getCardsAndFieldsByAppName
     * 
     * 
    ***/
    public Map<String, List<Field_Meta_Data__c>> getCardToFieldsMap() {
        Map<String, List<Field_Meta_Data__c>> fieldMeta = new Map<String, List<Field_Meta_Data__c>>();
        for(SObject record: records) {
            Field_Meta_Data__c meta = (Field_Meta_Data__c) record;
            String cardId = meta.Card_Meta_Data__c;
            List<Field_Meta_Data__c> fields = new List<Field_Meta_Data__c>();
            if(fieldMeta.containsKey(cardId)) {
                fields = fieldMeta.get(cardId);
            }
            fields.add(meta);
            fieldMeta.put(cardId, fields);
        }
        return fieldMeta; 
    }
    
    /***
     * Description: get app id to fields map
     * Used by FieldMetaDataService.getFields
     * 
    ***/
    public Map<String, Map<String, List<Field_Meta_Data__c>>> getAppToFields() {
        Map<String, Map<String, List<Field_Meta_Data__c>>> appToFieldMeta = new Map<String, Map<String, List<Field_Meta_Data__c>>>();
        for(SObject record: records) {
            Map<String, List<Field_Meta_Data__c>> fieldMeta = new Map<String, List<Field_Meta_Data__c>>();
            Field_Meta_Data__c meta = (Field_Meta_Data__c) record;
            String appMetaDataId = meta.Card_Meta_Data__r.Application_Meta_Data__c;
            if(appToFieldMeta.containsKey(appMetaDataId)) {
                fieldMeta = appToFieldMeta.get(appMetaDataId);
            }
            String cardId = meta.Card_Meta_Data__c;
            List<Field_Meta_Data__c> fields = new List<Field_Meta_Data__c>();
            if(fieldMeta.containsKey(cardId)) {
                fields = fieldMeta.get(cardId);
            }
            fields.add(meta);
            fieldMeta.put(cardId, fields);
            appToFieldMeta.put(appMetaDataId, fieldMeta);
        }
        return appToFieldMeta; 
    }
    public List<Field_Meta_Data__c> filteredInfoFields(){ 
        List<Field_Meta_Data__c> fields = new List<Field_Meta_Data__c>();
        for(SObject record: records) {
            Field_Meta_Data__c field = (Field_Meta_Data__c) record;
            if(field.Type__c != 'info') {
                fields.add(field);
            }
             
        }
        return fields;
    }
    /***
     * Description: used to get user field names
     * Used by : by sc_onboardingController.getUserInfo
     * 
    ***/
    public List<String> getUserFieldNames() {
        List<String> fields = new List<String>();
        for(SObject record: records) {
            Field_Meta_Data__c fieldMetaData = (Field_Meta_Data__c) record;
            if(sc_GlobalConstants.USERSTR.equalsIgnoreCase(fieldMetaData.Object__c)) {
                if(fieldMetaData.Type__c != 'Info') {
                    fields.add(fieldMetaData.ObjectField__c);
                }
            }
        }
        return fields;
    }

    // Summary the fields to be Card Meta Data => List Fields
    public Map<String, List<Field_Meta_Data__c>> getCardId2FieldList() {
        Map<String, List<Field_Meta_Data__c>> cardId2FieldList = new Map<String, List<Field_Meta_Data__c>>();
        for(Field_Meta_Data__c record: (List<Field_Meta_Data__c> )records) {
            List<Field_Meta_Data__c> fieldList = new List<Field_Meta_Data__c>();
            if(cardId2FieldList.containsKey(record.Card_Meta_Data__c)) {
                fieldList = cardId2FieldList.get(record.Card_Meta_Data__c);
            }
            fieldList.add(record);
            cardId2FieldList.put(record.Card_Meta_Data__c, fieldList);
        }
        return cardId2FieldList;
    }
    

}