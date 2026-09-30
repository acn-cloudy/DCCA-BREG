public with sharing class FilingController {
    @AuraEnabled
    public static String getRecord(String objectName, String recordId, String fields) {
        String SOQLstatement = 'SELECT '+ fields +' FROM ' + objectName + ' WHERE Id= :recordId';
        List<sObject> listOfData = Database.query(SOQLstatement);
		return JSON.serialize(listOfData);
      }
    @AuraEnabled
    public static String updateRecord(String fieldsListString) {
        
       	// Set <String> fieldsSet = updatedFields.keySet();
        // List<String> fieldsList = new List<String>(fieldsSet);
		// String fields = String.join(fieldsList, ',');
        // String SOQLstatement = 'SELECT '+ fields +' FROM Filing__c WHERE Id= :recordId';
        // List<sObject> listOfData = Database.query(SOQLstatement);
        SObject record = (SObject)json.deserialize(fieldsListString, SObject.class);
        // set the new data to sobject
        // for (String key : fieldsList) {
        //     listOfData[0].put(key, updatedFields.get(key));
        // }
    	update record;
        return 'success';
    }
}