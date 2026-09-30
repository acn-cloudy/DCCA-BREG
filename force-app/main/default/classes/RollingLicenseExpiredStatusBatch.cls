/**
 * VPVL-219: Daily batch to set expired rolling-license-period licenses to terminated status.
 *
 * Criteria:
 * - LicenseType__c.RollingLicensePeriod__c = true
 * - License__c.EffectiveExpireDate__c < TODAY
 * - License__c.Status__c IN (C, CM, Z, ZM) only
 *
 * Action: Set License__c.Status__c = "F - Terminated; Needs to Reapply"
 *
 * Schedule (daily): System.schedule('Rolling License Expired Status', '0 0 1 * * ?', new RollingLicenseExpiredStatusBatch());
 * Manual run: Database.executeBatch(new RollingLicenseExpiredStatusBatch(), 200);
 */
public with sharing class RollingLicenseExpiredStatusBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {

    private static final String TARGET_STATUS = 'F - Terminated; Needs to Reapply';

    /** Statuses that are eligible to be updated (C, CM, Z, ZM only). */
    private static final Set<String> ELIGIBLE_STATUSES = new Set<String>{
        'C - Current, Valid & In Good Standing',
        'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
        'Z - Current & Valid, But Subject To Disciplinary Requirement',
        'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
    };

    private static final Integer DEFAULT_BATCH_SIZE = 200;

    private Integer processedCount = 0;
    private Integer updatedCount = 0;
    private Integer errorCount = 0;

    public void execute(SchedulableContext context) {
        Database.executeBatch(new RollingLicenseExpiredStatusBatch(), DEFAULT_BATCH_SIZE);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, EffectiveExpireDate__c, LicenseType__c, LicenseType__r.RollingLicensePeriod__c
            FROM License__c
            WHERE LicenseType__r.RollingLicensePeriod__c = true
              AND EffectiveExpireDate__c < TODAY
              AND Status__c IN :ELIGIBLE_STATUSES
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        List<License__c> toUpdate = new List<License__c>();

        for (SObject so : scope) {
            License__c lic = (License__c) so;
            processedCount++;
            if (ELIGIBLE_STATUSES.contains(lic.Status__c)) {
                lic.Status__c = TARGET_STATUS;
                toUpdate.add(lic);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
                updatedCount += toUpdate.size();
            } catch (Exception e) {
                errorCount += toUpdate.size();
                System.debug(LoggingLevel.ERROR, 'RollingLicenseExpiredStatusBatch update error: ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            'RollingLicenseExpiredStatusBatch completed. Processed: ' + processedCount +
            ', Updated: ' + updatedCount + ', Errors: ' + errorCount
        );
    }
}