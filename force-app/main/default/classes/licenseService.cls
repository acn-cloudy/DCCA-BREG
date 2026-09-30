/*
* ─────────────────────────────────────────────────────────
* class for the License Business Logics
* License trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ310819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-08-31
* ───────────────────────────────────────────────────────────
* Changes
*
* PacPoint EA081524: 00037317
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class licenseService {
    private static Map<String, AssociatedLicense__c> mostRecentExpiredEntityLicenses = new Map<String, AssociatedLicense__c>();
    public static Map<String, AssociatedLicense__c> ztEmployeeLicenseWithEndDate = new Map<String, AssociatedLicense__c>();
    public static Map<String, License__c> entityLicenseIdsUpdatedToZT = new Map<String, License__c>();
    private static Set<String> licenseIdForClassification = new Set<String>();
    private static List<String> entityLicenseIds = new List<String>();
    private static Map<String, String> licenseIdsForLicenseConditionDeletion = new Map<String, String>();
    private static List<String> licenseIdsForLicenseConditionCreate = new List<String>();
    private static List<String> licenseIdsForClassificationCheck = new List<String>();
    private static Map<String, String> licTypeMap = new Map<String, String>();
    private static Map<String, String> licNumberAssgnCodeMap = new Map<String, String>();
    private static Map<String, License__c> licenseRecordMap = new Map<String, License__c>();
    private static Map<String, LicenseType__c> licTypeRecordMap = new Map<String, LicenseType__c>();
    private static Map<String, Application__c> licApplicationMap = new Map<String, Application__c>();
    private static Map<String, LicenseNumberAssignment__mdt> licTypeMdtMap = new Map<String, LicenseNumberAssignment__mdt>();
    private static Map<String, LicenseNumberAssignments__c> licenseNumberAssignmentToBeUpdate = new Map<String, LicenseNumberAssignments__c>();
    private static Set<String> licenseIdsforFileGeneration = new Set<String>();
    private static Set<String> licenseIdForUnCheckGenerateFile = new Set<String>();
    private static List<LicenseNumberAssignments__c> licenseNumberAssignments = new List<LicenseNumberAssignments__c>();
    private static List<Id> licTypeMdtList = new List<Id> ();
    private static Map<String, LicenseType__c>  licenseTypeMap  = new Map<String, LicenseType__c>();
    private static Map<String, License__c> licToUpdate = new Map<String, License__c>();
    private static List<LicenseHistory__c> licenseHistories = new List<LicenseHistory__c>();
    private static set<String> licenseIdsForMailingAddresCaptured = new Set<String>();
    private static set<String> licenseIdsForBusinessAddresCaptured = new Set<String>();
    private static Set<String> licenseIdForPrincipalRMELoss = new Set<String>();
    private static Set<String> licenseIdForEntityLoss = new Set<String>();
    private static Set<String> licenseIdForRMELossReset = new Set<String>();
    private static Set<String> licenseIdsForAssocLicensesDualIndicatorToNull = new Set<String>();
    private static Set<String> licenseIdsForAMDInactivation = new Set<String>();
    public static Boolean disableUpdateAssociatedEntity = false;
    public static Set<String> licenseIdsForCERequiredReset = new Set<String>();

    // 00012549
    public static void generatePostCard(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        if(license.GenerateRenewalPostcards__c) {
            if(license.SelectRenewalPostcard__c != null && license.SelectRenewalPostcard__c != '') {
                // Assume the post card will be updated one per record
                Database.executeBatch(new GeneratePostCardBatch(license.Id,license.PostcardContent__c,true));
            }
            license.GenerateRenewalPostcards__c = false;
            license.SelectRenewalPostcard__c = null;
        }
    }

    // 00014637
    public static void generateRenewalNotification(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        if(license.GenerateDuplicateRenewalForm__c) {
            if(license.RenewalNotificationTemplate__c != null && license.RenewalNotificationTemplate__c != '') {
                Database.executeBatch(new GenerateRenewalNotificationBatch(license.Id,
                        license.RenewalNotificationTemplate__c));
            }
            license.GenerateDuplicateRenewalForm__c = false;
        }
    }
    //  Capture license conditions need for deletion.
    // 00006348
    public static void captureIdForLicenseConditionsRemove(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.DependentLicense__c != oldLicense.DependentLicense__c
            && oldLicense.DependentLicense__c != null ) {
            licenseIdsForLicenseConditionDeletion.put(license.Id, oldLicense.DependentLicense__c );
        }
    }

    // Capture license conditions need for create.
    // 00006348
    public static void captureIdForLicenseConditionsCreate(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.DependentLicense__c != oldLicense.DependentLicense__c
            && license.DependentLicense__c != null ) {
            licenseIdsForLicenseConditionCreate.add(license.Id);
        }
    }

    // Capture the license previous status
    //00007676
    public static void capturePreviousStatus(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.Status__c != oldLicense.Status__c) {
            license.PreviousStatus__c = oldLicense.Status__c;
        }
    }

    public static void captureZTStatusChagne(SObject oldSo, SObject so)  {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.Status__c != oldLicense.Status__c 
            && license.Status__c == 'ZT - Remain Forfeited Due To Failure To Provide Proof Of Continuous Coverage of Insurance or Bond') {
            entityLicenseIdsUpdatedToZT.put(license.Id, license);
        }
        System.debug('####license.Status__c#####' + license.Status__c);
        System.debug('####entityLicenseIdsUpdatedToZT#####' + entityLicenseIdsUpdatedToZT);
    }

    // 00026663
    public static void captureRecentTerminatedEmployers(Set<Id> recordIds) {
        List<AssociatedLicense__c> records 
            = AssociatedLicenseSelector.getTerminatedEmployerLicenses(recordIds);
        mostRecentExpiredEntityLicenses = (new AssociatedLicenseDomain(records)
            ).getMostRecentExpiredLicense();
    }
    
    // 00011992
    public static void captureUpdate(SObject oldSo, SObject so) {
        License__c record = (License__c) so ;
        License__c oldRecord = (License__c) oldSo;
        Date endDate = AssociatedLicenseService.employeeLicenseWithEndDate.get(record.Id);
        
        if(endDate == null) endDate = Date.today();
        System.debug('#######test endDate#######' + endDate);

        // Criteria 1
        if(((record.LicenseTypeName__c == 'RB - Entity'
            && record.PB_Counter__c != oldRecord.PB_Counter__c
            && record.PB_Counter__c == 0)
            ||(record.EntityPrincipalCounter__c != oldRecord.EntityPrincipalCounter__c
            && record.EntityPrincipalCounter__c == 0
            && record.LicenseTypeName__c != 'RB - Entity'))
            && record.LicenseTypeName__c != 'MVD'
            && record.LicenseTypeName__c != 'BAP'
            && record.LicenseTypeName__c != 'BEP'
            && record.LicenseTypeName__c != 'MAP'
            && record.ActiveInactive__c != 'Inactive'
            && record.LicenseTypeDependencyRequired__c ) {
            if(record.Status__c == 'C - Current, Valid & In Good Standing'
            || record.Status__c == 'CP - Current Pending'
            || record.Status__c == 'CR - Current/Next Renewal Paid'
            || record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement'
            || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
            || record.Status__c == GlobalUtilities.STATUSZI) {
                record.LossofPrincipalRME__c = true;
                record.LossofPrincipalRMEDate__c = endDate;
                // VPVL-13: For RB-Entity, notification and suspense moved to midnight batch
                record.LossofPrincipalBrokerDate__c = endDate;
            }
            if(record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CR - Current/Next Renewal Paid'
                || record.Status__c == 'CP - Current Pending') {
                record.Status__c = record.StatusDuetoLossofDependent__c;
            }

        }
        // Criteria 2
        if(record.NumberofActiveEmployees__c < oldRecord.NumberofActiveEmployees__c
            && record.EntityPrincipalCounter__c == oldRecord.EntityPrincipalCounter__c
            && record.LicenseTypeName__c != 'MVD'
            && record.LicenseTypeName__c != 'BAP'
            && record.LicenseTypeName__c != 'BEP'
            && record.LicenseTypeName__c != 'MAP'
            && record.ActiveInactive__c != 'Inactive'
            && record.LicenseTypeDependencyRequired__c ) {
                if(record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CP - Current Pending'
                || record.Status__c == 'CR - Current/Next Renewal Paid'
                || record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement'
                || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
                || record.Status__c == GlobalUtilities.STATUSZI) {
                record.LossOfRME__c = true;
                //00033941
                record.LossOfRMEDate__c = endDate;
            }
        }
        // Criteria 3
        if(record.NumberofActiveEmployers__c != oldRecord.NumberofActiveEmployers__c
            && record.NumberofActiveEmployers__c == 0
            && record.ActiveInactive__c != 'Inactive'
            && record.LicenseTypeName__c != 'MVD'
            && record.LicenseTypeName__c != 'AMD'
            && record.LicenseTypeName__c != 'BAP'
            && record.LicenseTypeName__c != 'BEP'
            && record.LicenseTypeName__c != 'MAP'
            && record.LicenseTypeDependencyRequired__c 
            && (record.Status__c == 'C - Current, Valid & In Good Standing'
            || record.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due'
            || record.Status__c == 'CP - Current Pending'
            || record.Status__c == 'CR - Current/Next Renewal Paid'
            || record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement'
            || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
            || record.Status__c == GlobalUtilities.STATUSZI) 
            ) {

            
            
            // Found Asscoaited Licenses?
            if(mostRecentExpiredEntityLicenses.containsKey(record.Id) ) {
                // Yes
                // LossofEntityDate__c = Associated Entity License from 
                // the previous "Query Associated Licenses" . Ins_Expire_Cancel_Date__c
                
                record.LossofEntityDate__c 
                = mostRecentExpiredEntityLicenses.get(record.Id).EntityLicense__r.Ins_Expire_Cancel_Date__c;
                record.LossofEntity__c = true;
            } else {
                // No
                if(record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CR - Current/Next Renewal Paid'
                || record.Status__c == 'CP - Current Pending') {
                    record.Status__c = record.StatusDuetoLossofDependent__c;
                }
                record.LossofEntity__c = true;
                // 00033941
                record.LossofEntityDate__c = endDate;
                record.GenerateRMELosesEntityNotification__c = true;
            }
        }
        // Criteria 3A
        if(record.NumberofActiveEmployers__c < oldRecord.NumberofActiveEmployers__c
             && record.NumberofActiveEmployers__c == 1
             && record.LicenseTypeName__c != 'MVD'
             && record.LicenseTypeName__c != 'BAP'
             && record.LicenseTypeName__c != 'BEP'
             && record.LicenseTypeName__c != 'MAP'
             && record.LicenseTypeDependencyRequired__c ) {

            List<AssociatedLicense__c> assocLics = AssociatedLicenseSelector.getPDGByEmployee(new List<String>{record.Id}, null, ' and DualIndicator__c = \'Dual\'');

            if(!assocLics.isEmpty()){
                if(record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CP - Current Pending'
                || record.Status__c == 'CR - Current/Next Renewal Paid'
                || record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement'
                || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
                || record.Status__c == GlobalUtilities.STATUSZI) {
                    record.Dual__c = false;
                    record.GenerateLossOfDualNotification__c = true;
                    licenseIdsForAssocLicensesDualIndicatorToNull.add(record.Id);
                }
            }
        }
        // Criteria 4
        if(record.NumberofActiveEmployees__c != oldRecord.NumberofActiveEmployees__c &&
            record.NumberofActiveEmployees__c == 0 && record.LicenseTypeName__c == 'MVD'
            && record.LicenseTypeName__c != 'BAP'
            && record.LicenseTypeName__c != 'BEP'
            && record.LicenseTypeName__c != 'MAP'
            && record.ActiveInactive__c != 'Inactive') {
                if(record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CP - Current Pending'
                || record.Status__c == 'CR - Current/Next Renewal Paid'
                || record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement'
                || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
                || record.Status__c == GlobalUtilities.STATUSZI) {
                    record.LossofPrincipalRME__c = true;
                    // 00033941
                    record.LossofPrincipalRMEDate__c = endDate;
                    record.GenerateEntityLosesRMENotification__c = true;
                }
                if(record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CR - Current/Next Renewal Paid'
                || record.Status__c == 'CP - Current Pending') {
                    record.Status__c = record.StatusDuetoLossofDependent__c;
                }
        }

        for(String key: ztEmployeeLicenseWithEndDate.KeySet()) {
            mostRecentExpiredEntityLicenses.put(key, ztEmployeeLicenseWithEndDate.get(key));
        }
        System.debug('####mostRecentExpiredEntityLicenses#######' + mostRecentExpiredEntityLicenses);
        if(record.LossOfEntity__c == true ) {
            if(mostRecentExpiredEntityLicenses.containsKey(record.Id)) {
                record.LossofEntityDate__c = mostRecentExpiredEntityLicenses.get(record.Id).EntityLicense__r.Ins_Expire_Cancel_Date__c;
            }
        }

        //00037665
        if(licenseIdsForCERequiredReset.contains(record.Id)) record.CEisConfirmed__c = false;
    }
    // 00008669
    public static void calculateEntityLicenses() {
        if(!entityLicenseIds.isEmpty() && (!disableUpdateAssociatedEntity)) {
            TriggerHelper.disableAssociatedLicenseTrigger = true;
            //Query Associated License records
            List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getAssociatedLicenses(entityLicenseIds);

            if(associatedLicenses.size() > 50 && (!System.isBatch())) {
                // move to the batch
                Database.executeBatch(new BatchUpdateActiveEmployeeLicenseNum(entityLicenseIds), 50);
                entityLicenseIds.clear();

            } else {
                entityLicenseIds.clear();
                AssociatedLicenseService.licenseIdsEmploymentCount.addAll((List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c'));
                AssociatedLicenseService.countLicenseRecords();
            }
        }
    }
    // 00008669
    public static void captureForActiveEmployersCal(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.Status__c != oldLicense.Status__c ||
            license.ActiveInactive__c != oldLicense.ActiveInactive__c) {
            // Check with the number of active employers update
            entityLicenseIds.add(license.Id);
        }
    }

    // 00033728
    public static void captureAMDInactivation(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.SendAMDInactivationEmail__c && license.SendAMDInactivationEmail__c != oldLicense.SendAMDInactivationEmail__c) {
            license.SendAMDInactivationEmail__c = false;
            licenseIdsForAMDInactivation.add(license.Id);
            
        }
    }

    // 00007697
    public static void captureLicenseTypeRecords(List<License__c> records) {
        List<String> licenseTypeIds = (List<String>)(new LicenseDomain(records)).getFieldValues('LicenseType__c');
        List<LicenseType__c> licenseTypes = [select Id, ClassificationCheckRequired__c from LicenseType__c where id in: licenseTypeIds];
        licenseTypeMap = new Map<String, LicenseType__c>(licenseTypes);
    }

    // The Business Analyst should complete this field with the Title of the Business Requirement. Internal Development Task: The Solution Architect should complete this field with the Title of the Development Task.Trigger to perform a "Classification Check" and ensure Entities have the required RME Classifications
    // 00007697
    public static void performLicenseClassificationCheck(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        LicenseType__c licenseType = new LicenseType__c();
        List<String> statusList = new List<String>();
        statusList.add('C - Current, Valid & In Good Standing');
        statusList.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');
        statusList.add('R - Valid Thru Expiration Date, Subject To Renewal');
        statusList.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');

        if (license.LicenseType__c != null) {
            licenseType = licenseTypeMap.get(license.LicenseType__c);
        }
        if((((license.LossofPrincipalRME__c != oldLicense.LossofPrincipalRME__c
            && license.LossofPrincipalRME__c ==  true) || (license.LossofRME__c != oldLicense.LossofRME__c
            && license.LossofRME__c ==  true))
            || licenseIdForRMELossReset.contains(license.Id))
            && license.Status__c != null
            && statusList.contains(license.Status__c)
            && licenseType != null
            && licenseType.ClassificationCheckRequired__c == true) {
            licenseIdsForClassificationCheck.add(license.Id);
            licenseIdForRMELossReset.remove(license.Id);
        }
    }

    // Capture record for PDF Generation Engine
    // 00005902
    public static void captureIdForFileGeneration(SObject so) {
        License__c license = (License__c) so;
        if(license.GenerateFile__c) {
            licenseIdsforFileGeneration.add(license.Id);
            licenseIdForUnCheckGenerateFile.add(license.Id);
        }
    }

    // Capture record for PDF Generation Engine
    // 00005902
    public static void captureIdForFileGeneration(SObject oldSo, SObject so) {
        License__c license = (License__c) so;
        License__c oldLicense = (License__c) oldSo;
        if(license.GenerateFile__c && license.GenerateFile__c  != oldLicense.GenerateFile__c) {
            licenseIdsforFileGeneration.add(license.Id);
            license.GenerateFile__c = false;
        } else if (license.GenerateFile__c) {
            license.GenerateFile__c = false;
        }
    }

    //00005294 cache LicenseTypeMap 
    public static void cacheRecordsForLicenseInitiation(List<License__c> licenses) {
        // Provide licnese type Id => license type map  
        List<String> licenseTypeIds = (List<String>)(new LicenseDomain(licenses)).getFieldValues('LicenseType__c');

        // Query LicenseType records and convert it to Id => LicenseType record
        List<LicenseType__c> licenseTypes =  LicenseTypeSelector.getLicenseTypesByIds(licenseTypeIds);

        List<String> boardProgramIds = (List<String>)(new LicenseTypeDomain(licenseTypes)).getFieldValues('BoardProgram__c');
        // Convert from Id => licenseType 
        licTypeRecordMap = (new LicenseTypeDomain(licenseTypes)).getIdToLicenseType();

        // Provide licnese type Id => license type map  
        List<String> applicationIds = (List<String>)(new LicenseDomain(licenses)).getFieldValues('Application__c');
        List<Application__c> applications = ApplicationSelector.getApplications(applicationIds);
        licApplicationMap =(new ApplicationDomain(applications)).getIdToApplication();
        List<License__c> dependentLicenses = (new ApplicationDomain(applications)).getDependentLicenses();
        // Convert from Id => License
        licenseRecordMap = (new LicenseDomain(dependentLicenses)).getIdToLicense();

        licenseNumberAssignments = LicenseNumberAssignmentSelector.getLicenseNumberAssignments(
                boardProgramIds, licenseTypeIds);
    }

    // 00010823
    // Check Loss of Principal Suspense Process
    public static void capturePrincipalSuspenseProcess(SObject oldSo, SObject so) {
        License__c record = (License__c) so;
        License__c oldRecord = (License__c) oldSo;

        if((record.LossofPrincipalRME__c != oldRecord.LossofPrincipalRME__c ||record.EntityPrincipalCounter__c != oldrecord.EntityPrincipalCounter__c)
            && record.LossofPrincipalRME__c) {
            if(record.EntityPrincipalCounter__c == 0 && record.DependencyRequired__c && (
                record.Status__c == 'C - Current, Valid & In Good Standing' || record.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due' ||
                record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement' || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement' ||
                record.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal' || record.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due' ||
                record.Status__c == 'CR - Current/Next Renewal Paid')) {
                    licenseIdForPrincipalRMELoss.add(record.Id);
                }
        }
    }
    // 00010823
    // Process Check of creation suspense records
    public static void createPrincipalRMESuspenses(List<License__c> records) {
        if(!licenseIdForPrincipalRMELoss.isEmpty()) {
            // 
            List<License__c> filteredRecords = (new LicenseDomain(records)).filterLicenseFromSet(licenseIdForPrincipalRMELoss);

            List<AssociatedLicense__c> associatedLicenses
                = AssociatedLicenseSelector.getPrincipalAssociatedLicenses(licenseIdForPrincipalRMELoss);
            licenseIdForPrincipalRMELoss.clear();
            Set<String> existingLicenseIds = (new AssociatedLicenseDomain(associatedLicenses)).getEntityLicenseIds();
            List<License__c>  filteredRecordsForSuspense = (new LicenseDomain(filteredRecords)).filteroutLicenseFromSet(existingLicenseIds);
            List<String> licenseIdsForSuspense = (new LicenseDomain(filteredRecordsForSuspense)).getIds();
            List<License__c> recordsForSuspense = LicenseSelector.getLicenses(licenseIdsForSuspense);
            //
            List<Suspense__c> suspenses = (new LicenseDomain(recordsForSuspense)).getPrincipalSuspenses();
            insert suspenses;
        }

    }
    // 00010823
    // Process Check of creation suspense records
    public static void createEntitySuspenses(List<License__c> records) {
        if(!licenseIdForEntityLoss.isEmpty()) {
            List<License__c> filteredRecords = (new LicenseDomain(records)).filterLicenseFromSet(licenseIdForEntityLoss);
            List<AssociatedLicense__c> associatedLicenses
                = AssociatedLicenseSelector.getEntityAssociatedLicenses(licenseIdForEntityLoss);
            licenseIdForEntityLoss.clear();
            Set<String> existingLicenseIds = (new AssociatedLicenseDomain(associatedLicenses)).getEntityLicenseIds();
            List<License__c>  filteredRecordsForSuspense = (new LicenseDomain(filteredRecords)).filteroutLicenseFromSet(existingLicenseIds);
            
            List<String> licenseIdsForSuspense = (new LicenseDomain(filteredRecordsForSuspense)).getIds();
            // 00028291 to filter licenses which exist NFRM - RME WIHTOUT EMPLOYMENT
            // Check to see if the license has any other suspense record relating to loss of employer 
            List<Suspense__c> existingSuspenses = SuspenseSelector.getNFRMSuspenseByLicenseIds(licenseIdsForSuspense);
            Set<String> licenseIdExistingWithSuspense = (new SuspenseDomain(existingSuspenses)).getLicenseIds();
            filteredRecordsForSuspense = (new LicenseDomain(filteredRecordsForSuspense)).filteroutLicenseFromSet(licenseIdExistingWithSuspense);
            licenseIdsForSuspense = (new LicenseDomain(filteredRecordsForSuspense)).getIds();
            // End 00028291
            
            List<License__c> recordsForSuspense = LicenseSelector.getLicenses(licenseIdsForSuspense);
            List<Suspense__c> suspenses = (new LicenseDomain(recordsForSuspense)).getEntitySuspenses();
            // 00028291
            if(!suspenses.isEmpty())
                insert suspenses;
        }

    }

    // 00010823
    // Check Loss of Entity Suspense Process
    public static void captureEntitySuspenseProcess(SObject oldSo, SObject so) {
        License__c record = (License__c) so;
        License__c oldRecord = (License__c) oldSo;
        if(record.LossOfEntity__c != oldRecord.LossOfEntity__c && record.LossOfEntity__c
            && (record.NumberofActiveEmployers__c == null || record.NumberofActiveEmployers__c == 0)
            && record.DependencyRequired__c) {
                licenseIdForEntityLoss.add(record.Id);
        }
    }

    //00005294
    public static void populateLicenceName(SObject so){
        License__c record = (License__c) so;
        String licenseTypeId = record.LicenseType__c;
        String applicationId = record.Application__c;

        LicenseType__c licenseType = licTypeRecordMap.get(licenseTypeId);
        Application__c application = licApplicationMap.get(applicationId);
        if(application == null || licenseType == null ) {
            return;
        }

        /***
        *   Set the license number = R-YYMMDD####
        *   where #### is a counter that starts at 001
        *   at the beginning of each day (12:00AM HST),
        *   then counts up and resets back to 001 at the start of the next day
        *** */
        if(licenseType.Apprentice__c) {
            // 
            record.Name = CounterService.getApprenticeApplicationCounter();
            return;
        }

        if(licenseType.Branch__c) {
            if(application.DependentLicense__c != null && licenseRecordMap.get(application.DependentLicense__c) != null) {
                License__c dependentLicense = licenseRecordMap.get(application.DependentLicense__c);

                if(dependentLicense.BranchNumber__c == null || dependentLicense.BranchNumber__c == 0) {
                    dependentLicense.BranchNumber__c = 1;
                }
                String branchNumber = dependentLicense.BranchNumber__c + '';
                // if(branchNumber.length() == 1) {
                //     branchNumber = '0' + branchNumber;
                // }

                record.Name = licenseType.LicensePrefix__c + '-'
                    + dependentLicense.LicenseNumberFormula__c + '-'
                    + branchNumber;

                dependentLicense.BranchNumber__c ++;
            }
            return;
        }

        String assignmentCode = licenseType.LicenseNumberAssignmentCode__c;

        String boardProgramId = licenseType.BoardProgram__c;
        LicenseNumberAssignments__c licenseNumberAssignment = null;
        if(assignmentCode == 'BRD' ) {
            licenseNumberAssignment = (new LicenseNumberAssignmentDomain(licenseNumberAssignments
                    )).getLicenseNumberAssignmentByBoardProgram(boardProgramId);

        } else if(assignmentCode == 'LIC' ) {
            licenseNumberAssignment = (new LicenseNumberAssignmentDomain(licenseNumberAssignments
                    )).getLicenseNumberAssignmentByLicenseType(licenseTypeId);
        }

        if(assignmentCode == 'MAN' ) {
            record.Name =  (licenseType.LicensePrefix__c != null ? licenseType.LicensePrefix__c + '-' : '')
                                    + (application.LicenseNumber__c != null ? application.LicenseNumber__c + '-': '')
                                    + (application.OfficeNumber__c != null ? application.OfficeNumber__c + '': '0');
        } else if(licenseNumberAssignment != null) {
            if(licenseNumberAssignmentToBeUpdate.containsKey(licenseNumberAssignment.Id)) {
                licenseNumberAssignment = licenseNumberAssignmentToBeUpdate.get(licenseNumberAssignment.Id);
            }

            record.Name =  (licenseType.LicensePrefix__c != null ? licenseType.LicensePrefix__c + '-' : '')
                                    + (licenseNumberAssignment.LicenseNumber__c != null ? licenseNumberAssignment.LicenseNumber__c + '-': '')
                                    + (application.OfficeNumber__c != null ? application.OfficeNumber__c + '': '0');
            record.LicenseConsecutiveNumber__c = String.valueOf(licenseNumberAssignment.LicenseNumber__c );
            licenseNumberAssignment.LicenseNumber__c  += 1;
            licenseNumberAssignmentToBeUpdate.put(licenseNumberAssignment.Id, licenseNumberAssignment);
        }
    }

    // 5294
    public static void updateDependentLicenses() {
        if(!licenseRecordMap.isEmpty() ) {
            List<License__c> dependentLicenses = licenseRecordMap.values();
            licenseRecordMap.clear();
            TriggerHelper.disableLicenseTrigger = true;
            update dependentLicenses;
            TriggerHelper.disableLicenseTrigger = false;

        }

    }

    public static void updateLicenseNumberAssignments() {
        if(!licenseNumberAssignmentToBeUpdate.isEmpty()) {
            List<LicenseNumberAssignments__c> licenseNumberAssignments = licenseNumberAssignmentToBeUpdate.values();

            // 00011339
            List<String> prefix = (new LicenseNumberAssignmentDomain(licenseNumberAssignments)).getLicenseTypePrefix();
            Set<String> recordIds = licenseNumberAssignmentToBeUpdate.keySet();
            List<LicenseNumberAssignments__c> extralicenseNumberAssignments
                = LicenseNumberAssignmentSelector.getLicenseAssignmentsByLICPrefix(prefix, recordIds);
            Map<String, LicenseNumberAssignments__c> prefix2licenseNumberAssignments
                = (new LicenseNumberAssignmentDomain(licenseNumberAssignments)).getLicenseTypePrefixMap();
            (new LicenseNumberAssignmentDomain(extralicenseNumberAssignments)).updateLicenseNumber(prefix2licenseNumberAssignments);
            licenseNumberAssignments.addAll(extralicenseNumberAssignments);

            // End
            // Find all the licenseNumber that has the same prefix values and the assignment code is LIC
            update licenseNumberAssignments;
            licenseNumberAssignmentToBeUpdate.clear();
        }
    }

    // Used to capture the license creation 
    // Call by LicenseHandler.afterInsert
    // 00004719
    public static void captureLicenseForClassification(SObject so) {
        License__c license = (License__c) so;
        if(license.Application__c != null  && license.GenerateClassifications__c) {
            licenseIdForClassification.add(license.Id);
        }
    }

    // Used to create classifications based on applications
    // 00004719
    public static void createClassifications(List<License__c> records) {
        List<License__c> licenses
            = (new LicenseDomain(records)).filterLicenseFromSet(licenseIdForClassification);
        licenseIdForClassification.clear();
        // Query Application records to make sure the generateLicense is checked.
        List<String> applicationIds = (new LicenseDomain(licenses)).getApplicationIds();
        // Get ApplicationId => List<Classification__c>>
        // (filter the status is "NE or P")
        List<String> statusList = new List<String>();
        statusList.add('NE - No Exam Required--Class to be Licensed');
        statusList.add('P - Passed Exam--Class to be Licensed');
        Map<String, List<ApplicationClassifications__c>>  appIdToClassifications
            = ApplicationClassificationsService.getAppClassifications(applicationIds, statusList);

        insert (new LicenseDomain(licenses)).convertToLicenseClassifications(appIdToClassifications);
        // update license status to C - CURRENT, VALID & IN GOOD STANDING
        // Filter by licenses
        // update (new LicenseDomain(licenses)).getLicensesStatusToBeUpdated(appIdToClassifications);
    }

    // Call PDF Generation Engine
    // 00005902
    public static void generateFile(List<License__c> licenses, Set<String> filteredIds){
        List<License__c> records = (new LicenseDomain(licenses)).filterRecords(filteredIds);
        // Call application file generator
        (new LicenseDomain(records)).generateFile();
        // PVL_PDFGenerator.producePDFToFile(records[0].Id);
    }
    public static void unCheckFileGenerator(List<License__c> licenses) {
        List<License__c> records = (new LicenseDomain(licenses)).filterRecords(licenseIdForUnCheckGenerateFile);
        licenseIdForUnCheckGenerateFile.clear();
        List<License__c> licensesForUpdate
            = (new LicenseDomain(records)).generateLicenseRecordsForUncheckFileGenerate();
        TriggerHelper.disableLicenseTrigger = true;
        update licensesForUpdate;
        TriggerHelper.disableLicenseTrigger = false;
    }
    // delete license conditions.
    // 00006348
    public static void deleteLicenseConditions() {
        if(licenseIdsForLicenseConditionDeletion.isEmpty()) {
            return;
        }
        // 
        Set<String> licenseIdSet = licenseIdsForLicenseConditionDeletion.keySet();
        List<String> dependentLicenseIds = licenseIdsForLicenseConditionDeletion.values();
        List<String> licenseIds = new List<String>(licenseIdSet);
        // Query existing license Conditions
        List<LicenseConditions__c> licenseConditions
            = LicenseConditionSelector.getLicenseConditionsByLicenseIds(licenseIds);
        // Query License Conditions to be deleted
        List<LicenseConditions__c> dependentLicenseConditions
            = LicenseConditionSelector.getLicenseConditionsByLicenseIds(dependentLicenseIds);
        // Get License Id => License Conditions Id Set
        Map<String, Set<String>> licenseIdToConditionIdSet
            = (new LicenseConditionDomain(licenseConditions)).getLicenseConditionIdSet(licenseIdsForLicenseConditionDeletion);
        List<LicenseConditions__c> conditionsForDeletion
            = (new LicenseConditionDomain(dependentLicenseConditions)
                ).filterLicenseConditionsForDeletion(licenseIdToConditionIdSet);
        licenseIdsForLicenseConditionDeletion.clear();
        delete conditionsForDeletion;
    }
    // create license conditions.
    // 00006348
    public static void createLicenseConditions() {
        if(licenseIdsForLicenseConditionCreate.isEmpty()) {
            return;
        }
        List<LicenseConditions__c> licenseConditions
            = LicenseConditionSelector.getLicenseConditionsByLicenseIds(licenseIdsForLicenseConditionCreate);
        licenseIdsForLicenseConditionCreate.clear();
        List<LicenseConditions__c> conditions = (new LicenseConditionDomain(licenseConditions)).getLicenseConditionsRecords();
        LicenseConditionService.createLicenseConditions(conditions);
    }
    //6. If License__c.LossofRME__c = TRUE then set the License__c.LossofRME__c  = FALSE
    // public static void captureRMELoss(Sobject oldSo, SObject so) {
    //     License__c oldRecord = (License__c) oldSo;
    //     License__c record = (License__c) so;
    //     if(oldRecord.LossofRME__c != record.LossofRME__c && record.LossofRME__c) {
    //         licenseIdForRMELossReset.add(record.Id);
    //         record.LossofRME__c = false;
    //     }
    // }

    // Trigger to perform a "Classification Check" and ensure Entities have the required RME Classifications
    // 00007697
    public static void updateLicenseClassificationStatus() {
        if(licenseIdsForClassificationCheck.isEmpty()) {
            return;
        }
        // 1.Find all Active Classification records under the License 
        List<LicenseClassification__c> licenseClassifications
            = LicenseClassificationSelector.getValidGoodLicenseClassifications(licenseIdsForClassificationCheck);

        // 2.Find all active Associated Licenses under the License
        List<AssociatedLicense__c> associatedLicenses
            = AssociatedLicenseSelector.getEmployedAssociatedLicenses(licenseIdsForClassificationCheck);

        // 2.1 Associated Licenses Found
        if (associatedLicenses.size() > 0) {
            // 3.Loop through each Associated License record found, and find all Active Classifications under each 
            List<String> associatedEmployeeLicenseIds = new List<String>();
            Map<Id, Id> idToEntityLicenseMap = new Map<Id, Id>();
            for (AssociatedLicense__c al : associatedLicenses) {
                associatedEmployeeLicenseIds.add(al.EmployeeLicense__c);
                idToEntityLicenseMap.put(al.EmployeeLicense__c, al.EntityLicense__c);
            }

            List<LicenseClassification__c> licenseClassificationsForEmployeeLicenses
                = LicenseClassificationSelector.getValidGoodLicenseClassifications(associatedEmployeeLicenseIds);

            Map<Id, List<String>> idToClassificationNameMap = new Map<Id, List<String>>();
            for (LicenseClassification__c lc : licenseClassificationsForEmployeeLicenses) {
                if (lc.License__c != null
                    && idToEntityLicenseMap.containsKey(lc.License__c)
                    && idToClassificationNameMap.containsKey(idToEntityLicenseMap.get(lc.License__c))) {
                    idToClassificationNameMap.get(idToEntityLicenseMap.get(lc.License__c)).add(lc.ClassificationName__c);
                } else {
                    idToClassificationNameMap.put(idToEntityLicenseMap.get(lc.License__c), new List<String>{lc.ClassificationName__c});
                }
            }

            // call LicenseClassificationDomain
            licenseIdsForClassificationCheck.clear();
            List<LicenseClassification__c> licenseClassificationsForUpdate = (new LicenseClassificationDomain(LicenseClassifications)).updateStatusBasedOnAssociatedLicense(idToClassificationNameMap);
            if(!licenseClassificationsForUpdate.isEmpty()) {
                update licenseClassificationsForUpdate;
            }
        } else {
            // 2.2 No Associated Licenses Found
            licenseIdsForClassificationCheck.clear();
            List<LicenseClassification__c> licenseClassificationsForUpdate = (new LicenseClassificationDomain(LicenseClassifications)).updateLicenseClassificationStatus();
            if(!licenseClassificationsForUpdate.isEmpty()) {
                update licenseClassificationsForUpdate;
            }
        }
    }

    // Used to call service in the end.
    public static void runInFinally(List<License__c> licenses) {
        if(Trigger.isAfter != null && Trigger.isAfter) {
            licenseIdForRMELossReset.clear();
            // create license conditions .
            // 00006348
            createLicenseConditions();

            updateLicenseNumberAssignments();
            updateDependentLicenses();
            //00007697
            if(!licenseIdsForClassificationCheck.isEmpty()) {
                licenseService.updateLicenseClassificationStatus();
            }
            if(!licenseIdForClassification.isEmpty()) {
                // Used to create classifications based on applications
                // 00004719
                licenseService.createClassifications(licenses);
            }
            // 00005902
            if(!licenseIdsforFileGeneration.isEmpty()) {
                generateFile(licenses, licenseIdsforFileGeneration);
                licenseIdsforFileGeneration.clear();
            }
            // 00005902
            unCheckFileGenerator(licenses);
            //00008996
            recordAddressUpdate();

            // 00010823
            // VPVL-13: Commented out - suspense creation moved to midnight batch job
            // createPrincipalRMESuspenses(licenses);
            // createEntitySuspenses(licenses);
            //End

            // 00008669
            // calculate licenses
            calculateEntityLicenses();

            //00026550
            if (!licenseIdsForAssocLicensesDualIndicatorToNull.isEmpty()) {
                nullifyAssocLicensesDualIndicator(licenseIdsForAssocLicensesDualIndicatorToNull);
                licenseIdsForAssocLicensesDualIndicatorToNull.clear();
            }

            //00033728  
            if (!licenseIdsForAMDInactivation.isEmpty() && !System.isBatch()){
                List<License__c> AMDInactiveLicense 
                    = (new LicenseDomain(licenses)).filterLicenseFromSet(licenseIdsForAMDInactivation);
                insert (new LicenseDomain(AMDInactiveLicense)).generateAMDInactivationNotifications(false);
                Database.executeBatch(new AMDInactivationBatch(), 10);
                licenseIdsForAMDInactivation.clear();
            }
        }


        if(Trigger.isBefore != null && Trigger.isBefore) {
            deleteLicenseConditions();
            CounterService.saveApprenticeApplication();
        }

    }

    // CASE 00005439
    public static Map<String, List<LicenseRequirements__c>> getLicenseRequirements(List<String> licenseIds) {
        List<LicenseRequirements__c> licenseRequirementsList = LicenseSelector.getRequirementsByLicenseIds(licenseIds);
        Map<String, List<LicenseRequirements__c>> licenseReqList = new Map<String, List<LicenseRequirements__c>>();
        for(LicenseRequirements__c lr : licenseRequirementsList) {
            List<LicenseRequirements__c> requirementsList = licenseReqList.get(lr.License__c);
            if(requirementsList == null) {
                requirementsList = new List<LicenseRequirements__c>();
            }
            requirementsList.add(lr);
            licenseReqList.put(lr.License__c, requirementsList);
        }
        return licenseReqList;
    }
    // 00008996
    public static void recordAddressUpdate() {
        if(!licenseHistories.isEmpty()) {

            //00037317
            Set<String> historyLicIds = new Set<String>();
            for(LicenseHistory__c licenseHistory : licenseHistories){
                historyLicIds.add(licenseHistory.License__c);
            }

            // Get License and License Type Periods
            Map<Id, License__c> licsMap = new Map<Id, License__c>();
            Set<String> licTypes = new Set<String>();
            for(License__c lic : LicenseSelector.getLicensesAddressChangeDetails(historyLicIds)){
                licsMap.put(lic.Id, lic);
                licTypes.add(lic.LicenseType__c);
            }

            
            Map<Id, LicenseType__c> licsTypeMap = new Map<Id, LicenseType__c>();
            for(LicenseType__c licType : LicenseTypeSelector.getLicenseTypePeriods(licTypes)){
                licsTypeMap.put(licType.Id, licType);
            }

            for(LicenseHistory__c licenseHistory : licenseHistories){
                License__c currentLicense = licsMap.get(licenseHistory.License__c);
                if(currentLicense == null) continue;
                
                LicenseType__c currentLicenseType = licsTypeMap.get(currentLicense.LicenseType__c);
                if(currentLicenseType == null) continue;

                if(licenseHistory.TransactionType__c == 'CBADD - BUSINESS ADDRESS CHANGED - OLD ADDRESS RECORDED HERE (ALL LICENSE TYPES CONSIDERED A BUSINESS AND BUSINESS ADDRESS CHANGES)'){
                    licenseHistory.LicensePeriod__c = currentLicense.Business_Address_Update_from_Renewal__c ? currentLicenseType.NextLicensePeriod__c : currentLicenseType.PreviousLicensePeriod__c;
                } else if(licenseHistory.TransactionType__c == 'CMADD - MAILING ADDRESS CHANGED - OLD ADDRESS RECORDED HERE'){
                    licenseHistory.LicensePeriod__c = currentLicense.Mailing_Address_Update_from_Renewal__c ? currentLicenseType.NextLicensePeriod__c : currentLicenseType.PreviousLicensePeriod__c;
                }

                currentLicense.Business_Address_Update_from_Renewal__c = false;
                currentLicense.Mailing_Address_Update_from_Renewal__c = false;
                licsMap.put(currentLicense.Id, currentLicense);
            }

            WithoutSharingDmlHelper.doInsert(licenseHistories);
            licenseHistories.clear();

            if(!licsMap.isEmpty()) WithoutSharingDmlHelper.doUpdate(licsMap.values());
        }
    }

    public static void captureAddressesUpdate(SObject oldSo, SObject so) {
        License__c oldLicense = (License__c) oldSo;
        License__c license = (License__c) so;
        
        if ((license.BusinessStreet__c != oldLicense.BusinessStreet__c
            || license.BusinessCity__c != oldLicense.BusinessCity__c
            || license.BusinessState__c != oldLicense.BusinessState__c
            || license.BusinessZipcode__c != oldLicense.BusinessZipcode__c)
            && !license.BypassLicenseHistoryCreation__c
            && !licenseIdsForBusinessAddresCaptured.contains(license.Id)) {
                LicenseHistory__c history = new LicenseHistory__c();
                history.License__c = license.Id;
                history.EffectiveDate__c = oldLicense.BusinessAddressEffectiveDate__c;
                history.TransactionType__c = 'CBADD - BUSINESS ADDRESS CHANGED - OLD ADDRESS RECORDED HERE (ALL LICENSE TYPES CONSIDERED A BUSINESS AND BUSINESS ADDRESS CHANGES)';
                history.Remarks__c = generateRemarksField(oldLicense.BusinessStreet__c, oldLicense.BusinessCity__c,
                oldLicense.BusinessState__c, oldLicense.BusinessZipcode__c);
                history.TermDate__c = license.BusinessAddressEffectiveDate__c;
                licenseHistories.add(history);
                licenseIdsForBusinessAddresCaptured.add(license.Id);
        }

        if ((license.MailingStreet__c != oldLicense.MailingStreet__c
            || license.MailingCity__c != oldLicense.MailingCity__c
            || license.MailingState__c != oldLicense.MailingState__c
            || license.MailingZipcode__c != oldLicense.MailingZipcode__c)
            && !license.BypassLicenseHistoryCreation__c
            && !licenseIdsForMailingAddresCaptured.contains(license.Id)) {
                LicenseHistory__c history = new LicenseHistory__c();
                history.License__c = license.Id;
                history.EffectiveDate__c = oldLicense.MailingAddressEffectiveDate__c;
                history.TransactionType__c = 'CMADD - MAILING ADDRESS CHANGED - OLD ADDRESS RECORDED HERE';
                history.Remarks__c = generateRemarksField(oldLicense.MailingStreet__c, oldLicense.MailingCity__c,
                oldLicense.MailingState__c, oldLicense.MailingZipcode__c);
                history.TermDate__c = license.MailingAddressEffectiveDate__c;
                licenseHistories.add(history);
                licenseIdsForMailingAddresCaptured.add(license.Id);
        }

    }
    public static String generateRemarksField(String street, String city, String state, String zipCode) {
        if(street == null) {
            street = '';
        }
        if(city == null) {
            city = '';
        }
        if(state == null) {
            state = '';
        }
        if(zipCode == null) {
            zipCode = '';
        }
        String strs = street + ' ' + city + ', ' +state+' '+ zipCode;
        if(strs == ', ') strs = '';
        return strs;

    }

    /*
     * PacPoint-CL02182022 - Create for Case 00019924
     */
    public static void sendNoticeOfLicensure(List<License__c> licenses, Map<Id, License__c> oldMap) {
        List<String> ids = new List<String>();
        for (License__c l : licenses) {
            if (l.GenerateNoticeofLicensureEmail__c && !oldMap.get(l.Id).GenerateNoticeofLicensureEmail__c) {
                ids.add(l.Id);
            }
        }

        if (!ids.isEmpty()) {
            sendNoticeOfLicensure(ids);
        }
    }

    /*
     * PacPoint-CL02182022 - Create for Case 00019924
     */
    @Future
    public static void sendNoticeOfLicensure(List<String> licenseIds) {
        List<License__c> licensesForEmail = LicenseSelector.getLicenses(licenseIds);
        Set<String> emailTemplatesFilter = new Set<String>();

        for (License__c l : licensesForEmail) {
            if (l.LicenseType__r.NoticeofLicensureEmailTemplate__c != null) {
                String emailTemplate =
                        'Lic' + l.LicenseType__r.NoticeofLicensureEmailTemplate__c.replaceAll('[^a-zA-Z]', '');
                emailTemplatesFilter.add(emailTemplate);
            }
        }

        List<EmailTemplate> emailTemplates = [
                SELECT
                        Id,
                        DeveloperName
                FROM EmailTemplate
                WHERE DeveloperName IN :emailTemplatesFilter
        ];

        Map<String, EmailTemplate> emailTemplateMap = new Map<String, EmailTemplate>();
        for (EmailTemplate et : emailTemplates) {
            emailTemplateMap.put(et.DeveloperName, et);
        }

        List<Messaging.SingleEmailMessage> msgs = new List<Messaging.SingleEmailMessage>();
        List<OrgWideEmailAddress> fromAddress = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'DCCA No Reply'];
        String eId;
        if(Test.isRunningTest()) {
            EmailTemplate temp= [Select Id from EmailTemplate where IsActive = true limit 1];
            eId = temp.Id;
        }
        
        for (License__c l : licensesForEmail) {
            String emailTemplateId;
            if (l.LicenseType__r.NoticeofLicensureEmailTemplate__c != null && l.NotificationEmail__c != null) {
                String emailTemplate = 'Lic' + l.LicenseType__r.NoticeofLicensureEmailTemplate__c.replaceAll('[^a-zA-Z]', '');
                if(emailTemplateMap.containsKey(emailTemplate)) {
                    emailTemplateId = emailTemplateMap.get(emailTemplate).Id;
                }
            } else if(Test.isRunningTest() ) {
                emailTemplateId = eId;
            }
            if (emailTemplateId != null) {
                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setTemplateId(emailTemplateId);
                msg.setTargetObjectId(UserInfo.getUserId());
                msg.setTreatTargetObjectAsRecipient(false);
                msg.setToAddresses(new List<String>{l.NotificationEmail__c});
                msg.setWhatId(l.Id);
                if (!fromAddress.isEmpty()) {
                    msg.setOrgWideEmailAddressId(fromAddress[0].Id);
                }
                msgs.add(msg);
            }
        }
        if(!Test.isRunningTest()) Messaging.sendEmail(msgs);
    }

    //Case 00021265
    @future(callout=true)
    public static void sendRenewalEmails(List<String> licenseIds) {
        Map<Id, License__c> licensesMap = new Map<Id, License__c>(LicenseSelector.getLicenses(licenseIds));
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        Map<String, List<String>> emailTemplateLicenseIdsMap = new Map<String, List<String>>();

        for (License__c l : licensesMap.values()) {
            String tpl = l.LicenseType__r.RenewalReminderEmailTemplate__c;
            //Added by Sohan 09/18/2025
            String etMd = 'IMLCC_MD_Renewal_Email_Template';
            String etDos = 'IMLCC_DOS_Renewal_Email_Template';
            //
            if (!emailTemplateLicenseIdsMap.containsKey(tpl)) {
                emailTemplateLicenseIdsMap.put(tpl, new List<String>());
            }

            if (l.PVL_Portal_User__c == null || l.PVL_Portal_User__r.Email__c == null) {
                continue;
            }

            //Added by Sohan 09/18/2025
            if(l.LicenseTypeName__c == 'MD' && l.MethodofLicensure__c == 'LC - Licensure Compact'){
                if (!emailTemplateLicenseIdsMap.containsKey(etMd)) {
                    emailTemplateLicenseIdsMap.put(etMd, new List<String>());
                }
                emailTemplateLicenseIdsMap.get(etMd).add(l.Id);
            }
            else if(l.LicenseTypeName__c == 'DOS' && l.MethodofLicensure__c == 'LC - Licensure Compact'){
                if (!emailTemplateLicenseIdsMap.containsKey(etDos)) {
                    emailTemplateLicenseIdsMap.put(etDos, new List<String>());
                }
                emailTemplateLicenseIdsMap.get(etDos).add(l.Id);
            }
            else{
                emailTemplateLicenseIdsMap.get(tpl).add(l.Id);
            }
            //

            //Updated by Sohan 09/18/2025
            //emailTemplateLicenseIdsMap.get(tpl).add(l.Id);
            //
        }

        Map<String, EmailTemplate> emailTemplateMap = new Map<String, EmailTemplate>();

        for (
                EmailTemplate em
                :
        [
                SELECT
                        Id,
                        DeveloperName
                FROM EmailTemplate
                WHERE DeveloperName IN :emailTemplateLicenseIdsMap.keySet()
        ]) {
            emailTemplateMap.put(em.DeveloperName, em);
        }

        String orgWideFromAddressId = [
                SELECT
                        Id
                FROM OrgWideEmailAddress
                WHERE DisplayName = 'DCCA No Reply'
                LIMIT 1
        ].Id;

        for (String tpl : emailTemplateLicenseIdsMap.keySet()) {
            for (String licenseId : emailTemplateLicenseIdsMap.get(tpl)) {
                
                String emailTemplateId ;
                if(Test.isRunningTest()) {
                    EmailTemplate temp= [Select Id from EmailTemplate where IsActive = true limit 1];
                    emailTemplateId = temp.Id;

                } else {
                    EmailTemplate temp = emailTemplateMap.get(tpl);
                    emailTemplateId = temp.Id;
                }
                

                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setTemplateId(emailTemplateId);
                msg.setOrgWideEmailAddressId(orgWideFromAddressId);
                msg.setTargetObjectId(UserInfo.getUserId());
                msg.setWhatId(licenseId);
                msg.setToAddresses(new String[]{licensesMap.get(licenseId).PVL_Portal_User__r.Email__c});
                msg.setTreatTargetObjectAsRecipient(false);
                messages.add(msg);
            }
        }

        Messaging.sendEmail(messages, false);
    }

    public static void nullifyAssocLicensesDualIndicator(Set<String> parentLicenseIds) {
        List<AssociatedLicense__c> assocLicenses = [
            SELECT Id
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :parentLicenseIds
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND DualIndicator__c = 'Dual'
        ];

        for (AssociatedLicense__c al : assocLicenses) {
            al.DualIndicator__c = null;
        }

        update assocLicenses;
    }

    /**
     * VPVL-13: When RB-Entity License is set to Inactive or Status is set to TC,
     * set LossofEntityDate__c to today. The associated license updates (inactivating employees,
     * creating INAC history records) are handled by the midnight batch job.
     * Created by: Akanksha Reddy Anthireddygari
     * Created date: 01/12/2026
     */
    public static void captureRbEntityInactivationForAssociatedLicenses(SObject oldSo, SObject so) {
        License__c record = (License__c) so;
        License__c oldRecord = (License__c) oldSo;
        
        // Check if this is an RB-Entity license
        if (record.LicenseTypeName__c != 'RB - Entity') {
            return;
        }
        
        // Check if ActiveInactive__c changed to Inactive OR Status changed to TC
        Boolean isInactiveChange = (oldRecord.ActiveInactive__c != 'Inactive' && record.ActiveInactive__c == 'Inactive');
        Boolean isStatusTCChange = (oldRecord.Status__c != 'TC' && record.Status__c == 'TC');
        
        if (!isInactiveChange && !isStatusTCChange) {
            return;
        }
        
        // VPVL-13: Set LossofRBEntityDate to today (associated license updates moved to midnight batch)
        record.LossofRBEntityDate__c = Date.today();
    }

    /**
     * VPVL-13: When a Sole Proprietor License is set to Inactive,
     * set LossofSoleProprietorDate__c to today. The associated license updates 
     * are handled by the midnight batch job.
     * Created by: Akanksha Reddy Anthireddygari
     * Created date: 01/22/2026
     */
    public static void captureSoleProprietorInactivation(SObject oldSo, SObject so) {
        License__c record = (License__c) so;
        License__c oldRecord = (License__c) oldSo;
        
        // Check if this is a Sole Proprietor license (any type containing 'Sole Proprietor')
        if (record.LicenseTypeName__c == null || !record.LicenseTypeName__c.contains('Sole Proprietor')) {
            return;
        }
        
        // Check if ActiveInactive__c changed to Inactive
        Boolean isInactiveChange = (oldRecord.ActiveInactive__c != 'Inactive' && record.ActiveInactive__c == 'Inactive');
        
        if (!isInactiveChange) {
            return;
        }
        
        // VPVL-13: Set LossofSoleProprietorDate to today (associated license updates moved to midnight batch)
        record.LossofSoleProprietorDate__c = Date.today();
    }
}