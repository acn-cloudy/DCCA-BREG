/*
 * ___________________________________________________________________________________
 * Retrieves the default FileDetail record type of the currently logged in user
 * FileDetailDefaultRecordTypeGetterTest
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
public class FileDetailDefaultRecordTypeGetter {
    @InvocableMethod(label = 'Get Default RecordTypeId' description = 'Returns the default FileDetail RecordTypeId')
    public static List<String> getId() {
        List<RecordTypeInfo> rtis = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfos();
        List<String> ret = new List<String>();
        for (RecordTypeInfo rti : rtis) {
            if (rti.isDefaultRecordTypeMapping()) {
                ret.add(rti.getRecordTypeId());
            }
        }

        return ret;
    }
}