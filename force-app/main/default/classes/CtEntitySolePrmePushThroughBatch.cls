/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: ContractorRenewalPushThroughBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL09142022 - Created for case 00024031
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 09/14/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class CtEntitySolePrmePushThroughBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful{
    public Set<String> licenseTypeFilter = new Set<String>{
        'CT - RME',
        'CT - Sole Proprietor',
        'CT - Entity'
        };

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<License__c> licenses = (List<License__c>)scope;
        Map<Id, License__c> licensesMap = new Map<Id, License__c>(licenses);
        Map<Id, Id> ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap = new Map<Id, Id>();
        Map<Id, Id> ctEntityAssociatedEmployeeLicenseIdLicenseIdMap = new Map<Id, Id>();
        Map<Id, Id> ctRmeAssociatedEntityLicenseIdLicenseIdMap = new Map<Id, Id>();
        Set<Id> licenseIdsToComplete = new Set<Id>();
        Set<Id> licenseIdsWithoutAssoc = new Set<Id>();
        Set<Id> assocLicenseIds = new Set<Id>();

        for (License__c l : licenses) {
            if (l.LicenseTypeName__c == 'CT - Sole Proprietor') {
                if (l.NumberofActiveEmployees__c > 1) {
                    if (!l.AssociatedEmployee__r.isEmpty()) {
                        for (AssociatedLicense__c al : l.AssociatedEmployee__r) {
                            if (al.EmployeeLicense__c != null) {
                                ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.put(al.EmployeeLicense__c, l.Id);
                                assocLicenseIds.add(al.EmployeeLicense__c);
                            }
                        }
                    } else {
                        licenseIdsWithoutAssoc.add(l.Id);
                    }
                } else {
                    licenseIdsToComplete.add(l.Id);
                }
                continue;
            }

            if (l.LicenseTypeName__c == 'CT - Entity') {
                if (!l.AssociatedEmployee__r.isEmpty()) {
                    for (AssociatedLicense__c al : l.AssociatedEmployee__r) {
                        if (al.EmployeeLicense__c != null && (al.PositionStatus__c == 'P - PRINCIPAL')) {
                            ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.put(al.EmployeeLicense__c, l.Id);
                            assocLicenseIds.add(al.EmployeeLicense__c);
                        }
                    }

                    if (!ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.values().contains(l.Id)) {
                        licenseIdsWithoutAssoc.add(l.Id);
                    }
                } else {
                    licenseIdsWithoutAssoc.add(l.Id);
                }
                continue;
            }

            if (l.LicenseTypeName__c == 'CT - RME') {
                if (!l.AssociatedEntities__r.isEmpty()) {
                    for (AssociatedLicense__c al : l.AssociatedEntities__r) {
                        if (al.EntityLicense__c != null && (al.PositionStatus__c == 'P - PRINCIPAL')) {
                            ctRmeAssociatedEntityLicenseIdLicenseIdMap.put(al.EntityLicense__c, l.Id);
                            assocLicenseIds.add(al.EntityLicense__c);
                        }
                    }
                }
            }
        }

        //find associated applications
        List<Application__c> associatedApplications = [
            SELECT
                Id,
                CurrentLicense__c,
                LicensePeriodRNEW__c,
                LicenseType__r.PreviousLicensePeriod__c
            FROM Application__c
            WHERE CurrentLicense__c IN :assocLicenseIds
            AND Type__c = 'RNEW - Renewal'
            AND (Phase__c = 'D - Dependency Review' OR Phase__c = 'H - License Generation')
            AND (Status__c = 'D1 - Awaiting Dependency Review' OR Status__c = 'HC - Application Completed')
        ];

        //collect valid applications
        Set<Id> assocLicenseIdsWithValidApplication = new Set<Id>();

        for (Application__c a : associatedApplications) {
            if (a.LicensePeriodRNEW__c != a.LicenseType__r.PreviousLicensePeriod__c) {
                continue;
            }

            assocLicenseIdsWithValidApplication.add(a.CurrentLicense__c);

            if (ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.containsKey(a.CurrentLicense__c)) {
                licenseIdsToComplete.add(ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.get(a.CurrentLicense__c));
                continue;
            }

            if (ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.containsKey(a.CurrentLicense__c)) {
                licenseIdsToComplete.add(ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.get(a.CurrentLicense__c));
                continue;
            }

            if (ctRmeAssociatedEntityLicenseIdLicenseIdMap.containsKey(a.CurrentLicense__c)) {
                licenseIdsToComplete.add(ctRmeAssociatedEntityLicenseIdLicenseIdMap.get(a.CurrentLicense__c));
                continue;
            }
        }

        //find remaining licences for RM
        assocLicenseIds.removeAll(assocLicenseIdsWithValidApplication);
        for (Id i : assocLicenseIds) {
            if (ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.containsKey(i) &&
                !licenseIdsToComplete.contains(ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.get(i))) {
                licenseIdsWithoutAssoc.add(ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.get(i));
                continue;
            }

            if (ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.containsKey(i) &&
                !licenseIdsToComplete.contains(ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.get(i))) {
                licenseIdsWithoutAssoc.add(ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.get(i));
                continue;
            }

            if (ctRmeAssociatedEntityLicenseIdLicenseIdMap.containsKey(i) &&
                !licenseIdsToComplete.contains(ctRmeAssociatedEntityLicenseIdLicenseIdMap.get(i))) {
                licenseIdsWithoutAssoc.add(ctRmeAssociatedEntityLicenseIdLicenseIdMap.get(i));
                continue;
            }
        }


        List<License__c> licensesToUpdate = new List<License__c>();
        for (Id licId : licenseIdsWithoutAssoc) {
            License__c l = new License__c();
            l.Id = licId;
            l.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
            licensesToUpdate.add(l);
        }

        if (!licenseIdsToComplete.isEmpty()) {
            List<Application__c> applicationsToUpdate = new List<Application__c>();
            //find applications to update
            List<Application__c> applications = [
                SELECT
                    Id,
                    LicensePeriodRNEW__c,
                    LicenseType__r.PreviousLicensePeriod__c
                FROM Application__c
                WHERE CurrentLicense__c IN :licenseIdsToComplete
                AND Type__c = 'RNEW - Renewal'
            ];

            for (Application__c a : applications) {
                if (a.LicensePeriodRNEW__c != a.LicenseType__r.PreviousLicensePeriod__c) {
                    continue;
                }

                a.Phase__c = 'H - License Generation';
                a.Status__c = 'HC - Application Completed';
                applicationsToUpdate.add(a);
            }

            Database.update(applicationsToUpdate, false);

            for (Id licId : licenseIdsToComplete) {
                License__c l = new License__c();
                l.Id = licId;
                l.Status__c = 'C - Current, Valid & In Good Standing';
                l.EffectiveExpireDate__c = licensesMap.get(licId).LicenseType__r.LicenseTypeExpireDate__c;
                licensesToUpdate.add(l);
            }
        }

        Database.update(licensesToUpdate, false);
    }

    public void finish(Database.BatchableContext bc) {
        BatchJobFinishNotification notification = new BatchJobFinishNotification('CT Entity/Sole/PRME Push Through');
        notification.sendEmail();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String associatedLicenseEntitiesSubQuery = '(SELECT Id, EmployeeLicense__c, PositionStatus__c ' +
            'FROM AssociatedEmployee__r ' +
            'WHERE EmploymentStatus__c = \'Employed\' ' +
            'AND (EndDate__c = null OR EndDate__c > TODAY) ' +
            'AND (EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\' ' +
            'OR EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\') ' +
            'AND EmployeeActiveInactive__c= \'Active\') ';

        String associatedLicenseEmployeesSubQuery = '(SELECT Id, EntityLicense__c, PositionStatus__c ' +
            'FROM AssociatedEntities__r ' +
            'WHERE EmploymentStatus__c = \'Employed\'' +
            'AND (EndDate__c = null OR EndDate__c > TODAY) ' +
            'AND (EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\' ' +
            'OR EntityLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\') ' +
            'AND EntityActiveInactive__c = \'Active\') ';

        return Database.getQueryLocator('SELECT Id, Name, ' +
            'NumberofActiveEmployees__c, ' +
            'LicenseType__r.NextLicensePeriodExpireDate__c, ' +
            'LicenseType__r.LicenseTypeExpireDate__c, ' +
            'LicenseTypeName__c, ' +
            associatedLicenseEmployeesSubQuery + ', ' +
            associatedLicenseEntitiesSubQuery +
            'FROM License__c ' +
            'WHERE LicenseTypeName__c IN :licenseTypeFilter ' +
            'AND Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' +
            'AND ThisLicenseRenewed__c = true');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CtEntitySolePrmePushThroughBatch());
    }
}