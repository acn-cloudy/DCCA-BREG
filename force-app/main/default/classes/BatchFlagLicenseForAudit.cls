/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  checkLicenseStatus : Find and set the status of Licenses with License Types Start of RenewalPerios = Today
 *  Covered by LicenseUpdateStatusTest
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @created      PacPoint-AZ120919 - Created for PVL Phase 1
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 * 00006486
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */

global class BatchFlagLicenseForAudit implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private Set<String> licenseTypeIdList;
    // 00006750
    private Boolean isFromLicenseType = false;
    private Boolean skipTheExecute = false;
    private String PREAUDIT = 'Pre-Audit';
    public Map<String, Integer> licenseTypeMap;
    // LicenseType__c => number
    private Map<String, Integer> licenseTypeNum;
    private Map<String, Decimal> licenseTypeCushion;
    private Map<String, Integer> licenseTypeOfTotalNum;

    public String licenseTypeId;

    Set<String> licenseTypeAuditStatusSet;
    Set<String> licenseTypeAuditActiveInactiveSet;

    /*
     * variables
     */
    public String query =
    'Select Id, Status__c, Privilege__c, AuditNumber__c, ActiveInactive__c, GenerateFlaggedForAuditNotification__c, FlaggedforAudit__c, MethodofLicensure__c, LicenseType__c, ' +
    'LicenseType__r.AuditActiveInactive__c, LicenseType__r.AuditStatuses__c, LicenseType__r.Audit_Method_of_Licensure__c, LicenseType__r.Audit_Method_of_Licensure_Selection__c, LicenseType__r.Id, LicenseType__r.NoticeOfAuditNotification__r.Name, ' +
    'LicenseType__r.SpecialPrivilege__c, LicenseType__r.AuditCushionPercent__c, LicenseType__r.SpecialPrivilegeAuditSelection__c ' +
    'from License__c ';
    public String condition = ' where LicenseType__r.RunAuditDate__c = today and FlaggedforAudit__c = false and ExcludeAudit__c = false ';

    global BatchFlagLicenseForAudit() {
        licenseTypeMap = new Map<String, Integer>();
        licenseTypeCushion = new Map<String, Decimal>();
        licenseTypeOfTotalNum = new Map<String, Integer>();
        query = query + condition + ' order by LicenseType__c, Name';

    }

    global BatchFlagLicenseForAudit(Set<String> licenseTypeIds ) {
        licenseTypeMap = new Map<String, Integer>();
        licenseTypeCushion = new Map<String, Decimal>();
        licenseTypeOfTotalNum = new Map<String, Integer>();
        licenseTypeIdList = licenseTypeIds;
        condition = ' where  LicenseType__c in: licenseTypeIdList ';
        query = query + condition + ' order by LicenseType__c, Name';
    }

    global BatchFlagLicenseForAudit(
            Map<String, Integer> licenseTypeIdRestNum,
            Map<String, Integer> licenseTypeMap,
            Map<String, Integer> licenseTypeOfTotalNum,
            Boolean isFromLicenseType) {

        this.isFromLicenseType = isFromLicenseType;
        this.licenseTypeOfTotalNum = licenseTypeOfTotalNum;
        licenseTypeCushion = new Map<String, Decimal>();
        List<Id> licenseTypeIds = new List<Id>();
        for (String licenseTypeId : licenseTypeIdRestNum.keySet()) {
            licenseTypeIds.add(licenseTypeId);
        }

        condition =
                'where FlaggedforAudit__c = false and ExcludeAudit__c = false and AuditNumber__c = null and LicenseType__c in ' +
                GlobalUtilities.convertIdsToIdStr(licenseTypeIds);
        query = query + condition + ' order by LicenseType__c, Name';
        this.licenseTypeNum = licenseTypeIdRestNum;
        this.licenseTypeMap = licenseTypeMap;
    }

    global BatchFlagLicenseForAudit(String recordId) {
        this();
        query = 'SELECT ' +
                'Id,' +
                'Status__c, ' +
                'Privilege__c, ' +
                'AuditNumber__c, ' +
                'ActiveInactive__c, ' +
                'GenerateFlaggedForAuditNotification__c, ' +
                'FlaggedforAudit__c, ' +
                'MethodofLicensure__c,' +
                'LicenseType__c,' +
                'LicenseType__r.AuditActiveInactive__c,' +
                'LicenseType__r.AuditStatuses__c,' +
                'LicenseType__r.Audit_Method_of_Licensure__c,' +
                'LicenseType__r.Audit_Method_of_Licensure_Selection__c, '+
                'LicenseType__r.Id, ' +
                'LicenseType__r.SpecialPrivilege__c, ' +
                'LicenseType__r.SpecialPrivilegeAuditSelection__c,' +
                'LicenseType__r.AuditCushionPercent__c, ' +
                'LicenseType__r.NoticeOfAuditNotification__r.Name ' +
                'FROM License__c WHERE LicenseType__c =\'' + recordId +
                '\' AND FlaggedforAudit__c = false  ' +
                'AND ExcludeAudit__c = false ';
        this.licenseTypeId = recordId;
    }

    global BatchFlagLicenseForAudit(String recordId, String recordId2, String recordId3) {
        this();
        query =
                'Select Id, Status__c, AuditNumber__c, Privilege__c, ActiveInactive__c, GenerateFlaggedForAuditNotification__c, FlaggedforAudit__c, MethodofLicensure__c, LicenseType__c, ' +
                'LicenseType__r.AuditActiveInactive__c, LicenseType__r.AuditStatuses__c, LicenseType__r.Audit_Method_of_Licensure__c, LicenseType__r.Audit_Method_of_Licensure_Selection__c, LicenseType__r.Id, ' +
                'LicenseType__r.SpecialPrivilege__c, LicenseType__r.SpecialPrivilegeAuditSelection__c, LicenseType__r.AuditCushionPercent__c, LicenseType__r.NoticeOfAuditNotification__r.Name ' +
                'from License__c where (LicenseType__c =\'' + recordId + '\' or LicenseType__c =\'' + recordId2 +
                '\' or LicenseType__c =\'' + recordId3 +
                '\') and FlaggedforAudit__c = false   and ExcludeAudit__c = false order by LicenseType__c';
    }

    global BatchFlagLicenseForAudit(String recordId, Boolean isSave) {
        this();
        query = 'SELECT' +
                ' Id,' +
                'Status__c,' +
                'Privilege__c,' +
                'AuditNumber__c,' +
                'ActiveInactive__c,' +
                'GenerateFlaggedForAuditNotification__c,' +
                'FlaggedforAudit__c,' +
                'MethodofLicensure__c,' +
                'LicenseType__c,' +
                'LicenseType__r.AuditActiveInactive__c,' +
                'LicenseType__r.AuditStatuses__c,' +
                'LicenseType__r.Audit_Method_of_Licensure__c,' +
                'LicenseType__r.Audit_Method_of_Licensure_Selection__c,' +
                'LicenseType__r.Id,' +
                'LicenseType__r.SpecialPrivilege__c,' +
                'LicenseType__r.SpecialPrivilegeAuditSelection__c,' +
                'LicenseType__r.AuditCushionPercent__c,' +
                'LicenseType__r.NoticeOfAuditNotification__r.Name ' +
                'FROM License__c where LicenseType__c =\'' + recordId +
                '\' AND FlaggedforAudit__c = false' +
                '  AND ExcludeAudit__c = false ' +
                ' ORDER BY LicenseNumberFormula__c';
        this.isFromLicenseType = isSave;
        this.licenseTypeId = recordId;
    }

    global BatchFlagLicenseForAudit(String recordId, Boolean isSave, Set<String> licenseTypeAuditStatusSet) {
        this(recordId, isSave, licenseTypeAuditStatusSet, null);
    }

    global BatchFlagLicenseForAudit(String recordId, Boolean isSave, Set<String> licenseTypeAuditStatusSet, Set<String> licenseTypeAuditActiveInactiveSet) {
        this();
        this.licenseTypeAuditStatusSet = licenseTypeAuditStatusSet;
        this.licenseTypeAuditActiveInactiveSet = licenseTypeAuditActiveInactiveSet;
        query = 'SELECT' +
                ' Id,' +
                'Status__c,' +
                'Privilege__c,' +
                'AuditNumber__c,' +
                'ActiveInactive__c,' +
                'GenerateFlaggedForAuditNotification__c,' +
                'FlaggedforAudit__c,' +
                'MethodofLicensure__c,' +
                'LicenseType__c,' +
                'LicenseType__r.AuditActiveInactive__c,' +
                'LicenseType__r.AuditStatuses__c,' +
                'LicenseType__r.Audit_Method_of_Licensure__c,' +
                'LicenseType__r.Audit_Method_of_Licensure_Selection__c,' +
                'LicenseType__r.Id,' +
                'LicenseType__r.SpecialPrivilege__c,' +
                'LicenseType__r.SpecialPrivilegeAuditSelection__c,' +
                'LicenseType__r.AuditCushionPercent__c,' +
                'LicenseType__r.NoticeOfAuditNotification__r.Name ' +
                'FROM License__c where LicenseType__c =\'' + recordId +
                '\' AND FlaggedforAudit__c = false' +
                '  AND ExcludeAudit__c = false ';
        if (licenseTypeAuditStatusSet != null) {
            query += '  AND Status__c IN  :licenseTypeAuditStatusSet ';
        }
        if (licenseTypeAuditActiveInactiveSet != null) {
            query += '  AND ActiveInactive__c IN  :licenseTypeAuditActiveInactiveSet ';
        }
        query += ' ORDER BY LicenseNumberFormula__c';
        this.isFromLicenseType = isSave;
        this.licenseTypeId = recordId;
    }

    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        if (skipTheExecute) return;
        List<License__c> licenses = new List<License__c>();
        
        for(License__c record: (List<License__c>) scope) {
            if ((record.LicenseType__r.SpecialPrivilegeAuditSelection__c == 'Query Special Privileges Only' ||
                    record.LicenseType__r.SpecialPrivilegeAuditSelection__c == 'Query Null Special Privileges') &&
                    record.LicenseType__r.SpecialPrivilege__c != null) {
                Set<String> splitSp = new Set<String>(record.LicenseType__r.SpecialPrivilege__c.split(';'));
                if (record.LicenseType__r.SpecialPrivilegeAuditSelection__c == 'Query Special Privileges Only') {
                    if(splitSp.contains(record.Privilege__c)) {
                        licenses.add(record);
                    }
                } else if (record.LicenseType__r.SpecialPrivilegeAuditSelection__c == 'Query Null Special Privileges') {
                    if(!splitSp.contains(record.Privilege__c)) {
                        licenses.add(record);
                    }
                } else {
                    licenses.add(record);
                }
            } else if((record.LicenseType__r.Audit_Method_of_Licensure_Selection__c == 'Query Method of Licensure only' || 
                        record.LicenseType__r.Audit_Method_of_Licensure_Selection__c == 'Query Null Method of Licensure') 
                        && record.LicenseType__r.Audit_Method_of_Licensure__c != null){
                if(record.LicenseType__r.Audit_Method_of_Licensure_Selection__c == 'Query Method of Licensure only'){           
                    if(record.LicenseType__r.Audit_Method_of_Licensure__c == record.MethodofLicensure__c) 
                        licenses.add(record);
                }
                else if(record.LicenseType__r.Audit_Method_of_Licensure_Selection__c == 'Query Null Method of Licensure'){
                    if(record.LicenseType__r.Audit_Method_of_Licensure__c != record.MethodofLicensure__c) 
                        licenses.add(record);
                }
            } else {
                licenses.add(record);
            }
        }


        for (License__c license : licenses) {
            licenseTypeCushion.put(license.LicenseType__c, license.LicenseType__r.AuditCushionPercent__c);
        }

        if (licenseTypeNum != null && licenseTypeNum.isEmpty()) {
            skipTheExecute = true;
            return;
        }

        // Convert to license Type Id = > license list
        Map<String, List<License__c>> licenseTypeId2Licenses =
                (new LicenseDomain(licenses)).convertToLicenseTypeIdToLicenses();
        System.debug('#####licenseTypeOfTotalNum##' + licenseTypeOfTotalNum);
        if (licenseTypeNum == null) {
            for (String licenseTypeId : licenseTypeId2Licenses.keySet()) {
                Integer total = 0;
                if (licenseTypeOfTotalNum.containsKey(licenseTypeId)) {
                    total = licenseTypeOfTotalNum.get(licenseTypeId);
                }
                total += licenseTypeId2Licenses.get(licenseTypeId).size();
                licenseTypeOfTotalNum.put(licenseTypeId, total);
            }
        }

        System.debug('#####licenseTypeOfTotalNum##' + licenseTypeOfTotalNum);

        List<License__c> filteredLicenses = new List<License__c>();
        for (List<License__c> licenseRecords : licenseTypeId2Licenses.values()) {
            filteredLicenses.addAll(licenseRecords);
        }

        List<LicenseType__c> licenseTypes = (new LicenseDomain(filteredLicenses)).getLicenseTypes();

        if (licenseTypes != null) {
            List<License__c> licensesForUpdate =
                    (new LicenseTypeDomain(licenseTypes)).filterLicensesByCushionPercent(licenseTypeId2Licenses);
            if (licenseTypeNum == null) {
                licenseTypeMap = (new LicenseDomain(licensesForUpdate)).updateAuditNumber(licenseTypeMap);
            } else {
                Map<String, Map<String, Integer>> ints =
                        (new LicenseDomain(licensesForUpdate)).updateAuditNumberWithDedicateNumber(licenseTypeMap,
                                licenseTypeNum);
                licenseTypeMap = ints.get('licenseTypeMap');
                licenseTypeNum = ints.get('licenseTypeNum');
            }

            System.debug('#####licenseTypeNum####' + licenseTypeNum);
            System.debug('#####licenseTypeMap####' + licenseTypeMap);
            // Database.update(licensesForUpdate, false);
            List<Notification__c> notifications = new List<Notification__c>();
            if (this.isFromLicenseType) {
                // 00015122
                for (License__c record : licensesForUpdate) {
                    record.GenerateFlaggedForAuditNotification__c = false;
                }
            }

            if (!licensesForUpdate.isEmpty()) {
                TriggerHelper.disableLicenseTrigger = true;
                update licensesForUpdate;
                TriggerHelper.disableLicenseTrigger = false;
            }

            if (!notifications.isEmpty()) {
                insert notifications;
            }

            // 00029388
            List<String> licenseIdsForHistoryCheck = (new LicenseDomain(licensesForUpdate)).getIds();
            List<LicenseHistory__c> histories 
                = LicenseHistorySelector.getPostAuditLicenseHistories(new List<String>{'RNEW - RENEWED'}, licenseIdsForHistoryCheck);
            List<LicenseHistory__c> historiesForUpdate = (new LicenseHistoryDomain(histories)).updateMarks();
            if(!historiesForUpdate.isEmpty()) update historiesForUpdate;

        }
    }

    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new BatchFlagLicenseForAudit(), 100);
    }

    public void generateRenewalLetters() {

        //00015680 to check the audit type
        LicenseType__c licenseType = [Select Id, AuditType__c, Audit_Method_of_Licensure__c, Audit_Method_of_Licensure_Selection__c, RenewalFormTemplateBulkRenewals__c, NoticeOfAuditNotification__r.Name from LicenseType__c where Id =: licenseTypeMap.KeySet()];
        Notification__c notification = new Notification__c();
        notification.RecordId__c = licenseType.Id;
        notification.LicenseType__c = licenseType.Id;
        notification.DocGeneratorSettings__c = licenseType.NoticeOfAuditNotification__r.Name;
        notification.DocumentTemplateName__c = licenseType.NoticeOfAuditNotification__r.Name;
        insert notification;
        Database.executeBatch(new DocumentGeneratorProcessBatch(notification.LicenseType__c,
                notification.Id, notification.DocumentTemplateName__c, true), 4);
        if (licenseType.AuditType__c == PREAUDIT && licenseType.Audit_Method_of_Licensure_Selection__c != 'Query Method of Licensure only') {
            Database.executeBatch(new GenerateRenewalNotificationBatch(licenseType.Id, true,
                    licenseType.RenewalFormTemplateBulkRenewals__c, true), 200);
            Database.executeBatch(new GenerateRenewalNotificationBatch(licenseType.Id, false,
                    'RenewalNotification', true), 200);
        }
    }

    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {
        Map<String, Integer> licenseTypeIdRestNum = new Map<String, Integer>();
        String licenseTypeName = '';
        if (licenseTypeOfTotalNum != null) {
            for (String licenseTypeId : licenseTypeOfTotalNum.keySet()) {
                Integer cont = licenseTypeOfTotalNum.get(licenseTypeId);
                Integer currentInt = licenseTypeMap.get(licenseTypeId);
                Decimal auditCushion = licenseTypeCushion.get(licenseTypeId);
                if (auditCushion == null) auditCushion = 0;
                Integer dedicatedNum = Integer.valueOf(Math.ceil(cont * auditCushion / 100));
                if(auditCushion > 0 && dedicatedNum == 0) {
                    auditCushion = 1;
                }
                Integer num = licenseTypeMap.get(licenseTypeId) ;
                if (num == null) num = 0;
                Integer restOfNum = dedicatedNum - num;
                if (restOfNum > 0) {
                    licenseTypeIdRestNum.put(licenseTypeId, restOfNum);
                }
            }
            if (!licenseTypeIdRestNum.isEmpty() && !skipTheExecute) {
                Database.executeBatch(
                        new BatchFlagLicenseForAudit(licenseTypeIdRestNum, licenseTypeMap, licenseTypeOfTotalNum,
                                this.isFromLicenseType), 200);
            } else if (this.isFromLicenseType && licenseTypeMap.size() == 1) {
                generateRenewalLetters();

                if (this.licenseTypeId != null) {
                    LicenseType__c licenseType = [SELECT Id, Name FROM LicenseType__c WHERE Id = :this.licenseTypeId];
                    licenseTypeName = licenseType.Name;
                }

                BatchJobFinishNotification notification =
                        new BatchJobFinishNotification('Flag License for Audit - In Bulk', licenseTypeName);
                notification.sendEmail();
            }else{
                if (this.licenseTypeId != null) {
                    LicenseType__c licenseType = [SELECT Id, Name FROM LicenseType__c WHERE Id = :this.licenseTypeId];
                    licenseTypeName = licenseType.Name;
                }

                if(isFromLicenseType) {
                    BatchJobFinishNotification notification =
                            new BatchJobFinishNotification('Flag License for Audit - In Bulk', licenseTypeName);
                    notification.sendEmail();
                }else{
                    BatchJobFinishNotification notification =
                            new BatchJobFinishNotification('Flag License for Audit', licenseTypeName);
                    notification.sendEmail(); 
                }
            }
        }

    }
}