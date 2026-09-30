/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: CtRmePushThroughBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10192022 - Created for case 00024031
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/19/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class CtRmePushThroughBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {

    public void execute(Database.BatchableContext param1, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>)scope;
        Map<Id, License__c> licensesMap = new Map<Id, License__c>(licenses);
        List<Application__c> applicationsToUpdate = new List<Application__c>();
        List<License__c> licensesToUpdate = new List<License__c>();
        Set<Id> licenseIdsToComplete = new Set<Id>();

        for (License__c l : licenses) {
            if (l.AssociatedEntities__r.isEmpty()) {
                l.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
                licensesToUpdate.add(l);
                continue;
            }

            licenseIdsToComplete.add(l.Id);
        }

        //find associated applications
        List<Application__c> associatedApplications = [
            SELECT
                Id,
                CurrentLicense__c,
                LicensePeriodRNEW__c,
                LicenseType__r.PreviousLicensePeriod__c
            FROM Application__c
            WHERE CurrentLicense__c IN :licenseIdsToComplete
            AND LicensePeriodRNEW__c != null
            AND Status__c = 'D1 - Awaiting Dependency Review'
            AND Type__c = 'RNEW - Renewal'
        ];

        for (Application__c a : associatedApplications) {
            if (a.LicensePeriodRNEW__c != a.LicenseType__r.PreviousLicensePeriod__c) {
                continue;
            }

            a.Phase__c = 'H - License Generation';
            a.Status__c = 'HC - Application Completed';
            applicationsToUpdate.add(a);

            License__c li = licensesMap.get(a.CurrentLicense__c);
            li.Status__c = 'C - Current, Valid & In Good Standing';
            li.EffectiveExpireDate__c = li.LicenseType__r.LicenseTypeExpireDate__c;
            licensesToUpdate.add(li);
        }

        Database.update(applicationsToUpdate, false);
        Database.update(licensesToUpdate, false);
    }

    public void finish(Database.BatchableContext bc) {
        BatchJobFinishNotification notification = new BatchJobFinishNotification('CT RME Push Through');
        notification.sendEmail();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String associatedLicenseEmployeesSubQuery = '(' +
            'SELECT Id, ' +
            'EntityLicense__c ' +
            'FROM AssociatedEntities__r ' +
            'WHERE EmploymentStatus__c = \'Employed\' ' +
            'AND EntityLicense__r.Status__c =\'C - Current, Valid & In Good Standing\' ' +
            'AND EntityLicense__r.ThisLicenseRenewed__c = true ' +
            'AND (EndDate__c = null OR EndDate__c > TODAY) ' +
            'AND PositionStatus__c = null ' +
            'AND EntityActiveInactive__c = \'Active\') ';

        return Database.getQueryLocator('SELECT Id, ' +
            'NumberofActiveEmployees__c, ' +
            'LicenseType__r.NextLicensePeriodExpireDate__c, ' +
            'LicenseType__r.LicenseTypeExpireDate__c, ' +
            'LicenseTypeName__c, ' +
            associatedLicenseEmployeesSubQuery +
            'FROM License__c ' +
            'WHERE LicenseTypeName__c =\'CT - RME\' ' +
            'AND Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' +
            'AND ThisLicenseRenewed__c = true');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CtRmePushThroughBatch());
    }
}