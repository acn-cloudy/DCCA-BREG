/*
 * ___________________________________________________________________________________
 * Helper class for loading license type from LicenseType__c object
 * Covered by: $
 * __________________________________________________________________________________
 * PacPoint-CL081519 - Created for Phase $
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 8/15/2019
 * __________________________________________________________________________________
 */
public class LicenseTypeLoader {
    public static List<LicenseType__c> getLicenseTypes(List<String> recordTypeFilter) {
        return [
                SELECT
                        Id,
                        Name,
                        ApplicationRecordType__c,
                        LicenseType__c,
                        AccountType__c,
                        ApplicationPageLayout__c,
                        Status__c
                FROM LicenseType__c
                WHERE Status__c = 'Active'
                AND ApplicationRecordType__c IN :recordTypeFilter
        ];
    }
}