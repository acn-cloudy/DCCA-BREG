public with sharing class BREGFileNumberGenerator {
    /**
     * Returns the next number in the sequence for the specified entity type.
     * Throws an exception if no matching sequence is found.
     *
     * @param entityType The type of the entity requesting the number.
     * @return The next number in the appropriate sequence.
     */
    public static Integer getNextNumber(String entityType) {
        if (String.isBlank(entityType)) {
            throw new IllegalArgumentException('Entity type must not be blank');
        }

        Map<String, BREG_File_Number_Sequence__c> allSequences = BREG_File_Number_Sequence__c.getAll();

        for (BREG_File_Number_Sequence__c sequence : allSequences.values()) {
            List<String> supportedEntities = sequence.breg_Entity_Codes__c != null ? sequence.breg_Entity_Codes__c.split(',') : new List<String>();

            if (supportedEntities.contains(entityType)) {
                return updateAndReturnNext(sequence);
            }
        }

        throw new IllegalArgumentException('No sequence found for entity type: ' + entityType);
    }

    /**
     * Increments the sequence and returns the new number in a transaction-safe way.
     * Uses SELECT ... FOR UPDATE to ensure exclusive access during the update.
     *
     * @param sequence The sequence record to update.
     * @return The incremented number.
     */
    private static Integer updateAndReturnNext(BREG_File_Number_Sequence__c sequence) {
        BREG_File_Number_Sequence__c seqRecord = [
            SELECT Id, breg_Current_Index__c
            FROM BREG_File_Number_Sequence__c
            WHERE Id = :sequence.Id
            LIMIT 1
            FOR UPDATE
        ];

        Integer nextNumber = (seqRecord.breg_Current_Index__c == null) ? 1 : (Integer) seqRecord.breg_Current_Index__c + 1;
        seqRecord.breg_Current_Index__c = nextNumber;
        update seqRecord;

        return nextNumber;
    }
}