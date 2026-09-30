global without sharing class LicenseEmployerAddressUpdateBatch implements Database.Batchable<SObject>, Database.Stateful {
    public Set<String> entityLicIds = new Set<String>();
    public String query = 'SELECT Id, EmployeeLicense__c, EffectiveDate__c, EntityLicense__r.RenewalMailtoStreet__c, EntityLicense__r.RenewalMailtoCity__c, '
        +' EntityLicense__r.RenewalMailtoState__c, EntityLicense__r.RenewalMailToZipCode__c, EntityLicense__r.LicenseeNameFormula__c, EntityLicense__r.RenewalMailtoCountry__c '
        +' FROM AssociatedLicense__c';
    
    global LicenseEmployerAddressUpdateBatch(Set<String> entityLicIds){
        this();
        this.entityLicIds = entityLicIds;
        query += ' WHERE EmploymentStatus__c = \'Employed\' AND (EndDate__c = null OR EndDate__c > TODAY) AND (EntityLicense__r.LicenseType__r.Entity__c = true OR EntityLicense__r.SoleOwner__c = true) AND EntityLicense__c IN: entityLicIds';
    }

    global LicenseEmployerAddressUpdateBatch() {  
        entityLicIds.clear();    
    }

    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<AssociatedLicense__c> assocLics = (List<AssociatedLicense__c>) scope;
        
        // Update Remaining Employee Licenses
        Map<String, License__c> employeesToUpdate = new Map<String, License__c>();
        Map<String, AssociatedLicense__c> employeeAssocLicMap = new Map<String, AssociatedLicense__c>();
        for(AssociatedLicense__c assocLic:assocLics){     
            License__c employeeLic = new License__c(
                Id = assocLic.EmployeeLicense__c,
                EmployerStreet__c = assocLic.EntityLicense__r.RenewalMailtoStreet__c,
                EmployerCity__c = assocLic.EntityLicense__r.RenewalMailtoCity__c,
                EmployerState__c = assocLic.EntityLicense__r.RenewalMailtoState__c,
                EmployerZipCode__c = assocLic.EntityLicense__r.RenewalMailToZipCode__c,
                EmployerCountry__c = assocLic.EntityLicense__r.RenewalMailtoCountry__c,
                EmployerName__c = assocLic.EntityLicense__r.LicenseeNameFormula__c
            );
            employeesToUpdate.put(assocLic.EmployeeLicense__c, employeeLic);
            employeeAssocLicMap.put(assocLic.EmployeeLicense__c, assocLic);
        }
        
        // Get Other Employees Assoc Licenses
        for(AssociatedLicense__c otherEmployeeAsocLic: [SELECT EmployeeLicense__c, EffectiveDate__c FROM AssociatedLicense__c WHERE EmploymentStatus__c = 'Employed' AND (EndDate__c = null OR EndDate__c > TODAY) AND EmployeeLicense__c IN :employeeAssocLicMap.keySet() AND (NOT(EntityLicense__c IN :this.entityLicIds))]){
            if(employeeAssocLicMap.get(otherEmployeeAsocLic.EmployeeLicense__c) != null && otherEmployeeAsocLic.EffectiveDate__c < employeeAssocLicMap.get(otherEmployeeAsocLic.EmployeeLicense__c).EffectiveDate__c) employeesToUpdate.remove(otherEmployeeAsocLic.EmployeeLicense__c);
        }
        
        TriggerHelper.disableLicenseTrigger = true;
        if(!employeesToUpdate.isEmpty()) update new List<License__c>(employeesToUpdate.values());
        TriggerHelper.disableLicenseTrigger = false;
    }

    global void finish(Database.BatchableContext context) {}
}