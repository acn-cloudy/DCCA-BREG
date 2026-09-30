@IsTest
private class BREGFileNumberGeneratorTest {
    @IsTest
    static void testGetNextNumberIncrementsMatchingSequence() {
        BREG_File_Number_Sequence__c sequenceRecord = new BREG_File_Number_Sequence__c(
            Name = 'Unit Test Sequence',
            breg_Entity_Codes__c = 'UT1,UT2',
            breg_Current_Index__c = 7
        );
        insert sequenceRecord;

        Integer nextNumber = BREGFileNumberGenerator.getNextNumber('UT1');

        BREG_File_Number_Sequence__c updatedSequence = [
            SELECT breg_Current_Index__c
            FROM BREG_File_Number_Sequence__c
            WHERE Id = :sequenceRecord.Id
            LIMIT 1
        ];

        System.assertEquals(8, nextNumber, 'Generator should increment and return the next number');
        System.assertEquals(8, updatedSequence.breg_Current_Index__c, 'Sequence record should be updated with the incremented number');
    }

    @IsTest
    static void testGetNextNumberThrowsForBlankEntityType() {
        try {
            BREGFileNumberGenerator.getNextNumber('');
            System.assert(false, 'Blank entity type should throw an exception');
        } catch (IllegalArgumentException ex) {
            System.assertEquals('Entity type must not be blank', ex.getMessage(), 'Blank entity type should return the expected error');
        }
    }

    @IsTest
    static void testGetNextNumberThrowsWhenNoSequenceExists() {
        try {
            BREGFileNumberGenerator.getNextNumber('MISSING_ENTITY_TYPE');
            System.assert(false, 'Missing entity type should throw an exception');
        } catch (IllegalArgumentException ex) {
            System.assertEquals('No sequence found for entity type: MISSING_ENTITY_TYPE', ex.getMessage(), 'Missing entity type should return the expected error');
        }
    }
}