/**
 * VPVL-13: Batch class to process NOPB and NBIC suspense records when their due date has passed.
 * 
 * This batch job runs daily and processes suspense records where:
 * - MaintenanceType__c = 'NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER' OR 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE'
 * - SuspenseDueDate__c < TODAY (due date has passed)
 * - Historical__c = false (not yet processed)
 * - Delete__c = false (not marked for deletion)
 * 
 * Processing Logic for NOPB:
 * 1. Inactivates the RB-Entity license and sets status to C
 * 2. Terminates all associated license records for the RB-Entity
 * 3. Inactivates all employee licenses associated with the RB-Entity
 * 4. Creates INAC History: Remarks = "Employer Lost Principal Broker"
 * 5. Deletes processed suspense records
 * 6. Creates notifications for licenses terminated
 * 
 * Processing Logic for NBIC:
 * 1. Terminates all RBO associated license records for the RB-Entity
 * 2. Inactivates all RBO licenses and sets status to C
 * 3. Creates INAC History: Remarks = "Employer Lost Broker-In-Charge"
 * 4. Deletes processed suspense records
 * 
 * Schedule Example:
 *   System.schedule('Suspense Due Date Processing Job', '0 30 0 * * ?', new SuspenseDueDateProcessingBatch());
 * 
 * Manual Execution:
 *   Database.executeBatch(new SuspenseDueDateProcessingBatch(), 50);
 * 
 * @author  Akanksha Reddy Anthireddygari
 * @created 2026-01-22
 * @ticket  VPVL-13
 */
global class SuspenseDueDateProcessingBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {
    
    // Constants
    private static final String MAINTENANCE_TYPE_NOPB = 'NOPB - REAL ESTATE FIRM WITHOUT PRINCIPAL BROKER';
    private static final String MAINTENANCE_TYPE_NBIC = 'NBIC - REAL ESTATE FIRM WITHOUT BROKER-IN-CHARGE';
    private static final Integer DEFAULT_BATCH_SIZE = 50;
    private static final Set<String> VALID_MAINTENANCE_TYPES = new Set<String>{
        MAINTENANCE_TYPE_NOPB,
        MAINTENANCE_TYPE_NBIC
    };
    
    // Stateful tracking variables
    private Integer totalSuspensesProcessed = 0;
    private Integer totalNOPBProcessed = 0;
    private Integer totalNBICProcessed = 0;
    private Integer totalEntitiesInactivated = 0;
    private Integer totalRBOLicensesInactivated = 0;
    private Integer totalAssociatedLicensesInactivated = 0;
    private Integer totalAssociatedLicenseRecordsTerminated = 0;
    private Integer totalHistoryRecordsCreated = 0;
    private Integer totalNotificationsCreated = 0;
    private Integer totalSuspensesDeleted = 0;
    private Integer totalErrors = 0;
    private List<String> errorMessages = new List<String>();
    
    /**
     * Schedulable execute method - kicks off the batch job
     * @param context Schedulable context
     */
    public void execute(SchedulableContext context) {
        Database.executeBatch(new SuspenseDueDateProcessingBatch(), DEFAULT_BATCH_SIZE);
    }
    
    /**
     * Batch start method - returns query locator for NOPB and NBIC suspense records with due date passed
     * @param context Batch context
     * @return QueryLocator for NOPB and NBIC suspenses with due date passed
     */
    global Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   License__c,
                   License__r.Id,
                   License__r.Name,
                   License__r.LicenseTypeName__c,
                   License__r.ActiveInactive__c,
                   License__r.PB_Counter__c,
                   MaintenanceType__c,
                   SuspenseDueDate__c,
                   Historical__c,
                   Delete__c
            FROM Suspense__c
            WHERE MaintenanceType__c IN :VALID_MAINTENANCE_TYPES
              AND SuspenseDueDate__c < TODAY
              AND Historical__c = false
              AND Delete__c = false
            ORDER BY SuspenseDueDate__c ASC
        ]);
    }
    
    /**
     * Batch execute method - processes each batch of suspense records
     * @param context Batch context
     * @param scope List of Suspense__c records to process
     */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Suspense__c> suspenses = (List<Suspense__c>) scope;
        
        if (suspenses.isEmpty()) {
            return;
        }
        
        // Separate NOPB and NBIC suspenses
        Map<Id, Suspense__c> nopbSuspensesByEntityId = new Map<Id, Suspense__c>();
        Map<Id, Suspense__c> nbicSuspensesByEntityId = new Map<Id, Suspense__c>();
        
        for (Suspense__c suspense : suspenses) {
            if (suspense.License__c == null || 
                suspense.License__r.LicenseTypeName__c != 'RB - Entity') {
                continue;
            }
            
            if (suspense.MaintenanceType__c == MAINTENANCE_TYPE_NOPB && 
                suspense.License__r.PB_Counter__c == 0) {
                nopbSuspensesByEntityId.put(suspense.License__c, suspense);
            } else if (suspense.MaintenanceType__c == MAINTENANCE_TYPE_NBIC) {
                nbicSuspensesByEntityId.put(suspense.License__c, suspense);
            }
        }
        
        totalSuspensesProcessed += nopbSuspensesByEntityId.size() + nbicSuspensesByEntityId.size();
        totalNOPBProcessed += nopbSuspensesByEntityId.size();
        totalNBICProcessed += nbicSuspensesByEntityId.size();
        
        // Process NOPB suspenses
        if (!nopbSuspensesByEntityId.isEmpty()) {
            processNOPBSuspenses(nopbSuspensesByEntityId);
        }
        
        // Process NBIC suspenses
        if (!nbicSuspensesByEntityId.isEmpty()) {
            processNBICSuspenses(nbicSuspensesByEntityId);
        }
    }
    
    /**
     * Process NOPB suspenses - inactivate entity and all associated licenses
     * @param suspensesByEntityId Map of entity license ID to NOPB suspense
     */
    private void processNOPBSuspenses(Map<Id, Suspense__c> suspensesByEntityId) {
        Set<Id> entityLicenseIds = suspensesByEntityId.keySet();
        List<Suspense__c> suspensesToDelete = new List<Suspense__c>();
        for (Suspense__c susp : suspensesByEntityId.values()) {
            suspensesToDelete.add(new Suspense__c(Id = susp.Id));
        }
        // Inactivate RB-Entity licenses and update status to C
        List<License__c> entityLicensesToUpdate = new List<License__c>();
        for (Id entityId : entityLicenseIds) {
            License__c entityToUpdate = new License__c();
            entityToUpdate.Id = entityId;
            entityToUpdate.ActiveInactive__c = 'Inactive';
            entityToUpdate.Status__c = 'C - Current, Valid & In Good Standing';
            entityLicensesToUpdate.add(entityToUpdate);
        }

        // Query associated licenses for the entities
        List<AssociatedLicense__c> associatedLicenses = [
            SELECT Id, 
                   EntityLicense__c,
                   EmployeeLicense__c,
                   EmployeeLicense__r.Id,
                   EmployeeLicense__r.ActiveInactive__c,
                   EmployeeLicense__r.LicenseHistoryLicensePeriod__c,
                   EmployeeLicense__r.PVL_Portal_User__r.Email__c,
                   EmploymentStatus__c,
                   EndDate__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :entityLicenseIds
              AND EmploymentStatus__c = 'Employed'
              AND (EndDate__c = null OR EndDate__c > TODAY)
        ];
        
        // Prepare collections for DML
        List<AssociatedLicense__c> associatedLicenseRecordsToTerminate = new List<AssociatedLicense__c>();
        Map<Id, License__c> employeeLicensesToInactivate = new Map<Id, License__c>();
        List<LicenseHistory__c> historyRecordsToCreate = new List<LicenseHistory__c>();
        List<Notification__c> notificationsToCreate = new List<Notification__c>();
        
        for (AssociatedLicense__c assocLic : associatedLicenses) {
            Date employmentEndDate = assocLic.EndDate__c != null ? assocLic.EndDate__c : Date.today();

            // Terminate the associated license record
            AssociatedLicense__c alToTerminate = new AssociatedLicense__c();
            alToTerminate.Id = assocLic.Id;
            alToTerminate.EmploymentStatus__c = 'Terminated';
            alToTerminate.EndDate__c = employmentEndDate;
            alToTerminate.TerminationReason__c = 'PLOS - TERMINATION DUE TO PRINCIPAL';
            associatedLicenseRecordsToTerminate.add(alToTerminate);
            
            // Inactivate the employee license
            if (assocLic.EmployeeLicense__c != null && 
                assocLic.EmployeeLicense__r.ActiveInactive__c == 'Active') {
                
                License__c empLicToInactivate = new License__c();
                empLicToInactivate.Id = assocLic.EmployeeLicense__c;
                empLicToInactivate.ActiveInactive__c = 'Inactive';
                empLicToInactivate.Status__c = 'C - Current, Valid & In Good Standing';
                employeeLicensesToInactivate.put(assocLic.EmployeeLicense__c, empLicToInactivate);

                LicenseHistory__c history = new LicenseHistory__c();
                history.License__c = assocLic.EmployeeLicense__c;
                history.TransactionType__c = 'I - INACTIVE';
                history.Remarks__c = 'Employer Lost Principal Broker';
                history.EffectiveDate__c = employmentEndDate;
                history.LicensePeriod__c = assocLic.EmployeeLicense__r.LicenseHistoryLicensePeriod__c;
                historyRecordsToCreate.add(history);

                Notification__c notification = new Notification__c();
                notification.License__c = assocLic.EmployeeLicense__c;
                notification.RecordId__c = assocLic.EmployeeLicense__c;
                notification.DocGeneratorSettings__c = 'License Placed on Inactive Status';
                notification.DocumentTemplateName__c = 'License Placed on Inactive Status';
                notification.Scheduled__c = true;
                notification.SendToPrinter__c = true;
                notification.Fire__c = true;
                notification.Status__c = 'Scheduled';
                notification.PrintStatus__c = 'Ready for Print';
                notificationsToCreate.add(notification);
            }
        }
        
        // Perform DML operations
        // 1. Inactivate entity licenses
        if (!entityLicensesToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(entityLicensesToUpdate, false);
            logErrors(results, 'Entity License Inactivation');
            totalEntitiesInactivated += countSuccesses(results);
        }

        // 2. Terminate associated license records
        if (!associatedLicenseRecordsToTerminate.isEmpty()) {
            Database.SaveResult[] results = Database.update(associatedLicenseRecordsToTerminate, false);
            logErrors(results, 'AssociatedLicense Termination');
            totalAssociatedLicenseRecordsTerminated += countSuccesses(results);
        }
        
        // 3. Inactivate employee licenses
        if (!employeeLicensesToInactivate.isEmpty()) {
            Database.SaveResult[] results = Database.update(employeeLicensesToInactivate.values(), false);
            logErrors(results, 'Employee License Inactivation');
            totalAssociatedLicensesInactivated += countSuccesses(results);
        }

        // 4. Create history records
        if (!historyRecordsToCreate.isEmpty()) {
            Database.SaveResult[] results = Database.insert(historyRecordsToCreate, false);
            logErrors(results, 'License History Creation');
            totalHistoryRecordsCreated += countSuccesses(results);
        }

        // 5. Create notifications
        if (!notificationsToCreate.isEmpty()) {
            Database.SaveResult[] results = Database.insert(notificationsToCreate, false);
            logErrors(results, 'Notification Creation');
            totalNotificationsCreated += countSuccesses(results);
        }

        // 6. Delete suspenses
        if (!suspensesToDelete.isEmpty()) {
            Database.DeleteResult[] results = Database.delete(suspensesToDelete, false);
            logDeleteErrors(results, 'NOPB Suspense Delete');
            totalSuspensesDeleted += countDeleteSuccesses(results);
        }
    }
    
    /**
     * Process NBIC suspenses - inactivate RBO licenses only
     * @param suspensesByEntityId Map of entity license ID to NBIC suspense
     */
    private void processNBICSuspenses(Map<Id, Suspense__c> suspensesByEntityId) {
        Set<Id> entityLicenseIds = suspensesByEntityId.keySet();
        List<Suspense__c> suspensesToDelete = new List<Suspense__c>();
        for (Suspense__c susp : suspensesByEntityId.values()) {
            suspensesToDelete.add(new Suspense__c(Id = susp.Id));
        }
        
        // Query RBO associated licenses for the entities
        // RBO licenses are where EmployeeLicense__c = RB-Entity Id and EntityLicenseType__c = 'RBO'
        List<AssociatedLicense__c> rboAssociatedLicenses = [
            SELECT Id, 
                   EmployeeLicense__c,
                   EntityLicense__c,
                   EntityLicense__r.Id,
                   EntityLicense__r.ActiveInactive__c,
                   EntityLicense__r.LicenseHistoryLicensePeriod__c,
                   EmploymentStatus__c,
                   EndDate__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :entityLicenseIds
              AND EntityLicenseType__c = 'RBO'
              AND EmploymentStatus__c = 'Employed'
              AND (EndDate__c = null OR EndDate__c > TODAY)
              AND EntityLicense__r.ActiveInactive__c = 'Active'
        ];
        
        if (rboAssociatedLicenses.isEmpty()) {
            return;
        }
        
        // Prepare collections for DML
        List<AssociatedLicense__c> rboRecordsToTerminate = new List<AssociatedLicense__c>();
        Map<Id, License__c> rboLicensesToInactivate = new Map<Id, License__c>();
        List<LicenseHistory__c> historyRecordsToCreate = new List<LicenseHistory__c>();
        
        for (AssociatedLicense__c assocLic : rboAssociatedLicenses) {
            Date employmentEndDate = assocLic.EndDate__c != null ? assocLic.EndDate__c : Date.today();
            
            // Terminate the RBO associated license record
            AssociatedLicense__c alToTerminate = new AssociatedLicense__c();
            alToTerminate.Id = assocLic.Id;
            alToTerminate.EmploymentStatus__c = 'Terminated';
            alToTerminate.EndDate__c = employmentEndDate;
            alToTerminate.TerminationReason__c = 'NBIC - TERMINATION DUE TO BROKER-IN-CHARGE';
            rboRecordsToTerminate.add(alToTerminate);
            
            // Inactivate the RBO license
            if (assocLic.EntityLicense__c != null && 
                assocLic.EntityLicense__r.ActiveInactive__c == 'Active') {
                
                License__c rboLicToInactivate = new License__c();
                rboLicToInactivate.Id = assocLic.EntityLicense__c;
                rboLicToInactivate.ActiveInactive__c = 'Inactive';
                rboLicToInactivate.Status__c = 'C - Current, Valid & In Good Standing';
                rboLicensesToInactivate.put(assocLic.EntityLicense__c, rboLicToInactivate);
                
                // Create INAC History for RBO license
                LicenseHistory__c history = new LicenseHistory__c();
                history.License__c = assocLic.EntityLicense__c;
                history.TransactionType__c = 'I - INACTIVE';
                history.Remarks__c = 'Employer Lost Broker-In-Charge';
                history.EffectiveDate__c = employmentEndDate;
                history.LicensePeriod__c = assocLic.EntityLicense__r.LicenseHistoryLicensePeriod__c;
                historyRecordsToCreate.add(history);
            }
        }
        
        // Perform DML operations
        // 1. Terminate RBO associated license records
        if (!rboRecordsToTerminate.isEmpty()) {
            Database.SaveResult[] results = Database.update(rboRecordsToTerminate, false);
            logErrors(results, 'RBO AssociatedLicense Termination');
            totalAssociatedLicenseRecordsTerminated += countSuccesses(results);
        }
        
        // 2. Inactivate RBO licenses
        if (!rboLicensesToInactivate.isEmpty()) {
            Database.SaveResult[] results = Database.update(rboLicensesToInactivate.values(), false);
            logErrors(results, 'RBO License Inactivation');
            totalRBOLicensesInactivated += countSuccesses(results);
        }
        
        // 3. Create history records
        if (!historyRecordsToCreate.isEmpty()) {
            Database.SaveResult[] results = Database.insert(historyRecordsToCreate, false);
            logErrors(results, 'RBO License History Creation');
            totalHistoryRecordsCreated += countSuccesses(results);
        }
        
        // 4. Delete NBIC suspenses
        if (!suspensesToDelete.isEmpty()) {
            Database.DeleteResult[] results = Database.delete(suspensesToDelete, false);
            logDeleteErrors(results, 'NBIC Suspense Delete');
            totalSuspensesDeleted += countDeleteSuccesses(results);
        }
    }
    
    /**
     * Log errors from DML results
     */
    private void logErrors(Database.SaveResult[] results, String operationType) {
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                totalErrors++;
                String errorMsg = operationType + ' Error: ';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, 'SuspenseDueDateProcessingBatch: ' + errorMsg);
            }
        }
    }
    
    /**
     * Count successful operations from results
     */
    private Integer countSuccesses(Database.SaveResult[] results) {
        Integer count = 0;
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                count++;
            }
        }
        return count;
    }

    private void logDeleteErrors(Database.DeleteResult[] results, String operationType) {
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                totalErrors++;
                String errorMsg = operationType + ' Error: ';
                for (Database.Error err : results[i].getErrors()) {
                    errorMsg += err.getMessage() + '; ';
                }
                errorMessages.add(errorMsg);
                System.debug(LoggingLevel.ERROR, 'SuspenseDueDateProcessingBatch: ' + errorMsg);
            }
        }
    }

    private Integer countDeleteSuccesses(Database.DeleteResult[] results) {
        Integer count = 0;
        for (Database.DeleteResult result : results) {
            if (result.isSuccess()) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * Batch finish method - logs summary of batch execution
     * @param context Batch context
     */
    global void finish(Database.BatchableContext context) {
        String summary = String.format(
            'SuspenseDueDateProcessingBatch completed.\n' +
            '- Total Suspenses Processed: {0}\n' +
            '  - NOPB Suspenses: {1}\n' +
            '  - NBIC Suspenses: {2}\n' +
            '- RB-Entity Licenses Inactivated: {3}\n' +
            '- RBO Licenses Inactivated: {4}\n' +
            '- Employee Licenses Inactivated: {5}\n' +
            '- Associated License Records Terminated: {6}\n' +
            '- History Records Created: {7}\n' +
            '- Notifications Created: {8}\n' +
            '- Suspenses Deleted: {9}\n' +
            '- Errors: {10}',
            new List<Object>{
                totalSuspensesProcessed,
                totalNOPBProcessed,
                totalNBICProcessed,
                totalEntitiesInactivated,
                totalRBOLicensesInactivated,
                totalAssociatedLicensesInactivated,
                totalAssociatedLicenseRecordsTerminated,
                totalHistoryRecordsCreated,
                totalNotificationsCreated,
                totalSuspensesDeleted,
                totalErrors
            }
        );
        
        System.debug(LoggingLevel.INFO, summary);
        
        if (!errorMessages.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Errors: ' + String.join(errorMessages, '\n'));
        }
    }
}