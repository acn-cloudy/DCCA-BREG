/*
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * checkLicenseStatus:Find and set the status of Licenses with License Types Start of RenewalPerios = Today
 * Covered by LicenseTerminationTest
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Initial implementation
 *
 * @author Iene Cahilo - PacificPointCorp
 *
 * @created PacPoint-IC071819 - Created for PVL Phase 1
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Changes
 * Review Irene's Code - Chris Z
 * Logic update - Chris L 10/30/2020 @case 00011612
 * Logic update - Chris L 06/22/2022 @case 00022198
 * Logic update - Chris L 09/19/2022 @case 00024092
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 *
 * @See case 00011612
 */

global class LicenseTermination implements schedulable, Database.Batchable<SObject> {
    /*
     * variables
     */
    public String query ;

    public Set<String> statusFilter = new Set<String>{'D - Forfeited; Needs to Restore',
                                                      'DM - Forfeited/Maintenance Requirement Due',
                                                      'ZD - Forfeited Disciplined License; Needs To Restore'};

    global LicenseTermination() {
        query = 'SELECT Id,' +
                'Status__c,' +
                'RestorationDeadline__c, ' +
                'LicenseType__c, ' +
                'LicenseType__r.RenewalWindowInDays__c, ' +
                'LicenseType__r.RestorationDeadline__c, ' +
                'LicenseType__r.StatusDuetoNonRestore__c, ' +
                '(SELECT Id,Status__c FROM LicenseClassifications__r) '+
                'FROM License__c ' +
                'WHERE Status__c IN :statusFilter ' +
                'AND RestorationDeadline__c < TODAY ' +
                'AND LicenseType__r.Status__c = \'Active\' ' +
                'AND LicenseType__r.StatusDuetoNonRestore__c <> null';
    }

    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>) scope;
        Map<Id, License__c> recordMap = new Map<Id, License__c>(licenses);
        List<License__c> recordsToUpdate = new List<License__c>();
        LIst<LicenseClassification__c> licenseClassificationsToUpdate = new List<LicenseClassification__c>();
        List<Application__c> activeApplicationRestore = new List<Application__c>([
                SELECT
                        Id,
                        CurrentLicense__c
                FROM Application__c
                WHERE CurrentLicense__c IN :recordMap.keySet()
                AND Type__c = 'RSTR - Restore - No A/I Status'
                AND Status__c <> 'HC - Application Completed'
        ]);

        Set<Id> licenseIdsWithActiveRstrApplications = new Set<Id>();

        for (Application__c a : activeApplicationRestore) {
            licenseIdsWithActiveRstrApplications.add(a.CurrentLicense__c);
        }

        List<LicenseHistory__c> licenseHistoryRecordsToCreate = new List<LicenseHistory__c>();

        for (License__c lc : licenses) {
            Integer renewalDays = (Integer)lc.LicenseType__r.RenewalWindowInDays__c;
            Date dateFilter = lc.RestorationDeadline__c.addDays(renewalDays == null ? 0 : renewalDays);

            if (licenseIdsWithActiveRstrApplications.contains(lc.Id) && dateFilter>Date.today()) {
                continue;
            }

            lc.TerminationDate__c = lc.RestorationDeadline__c;
            lc.ExcludefromHistoryProcessing__c = true;
            if (lc.Status__c == 'D - Forfeited; Needs to Restore') {
                lc.Status__c = lc.LicenseType__r.StatusDuetoNonRestore__c;
            } else {
                lc.Status__c = 'FM - Terminated/Maintenance Requirement Due; Needs To Reapply';
            }

            for (LicenseClassification__c classification : lc.LicenseClassifications__r) {
                if (classification.Status__c == 'D - Class No Longer Active (License Delinquent)') {
                    classification.Status__c = 'F - Class No Longer Active (License Forfeited)';
                    licenseClassificationsToUpdate.add(classification);
                }
            }

            recordsToUpdate.add(lc);

            LicenseHistory__c lh = new LicenseHistory__c();
            lh.License__c = lc.Id;
            lh.TransactionType__c = 'FORF - FORFEITED';
            lh.EffectiveDate__c = lc.RestorationDeadline__c;

            licenseHistoryRecordsToCreate.add(lh);
        }

        update licenses;
        update licenseClassificationsToUpdate;
        insert licenseHistoryRecordsToCreate;
    }

    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new LicenseTermination(), 100);
    }

    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {
        BatchJobFinishNotification notification = new BatchJobFinishNotification('Terminate Non Restore Licenses');
        notification.sendEmail();
    }
}