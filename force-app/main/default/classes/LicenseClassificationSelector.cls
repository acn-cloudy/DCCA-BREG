/**** 
* ─────────────────────────────────────────────────────────
* class for selecting Data from the License Classification
* ─────────────────────────────────────────────────────────
* PacPoint-AZ210220 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class LicenseClassificationSelector {
   //
   public static List<LicenseClassification__c> getLicenseClassifications(List<String> licenseIds) {
       return [Select Id, License__c, Status__c, EndDate__c, ClassificationName__c from LicenseClassification__c where License__c in: licenseIds];
   }
   //add this for 00007697
   public static List<LicenseClassification__c> getValidGoodLicenseClassifications(List<String> licenseIds) {
       return [Select Id, License__c, License__r.Licensee__c, Status__c, License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c,  ClassificationName__c from LicenseClassification__c where License__c in: licenseIds AND Status__c = 'C - Current, Valid & In Good Standing'];
   }

   //add this for 00031024
   public static List<LicenseClassification__c> getValidRecordsByAccountdsAndLT(List<String> accountIds, List<String> licenseTypeNames) {
        return [Select Id, License__c, Status__c, License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c,  ClassificationName__c, License__r.Licensee__c
            from LicenseClassification__c where License__r.Licensee__c in: accountIds 
                AND Status__c = 'C - Current, Valid & In Good Standing' 
                AND License__r.Status__c = 'C - Current, Valid & In Good Standing' 
                AND License__r.LicenseType__r.Name in: licenseTypeNames];
    }

    //add this for 00031024
   public static List<LicenseClassification__c> getRecordsByAccountdsAndLT(List<String> accountIds, List<String> licenseTypeNames) {
    return [Select Id, License__c, Status__c, License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c,  ClassificationName__c, License__r.Licensee__c
        from LicenseClassification__c where License__r.Licensee__c in: accountIds 
            AND Status__c = 'C - Current, Valid & In Good Standing'
            AND License__r.LicenseType__r.Name in: licenseTypeNames];
    }

    public static List<LicenseClassification__c> getRRecordsByAccountdsAndLT(List<String> accountIds, List<String> licenseTypeNames) {
        return [Select Id, License__c, Status__c, License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c,  ClassificationName__c, License__r.Licensee__c
            from LicenseClassification__c where License__r.Licensee__c in: accountIds 
                AND License__r.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal'
                AND Status__c = 'C - Current, Valid & In Good Standing'
                AND License__r.LicenseType__r.Name in: licenseTypeNames];
    }
    
}