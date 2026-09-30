/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: ContractorRenewalPushThroughTest
 * -----------------------------------------------------------------------------------
 * PacPoint-EA20240718 - Created for case 00036531
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 07/18/2024
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public  class ContractorRenewalPushThrough implements Schedulable, Database.Batchable<SObject>, Database.Stateful{
    public Boolean secondRun = false;

    public ContractorRenewalPushThrough(){
        secondRun = false;
    }

    public ContractorRenewalPushThrough(Boolean nextRun){
        secondRun = nextRun;
    }

    public Set<String> licenseTypeFilter = new Set<String>{
        'CT - RME',
        'CT - Sole Proprietor',
        'CT - Entity'
        };

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        turnOffAppRenewFlow();
        ApplicationHandler.bypassInsuranceValidation = true;
        if(!secondRun) processFirstRun(scope);
        if(secondRun) processSecondRun(scope);
        ApplicationHandler.bypassInsuranceValidation = false;
        turnOnAppRenewFlow();
    }

    private static void turnOffAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = true;
        upsert orgSetting;
    }

    private static void turnOnAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = false;
        upsert orgSetting;
    }

    public void processFirstRun(List<SObject> scope){
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
                // if (l.NumberofActiveEmployees__c > 1) {
                //     if (!l.AssociatedEmployee__r.isEmpty()) {
                //         for (AssociatedLicense__c al : l.AssociatedEmployee__r) {
                //             if (al.EmployeeLicense__c != null) {
                //                 ctSolePropAssociatedEmployeeLicenseIdLicenseIdMap.put(al.EmployeeLicense__c, l.Id);
                //                 assocLicenseIds.add(al.EmployeeLicense__c);
                //             }
                //         }
                //     } else {
                //         licenseIdsWithoutAssoc.add(l.Id);
                //     }
                // } else {
                //     licenseIdsToComplete.add(l.Id);
                // }

                licenseIdsToComplete.add(l.Id);
                continue;
            }

            if (l.LicenseTypeName__c == 'CT - Entity') {
                if (!l.AssociatedEmployee__r.isEmpty()) {
                    for (AssociatedLicense__c al : l.AssociatedEmployee__r) {
                        if (al.EmployeeLicense__c != null && (al.PositionStatus__c == 'P - PRINCIPAL')) {
                            ctEntityAssociatedEmployeeLicenseIdLicenseIdMap.put(al.EmployeeLicense__c, l.Id);
                            if(al.EmployeeLicenseStatus__c == 'C - Current, Valid & In Good Standing') licenseIdsToComplete.add(l.id);
                            else assocLicenseIds.add(al.EmployeeLicense__c);
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

                            if(al.EntityLicenseStatus__c == 'C - Current, Valid & In Good Standing') licenseIdsToComplete.add(l.id);
                            else assocLicenseIds.add(al.EntityLicense__c);
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
            AND SameAsLicenseTypeRenewPeriod__c = true
        ];

        //collect valid applications
        Set<Id> assocLicenseIdsWithValidApplication = new Set<Id>();

        for (Application__c a : associatedApplications) {
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
        // for (Id licId : licenseIdsWithoutAssoc) {
        //     License__c l = new License__c();
        //     l.Id = licId;
        //     l.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
        //     licensesToUpdate.add(l);
        
        // }

        if (!licenseIdsToComplete.isEmpty()) {
            List<Application__c> applicationsToUpdate = new List<Application__c>();
            //find applications to update
            List<Application__c> applications = [
                SELECT
                    Id,
                    CurrentLicense__c
                FROM Application__c
                WHERE CurrentLicense__c IN :licenseIdsToComplete
                AND Type__c = 'RNEW - Renewal'
                AND SameAsLicenseTypeRenewPeriod__c = true
            ];

            for (Application__c a : applications) {
                a.Phase__c = 'H - License Generation';
                a.Status__c = 'HC - Application Completed';
                applicationsToUpdate.add(a);
            }

            Database.update(applicationsToUpdate, false);

            List<String> validLicenseIds = (List<String>) (new ApplicationDomain(applicationsToUpdate)).getFieldValues('CurrentLicense__c');
            for (Id licId : licenseIdsToComplete) {
                if(!validLicenseIds.contains(licId)) continue;
                License__c l = new License__c();
                l.Id = licId;
                l.Status__c = 'C - Current, Valid & In Good Standing';
                l.EffectiveExpireDate__c = licensesMap.get(licId).LicenseType__r.LicenseTypeExpireDate__c;
                licensesToUpdate.add(l);
            }
        }

        Database.update(licensesToUpdate, false);
    }

    public void processSecondRun(List<SObject> scope){
        List<License__c> licenses = (List<License__c>)scope;
        Map<Id, License__c> licensesMap = new Map<Id, License__c>(licenses);
        List<Application__c> applicationsToUpdate = new List<Application__c>();
        List<License__c> licensesToUpdate = new List<License__c>();
        Set<Id> licenseIdsToComplete = new Set<Id>();

        for (License__c l : licenses) {
            if (l.AssociatedEntities__r.isEmpty()) {
            //     l.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due';
            //     licensesToUpdate.add(l);
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
            AND SameAsLicenseTypeRenewPeriod__c = true
        ];

        for (Application__c a : associatedApplications) {
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
        if(!secondRun){            
            BatchJobFinishNotification notification = new BatchJobFinishNotification('CT Entity/Sole/PRME Push Through');
            notification.sendEmail();            
            Database.executeBatch(new ContractorRenewalPushThrough(true));
        } else {
            BatchJobFinishNotification notification = new BatchJobFinishNotification('CT RME Push Through');
            notification.sendEmail();
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query;

        if(!secondRun){            
            String associatedLicenseEntitiesSubQuery = '(SELECT Id, EmployeeLicense__c, PositionStatus__c, EmployeeLicenseStatus__c ' +
            'FROM AssociatedEmployee__r ' +
            'WHERE EmploymentStatus__c = \'Employed\' ' +
            'AND (EndDate__c = null OR EndDate__c > TODAY) ' +
            'AND (EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\' ' +
            'OR EmployeeLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\') ' +
            'AND EmployeeActiveInactive__c= \'Active\') ';

            String associatedLicenseEmployeesSubQuery = '(SELECT Id, EntityLicense__c, PositionStatus__c, EntityLicenseStatus__c ' +
                'FROM AssociatedEntities__r ' +
                'WHERE EmploymentStatus__c = \'Employed\'' +
                'AND (EndDate__c = null OR EndDate__c > TODAY) ' +
                'AND (EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\' ' +
                'OR EntityLicenseStatus__c = \'R - Valid Thru Expiration Date, Subject To Renewal\') ' +
                'AND EntityActiveInactive__c = \'Active\') ';
                

            query = 'SELECT Id, Name, ' +
                'NumberofActiveEmployees__c, ' +
                'LicenseType__r.NextLicensePeriodExpireDate__c, ' +
                'LicenseType__r.LicenseTypeExpireDate__c, ' +
                'LicenseTypeName__c, ' +
                associatedLicenseEmployeesSubQuery + ', ' +
                associatedLicenseEntitiesSubQuery +
                'FROM License__c ' +
                'WHERE LicenseTypeName__c IN :licenseTypeFilter ' +
                'AND Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' +
                'AND ThisLicenseRenewed__c = true';

            List<License__c> lics = [
                SELECT Id FROM License__c 
                WHERE LicenseTypeName__c IN :licenseTypeFilter
                AND Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal'
                AND ThisLicenseRenewed__c = true
            ];
        
            if(lics.isEmpty()) secondRun = true;
        } 
        
        if(secondRun){
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

            query = 'SELECT Id, ' +
                'NumberofActiveEmployees__c, ' +
                'LicenseType__r.NextLicensePeriodExpireDate__c, ' +
                'LicenseType__r.LicenseTypeExpireDate__c, ' +
                'LicenseTypeName__c, ' +
                associatedLicenseEmployeesSubQuery +
                'FROM License__c ' +
                'WHERE LicenseTypeName__c =\'CT - RME\' ' +
                'AND Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\'' +
                'AND ThisLicenseRenewed__c = true';
        }

        return Database.getQueryLocator(query);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ContractorRenewalPushThrough(false));        
    }
}