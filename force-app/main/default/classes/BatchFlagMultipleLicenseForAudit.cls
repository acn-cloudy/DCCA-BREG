/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Utilize BatchFlagLicenseForAudit to audit multiple user selected license types related to a
 *  Board Program  
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @created      PacPoint-TK080322 - Case 21880
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 *  
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */

public with sharing class BatchFlagMultipleLicenseForAudit {

    @InvocableMethod(
        label='Audit User Selected Licenses'
        description='Audit user selected license types in the respective board program.'
        category='LicenseType__c'
        )
    public static void auditSelectedLicenses(List<String> selectedLicenses) {

        // get the list of user selected licenses from the screen flow
        String licenses = selectedLicenses.get(0);

        // this will be used as condition in SOQL query where Name IN: lstLicenses
        List<String> lstLicenses = licenses.split(';');

        // declare Set of unique licenseTypes to be passed to batch apex
        Set<String> licenseTypes = new Set<String>();
        
        // get the user selected license records and format it as a set of string Ids 
        List<License__c> record = [Select Id, LicenseType__c from License__c WHERE LicenseType__r.Name IN :lstLicenses];
        for (License__c rec : record) {
            licenseTypes.add(rec.LicenseType__c);
        }

        // pass it to BatchFlagLicenseForAudit
        BatchFlagLicenseBeforeAudit batchAudit = new BatchFlagLicenseBeforeAudit(licenseTypes);
        Database.executeBatch(batchAudit, 200);
    }    
}