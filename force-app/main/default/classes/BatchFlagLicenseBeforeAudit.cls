/*****
 * Used to invoke BatchFlagLicenseForAudit batch class 
 * 00029406
 * Created Date: 6/26/23
 * Created By: Alvin Zhou
 * *** */
global class BatchFlagLicenseBeforeAudit implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private String option;
    private Boolean isFromLicenseType = false; 
    private Set<String> licenseTypeIds;
    public String recordId;
    private String query = 'Select Id, CEisConfirmed__c, FlaggedforAudit__c, AuditNumber__c, AuditDate__c, AuditCERequirement__c from License__c where AvailableForClearInAudit__c = true and FlaggedforAudit__c = true';

    Set<String> licenseTypeAuditStatusSet;
    Set<String> licenseTypeAuditActiveInactiveSet;

    global BatchFlagLicenseBeforeAudit(Set<String> licenseTypeIds ) {
        option = '1';
        this.licenseTypeIds = licenseTypeIds;
        query = query + ' and LicenseType__c in :licenseTypeIds ';
    }

    global BatchFlagLicenseBeforeAudit(String recordId ) {
        option = '2';
        this.recordId = recordId;
        query = query + ' and LicenseType__c =:recordId ';
    }

    global BatchFlagLicenseBeforeAudit(String recordId, Boolean isFromLicenseType ) {
        option = '3';
        this.recordId = recordId;
        this.isFromLicenseType = isFromLicenseType;
        query = query + ' and LicenseType__c =:recordId ';
    }

    global BatchFlagLicenseBeforeAudit(String recordId, Boolean isFromLicenseType, Set<String> licenseTypeAuditStatusSet ) {
        this(recordId, isFromLicenseType, licenseTypeAuditStatusSet, null);
    }

    global BatchFlagLicenseBeforeAudit(String recordId, Boolean isFromLicenseType, Set<String> licenseTypeAuditStatusSet, Set<String> licenseTypeAuditActiveInactiveSet ) {
        option = '4';
        this.recordId = recordId;
        this.isFromLicenseType = isFromLicenseType;
        query = query + ' and LicenseType__c =:recordId ';
        this.licenseTypeAuditStatusSet = licenseTypeAuditStatusSet;
        this.licenseTypeAuditActiveInactiveSet = licenseTypeAuditActiveInactiveSet;
    }

    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<License__c> records = (List<License__c>)scope;
        for(License__c record: records) {
            record.FlaggedforAudit__c = false;
            record.AuditDate__c = null;
            record.AuditCERequirement__c = null;
            record.AuditNumber__c = null;
            record.CEisConfirmed__c = false;
        }
        update records;
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(this);
    }

    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {
        Switch on option {
            when '1' {
                Database.executeBatch(new BatchFlagLicenseForAudit(licenseTypeIds), 100);  
            }
            when '2' {
                Database.executeBatch(new BatchFlagLicenseForAudit(recordId), 100);  
            }
            when '3' {
                Database.executeBatch(new BatchFlagLicenseForAudit(recordId, isFromLicenseType), 100);  
            }
            when '4' {
                Database.executeBatch(new BatchFlagLicenseForAudit(recordId, isFromLicenseType, licenseTypeAuditStatusSet, licenseTypeAuditActiveInactiveSet), 100);  
            }
            when else {}
        }
        
    }
}