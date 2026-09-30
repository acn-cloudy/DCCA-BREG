/*
* ─────────────────────────────────────────────────────────
* Controller for the LicenseTypeBatchJobsController Lightning Component 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ121019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Surbhi Sharma - PacificPointCorp 
* @created      2019-09-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseTypeBatchJobsController {
    @AuraEnabled
    public static void runLicenseAuditProcess(String recordId){
        BatchFlagLicenseBeforeAudit licenseForAudit = new BatchFlagLicenseBeforeAudit(recordId);
        Database.executeBatch(licenseForAudit, 200);
    }
    
    
}