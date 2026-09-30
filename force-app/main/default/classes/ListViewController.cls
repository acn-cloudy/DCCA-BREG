public class ListViewController {
    public class CustomRecord {
        public Integer index{set;get;}
        public SObject record {set;get;}
        public Boolean isSuccess {set;get;}
        public Boolean updated {set;get;}
        public List<Database.Error> errors {set;get;}
    }
    @auraEnabled 
    public static String sortRecords(String relatedSObject, String sortBy, String sortSeq, 
            List<String> recordIds, List<String> columnNames) {
        String query = 'Select ' +  String.join(columnNames, ',') + ' from ' + relatedSObject 
                        +' where Id in: recordIds  order by ' +sortBy ;
        if(sortSeq != 'down') {
            query += ' desc';
        }
        return Json.serialize(Database.query (query));
    }
    @auraEnabled
    public static String upsertRecords(String recordStr) {
        List<CustomRecord> customRecords = (List<CustomRecord>) JSON.deserialize(
            recordStr, List<CustomRecord>.class);

        List<CustomRecord> newRecords = new List<CustomRecord>();
        List<CustomRecord> updatedRecords = new List<CustomRecord>();
        for(CustomRecord customRecord: customRecords) {
            if(customRecord.record.Id == null) {
                newRecords.add(customRecord);
            } else {
                updatedRecords.add(customRecord);
            }
        }
        List<CustomRecord> newResults = updateRecords(newRecords, true);
        List<CustomRecord> updatedResults = updateRecords(updatedRecords, false);
        updatedResults.addAll(newResults);
        System.debug('####updatedResults####' +updatedResults);
        return JSON.serialize(updatedResults);
    }
    public static List<CustomRecord> updateRecords(List<CustomRecord> customRecords, Boolean isInsert) {
        List<SObject> records = new List<SObject>();
        for(CustomRecord customRecord: customRecords) {
            records.add(customRecord.record);
        }
        List<Database.SaveResult> results = null;
        if(isInsert) {
            results = Database.insert(records, false);
        } else {
            results = Database.update(records, false);
        }
        for(Integer i = 0 ;i< results.size(); i++) {
            Database.SaveResult result = results.get(i);
            CustomRecord customRecord = customRecords.get(i);
            customRecord.isSuccess = result.isSuccess();
            customRecord.updated = false;
            if(!customRecord.isSuccess){
                customRecord.errors = result.getErrors();
            } 
        }
        return customRecords;
    }
}