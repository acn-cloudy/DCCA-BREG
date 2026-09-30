/*
* ─────────────────────────────────────────────────────────
* class for the query for License Number Assignments
* 
* ─────────────────────────────────────────────────────────
* PacPoint-AZ031019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-10-03
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseNumberAssignmentSelector {
    public static List<LicenseNumberAssignments__c> getLicenseNumberAssignments(List<String> boardProgramIds, List<String> licenseTypeIds) {
        return [SELECT Id, LicenseNumber__c, LicenseType__c, BoardProgram__c, LicenseType__r.LicensePrefix__c 
                FROM LicenseNumberAssignments__c 
                WHERE LicenseType__c IN :licenseTypeIds 
                OR BoardProgram__c IN :boardProgramIds
                FOR UPDATE];
    }

    public static List<LicenseNumberAssignments__c> getLicenseAssignmentsByLICPrefix(List<String> licPrefix, Set<String> recordIds) {
        return [SELECT Id, LicenseNumber__c, LicenseType__c, BoardProgram__c, LicenseType__r.LicensePrefix__c 
                FROM LicenseNumberAssignments__c 
                WHERE LicenseType__r.LicensePrefix__c IN :licPrefix 
                AND LicenseType__r.LicenseNumberAssignmentCode__c = 'LIC' 
                AND Id NOT IN :recordIds
                FOR UPDATE];
    }
}