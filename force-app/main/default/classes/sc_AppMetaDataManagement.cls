public class sc_AppMetaDataManagement {
    public class DataFeed {
        public Application_Meta_Data__c record {set;get;}
        public List<Card_Meta_Data__c> cards {set;get;}
        public Map<String, List<Field_Meta_Data__c>> fields {set;get;}
        public List<Field_Filter__c> fieldFilters {set;get;}

    }
    @AuraEnabled
    public static Boolean backupApp(String recordId) {
        Application_Meta_Data__c record = [Select Id, Name from Application_Meta_Data__c where Id =: recordId];
        return backupAppMetaData(record.Name);
    }

    @InvocableMethod(label='Backup Apps' category='Dynamic Application Form')
    public static void backup(List<String> names) {
        backupAppMetaData(names.get(0));
    }


    public static Boolean backupAppMetaData(String appName) {
        List<Application_Meta_Data__c> appData = sc_ApplicationMetaDataSelector.getApplicationMetaDataByName(appName);
        List<Card_Meta_Data__c> cardData = sc_CardMetaDataSelector.getCardsAndFieldsByAppName(appName);
        List<Field_Meta_Data__c> fieldData = sc_FieldMetaDataSelector.getFieldMetaDataByAppName(appName);
        Map<String, List<Field_Meta_Data__c>> fieldMetaData = (new sc_FieldMetaDataDomain(fieldData)).getCardId2FieldList();
        List<Field_Filter__c> fieldFilters = sc_FieldFilterSelector.getFieldFiltersByAppName(appName);

        DataFeed feed = new DataFeed();
        feed.record = appData.get(0);
        feed.cards = cardData;
        feed.fields = fieldMetaData;
        feed.fieldFilters = fieldFilters;
        String str = JSON.serialize(feed);
        
        return createOrUpdateStaticResource(appName, str, 'text/plain');
    }
    
    public static Boolean createOrUpdateStaticResource(String resourceName, String fileContent, String contentType) {
        String fileName = resourceName.replace(' ', '');
        fileName = fileName.replace('-', '');
        String itemName = '%' + resourceName ;
        List<StaticResource> resourceRecords = [Select Id, name, Body, Description from StaticResource where Description like: itemName];
        String recordId = null;
        if(!resourceRecords.isEmpty()) {
            recordId = resourceRecords.get(0).Id;
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:UI_API_Credentials/services/data/v53.0/tooling/sobjects/StaticResource');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        Map<String, Object> requestBody = new Map<String, Object>{
            'FullName' => fileName,
            'Metadata' => new Map<String, Object>{
                'content' => EncodingUtil.base64Encode(Blob.valueOf(fileContent)),
                'cacheControl' => 'Public',
                'description' => 'Dynamic Application - ' + resourceName,
                'contentType' => contentType}
        };

        if(recordId != null) {
            req.setEndpoint('callout:UI_API_Credentials/services/data/v53.0/tooling/sobjects/StaticResource/'+ recordId);
            req.setMethod('PATCH');
            requestBody = new Map<String, Object>{
                'FullName' => fileName,
                'Metadata' => new Map<String, Object>{
                    'content' => EncodingUtil.base64Encode(Blob.valueOf(fileContent)),
                    'cacheControl' => 'Public',
                    'description' => 'Dynamic Application - ' + resourceName,
                    'contentType' => contentType}
            };
        }
        req.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        Boolean isSucceed = false;
        if(Test.isRunningTest()) {
            return isSucceed;
        }
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 201 || res.getStatusCode() == 204) {
            System.debug('Static resource created or updated successfully');
            isSucceed = true;
        } else {
            System.debug('Error: ' + res.getStatusCode() + ' ' + res.getStatus());
            System.debug(res.getBody());
        }
        return isSucceed;
    }
    public static void parseResource(String resourceName, String recordId) {
        String itemName = '%' + resourceName ;
        StaticResource record = [Select Id, name, Body, Description from StaticResource where Description like: itemName];
        Blob value = record.Body;
        String str = value.toString();
        parseApplication(str, recordId);
    }
    public static void parseResource(String resourceName) {
        String itemName = '%' + resourceName ;
        StaticResource record = [Select Id, name, Body, Description from StaticResource where Description like: itemName];
        Blob value = record.Body;
        String str = value.toString();
        parseApplication(str);
    }

    public static void parseApplication(String str) {
        DataFeed feed = (DataFeed)JSON.deserialize(str, DataFeed.class);
        Application_Meta_Data__c record = feed.record;
        record.Id = null;
        insert record;

        List<Card_Meta_Data__c> cardRecords = feed.cards;
        List<String> originalCardMetaDataIds = new List<String>();
        for(Card_Meta_Data__c cardRecord: cardRecords) {
            originalCardMetaDataIds.add(cardRecord.Id);
        }
        // remove Ids
        for(Card_Meta_Data__c cardRecord: cardRecords) {
            cardRecord.Id = null;
            cardRecord.Application_Meta_Data__c = record.Id;

        }
        insert cardRecords;
        Map<String, String> oldId2NewId = new Map<String, String>();

        for(Integer index =0;index< cardRecords.size(); index ++) {
            Card_Meta_Data__c cardRecord = cardRecords.get(index);
            oldId2NewId.put(originalCardMetaDataIds.get(index), cardRecord.Id);
        }

        Map<String, List<Field_Meta_Data__c>> fieldData = feed.fields;
        
        List<String> oldFieldIds = new List<String>();
        System.debug('#######oldId2NewId######' + oldId2NewId);
        List<Field_Meta_Data__c> fieldToInsert = new List<Field_Meta_Data__c>();
        for(String key: fieldData.keySet()) {
            String cardId = oldId2NewId.get(key);
            List<Field_Meta_Data__c> fieldMeta = fieldData.get(key);
            for(Field_Meta_Data__c fieldD: fieldMeta) {
                oldFieldIds.add(fieldD.Id);

                fieldD.Card_Meta_Data__c = cardId;
                fieldD.Id = null;
                fieldToInsert.add(fieldD);

            }
        }
        insert fieldToInsert;

        Map<String, String> oldId2NewFieldId = new Map<String, String>();

        for(Integer index =0;index< fieldToInsert.size(); index ++) {
            Field_Meta_Data__c fieldRecord = fieldToInsert.get(index);
            oldId2NewFieldId.put(oldFieldIds.get(index), fieldRecord.Id);
        }

        System.debug('#######oldId2NewFieldId######' + oldId2NewFieldId);

        List<Field_Filter__c> fieldFilters = feed.fieldFilters;
        for(Field_Filter__c fieldFilter: fieldFilters) {
            fieldFilter.Id = null;
            fieldFilter.Affected_Field_Meta_Data__c = oldId2NewFieldId.get(fieldFilter.Affected_Field_Meta_Data__c);
        }
        insert fieldFilters;
    }

    public static void parseApplication(String str, String recordId) {
        DataFeed feed = (DataFeed)JSON.deserialize(str, DataFeed.class);
        Application_Meta_Data__c record = feed.record;
        record.Id = recordId;
        // insert record;

        List<Card_Meta_Data__c> cardRecords = feed.cards;
        List<String> originalCardMetaDataIds = new List<String>();
        for(Card_Meta_Data__c cardRecord: cardRecords) {
            originalCardMetaDataIds.add(cardRecord.Id);
        }
        // remove Ids
        for(Card_Meta_Data__c cardRecord: cardRecords) {
            cardRecord.Id = null;
            cardRecord.Application_Meta_Data__c = record.Id;

        }
        insert cardRecords;
        Map<String, String> oldId2NewId = new Map<String, String>();

        for(Integer index =0;index< cardRecords.size(); index ++) {
            Card_Meta_Data__c cardRecord = cardRecords.get(index);
            oldId2NewId.put(originalCardMetaDataIds.get(index), cardRecord.Id);
        }

        Map<String, List<Field_Meta_Data__c>> fieldData = feed.fields;
        
        List<String> oldFieldIds = new List<String>();
        System.debug('#######oldId2NewId######' + oldId2NewId);
        List<Field_Meta_Data__c> fieldToInsert = new List<Field_Meta_Data__c>();
        for(String key: fieldData.keySet()) {
            String cardId = oldId2NewId.get(key);
            List<Field_Meta_Data__c> fieldMeta = fieldData.get(key);
            for(Field_Meta_Data__c fieldD: fieldMeta) {
                oldFieldIds.add(fieldD.Id);

                fieldD.Card_Meta_Data__c = cardId;
                fieldD.Id = null;
                fieldToInsert.add(fieldD);

            }
        }
        insert fieldToInsert;

        Map<String, String> oldId2NewFieldId = new Map<String, String>();

        for(Integer index =0;index< fieldToInsert.size(); index ++) {
            Field_Meta_Data__c fieldRecord = fieldToInsert.get(index);
            oldId2NewFieldId.put(oldFieldIds.get(index), fieldRecord.Id);
        }

        System.debug('#######oldId2NewFieldId######' + oldId2NewFieldId);

        List<Field_Filter__c> fieldFilters = feed.fieldFilters;
        for(Field_Filter__c fieldFilter: fieldFilters) {
            fieldFilter.Id = null;
            fieldFilter.Affected_Field_Meta_Data__c = oldId2NewFieldId.get(fieldFilter.Affected_Field_Meta_Data__c);
        }
        insert fieldFilters;
    }
    public static void deleteWholeApp(String recordId) {
        List<Field_Filter__c> fieldFilters = [Select Id from Field_Filter__c where Affected_Field_Meta_Data__r.Card_Meta_Data__r.Application_Meta_Data__c =: recordId];
        List<Field_Meta_Data__c> fieldMetaData = [Select Id from Field_Meta_Data__c where Card_Meta_Data__r.Application_Meta_Data__c =: recordId];
        List<Card_Meta_Data__c> cardMetaData = [Select Id from Card_Meta_Data__c where Application_Meta_Data__c =: recordId];
        List<Application_Meta_Data__c> appMetaData = [Select Id from Application_Meta_Data__c where Id =: recordId];
        delete fieldFilters;
        delete fieldMetaData;
        delete cardMetaData;
        // delete appMetaData;
    }
}