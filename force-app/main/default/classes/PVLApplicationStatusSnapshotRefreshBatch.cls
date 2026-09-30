public with sharing class PVLApplicationStatusSnapshotRefreshBatch implements Database.Batchable<SObject> {
    public static final Integer DEFAULT_BATCH_SIZE = 100;

    private Set<Id> applicationIds;

    public PVLApplicationStatusSnapshotRefreshBatch() {
        this.applicationIds = null;
    }

    public PVLApplicationStatusSnapshotRefreshBatch(Set<Id> applicationIds) {
        this.applicationIds = applicationIds == null ? null : new Set<Id>(applicationIds);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        if (applicationIds != null) {
            return Database.getQueryLocator([
                SELECT
                    Id,
                    Status__c,
                    Phase__c,
                    Type__c,
                    OnlineApplicationType__c,
                    ApplicationReceivedDate__c,
                    A3StartDate__c,
                    DeficiencyDueDate__c,
                    ApplicationRespondbyDate__c,
                    CreatedDate,
                    LastModifiedDate,
                    SystemModstamp,
                    CurrentLicense__c,
                    CurrentLicense__r.Status__c,
                    CurrentLicense__r.SystemModstamp,
                    CurrentLicense__r.EffectiveExpireDate__c,
                    CurrentLicense__r.ForfeitureDate__c,
                    CurrentLicense__r.ThisLicenseRenewed__c,
                    DependentLicense__c,
                    DependentLicense__r.Status__c,
                    DependentLicense__r.SystemModstamp,
                    DependentLicense2__c,
                    DependentLicense2__r.Status__c,
                    DependentLicense2__r.SystemModstamp,
                    DependentApplication__c,
                    DependentApplication__r.Status__c,
                    DependentApplication__r.SystemModstamp,
                    DependencyRequired__c,
                    LicenseType__r.Name,
                    LicenseType__r.DependencyRequired__c,
                    LicenseType__r.X2ndDependencyRequired__c,
                    LicenseType__r.RequiresInsurance__c
                FROM Application__c
                WHERE Id IN :applicationIds
            ]);
        }

        return Database.getQueryLocator([
            SELECT
                Id,
                Status__c,
                Phase__c,
                Type__c,
                OnlineApplicationType__c,
                ApplicationReceivedDate__c,
                A3StartDate__c,
                DeficiencyDueDate__c,
                ApplicationRespondbyDate__c,
                CreatedDate,
                LastModifiedDate,
                SystemModstamp,
                CurrentLicense__c,
                CurrentLicense__r.Status__c,
                CurrentLicense__r.SystemModstamp,
                CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.ForfeitureDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c,
                DependentLicense__c,
                DependentLicense__r.Status__c,
                DependentLicense__r.SystemModstamp,
                DependentLicense2__c,
                DependentLicense2__r.Status__c,
                DependentLicense2__r.SystemModstamp,
                DependentApplication__c,
                DependentApplication__r.Status__c,
                DependentApplication__r.SystemModstamp,
                DependencyRequired__c,
                LicenseType__r.Name,
                LicenseType__r.DependencyRequired__c,
                LicenseType__r.X2ndDependencyRequired__c,
                LicenseType__r.RequiresInsurance__c
            FROM Application__c
            WHERE Status__c NOT IN :PVLApplicationStatusSelector.CLOSED_APPLICATION_STATUSES
        ]);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Application__c> applications = new List<Application__c>();
        for (SObject record : scope) {
            applications.add((Application__c) record);
        }
        PVLApplicationStatusFreshnessService.refreshSnapshots(applications);
    }

    public void finish(Database.BatchableContext context) {}
}