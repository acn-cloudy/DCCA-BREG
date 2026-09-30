/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: MVRRenewalTest
 * -----------------------------------------------------------------------------------
 * PacPoint-EA03092023 - Created for case 00027705
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 03/09/2023
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public without sharing class MVRRenewal {

    @InvocableMethod(label='Motor Vehicle Repair Industry Renewal' description='Handle all Motor Vehicle Repair License Types')
    public static List<MVRRenewalResult> runMVRRenewal(List<Input> inputs) {
        List<MVRRenewalResult> resultList = new List<MVRRenewalResult>();
        for(Input inputUnit: inputs) {
            Application__c inputApplication = inputUnit.InputApplication;
            License__c inputLicense = inputUnit.InputLicense;
            List<String> mrcTypes = new List<String>{'MRC', 'MC', 'MR'};
            List<String> rsTypes = new List<String>{'RDS', 'RD'};

            if(
                inputApplication != null
                && inputLicense != null
            ){

                String licenseType = null;
                if(
                    inputLicense.LicenseTypeFormula__c == null
                    && inputLicense.LicenseType__c != null
                ){
                    LicenseType__c lt = [SELECT Name FROM LicenseType__c WHERE Id =: inputLicense.LicenseType__c];
                    licenseType = lt.Name;
                } else {
                    licenseType = inputLicense.LicenseTypeFormula__c;
                }

                if(
                    licenseType != null
                    && mrcTypes.contains(licenseType)
                ){
                    processMRCLicenseType(inputApplication.Id, inputLicense.Id);
                } else if(
                    licenseType != null
                    && rsTypes.contains(licenseType)
                ){
                    processRSLicenseType(inputApplication.Id, inputLicense.Id);
                }
                
            }
            //parse outputs
            MVRRenewalResult result = new MVRRenewalResult();
            result.InputApplication = inputApplication;
            result.InputLicense = inputLicense;
            resultList.add(result);
        }
        return resultList;
    }

    public static void processMRCLicenseType(String applicationId, String licenseId){
        Application__c inputApplication = getApplication(applicationId);
        License__c inputLicense = getLicense(licenseId);

        renewApplication(inputApplication);
        renewLicense(inputApplication, inputLicense);
        processRenewalHistory(inputApplication, inputLicense);

        if(inputApplication.Type__c == 'RNEW - Renewal'){

            List<AssociatedLicense__c> associatedRDSLicenses = getAssociatedRDSLicenses(inputLicense.Id);
            if(associatedRDSLicenses.size() > 0){
                // Look for Applications for each Associated License
                for(AssociatedLicense__c associatedRDSLicense : associatedRDSLicenses){
                    List<Application__c> allApplications = [
                        SELECT Id 
                        FROM Application__c 
                        WHERE CurrentLicense__c =: associatedRDSLicense.EntityLicense__c 
                        AND Type__c = 'RNEW - Renewal' 
                        AND Status__c = 'D1 - Awaiting Dependency Review' 
                        AND LicensePeriodRNEW__c =: inputApplication.LicenseType__r.NextLicensePeriod__c
                    ];

                    if(allApplications.size() > 0){                        
                        List<AssociatedLicense__c> associatedMRCLicenses = getAssociatedMRCLicenses(associatedRDSLicense.EntityLicense__c, true);
                        Boolean renewRDRDS = false;

                        if(associatedMRCLicenses.size() > 0){

                            associatedMRCLicenses = getAssociatedMRCLicenses(associatedRDSLicense.EntityLicense__c, false);

                            // Check if all Employees are Renewed
                            if(
                                associatedMRCLicenses.size() == associatedRDSLicense.EntityLicense__r.NumberofActiveEmployees__c
                                && associatedRDSLicense.EntityLicenseType__c == 'RDS'
                            ){

                                List<AssociatedLicense__c> nonMRLicenses = new List<AssociatedLicense__c>();

                                // Check for MR license and renew RD/RDS if found
                                for(AssociatedLicense__c associatedMRCLicense : associatedMRCLicenses){
                                    if(associatedMRCLicense.EmployeeLicenseType__c == 'MR'){
                                        renewRDRDS = true;
                                        break;
                                    } else {
                                        nonMRLicenses.add(associatedMRCLicense);
                                    }
                                }

                                // If no MR license found, check other Associated Licenses and see if one has completed all classifications
                                if(
                                    !renewRDRDS 
                                    && nonMRLicenses.size() > 0
                                ){
                                    for(AssociatedLicense__c nonMRLicense : nonMRLicenses){
                                        if(classificationsComplete(nonMRLicense.EmployeeLicense__c)){
                                            renewRDRDS = true;
                                            break;
                                        }
                                    }
                                }
                            } else if(
                                associatedMRCLicenses.size() == associatedRDSLicense.EntityLicense__r.NumberofActiveEmployees__c
                                && associatedRDSLicense.EntityLicenseType__c == 'RD'
                            ){
                                renewRDRDS = true;
                            } 
                        }
                        
                        if(renewRDRDS){
                            // Update License
                            License__c entityLicense = [SELECT Id, EffectiveExpireDate__c, Status__c FROM License__c WHERE Id =: associatedRDSLicense.EntityLicense__c];
                            entityLicense.PreviousEffectiveExpiryDate__c = entityLicense.EffectiveExpireDate__c;
                            entityLicense.EffectiveExpireDate__c = inputApplication.RNEWRSTRDate__c;
                            entityLicense.ThisLicenseRenewed__c = true;
                            entityLicense.CancelDate__c = null;

                            if(
                                entityLicense.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due' 
                                || entityLicense.Status__c == 'DM - Forfeited/Maintenance Requirement Due' 
                            ){
                                entityLicense.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
                            } else if(
                                entityLicense.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal' 
                                || entityLicense.Status__c == 'D - Forfeited; Needs to Restore' 
                            ){
                                entityLicense.Status__c = 'C - Current, Valid & In Good Standing';
                            }
                            
                            // Renew Applications
                            for(Application__c allApplication : allApplications){
                                renewApplication(allApplication);
                            }

                            
                            // Renew License
                            update entityLicense;
                        }
                    }
                }
            }
        }
    }

    public static void processRSLicenseType(String applicationId, String licenseId){
        Application__c inputApplication = getApplication(applicationId);
        License__c inputLicense = getLicense(licenseId);
        List<AssociatedLicense__c> assLicenses = new List<AssociatedLicense__c>();

        if(inputLicense.SoleOwner__c){
            assLicenses = [
                SELECT Id 
                FROM AssociatedLicense__c 
                WHERE EntityLicense__c =: inputLicense.Id 
                AND EmploymentStatus__c = 'Employed'
                AND (EndDate__c = null OR EndDate__c > today)
                AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
                AND EmployeeActiveInactive__c = 'Active' 
                AND (PositionStatus__c IN ('D - Designated') OR Position__c IN ('SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)'))
            ];
        } else if(inputApplication.Type__c == 'RNEW - Renewal'){
            assLicenses = [
                SELECT Id 
                FROM AssociatedLicense__c 
                WHERE EntityLicense__c =: inputLicense.Id 
                AND EmploymentStatus__c = 'Employed'
                AND (EndDate__c = null OR EndDate__c > today)
                AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
                AND EmployeeActiveInactive__c = 'Active' 
                AND PositionStatus__c IN ('D - Designated')
            ];
        }

        if(assLicenses.size() >= 1){
            List<AssociatedLicense__c> associatedMRCLicenses = getAssociatedMRCLicenses(inputLicense.Id, false);
            
            // Check if all Employees are Renewed
            if(
                associatedMRCLicenses.size() == inputLicense.NumberofActiveEmployees__c
                && inputApplication.LicenseType__r.Name == 'RDS'
            ){
                for(AssociatedLicense__c associatedMRCLicense : associatedMRCLicenses){
                    if(
                        associatedMRCLicense.EmployeeLicenseType__c == 'MR'
                        || classificationsComplete(associatedMRCLicense.EmployeeLicense__c)
                    ){
                        renewApplication(inputApplication);
                        renewLicense(inputApplication, inputLicense);
                        processRenewalHistory(inputApplication, inputLicense);
                    } else {
                        d1Application(inputApplication, inputLicense);
                    }
                }
            }else if(
                associatedMRCLicenses.size() == inputLicense.NumberofActiveEmployees__c
                && inputApplication.LicenseType__r.Name == 'RD'
            ){
                renewApplication(inputApplication);
                renewLicense(inputApplication, inputLicense);
                processRenewalHistory(inputApplication, inputLicense);
            } else if(associatedMRCLicenses.size() != inputLicense.NumberofActiveEmployees__c) {
                d1Application(inputApplication, inputLicense);    
            }                        
        } else {
            d1Application(inputApplication, inputLicense);
        }
    }

    public static Application__c getApplication(String applicationId){
        return [
            SELECT Id, Type__c, LicenseType__r.Name, LicenseType__r.NextLicensePeriod__c, RNEWRSTRDate__c, LicensePeriodRNEW__c, ApplicationReceivedDate__c 
            FROM Application__c
            WHERE Id =: applicationId
        ];
    }

    public static License__c getLicense(String licenseId){
        return [
            SELECT Id, NumberofActiveEmployees__c, Status__c, SoleOwner__c, LicenseTypeFormula__c, LicenseType__r.Name, LicenseType__r.LicenseTypeEffectiveDate__c, LicenseType__r.LicenseTypeExpireDate__c, LicenseType__r.NextLicensePeriodExpireDate__c , LicenseType__r.NextLicensePeriodEffectiveDate__c 
            FROM License__c
            WHERE Id =: licenseId
        ];
    }

    public static List<AssociatedLicense__c> getAssociatedRDSLicenses(Id licenseId){
        return [
            SELECT Id, EntityLicense__c, EntityLicense__r.NumberofActiveEmployees__c, EntityLicense__r.EffectiveExpireDate__c, EntityLicense__r.Status__c, EntityLicenseType__c
            FROM AssociatedLicense__c 
            WHERE EmployeeLicense__c =: licenseId 
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > today)
            AND EntityLicenseType__c IN ('RDS', 'RD')
        ];
    }

    public static List<AssociatedLicense__c> getAssociatedMRCLicenses(Id licenseId, Boolean filterPosition){
        if(filterPosition){
            return [
                SELECT Id, EmployeeLicense__c, EmployeeLicenseType__c, EmployeeLicenseStatus__c
                FROM AssociatedLicense__c 
                WHERE EntityLicense__c =: licenseId 
                AND EmploymentStatus__c = 'Employed'
                AND (EndDate__c = null OR EndDate__c > today)
                AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
                AND (PositionStatus__c IN ('D - Designated') OR Position__c IN ('SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)')) 
                AND EmployeeLicenseType__c IN ('MRC', 'MR', 'MC')
            ];
        } else {            
            return [
                SELECT Id, EmployeeLicense__c, EmployeeLicenseType__c, EmployeeLicenseStatus__c
                FROM AssociatedLicense__c 
                WHERE EntityLicense__c =: licenseId 
                AND EmploymentStatus__c = 'Employed'
                AND (EndDate__c = null OR EndDate__c > today)
                AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
                AND EmployeeLicenseType__c IN ('MRC', 'MR', 'MC')
            ];
        }
    }

    public static Boolean classificationsComplete(Id licenseId){
        Boolean completeChecklist = true;
        List<String> checklist = new List<String>();
        checklist.add('A1 Engine Repair');
        checklist.add('A2 Automatic Transmission/Transaxle');
        checklist.add('A3 Manual Drive Train and Axles');
        checklist.add('A4 Suspension and Steering');        
        checklist.add('A5 Brakes');
        checklist.add('A6 Electrical/Electronic Systems');
        checklist.add('A7 Heating and Air Conditioning');
        checklist.add('A8 Engine Performance');

        for(String checklistItem : checklist){
            List<LicenseClassification__c> lc = [
                SELECT Id 
                FROM LicenseClassification__c 
                WHERE License__c =: licenseId
                AND ClassificationName__c =: checklistItem 
                AND Status__c = 'C - Current, Valid & In Good Standing'
                AND (EndDate__c = null OR EndDate__c > today)
            ];

            if(lc.size() < 1){
                completeChecklist = false;
                break;
            }
        }

        return completeChecklist;
    }

    public static void renewApplication(Application__c inputApplication){
        inputApplication.Phase__c = 'H - License Generation';        
        inputApplication.Status__c = 'HC - Application Completed';
        update inputApplication;
    }

    public static void d1Application(Application__c inputApplication, License__c inputLicense){
        if(ApplicationService.skipApplicationPhaseUpdate) {
            return;
        }
        inputApplication.Phase__c = 'D - Dependency Review';
        inputApplication.Status__c = 'D1 - Awaiting Dependency Review';
        update inputApplication;

        inputLicense.ThisLicenseRenewed__c = true;
        update inputLicense;

        processRenewalHistory(inputApplication, inputLicense);
    }

    public static void renewLicense(Application__c inputApplication, License__c inputLicense){
        inputLicense.EffectiveExpireDate__c = inputApplication.RNEWRSTRDate__c;
        inputLicense.ThisLicenseRenewed__c = true;
        inputLicense.CancelDate__c = null;
 
            if(
                inputLicense.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due' 
                || inputLicense.Status__c == 'DM - Forfeited/Maintenance Requirement Due' 
            ){
                inputLicense.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
            } else if(
                inputLicense.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal' 
                || inputLicense.Status__c == 'D - Forfeited; Needs to Restore' 
            ){
                inputLicense.Status__c = 'C - Current, Valid & In Good Standing';
            }

        update inputLicense;
    }

    public static void processRenewalHistory(Application__c inputApplication, License__c inputLicense){
        List<LicenseHistory__c> licenseHistory =  new List<LicenseHistory__c>();
            if(inputApplication.Type__c == 'RNEW - Renewal'){
                licenseHistory = [
                    SELECT Id 
                    FROM LicenseHistory__c 
                    WHERE TransactionType__c = 'RNEW - RENEWED'
                    AND LicensePeriod__c =: inputApplication.LicensePeriodRNEW__c 
                    AND License__c =: inputLicense.Id
                ];
            } else if(inputApplication.Type__c == 'RSTR - Restore - No A/I Status'){
                licenseHistory = [
                    SELECT Id 
                    FROM LicenseHistory__c 
                    WHERE TransactionType__c = 'RSTR - RESTORED (LICENSE WAS DELINQUENT/FORFEITED)'
                    AND LicensePeriod__c =: inputApplication.LicensePeriodRNEW__c 
                    AND License__c =: inputLicense.Id
                ];
            }

        if(licenseHistory.size() < 1){
            Map<String, Object> params = new Map<String, Object>();
            params.put('InputApplication', inputApplication);
            params.put('InputLicense', inputLicense);
            Flow.Interview.Create_License_History f = new Flow.Interview.Create_License_History(params);
            f.start();
        }
    }

    public class Input{
        @InvocableVariable(required = true)
        public License__c InputLicense;

        @InvocableVariable(required = true)
        public Application__c InputApplication;
    }

    public class MVRRenewalResult{
        @InvocableVariable
        public Application__c InputApplication;
        
        @InvocableVariable
        public License__c InputLicense;
    }
}