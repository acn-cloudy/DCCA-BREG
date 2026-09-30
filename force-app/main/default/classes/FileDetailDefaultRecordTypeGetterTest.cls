/*
 * ___________________________________________________________________________________
 * Unit test for FileDetailDefaultRecordTypeGetter
 * __________________________________________________________________________________
 * PacPoint-CL011019 - Created for BREG phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author Chris Loyola - PacificPointCorp
 *
 * @created 01/10/2019
 * __________________________________________________________________________________
 */
@IsTest
private class FileDetailDefaultRecordTypeGetterTest {
    @IsTest
    static void getDefaultTest() {
        List<String> s = FileDetailDefaultRecordTypeGetter.getId();

        List<RecordTypeInfo> rtis = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfos();
        for (RecordTypeInfo rti : rtis) {
            if (rti.isDefaultRecordTypeMapping()) {
                System.assertEquals(s[0], rti.getRecordTypeId());
            }
        }
    }
}