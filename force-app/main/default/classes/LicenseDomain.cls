/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
* License records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ150819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-08-15
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class LicenseDomain extends SObjectDomain{
    public LicenseDomain(List<License__c> licenses) {
        super(licenses);
    }
    public List<License__c> filterLicenseBySoleOwner(Boolean soleOwner) {
        List<License__c> filteredRecords = new List<License__c>();
        for(License__c record: (List<License__c>)records) {
            if(record.SoleOwner__c == soleOwner) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    public List<License__c> getLicenseByLicenseTypeCodes(Set<String> typeCodes) {
        List<License__c> filteredRecords = new List<License__c>();
        for(License__c record: (List<License__c>) records) {
            if(typeCodes.contains(record.LicenseType__r.Name)) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    // 00010823
    public List<Suspense__c> getPrincipalSuspenses() {
        List<Suspense__c> suspenses = new List<Suspense__c>();
        for(License__c record: (List<License__c>) records) {
            Suspense__c suspense = new Suspense__c();
            suspense.License__c = record.Id;
            suspense.MaintenanceType__c = 'NPRM - NO PRINCIPAL RME';
            Integer days = 0;
            if(record?.LicenseType__r?.NumberofDaysUntilAutoForfeiture__c != null) {
                days = Integer.valueOf(record.LicenseType__r.NumberofDaysUntilAutoForfeiture__c);
            }
            Date principalDate = record.LossOfPrincipalRMEDate__c;
            if(principalDate == null) principalDate = Date.today();
            suspense.SuspenseDueDate__c = principalDate.addDays(days);
            suspense.SuspenseStatus__c = record.LicenseType__r.AutoForfeitureStatus__c;
            suspenses.add(suspense);
        }
        return suspenses;
    }
    
    public List<Suspense__c> getEntitySuspenses() {
        List<Suspense__c> suspenses = new List<Suspense__c>();
        // Define the license types to exclude
        Set<String> excludedLicenseTypes = new Set<String>{'BAP', 'BEP', 'MAP'};
    
        for(License__c record: (List<License__c>) records) {
            // Check if the license type should be excluded
            if(excludedLicenseTypes.contains(record.LicenseTypeName__c)) {
            // Skip generating suspense records for excluded license types
            continue;
            }
            Suspense__c suspense = new Suspense__c();
            suspense.License__c = record.Id;
            // suspense.MaintenanceType__c = 'NFRM - RME WITHOUT EMPLOYMENT';
            // 00028291 to replace maintenance type 
            // Use "NFEM - NO FIRM DUE TO EMPLOYMENT TERMINATION" as the maintenance type for 
            // loss of entity instead of "NFRM - RME WITHOUT EMPLOYMENT"
            suspense.MaintenanceType__c = 'NFEM - NO FIRM DUE TO EMPLOYMENT TERMINATION';
            // end
            Integer days = 0;
            if(record?.LicenseType__r?.NumberofDaysUntilAutoForfeiture__c != null) {
                days = Integer.valueOf(record.LicenseType__r.NumberofDaysUntilAutoForfeiture__c);
            }
            Date entityDate = record.LossofEntityDate__c;
            if(entityDate == null) entityDate = Date.today();
            suspense.SuspenseDueDate__c = entityDate.addDays(days);
            suspense.SuspenseStatus__c = record.LicenseType__r.AutoForfeitureStatus__c;
            suspenses.add(suspense);
        }
        return suspenses;  
    }

    // Used to provide the generate file uncheck process.
    public List<License__c> generateLicenseRecordsForUncheckFileGenerate() {
        List<License__c> recordsForUpdate = new List<License__c>();
        for(License__c record: (List<License__c>) records) {
            if(!record.GenerateFile__c) {
                continue;
            }
            License__c recordForUpdate = new License__c();
            recordForUpdate.Id = record.Id;
            recordForUpdate.GenerateFile__c = false;
            recordsForUpdate.add(recordForUpdate);
        }
        return recordsForUpdate;
    }

    public List<License__c> filteroutLicenseFromSet(Set<String> idSet) {
        List<License__c> filteredLicenses = new List<License__c>();
        for(SObject record: records) {
            License__c license = (License__c) record;
            if(!idSet.contains(license.Id)) {
                filteredLicenses.add(license);
            }
        }
        return filteredLicenses;
    }
    // 000116600
    public List<Suspense__c> updateLicenseRecords(Map<String, List<Suspense__c>> licenseId2Suspenses) {
        List<Suspense__c> suspenses = new List<Suspense__c>();
        Date yesterday = Date.today().addDays(-1);
        for(SObject record: records) {
            License__c license = (License__c) record;
            if(licenseId2Suspenses.containsKey(license.Id) ) {   
                if(licenseId2Suspenses.get(license.Id).size() == 1 ) {
                    license.Status__c = licenseId2Suspenses.get(license.Id).get(0).SuspenseStatus__c;
                    licenseId2Suspenses.get(license.Id).get(0).Historical__c = true;
                    suspenses.add(licenseId2Suspenses.get(license.Id).get(0));
                } else if(licenseId2Suspenses.get(license.Id).size() > 1) {
                    List<Suspense__c> srecords = licenseId2Suspenses.get(license.Id);
                    List<Suspense__c> candidates = new List<Suspense__c>();
                    for(Suspense__c suspense: srecords) {
                        if(suspense.SuspenseDueDate__c == license.ForfeitureDate__c 
                            && suspense.SuspenseStatus__c == license.LicenseType__r.StatusDueToLossOfInsurance__c) {
                            candidates.add(suspense);
                        }
                    }

                    if(candidates.isEmpty()) {
                        license.Status__c = licenseId2Suspenses.get(license.Id).get(0).SuspenseStatus__c;
                        licenseId2Suspenses.get(license.Id).get(0).Historical__c = true;
                        suspenses.add(licenseId2Suspenses.get(license.Id).get(0));
                    } else {
                        license.status__c = candidates.get(0).SuspenseStatus__c;
                        for(Suspense__c candidate: candidates ) {
                            candidate.Historical__c = true;
                            suspenses.add(candidate);
                        }
                    }
                }
                
            }
        }
        return suspenses;
    }

    // Used to filter record based on Id
    // Used by LicenseService.createClassifications
    public List<License__c> filterLicenseFromSet(Set<String> idSet) {
        List<License__c> filteredLicenses = new List<License__c>();
        for(SObject record: records) {
            License__c license = (License__c) record;
            if(idSet.contains(license.Id)) {
                filteredLicenses.add(license);
            }
        }
        return filteredLicenses;
    }
    
    // Get list of Application ids
    // Used by LicenseService.createClassifications
    public List<String> getApplicationIds() {
        List<String> applicationIds = new List<String>();
        for(SObject record: records) {
            License__c license = (License__c) record;
            if(license.Application__c != null ) {
                applicationIds.add(license.Application__c);
            }
        }
        return applicationIds;
    }
    // Get Licenses for status updated to "C - CURRENT, VALID & IN GOOD STANDING"
    // Used by LicenseService.createClassifications
    // public List<License__c> getLicensesStatusToBeUpdated(Map<String, List<ApplicationClassifications__c>>  appIdToClassifications ) {
    //     List<License__c> licensesToBeUpdated = new List<License__c>();        
    //     for(SObject record: records) {
    //         License__c license = (License__c) record;
    //         String applicationId = license.Application__c;
    //         List<ApplicationClassifications__c> appClssifications 
    //             = appIdToClassifications.get(applicationId);
    //         if(appClssifications == null ) continue;
    //         License__c licenseForUpdate =  new License__c();
    //         licenseForUpdate.Id = license.Id;
    //         licenseForUpdate.Status__c = 'C - CURRENT, VALID & IN GOOD STANDING';
    //         licensesToBeUpdated.add(licenseForUpdate);
    //     }
    //     return licensesToBeUpdated;
    // } 
    // Generate License Classifications
    // Used by LicenseService.createClassifications
    public List<LicenseClassification__c> convertToLicenseClassifications (
            Map<String, List<ApplicationClassifications__c>>  appIdToClassifications ) {
        List<LicenseClassification__c> licenseClassifications = new List<LicenseClassification__c>();        
        for(SObject record: records) {
            License__c license = (License__c) record;
            String applicationId = license.Application__c;
            List<ApplicationClassifications__c> appClssifications 
                = appIdToClassifications.get(applicationId);
            if(appClssifications == null ) continue;
            licenseClassifications.addAll((new ApplicationClassificationsDomain(
                appClssifications)).convertToLicenseClassifications(license));
        }

        return licenseClassifications;
    }

    /******00006486 */
    public Map<String, List<License__c>> convertToLicenseTypeIdToLicenses() {
        Map<String, List<License__c>> licenseTypeId2Licenses = new Map<String, List<License__c>>();
        for(License__c record: (List<License__c>) records) {
            String licenseTypeId = record.LicenseType__c;
            if(licenseTypeId == null) continue;
            List<License__c> licenses = licenseTypeId2Licenses.get(licenseTypeId);
            if(licenses == null) licenses = new List<License__c>();
            String auditActiveInactive = record.LicenseType__r.AuditActiveInactive__c;
            String auditStatuses = record.LicenseType__r.AuditStatuses__c;
            //String specialPrivileges = record.LicenseType__r.SpecialPrivilege__c;
            if(auditActiveInactive != null) {
                List<String> auditActiveInactiveList = auditActiveInactive.split(';');
                Set<String> auditActiveInactiveSet = new Set<String>(auditActiveInactiveList);
                if(record.ActiveInactive__c == null || !auditActiveInactiveSet.contains(record.ActiveInactive__c)) {
                    continue;
                }
            }

            if(auditStatuses != null) {
                List<String> auditStatusesList = auditStatuses.split(';');
                Set<String> auditStatusesSet = new Set<String>(auditStatusesList);
                if(record.Status__c == null || !auditStatusesSet.contains(record.Status__c)) {
                    continue;
                }
            }

//            if(specialPrivileges != null) {
//                List<String> specialPrivilegesList = specialPrivileges.split(';');
//                Set<String> specialPrivilegesSet = new Set<String>(specialPrivilegesList);
//                if(record.Privilege__c == null || !specialPrivilegesSet.contains(record.Privilege__c)) {
//                    continue;
//                }
//            }

            licenses.add(record);
            licenseTypeId2Licenses.put(licenseTypeId, licenses);
        }
        return licenseTypeId2Licenses;
    }
    /******00006486 ****used to get list of License Types***/
    public List<LicenseType__c> getLicenseTypes() {
        List<LicenseType__c> licenseTypes = new List<LicenseType__c>();
        Set<String> licenseTypeIdSet = new Set<String>();
        for(License__c record: (List<License__c>)records) {
            if(licenseTypeIdSet.contains(record.LicenseType__c)) {
                continue;
            }
            if(record.LicenseType__c != null) {
                licenseTypes.add(record.LicenseType__r);
                licenseTypeIdSet.add(record.LicenseType__c);
            }
        }
        return licenseTypes;

    }

    // Call future actions
    public void generateFile() {
        // if(System.isBatch() ) {
        //     return ;
        // }
        List<PVLProcess__e> processes = new List<PVLProcess__e>();
        for(SObject record: records) {
            License__c license = (License__c) record;
            String fileEngines = license.FileEngines__c;
            Map<String, String> payload = new Map<String, String>();
            PVLProcess__e process = new PVLProcess__e();
            if(fileEngines != null ) {
                System.debug('########fileEngines########' + fileEngines);
                List<String> fileEngineList = new List<String>();
                payload.put('Id', record.Id);
                payload.put('fileEngines', fileEngines);
                process.Type__c = 'Generate PDF';
                process.Payload__c = JSON.serialize(payload);
                processes.add(process);
                // for(String fileEngine: fileEngines.split(',')) {
                //     fileEngineList.add(fileEngine.trim());
                // }
                // for(String fileEngine: fileEngineList) {
                //     PVL_PDFGenerator.producePDFToFile(license.Id, fileEngine);
                //     System.debug('########app.Id########' + license.Id + '########fileEngines########' + fileEngines);
                // }
            }
        }
        EventBus.publish(processes);
        
    }

    // Get License Id => License record
    public Map<String, License__c> getIdToLicense() {
        Map<String, License__c> licenses = new Map<String, License__c>();
        for(SObject record : records) {
            License__c license = (License__c) record;
            licenses.put(license.Id, license);
        }
        return licenses;
    }

    // Used to update ClassPrefix__c on Lincese object.
    public List<License__c> updateClassPrefix(Map<String, String> licenseIdToClassPrefix_M) {
        List<License__c> licensesToUpdate = new List<License__c>();
        for(SObject record: records) {
            License__c lic = (License__c) record;
            if(licenseIdToClassPrefix_M.containsKey(lic.Id)) {
                lic.ClassPrefix__c = licenseIdToClassPrefix_M.get(lic.Id);
            } else {
                lic.ClassPrefix__c = null;
            }
            licensesToUpdate.add(lic);
        }
        return licensesToUpdate;
    }

    // Used to clear audit number and return only records that need to be updated
    // Used by BatchFlagLicenseForAudit.execute
    // 00006750
    public List<License__c> setAuditNumberNull() {
        List<License__c> licensesForUpdate = new list<License__c>();
        for(SObject record: records) {
            License__c licenseRecord = (License__c) record;
            // licenseRecord.AuditNumber__c = 0;
            if(licenseRecord.AuditNumber__c != null){
                licenseRecord.AuditNumber__c = null;
                licensesForUpdate.add(licenseRecord);
            }
                
        }
        return licensesForUpdate;
    }
    public void updateNumOfActiveEmployers(Map<String, Integer>  employeeLicenseCount) {
        for(License__c record: (List<License__c>) records) {
            // record.CurrentEmployerCount__c = employeeLicenseCount.get(record.Id);
            record.NumberOfActiveEmployers__c = employeeLicenseCount.get(record.Id);
            if(record.NumberOfActiveEmployers__c == null) record.NumberOfActiveEmployers__c = 0;
        }
    }
    // public void updateAuditCERequirements() {
    //     for(License__c record: (List<License__c>)records) {
    //         if(record.LicenseType__r.AuditType__c == 'Pre Audit' ) {
    //             if(record.LicenseType__r.PartialCERequirement__c == 'No (All CE will be Required)') {
    //                 record.AuditCERequirement__c = 'Full';
    //             } else if(record.LicenseType__r.PartialCERequirement__c == 'Licensed in 1st half of Biennium Requires Partial CE (1SB)') {
    //                 if(record.OriginalDateofLicensure__c >= record.LicenseType__r.FirstYearStart__c
    //                     && record.OriginalDateofLicensure__c < record.LicenseType__r.SecondYearStart__c) {
    //                     record.AuditCERequirement__c = 'Partial';
    //                 } else {
    //                     record.AuditCERequirement__c = 'Full';
    //                 }
    //             } else if( record.LicenseType__r.PartialCERequirement__c == 'Licensed in the Current License Period Requires Partial CE (CUR)') {
    //                 if(record.OriginalDateofLicensure__c >= record.LicenseType__r.LicenseTypeEffectiveDate__c
    //                     && record.OriginalDateofLicensure__c <= record.LicenseType__r.LicenseTypeExpireDate__c) {
    //                     record.AuditCERequirement__c = 'Partial';
    //                 } else {
    //                     record.AuditCERequirement__c = 'Full';
    //                 } 
    //             }
    //         } else if(record.LicenseType__r.AuditType__c == 'Post Audit' ) {
    //             if(record.LicenseType__r.PartialCERequirement__c == 'No (All CE will be Required)') {
    //                 record.AuditCERequirement__c = 'Full';
    //             } else if(record.LicenseType__r.PartialCERequirement__c == 'Licensed in 1st half of Biennium Requires Partial CE (1SB)') {
    //                 if(record.OriginalDateofLicensure__c >= record.LicenseType__r.PreviousFirstYearStart__c
    //                     && record.OriginalDateofLicensure__c < record.LicenseType__r.PreviousSecondYearStart__c) {
    //                     record.AuditCERequirement__c = 'Partial';
    //                 } else {
    //                     record.AuditCERequirement__c = 'Full';
    //                 }
    //             } else if( record.LicenseType__r.PartialCERequirement__c == 'Licensed in the Current License Period Requires Partial CE (CUR)') {
    //                 if(record.OriginalDateofLicensure__c >= record.LicenseType__r.PreviousLicensePeriodEffectiveDate__c
    //                     && record.OriginalDateofLicensure__c <= record.LicenseType__r.PreviousLicensePeriodExpireDate__c) {
    //                     record.AuditCERequirement__c = 'Partial';
    //                 } else {
    //                     record.AuditCERequirement__c = 'Full';
    //                 } 
    //             }
    //         }
                


    //     }
    // }
    // 00006750
    public Map<String, Integer> updateAuditNumber(Map<String, Integer> licenseTypeMap) {
        System.debug('#####records##########' + records);
        System.debug('#####records.length##########' + records.size());
        for(License__c licenseRecord: (List<License__c>)records) {
            Integer auditNumber = licenseTypeMap.get(licenseRecord.LicenseType__c);
            if( auditNumber == null ){
                // initial licenseTypeMap to licenseType => 1
                auditNumber = 1;
                
                licenseTypeMap.put(licenseRecord.LicenseType__c, 1);
            } else {
                auditNumber ++;
            }
            System.debug('###auditNumber###' + auditNumber);
            licenseRecord.AuditNumber__c = auditNumber;
            licenseTypeMap.put(licenseRecord.LicenseType__c, auditNumber);
        }
        return licenseTypeMap;
    }

     // 
     public Map<String, Map<String, Integer>> updateAuditNumberWithDedicateNumber(Map<String, Integer> licenseTypeMap, Map<String, Integer> licenseTypeNum) {
        Map<String, Map<String, Integer>> ints = new Map<String, Map<String, Integer>>();
        for(License__c licenseRecord: (List<License__c>)records) {
            Integer auditNumber = licenseTypeMap.get(licenseRecord.LicenseType__c);
            Integer restNum = licenseTypeNum.get(licenseRecord.LicenseType__c);
            if(!licenseTypeNum.containsKey(licenseRecord.LicenseType__c) || restNum == 0) {
                licenseRecord.FlaggedforAudit__c = false;
                licenseRecord.GenerateFlaggedForAuditNotification__c = false;
                continue;
            }
            if( auditNumber == null ){
                // initial licenseTypeMap to licenseType => 1
                auditNumber = 1;
                
                licenseTypeMap.put(licenseRecord.LicenseType__c, 1);
            } else {
                auditNumber ++;
            }
            restNum --;

            licenseRecord.AuditNumber__c = auditNumber;
            licenseTypeMap.put(licenseRecord.LicenseType__c, auditNumber);
            if(restNum == 0) {
                licenseTypeNum.remove(licenseRecord.LicenseType__c);
            } else {
                licenseTypeNum.put(licenseRecord.LicenseType__c, restNum);
            }
            
        }
        ints.put('licenseTypeMap', licenseTypeMap);
        ints.put('licenseTypeNum', licenseTypeNum);
        return ints;
    }

    //00008968
    public List<Notification__c> getNotifications() {
        List<Notification__c> notifications = new List<Notification__c>();
        for(License__c record: (List<License__c>) records) {
            if(record.ActiveInactive__c != 'Active') {
                continue;
            }
            if( record.Status__c == 'C - Current, Valid & In Good Standing'
                || record.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due'
                || record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement'
                || record.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement') 
            {
                Notification__c notification = new Notification__c();
                notification.RecordId__c = record.Id;
                notification.License__c = record.Id;
                notification.DocGeneratorSettings__c = record.LicenseType__r.InsuranceUpdateRequiredNotification__r.Name;
                notification.DocumentTemplateName__c = record.LicenseType__r.InsuranceUpdateRequiredNotification__r.Name;
                notification.Scheduled__c = true;
                notification.SendToPrinter__c = true;
                notification.Status__c = 'Scheduled';
                notifications.add(notification);
            }
        }
        return notifications;
    }

    //00008968
    public List<License__c> updateLicensesForBondReminder() {
        List<License__c> licensesForUpdate = new List<License__c>();
        for(License__c record: (List<License__c>) records) {
            if(record.ActiveInactive__c != 'Active' || !record.LicenseType__r.RequiresInsurance__c) {
                continue;
            }
            if(record.Status__c == 'C - Current, Valid & In Good Standing') {
                record.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
                licensesForUpdate.add(record);
            }

            if(record.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal') {
                record.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
                licensesForUpdate.add(record);
            }

            if(record.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement') {
                record.Status__c = 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement';
                licensesForUpdate.add(record);
            }
        }
        return licensesForUpdate;
    }

    public List<Suspense__c> generateNewSuspenseIfNotExist(Map<String, List<Suspense__c>> licenseId2Suspenses) {
        List<Suspense__c> suspensesForCreate = new List<Suspense__c>();
        for(License__c record: (List<License__c>) records) {
            if(!licenseId2Suspenses.containsKey(record.Id) 
                || licenseId2Suspenses.get(record.Id).isEmpty()) {
                Suspense__c suspense = new Suspense__c();
                Integer daysOfAdd = 0;
                
                if(record?.LicenseType__r?.NumberOfDaysUntilAutoForfeiture__c != null) {
                    daysOfAdd = Integer.valueOf(record?.LicenseType__r.NumberOfDaysUntilAutoForfeiture__c);
                }
                suspense.SuspenseDueDate__c = Date.today().addDays(daysOfAdd);
                suspense.MaintenanceType__c = 'NFRM - RME WITHOUT EMPLOYMENT';
                suspense.License__c = record.Id;
                suspense.SuspenseStatus__c = record.LicenseType__r.AutoForfeitureStatus__c;
                suspensesForCreate.add(suspense);
            }
        }
        return suspensesForCreate;
    }

    public void renewLicenses() {
        for(License__c record: (List<License__c>) records) {
            Date previousEffectiveDate = record.EffectiveExpireDate__c;
            record.EffectiveExpireDate__c = record.LicenseType__r.LicenseTypeExpireDate__c;
            record.PreviousEffectiveExpiryDate__c = previousEffectiveDate;
            record.ThisLicenseRenewed__c = true;
            if(record.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due' ) {
                record.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
            } else if(record.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal') {
                record.Status__c = 'C - Current, Valid & In Good Standing';
            }
        }
    }

    public List<Notification__c> generateAMDInactivationNotifications(Boolean isExecute) {
        List<Notification__c> notifications = new List<Notification__c>();
        for(License__c record: (List<License__c>) records) {
            Notification__c notification = new Notification__c();
            notification.RecipientEmail__c = record.NotificationEmail__c;
            notification.License__c = record.Id;
            notification.RecordId__c = record.Id;
            notification.Scheduled__c = true;
            notification.SendToPrinter__c = true;
            notification.Fire__c = isExecute;
            notification.Type__c = 'Email';
            notification.Status__c = 'Scheduled';
            notification.VFPage__c = 'AMDInactivationLetterNotice';
            notification.DocGeneratorSettings__c = 'AMD Inactivation Letter';
            notification.DocumentTemplateName__c = 'AMD Inactivation Letter.pdf';
            notification.PrintStatus__c = 'Ready for Print';
            notifications.add(notification);
        }
        return notifications;
    }
}