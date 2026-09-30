/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
* License number assignments records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ021019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-10-02
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseNumberAssignmentDomain extends SObjectDomain{
    public LicenseNumberAssignmentDomain(List<LicenseNumberAssignments__c> licenseNumberAssignments) {
        super(licenseNumberAssignments);
    }

    public LicenseNumberAssignments__c getLicenseNumberAssignmentByBoardProgram(String boardProgramId) {
        LicenseNumberAssignments__c selectedRecord = null;
        for(SObject record: records) {
            LicenseNumberAssignments__c licenseNumberAssignment = (LicenseNumberAssignments__c) record;
            if(licenseNumberAssignment.BoardProgram__c == boardProgramId) {
                selectedRecord = licenseNumberAssignment;
            }
        }
        return selectedRecord;
    }
    public LicenseNumberAssignments__c getLicenseNumberAssignmentByLicenseType(String licenseTypeId) {
        LicenseNumberAssignments__c selectedRecord = null;
        for(SObject record: records) {
            LicenseNumberAssignments__c licenseNumberAssignment = (LicenseNumberAssignments__c) record;
            if(licenseNumberAssignment.LicenseType__c == licenseTypeId) {
                selectedRecord = licenseNumberAssignment;
            }
        }
        return selectedRecord;
    }

    // 00011339
    public List<String> getLicenseTypePrefix() {
        List<String> licenseTypePrefix = new List<String>();
        for(LicenseNumberAssignments__c record: (List<LicenseNumberAssignments__c>)records) {
            licenseTypePrefix.add(record.LicenseType__r.LicensePrefix__c);

        }
        return licenseTypePrefix;
    }
    // 00011339
    public Map<String, LicenseNumberAssignments__c> getLicenseTypePrefixMap() {
        Map<String, LicenseNumberAssignments__c> licenseNumberAssignments = new Map<String, LicenseNumberAssignments__c> ();
        for(LicenseNumberAssignments__c record: (List<LicenseNumberAssignments__c>)records) {
            licenseNumberAssignments.put(record.LicenseType__r.LicensePrefix__c, record);

        }
        return licenseNumberAssignments;
    }
    // 00011339
    public void updateLicenseNumber(Map<String, LicenseNumberAssignments__c> licenseNumberAssignments) {
        for(LicenseNumberAssignments__c record: (List<LicenseNumberAssignments__c>)records) {
            if(licenseNumberAssignments.get(record.LicenseType__r.LicensePrefix__c) != null) {
                record.LicenseNumber__c = licenseNumberAssignments.get(record.LicenseType__r.LicensePrefix__c).LicenseNumber__c;
            }
        }
    }
}