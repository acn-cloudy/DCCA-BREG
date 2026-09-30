/**
 * VPVL-13: Batch class to handle license loss scenarios:
 * 1. RB-Entity Lost Principal Broker (NOPB suspense)
 * 2. RB-Entity Lost all BICs while having active RBO (NBIC suspense)
 * 3. RB-Entity Lost Entity (went Inactive/TC) - inactivate associated licenses, create INAC history
 * 4. Sole Proprietor Lost (went Inactive) - inactivate associated licenses, create INAC history
 * 
 * This batch job runs at midnight daily and processes licenses where:
 * - LossofPrincipalBrokerDate__c = TODAY (for NOPB suspense - RB-Entity only)
 * - LossofBICDate__c = TODAY (for NBIC suspense - RB-Entity only)
 * - LossofRBEntityDate__c = TODAY (for associated license inactivation - RB-Entity only)
 * - LossofSoleProprietorDate__c = TODAY (for associated license inactivation - Sole Proprietor only)
 * 
 * Validations before creating suspense:
 * - NOPB: Verifies the RB-Entity still has no active Principal Broker (PB_Counter__c = 0)
 * - NBIC: Verifies the RB-Entity still has active RBO and no active BIC
 * - Entity Loss: Verifies the RB-Entity is still Inactive
 * - Sole Proprietor Loss: Verifies the Sole Proprietor is still Inactive
 * 
 * Schedule Example:
 *   System.schedule('License Loss Processing Job', '0 0 0 * * ?', new RBEntityPrincipalBrokerSuspenseBatch());
 * 
 * Manual Execution:
 *   Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), 200);
 * 
 * @author  Akanksha Reddy Anthireddygari
 * @created 2026-01-22
 * @ticket  VPVL-13
 */
global class RBEntityPrincipalBrokerSuspenseBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {
    
    // Constants
    private static final String MAINTENANCE_TYPE_NOPB = 'NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER';
    private static final String MAINTENANCE_TYPE_NBIC = 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE';
    private static final String LICENSE_TYPE_RB_ENTITY = 'RB - Entity';
    private static final String POSITION_BIC = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)';
    private static final String STATUS_C = 'C - Current, Valid & In Good Standing';
    private static final Integer DEFAULT_BATCH_SIZE = 200;
    private static final Integer ADDITIONAL_DAYS = 10;
    
    // Valid statuses for suspense creation (matching Criteria 1 in licenseService.captureUpdate)
    private static final Set<String> VALID_STATUSES = new Set<String>{
        'C - Current, Valid & In Good Standing',
        'CP - Current Pending',
        'CR - Current/Next Renewal Paid',
        'Z - Current & Valid, But Subject To Disciplinary Requirement',
        'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
        'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)'
    };
    
    // Stateful tracking variables
    private Integer totalProcessed = 0;
    private Integer totalNOPBSuspensesCreated = 0;
    private Integer totalNBICSuspensesCreated = 0;
    private Integer totalNotificationsTriggered = 0;
    private Integer totalEmployeesInactivated = 0;
    private Integer totalHistoryRecordsCreated = 0;
    private Integer totalSkippedHasPB = 0;
    private Integer totalSkippedHasBIC = 0;
    private Integer totalSkippedNoRBO = 0;
    private Integer totalSkippedNotInactive = 0;
    private Integer totalErrors = 0;
    private List<String> errorMessages = new List<String>();
    
    /**
     * Schedulable execute method - kicks off the batch job
     * @param context Schedulable context
     */
    public void execute(SchedulableContext context) {
        Database.executeBatch(new RBEntityPrincipalBrokerSuspenseBatch(), DEFAULT_BATCH_SIZE);
    }
    
    /**
     * Batch start method - returns query locator for eligible licenses
     * @param context Batch context
     * @return QueryLocator for licenses with loss date = TODAY
     */
    global Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   Status__c,
                   ActiveInactive__c,
                   PB_Counter__c,
                   LossOfPrincipalRMEDate__c,
                   LossofPrincipalBrokerDate__c,
                   LossofBICDate__c,
                   LossofRBEntityDate__c,
                   LossofSoleProprietorDate__c,
                   LicenseTypeName__c,
                   GenerateEntityLosesRMENotification__c,
                   LicenseType__c,
                   LicenseType__r.Name,
                   LicenseType__r.NumberofDaysUntilAutoForfeiture__c,
                   LicenseType__r.AutoForfeitureStatus__c
            FROM License__c
            WHERE LossofPrincipalBrokerDate__c = TODAY 
               OR LossofBICDate__c = TODAY 
               OR LossofRBEntityDate__c = TODAY
               OR LossofSoleProprietorDate__c = TODAY
        ]);
    }
    
    /**
     * Batch execute method - processes each batch of licenses
     * Creates suspense records and handles inactivation
     * @param context Batch context
     * @param scope List of License__c records to process
     */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>) scope;
        
        if (licenses.isEmpty()) {
            return;
        }
        
        totalProcessed += licenses.size();
        
        // Collect license IDs for various checks
        Set<Id> licenseIdsForBICCheck = new Set<Id>();
        Set<Id> licenseIdsForEntityLoss = new Set<Id>();
        Set<Id> licenseIdsForSoleProprietorLoss = new Set<Id>();
        
        for (License__c license : licenses) {
            if (license.LossofBICDate__c == Date.today() && license.LicenseTypeName__c == LICENSE_TYPE_RB_ENTITY) {
                licenseIdsForBICCheck.add(license.Id);
            }
            if (license.LossofRBEntityDate__c == Date.today() && license.LicenseTypeName__c == LICENSE_TYPE_RB_ENTITY) {
                licenseIdsForEntityLoss.add(license.Id);
            }
            if (license.LossofSoleProprietorDate__c == Date.today() && 
                license.LicenseTypeName__c != null && 
                license.LicenseTypeName__c.contains('Sole Proprietor')) {
                licenseIdsForSoleProprietorLoss.add(license.Id);
            }
        }
        
        // Get licenses that have active BICs (to exclude from NBIC suspense)
        Set<Id> licensesWithActiveBIC = getLicensesWithActiveBIC(licenseIdsForBICCheck);
        
        // Get licenses that have active RBO associations
        Set<Id> licensesWithActiveRBO = getLicensesWithActiveRBO(licenseIdsForBICCheck);
        
        // Get associated licenses for entity loss processing
        Map<Id, List<AssociatedLicense__c>> entityToAssociatedLicenses = getAssociatedLicensesForEntities(licenseIdsForEntityLoss);
        
        // Get associated licenses for sole proprietor loss processing
        Map<Id, List<AssociatedLicense__c>> soleProprietorToAssociatedLicenses = getAssociatedLicensesForEntities(licenseIdsForSoleProprietorLoss);
        
        // Build lists for DML operations
        List<Suspense__c> suspensesToCreate = new List<Suspense__c>();
        List<License__c> licensesToUpdate = new List<License__c>();
        List<License__c> employeesToInactivate = new List<License__c>();
        List<LicenseHistory__c> historyToCreate = new List<LicenseHistory__c>();
        
        for (License__c license : licenses) {
            // Process Loss of Principal Broker (only for active RB-Entity licenses with valid status)
            if (license.LossofPrincipalBrokerDate__c == Date.today() 
                && license.LicenseTypeName__c == LICENSE_TYPE_RB_ENTITY
                && license.ActiveInactive__c == 'Active'
                && VALID_STATUSES.contains(license.Status__c)) {
                processLossOfPrincipalBroker(license, suspensesToCreate, licensesToUpdate);
            }
            
            // Process Loss of BIC (only for active RB-Entity licenses with valid status)
            if (license.LossofBICDate__c == Date.today()
                && license.LicenseTypeName__c == LICENSE_TYPE_RB_ENTITY
                && license.ActiveInactive__c == 'Active'
                && VALID_STATUSES.contains(license.Status__c)) {
                processLossOfBIC(license, licensesWithActiveBIC, licensesWithActiveRBO, suspensesToCreate);
            }
            
            // Process Loss of Entity (RB-Entity went Inactive/TC)
            if (license.LossofRBEntityDate__c == Date.today() 
                && license.LicenseTypeName__c == LICENSE_TYPE_RB_ENTITY) {
                processLossOfEntity(license, entityToAssociatedLicenses, employeesToInactivate, historyToCreate);
            }
            
            // Process Loss of Sole Proprietor
            if (license.LossofSoleProprietorDate__c == Date.today() 
                && license.LicenseTypeName__c != null 
                && license.LicenseTypeName__c.contains('Sole Proprietor')) {
                processLossOfSoleProprietor(license, soleProprietorToAssociatedLicenses, employeesToInactivate, historyToCreate);
            }
        }
        
        // Insert suspense records
        if (!suspensesToCreate.isEmpty()) {
            insertSuspenses(suspensesToCreate);
        }
        
        // Update licenses to trigger notification generation
        if (!licensesToUpdate.isEmpty()) {
            updateLicensesForNotification(licensesToUpdate);
        }
        
        // Inactivate employee licenses
        if (!employeesToInactivate.isEmpty()) {
            inactivateEmployeeLicenses(employeesToInactivate);
        }
        
        // Create history records
        if (!historyToCreate.isEmpty()) {
            createHistoryRecords(historyToCreate);
        }
    }
    
    /**
     * Process Loss of Principal Broker scenario
     */
    private void processLossOfPrincipalBroker(License__c license, List<Suspense__c> suspensesToCreate, List<License__c> licensesToUpdate) {
        // Skip if RB-Entity now has an active Principal Broker
        if (license.PB_Counter__c > 0) {
            totalSkippedHasPB++;
            return;
        }
        
        // Create NOPB suspense record
        Suspense__c suspense = buildNOPBSuspenseRecord(license);
        suspensesToCreate.add(suspense);
        
        // Set flag to trigger notification generation
        License__c licenseToUpdate = new License__c(
            Id = license.Id,
            GenerateEntityLosesRMENotification__c = true
        );
        licensesToUpdate.add(licenseToUpdate);
    }
    
    /**
     * Process Loss of BIC scenario
     */
    private void processLossOfBIC(License__c license, Set<Id> licensesWithActiveBIC, Set<Id> licensesWithActiveRBO, List<Suspense__c> suspensesToCreate) {
        // Skip if RB-Entity now has an active BIC
        if (licensesWithActiveBIC.contains(license.Id)) {
            totalSkippedHasBIC++;
            return;
        }
        
        // Skip if RB-Entity doesn't have active RBO
        if (!licensesWithActiveRBO.contains(license.Id)) {
            totalSkippedNoRBO++;
            return;
        }
        
        // Create NBIC suspense record
        Suspense__c suspense = buildNBICSuspenseRecord(license);
        suspensesToCreate.add(suspense);
    }
    
    /**
     * Process Loss of Entity scenario - inactivate associated employee licenses
     */
    private void processLossOfEntity(License__c license, Map<Id, List<AssociatedLicense__c>> entityToAssociatedLicenses, 
                                     List<License__c> employeesToInactivate, List<LicenseHistory__c> historyToCreate) {
        // Skip if RB-Entity is no longer Inactive (was re-activated)
        if (license.ActiveInactive__c != 'Inactive') {
            totalSkippedNotInactive++;
            return;
        }
        
        List<AssociatedLicense__c> associatedLicenses = entityToAssociatedLicenses.get(license.Id);
        
        if (associatedLicenses == null || associatedLicenses.isEmpty()) {
            return;
        }
        
        processAssociatedLicenseInactivation(associatedLicenses, employeesToInactivate, historyToCreate);
    }
    
    /**
     * Process Loss of Sole Proprietor scenario - inactivate associated employee licenses
     */
    private void processLossOfSoleProprietor(License__c license, Map<Id, List<AssociatedLicense__c>> soleProprietorToAssociatedLicenses, 
                                              List<License__c> employeesToInactivate, List<LicenseHistory__c> historyToCreate) {
        // Skip if Sole Proprietor is no longer Inactive (was re-activated)
        if (license.ActiveInactive__c != 'Inactive') {
            totalSkippedNotInactive++;
            return;
        }
        
        List<AssociatedLicense__c> associatedLicenses = soleProprietorToAssociatedLicenses.get(license.Id);
        
        if (associatedLicenses == null || associatedLicenses.isEmpty()) {
            return;
        }
        
        processAssociatedLicenseInactivation(associatedLicenses, employeesToInactivate, historyToCreate);
    }
    
    /**
     * Process associated license inactivation - shared logic for Entity and Sole Proprietor loss
     */
    private void processAssociatedLicenseInactivation(List<AssociatedLicense__c> associatedLicenses, 
                                                       List<License__c> employeesToInactivate, 
                                                       List<LicenseHistory__c> historyToCreate) {
        for (AssociatedLicense__c al : associatedLicenses) {
            if (al.EmployeeLicense__c == null || al.EmployeeLicense__r.ActiveInactive__c == 'Inactive') {
                continue;
            }
            
            // Inactivate employee license
            License__c empToInactivate = new License__c();
            empToInactivate.Id = al.EmployeeLicense__c;
            empToInactivate.ActiveInactive__c = 'Inactive';
            empToInactivate.Status__c = STATUS_C;
            employeesToInactivate.add(empToInactivate);
            
            // Create INAC History record
            Date employmentEndDate = al.EndDate__c != null ? al.EndDate__c : Date.today();
            
            LicenseHistory__c history = new LicenseHistory__c();
            history.License__c = al.EmployeeLicense__c;
            history.TransactionType__c = 'I - INACTIVE';
            history.Remarks__c = 'Employee Lost Employer';
            history.EffectiveDate__c = employmentEndDate;
            history.LicensePeriod__c = al.EmployeeLicense__r.LicenseHistoryLicensePeriod__c;
            historyToCreate.add(history);
        }
    }
    
    /**
     * Get associated licenses for entities that lost their entity status
     */
    private Map<Id, List<AssociatedLicense__c>> getAssociatedLicensesForEntities(Set<Id> entityIds) {
        Map<Id, List<AssociatedLicense__c>> result = new Map<Id, List<AssociatedLicense__c>>();
        
        if (entityIds.isEmpty()) {
            return result;
        }
        
        for (AssociatedLicense__c al : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c, EndDate__c,
                   EmployeeLicense__r.Id, EmployeeLicense__r.Status__c,
                   EmployeeLicense__r.ActiveInactive__c, EmployeeLicense__r.LicenseHistoryLicensePeriod__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :entityIds
              AND EmploymentStatus__c = 'Employed'
              AND (EndDate__c = null OR EndDate__c > TODAY)
        ]) {
            if (!result.containsKey(al.EntityLicense__c)) {
                result.put(al.EntityLicense__c, new List<AssociatedLicense__c>());
            }
            result.get(al.EntityLicense__c).add(al);
        }
        
        return result;
    }
    
    /**
     * Get set of license IDs that have active BICs
     */
    private Set<Id> getLicensesWithActiveBIC(Set<Id> licenseIds) {
        Set<Id> result = new Set<Id>();
        
        if (licenseIds.isEmpty()) {
            return result;
        }
        
        for (AssociatedLicense__c al : [
            SELECT EntityLicense__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :licenseIds
              AND Position__c = :POSITION_BIC
              AND EmploymentStatus__c = 'Employed'
              AND (EndDate__c = null OR EndDate__c > TODAY)
        ]) {
            result.add(al.EntityLicense__c);
        }
        
        return result;
    }
    
    /**
     * Get set of license IDs that have active RBO associations
     */
    private Set<Id> getLicensesWithActiveRBO(Set<Id> licenseIds) {
        Set<Id> result = new Set<Id>();
        
        if (licenseIds.isEmpty()) {
            return result;
        }
        
        for (AssociatedLicense__c al : [
            SELECT EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :licenseIds
              AND EntityLicenseType__c = 'RBO'
              AND EmploymentStatus__c = 'Employed'
              AND (EndDate__c = null OR EndDate__c > TODAY)
              AND EntityLicense__r.ActiveInactive__c = 'Active'
        ]) {
            result.add(al.EmployeeLicense__c);
        }
        
        return result;
    }
    
    /**
     * Build a NOPB Suspense__c record
     */
    private Suspense__c buildNOPBSuspenseRecord(License__c license) {
        Suspense__c suspense = new Suspense__c();
        suspense.License__c = license.Id;
        suspense.MaintenanceType__c = MAINTENANCE_TYPE_NOPB;
        
        Integer daysUntilForfeiture = 0;
        if (license.LicenseType__r?.NumberofDaysUntilAutoForfeiture__c != null) {
            daysUntilForfeiture = Integer.valueOf(license.LicenseType__r.NumberofDaysUntilAutoForfeiture__c);
        }
        
        Date principalLossDate = license.LossOfPrincipalRMEDate__c != null 
            ? license.LossOfPrincipalRMEDate__c 
            : Date.today();
        
        suspense.SuspenseDueDate__c = principalLossDate.addDays(daysUntilForfeiture + ADDITIONAL_DAYS);
        suspense.SuspenseStatus__c = license.LicenseType__r?.AutoForfeitureStatus__c;
        
        return suspense;
    }
    
    /**
     * Build a NBIC Suspense__c record
     */
    private Suspense__c buildNBICSuspenseRecord(License__c license) {
        Suspense__c suspense = new Suspense__c();
        suspense.License__c = license.Id;
        suspense.MaintenanceType__c = MAINTENANCE_TYPE_NBIC;
        
        Date bicLossDate = license.LossofBICDate__c != null 
            ? license.LossofBICDate__c 
            : Date.today();
        
        suspense.SuspenseDueDate__c = bicLossDate.addDays(ADDITIONAL_DAYS);
        suspense.SuspenseStatus__c = license.LicenseType__r?.AutoForfeitureStatus__c;
        
        return suspense;
    }
    
    /**
     * Insert suspenses with error handling
     */
    private void insertSuspenses(List<Suspense__c> suspenses) {
        Database.SaveResult[] results = Database.insert(suspenses, false);
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                if (suspenses[i].MaintenanceType__c == MAINTENANCE_TYPE_NOPB) {
                    totalNOPBSuspensesCreated++;
                } else if (suspenses[i].MaintenanceType__c == MAINTENANCE_TYPE_NBIC) {
                    totalNBICSuspensesCreated++;
                }
            } else {
                totalErrors++;
                String errorMsg = 'Suspense Insert - License: ' + suspenses[i].License__c + ' - ';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, 'RBEntityPrincipalBrokerSuspenseBatch error: ' + errorMsg);
            }
        }
    }
    
    /**
     * Update licenses to trigger notification generation
     */
    private void updateLicensesForNotification(List<License__c> licenses) {
        Database.SaveResult[] results = Database.update(licenses, false);
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                totalNotificationsTriggered++;
            } else {
                totalErrors++;
                String errorMsg = 'License Update (Notification) - License: ' + licenses[i].Id + ' - ';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, 'RBEntityPrincipalBrokerSuspenseBatch error: ' + errorMsg);
            }
        }
    }
    
    /**
     * Inactivate employee licenses
     */
    private void inactivateEmployeeLicenses(List<License__c> licenses) {
        Database.SaveResult[] results = Database.update(licenses, false);
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                totalEmployeesInactivated++;
            } else {
                totalErrors++;
                String errorMsg = 'Employee Inactivation - License: ' + licenses[i].Id + ' - ';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, 'RBEntityPrincipalBrokerSuspenseBatch error: ' + errorMsg);
            }
        }
    }
    
    /**
     * Create history records
     */
    private void createHistoryRecords(List<LicenseHistory__c> histories) {
        Database.SaveResult[] results = Database.insert(histories, false);
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                totalHistoryRecordsCreated++;
            } else {
                totalErrors++;
                String errorMsg = 'History Insert - License: ' + histories[i].License__c + ' - ';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, 'RBEntityPrincipalBrokerSuspenseBatch error: ' + errorMsg);
            }
        }
    }
    
    /**
     * Batch finish method - logs summary of batch execution
     */
    global void finish(Database.BatchableContext context) {
        String summary = String.format(
            'RBEntityPrincipalBrokerSuspenseBatch completed.\n' +
            '- Total Processed: {0}\n' +
            '- NOPB Suspenses Created: {1}\n' +
            '- NBIC Suspenses Created: {2}\n' +
            '- Notifications Triggered: {3}\n' +
            '- Employees Inactivated: {4}\n' +
            '- History Records Created: {5}\n' +
            '- Skipped (Has PB): {6}\n' +
            '- Skipped (Has BIC): {7}\n' +
            '- Skipped (No RBO): {8}\n' +
            '- Skipped (Not Inactive): {9}\n' +
            '- Errors: {10}',
            new List<Object>{
                totalProcessed,
                totalNOPBSuspensesCreated,
                totalNBICSuspensesCreated,
                totalNotificationsTriggered,
                totalEmployeesInactivated,
                totalHistoryRecordsCreated,
                totalSkippedHasPB,
                totalSkippedHasBIC,
                totalSkippedNoRBO,
                totalSkippedNotInactive,
                totalErrors
            }
        );
        
        System.debug(LoggingLevel.INFO, summary);
        
        if (!errorMessages.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Errors: ' + String.join(errorMessages, '\n'));
        }
    }
}