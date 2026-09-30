/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  The current Run Loss of Insurance Bonds Suspense job will create suspense records 
 *  and change the license status when the required insurance record is inactive. 
 *  We will need to update the current job to include a step to set the RME associated license under maintenance 
 *  when the associated Entity License status was changed to value stored in LicenseType.StatusDuetoRequiredINSInactive__c 
 *  due to loss of insurance. If there is another current employer, then we don't want to update the associated RME license.
 *  
 *  Covered by AssociatedInsuranceSuspenseBatchTest
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @created      PacPoint-AZ033122 - Created for PVL case 00028166
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
/*****
 * 
 * 
 * 
 * **** */
global class AssociatedInsuranceSuspenseBatch implements Database.Batchable<SObject>, Database.Stateful {
    public List<String> recordIds;
    public String query = 'Select Id, EmployeeLicense__r.LicenseType__r.DualRMELosesEmployerDuetoInsurance__r.Name, ' 
    + ' EntityLicense__c, EmployeeLicense__c, EmploymentStatus__c, EndDate__c, Position__c, EmployeeLicense__r.LicenseType__r.RMELosesEmployerDuetoInsurance__r.Name ' 
    + ' from AssociatedLicense__c where EntityLicense__c in: recordIds and EmploymentStatus__c = \'Employed\' ' 
        + ' and (EndDate__c = null or EndDate__c > Today) and Position__c != \'I - Inactive\' and ( Position__c != \'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)\' ' 
        + ' or EmployeeLicense__r.SoleOwner__c != true)';
    global AssociatedInsuranceSuspenseBatch(List<String> licenseIds) {
        this.recordIds = licenseIds;
    }
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<AssociatedLicense__c> records = (List<AssociatedLicense__c>)scope;
        List<String> employeeLicenseIds = (List<String>) (new AssociatedLicenseDomain(records)).getFieldValues('EmployeeLicense__c');
        // EmployeeId => EntityId
        Map<String, String> employeeId2EntityId = (new AssociatedLicenseDomain(records)).getEmployeeId2EntityId();
        List<AssociatedLicense__c> associatedLicenses = [Select Id, EntityLicense__c, EmployeeLicense__c, EmploymentStatus__c, EndDate__c, Position__c,
             EmployeeLicense__r.LicenseType__r.DualRMELosesEmployerDuetoInsurance__r.Name, DualIndicator__c from AssociatedLicense__c 
            where EmployeeLicense__c in: employeeLicenseIds and EmploymentStatus__c = 'Employed' and (EndDate__c = null or EndDate__c > Today)];
        // Filter associated licenses by employeeId and entity Id
        Map<String, List<AssociatedLicense__c>> associatedLicenseMap = (new AssociatedLicenseDomain(associatedLicenses)).filterAssociatedLicensesByEntityId(employeeId2EntityId);
        Set<String> employeeIds = employeeId2EntityId.keySet();
        Set<String> employeeIdsHasOtherEmployer = associatedLicenseMap.keySet();
        employeeIds.removeAll(employeeIdsHasOtherEmployer);

        List<License__c> licenses = [Select Id, Status__c, GenerateRMELosesEntityNotification__c, LicenseType__r.AutoForfeitureStatus__c, LicenseType__r.NumberOfDaysUntilAutoForfeiture__c from License__c where Id in: employeeIds];
        List<License__c> licenseForUpdate = new List<License__c>();
        //00028420
        List<Notification__c> notifications = new List<Notification__c>();
        Map<String, AssociatedLicense__c> employeeId2AssociatedLicenses = (new AssociatedLicenseDomain(records)).getEmployeeId2AssociatedLicenses();
        //
        for(License__c license: licenses) {
            // No
            if (license.Status__c == 'C - Current, Valid & In Good Standing'){
                license.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
            } else if (license.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal'){
                license.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due ';
            }
            licenseForUpdate.add(license);
            //00028420
            AssociatedLicense__c associatedLicense = employeeId2AssociatedLicenses.get(license.Id);
            if(associatedLicense != null) {
                notifications.add(initiateNotification(license.Id, 
                    associatedLicense.EmployeeLicense__r.LicenseType__r.RMELosesEmployerDuetoInsurance__r.Name));
            }
        }


        for(String employeeId: employeeIdsHasOtherEmployer) {
            // Yes 00028420
            // For the associated license found from "Query Associated License", check to see if AssociatedLicense.DualIndicator = true
            List<AssociatedLicense__c> alRecords = associatedLicenseMap.get(employeeId);
            for(AssociatedLicense__c alRecord: alRecords) {
                if(alRecord.DualIndicator__c == 'Dual') {
                    notifications.add(initiateNotification(employeeId, 
                        alRecord.EmployeeLicense__r.LicenseType__r.DualRMELosesEmployerDuetoInsurance__r.Name));
                    break;
                }
            }
        }
        // Yes 00028420
        if(!notifications.isEmpty()) {
            insert notifications;
        }
        
        if(licenseForUpdate.isEmpty()) {
            return;
        }
        

        List<String> licenseIdsForUpdate = (new LicenseDomain(licenseForUpdate)).getIds();
        List<Suspense__c> suspenses = [Select Id, SuspenseDueDate__c, License__r.LicenseType__r.NumberOfDaysUntilAutoForfeiture__c, MaintenanceType__c from Suspense__c 
            where MaintenanceType__c = 'NFRM - RME WITHOUT EMPLOYMENT' and License__c in: licenseIdsForUpdate];
        List<Suspense__c> filteredSuspenses = (new SuspenseDomain(suspenses)).filterSupsensesByDueDate();
        Map<String, List<Suspense__c>> licenseId2Suspenses = (new SuspenseDomain(filteredSuspenses)).getLicenseId2Suspenses();
        List<Suspense__c> suspenseForCreation = (new LicenseDomain(licenseForUpdate)).generateNewSuspenseIfNotExist(licenseId2Suspenses);
        
        if(!suspenseForCreation.isEmpty() ) {
            insert suspenseForCreation;
        }
        update licenseForUpdate;
    }

    private Notification__c initiateNotification(String licenseId, String templateName) {
        Notification__c notification = new Notification__c();
        notification.License__c = licenseId;
        notification.RecordId__c = licenseId;
        notification.Scheduled__c = true;
        notification.SendToPrinter__c = true;
        notification.Status__c = 'Scheduled';
        notification.DocGeneratorSettings__c = templateName;
        notification.DocumentTemplateName__c = templateName;
        return notification;
    }

    global void finish(Database.BatchableContext context) {

    }
}