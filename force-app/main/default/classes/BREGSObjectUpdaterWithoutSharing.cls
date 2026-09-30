public without sharing class BREGSObjectUpdaterWithoutSharing {
    public static void updateRecord(SObject recordToUpdate) {
        updateRecords(recordToUpdate == null ? null : new List<SObject>{ recordToUpdate });
    }

    public static void updateRecords(List<SObject> recordsToUpdate) {
        if (recordsToUpdate == null || recordsToUpdate.isEmpty()) {
            return;
        }

        update recordsToUpdate;
    }

    public static List<SObject> selectRecordsByQuery(String query) {
        if (String.isBlank(query)) {
            return new List<SObject>();
        }

        return Database.query(query);
    }

    public static void updateRecordsByQuery(String query, Map<String, Object> fieldValues) {
        if (String.isBlank(query) || fieldValues == null || fieldValues.isEmpty()) {
            return;
        }

        List<SObject> recordsToUpdate = selectRecordsByQuery(query);
        if (recordsToUpdate.isEmpty()) {
            return;
        }

        for (SObject recordToUpdate : recordsToUpdate) {
            for (String fieldApiName : fieldValues.keySet()) {
                recordToUpdate.put(fieldApiName, fieldValues.get(fieldApiName));
            }
        }

        update recordsToUpdate;
    }

    public static void upsertRecord(SObject recordToUpsert) {
        upsertRecords(recordToUpsert == null ? null : new List<SObject>{ recordToUpsert });
    }

    public static void upsertRecords(List<SObject> recordsToUpsert) {
        if (recordsToUpsert == null || recordsToUpsert.isEmpty()) {
            return;
        }

        upsert recordsToUpsert;
    }
}