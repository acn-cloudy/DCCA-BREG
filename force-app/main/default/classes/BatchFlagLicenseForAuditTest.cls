@IsTest
public with sharing class BatchFlagLicenseForAuditTest { 
    private static final String LICENSE_SOQL =
        'SELECT Id, Status__c, Privilege__c, AuditNumber__c, ActiveInactive__c, GenerateFlaggedForAuditNotification__c, ' +
        'FlaggedforAudit__c, MethodofLicensure__c, LicenseType__c, ' +
        'LicenseType__r.AuditActiveInactive__c, LicenseType__r.AuditStatuses__c, ' +
        'LicenseType__r.Audit_Method_of_Licensure__c, LicenseType__r.Audit_Method_of_Licensure_Selection__c, LicenseType__r.Id, ' +
        'LicenseType__r.SpecialPrivilege__c, LicenseType__r.AuditCushionPercent__c, LicenseType__r.SpecialPrivilegeAuditSelection__c, ' +
        'LicenseType__r.NoticeOfAuditNotification__r.Name ' +
        'FROM License__c';

    @TestSetup
    static void makeData() {
        TestDataFactory.createLicense();
        List<License__c> licenses = [SELECT Id, FlaggedforAudit__c FROM License__c];
        for (License__c license : licenses) {
            license.FlaggedforAudit__c = true;
        }
        update licenses;
    }

    private static void prepareLicensesEligibleForAudit() {
        List<License__c> licenses = [SELECT Id FROM License__c];
        for (License__c lic : licenses) {
            lic.FlaggedforAudit__c = false;
            lic.AuditNumber__c = null;
        }
        update licenses;
    }

    private static List<License__c> queryLicensesForExecute(Id licenseTypeId) {
        return Database.query(
            LICENSE_SOQL + ' WHERE LicenseType__c = :licenseTypeId AND FlaggedforAudit__c = FALSE'
        );
    }

    private static List<String> getActivePicklistApiValues(SObjectType sobType, String fieldApiName) {
        List<String> out = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = sobType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return out;
        }
        for (Schema.PicklistEntry pe : fieldMap.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (pe.isActive() && String.isNotBlank(pe.getValue())) {
                out.add(pe.getValue());
            }
        }
        return out;
    }

    /**
     * First value that exists on both License Type and License for Method of Licensure (restricted picklists differ per org).
     */
    private static String pickSharedMethodOfLicensureValue() {
        Set<String> ltVals = new Set<String>(
            getActivePicklistApiValues(LicenseType__c.SObjectType, 'Audit_Method_of_Licensure__c')
        );
        for (String licVal : getActivePicklistApiValues(License__c.SObjectType, 'MethodofLicensure__c')) {
            if (ltVals.contains(licVal)) {
                return licVal;
            }
        }
        return null;
    }

    /** License MethodofLicensure__c value different from the given license-type value, if any. */
    private static String pickLicenseMolDifferentFrom(String licenseTypeMol) {
        if (String.isBlank(licenseTypeMol)) {
            return null;
        }
        for (String licVal : getActivePicklistApiValues(License__c.SObjectType, 'MethodofLicensure__c')) {
            if (licVal != licenseTypeMol) {
                return licVal;
            }
        }
        return null;
    }

    private static Boolean licenseTypeHasPicklistValue(String fieldApiName, String apiValue) {
        return getActivePicklistApiValues(LicenseType__c.SObjectType, fieldApiName).contains(apiValue);
    }

    private static LicenseType__c queryLicenseTypeForBranchTests() {
        return [
            SELECT
                Id,
                SpecialPrivilegeAuditSelection__c,
                SpecialPrivilege__c,
                Audit_Method_of_Licensure__c,
                Audit_Method_of_Licensure_Selection__c,
                AuditCushionPercent__c
            FROM LicenseType__c
            LIMIT 1
        ];
    }

    private static LicenseType__c queryLicenseTypeForCushionUpdate() {
        return [SELECT Id, AuditCushionPercent__c FROM LicenseType__c LIMIT 1];
    }

    @IsTest
    static void testBatch() {
        prepareLicensesEligibleForAudit();
        License__c record = [SELECT Id, FlaggedforAudit__c, LicenseType__c FROM License__c LIMIT 1];
        BatchFlagLicenseForAudit auditRecord = new BatchFlagLicenseForAudit(record.LicenseType__c);
        Test.startTest();
        Database.executeBatch(auditRecord, 100);
        Test.stopTest();

        List<License__c> records = Database.query(
            'SELECT Id, Status__c, Privilege__c, AuditNumber__c, ActiveInactive__c, FlaggedforAudit__c, LicenseType__c, '
                + 'LicenseType__r.AuditActiveInactive__c, LicenseType__r.AuditStatuses__c, LicenseType__r.Id, '
                + 'LicenseType__r.SpecialPrivilege__c, LicenseType__r.AuditCushionPercent__c, LicenseType__r.SpecialPrivilegeAuditSelection__c, '
                + 'LicenseType__r.Audit_Method_of_Licensure__c, LicenseType__r.Audit_Method_of_Licensure_Selection__c '
                + 'FROM License__c'
        );
        new BatchFlagLicenseForAudit(record.LicenseType__c).execute(null, records);

        new BatchFlagLicenseForAudit(record.Id, record.Id, record.Id);
        new BatchFlagLicenseForAudit(record.LicenseType__c, true);
        new BatchFlagLicenseForAudit();
    }

    @IsTest
    static void testLicenseTypeBatchJobs() {
        prepareLicensesEligibleForAudit();
        License__c record = [SELECT Id, LicenseType__c FROM License__c LIMIT 1];

        LicenseTypeBatchJobsController.runLicenseAuditProcess(record.LicenseType__c);
        Map<String, Integer> licenseTypeNum = new Map<String, Integer>();
        Map<String, Integer> licenseTypeMap = new Map<String, Integer>();
        Map<String, Integer> licenseTypeTotalNum = new Map<String, Integer>();
        licenseTypeTotalNum.put(record.LicenseType__c, 5);
        licenseTypeNum.put(record.LicenseType__c, 2);
        licenseTypeMap.put(record.LicenseType__c, 1);
        BatchFlagLicenseForAudit batchAudit = new BatchFlagLicenseForAudit(
            licenseTypeMap,
            licenseTypeNum,
            licenseTypeTotalNum,
            true
        );

        Test.startTest();
        Database.executeBatch(batchAudit, 200);
        Test.stopTest();
    }

    @IsTest
    static void testLicenseTypeIdsBatchJobs() {
        prepareLicensesEligibleForAudit();
        License__c record = [SELECT Id, LicenseType__c FROM License__c LIMIT 1];

        LicenseTypeBatchJobsController.runLicenseAuditProcess(record.LicenseType__c);
        Set<String> typeIds = new Set<String>();
        typeIds.add(record.LicenseType__c);
        BatchFlagLicenseForAudit batchAudit = new BatchFlagLicenseForAudit(typeIds);
        Test.startTest();
        Database.executeBatch(batchAudit, 200);
        Test.stopTest();
    }

    @IsTest
    static void testSchedulableStartsDefaultBatch() {
        Test.startTest();
        new BatchFlagLicenseForAudit().execute(null);
        Test.stopTest();
    }

    @IsTest
    static void testConstructorWithAuditStatusesRunsBatch() {
        prepareLicensesEligibleForAudit();
        License__c record = [SELECT LicenseType__c, Status__c, ActiveInactive__c FROM License__c LIMIT 1];

        Set<String> statuses = new Set<String>{ record.Status__c };
        Set<String> activeInactive = new Set<String>{ record.ActiveInactive__c };

        Test.startTest();
        new BatchFlagLicenseForAudit(record.LicenseType__c, true, statuses);
        Database.executeBatch(new BatchFlagLicenseForAudit(record.LicenseType__c, true, statuses, activeInactive), 50);
        Test.stopTest();
    }

    @IsTest
    static void testThreeLicenseTypeIdsConstructorRunsBatch() {
        prepareLicensesEligibleForAudit();
        License__c record = [SELECT LicenseType__c FROM License__c LIMIT 1];
        Id ltId = record.LicenseType__c;

        Test.startTest();
        Database.executeBatch(new BatchFlagLicenseForAudit(ltId, ltId, ltId), 50);
        Test.stopTest();
    }

    @IsTest
    static void testExecuteFiltersQuerySpecialPrivilegesOnly() {
        prepareLicensesEligibleForAudit();
        LicenseType__c lt = queryLicenseTypeForBranchTests();
        lt.SpecialPrivilegeAuditSelection__c = 'Query Special Privileges Only';
        lt.SpecialPrivilege__c = 'SP_AUDIT_A;SP_AUDIT_B';
        lt.AuditCushionPercent__c = 100;
        update lt;

        List<License__c> toUpdate = [SELECT Id, Name FROM License__c WHERE LicenseType__c = :lt.Id ORDER BY Name];
        if (!toUpdate.isEmpty()) {
            toUpdate[0].Privilege__c = 'SP_AUDIT_A';
            update toUpdate[0];
        }
        if (toUpdate.size() > 1) {
            toUpdate[1].Privilege__c = 'NOT_IN_LIST';
            update toUpdate[1];
        }

        List<License__c> scope = queryLicensesForExecute(lt.Id);
        System.assert(!scope.isEmpty(), 'Expected unflagged licenses for execute scope');
        new BatchFlagLicenseForAudit(lt.Id).execute(null, scope);
    }

    @IsTest
    static void testExecuteFiltersQueryNullSpecialPrivileges() {
        prepareLicensesEligibleForAudit();
        LicenseType__c lt = queryLicenseTypeForBranchTests();
        lt.SpecialPrivilegeAuditSelection__c = 'Query Null Special Privileges';
        lt.SpecialPrivilege__c = 'IN_SET_ONLY';
        lt.AuditCushionPercent__c = 100;
        update lt;

        List<License__c> toUpdate = [SELECT Id FROM License__c WHERE LicenseType__c = :lt.Id LIMIT 1];
        if (!toUpdate.isEmpty()) {
            toUpdate[0].Privilege__c = 'NOT_IN_SET';
            update toUpdate[0];
        }

        List<License__c> scope = queryLicensesForExecute(lt.Id);
        System.assert(!scope.isEmpty(), 'Expected unflagged licenses for execute scope');
        new BatchFlagLicenseForAudit(lt.Id).execute(null, scope);
    }

    @IsTest
    static void testExecuteFiltersQueryMethodOfLicensureOnly() {
        prepareLicensesEligibleForAudit();
        if (!licenseTypeHasPicklistValue('Audit_Method_of_Licensure_Selection__c', 'Query Method of Licensure only')) {
            return;
        }
        String sharedMol = pickSharedMethodOfLicensureValue();
        System.assertNotEquals(
            null,
            sharedMol,
            'Org needs at least one API value shared by LicenseType.Audit_Method_of_Licensure__c and License__c.MethodofLicensure__c'
        );

        LicenseType__c lt = queryLicenseTypeForBranchTests();
        lt.SpecialPrivilegeAuditSelection__c = null;
        lt.SpecialPrivilege__c = null;
        lt.Audit_Method_of_Licensure_Selection__c = 'Query Method of Licensure only';
        lt.Audit_Method_of_Licensure__c = sharedMol;
        lt.AuditCushionPercent__c = 100;
        update lt;

        List<License__c> molRows = [SELECT Id FROM License__c WHERE LicenseType__c = :lt.Id];
        for (License__c lic : molRows) {
            lic.MethodofLicensure__c = sharedMol;
        }
        update molRows;

        List<License__c> scope = queryLicensesForExecute(lt.Id);
        System.assert(!scope.isEmpty(), 'Expected unflagged licenses for execute scope');
        new BatchFlagLicenseForAudit(lt.Id).execute(null, scope);
    }

    @IsTest
    static void testExecuteFiltersQueryNullMethodOfLicensure() {
        prepareLicensesEligibleForAudit();
        if (!licenseTypeHasPicklistValue('Audit_Method_of_Licensure_Selection__c', 'Query Null Method of Licensure')) {
            return;
        }
        List<String> ltMols = getActivePicklistApiValues(LicenseType__c.SObjectType, 'Audit_Method_of_Licensure__c');
        System.assert(!ltMols.isEmpty(), 'License Type Audit_Method_of_Licensure__c must have at least one active value');
        String ltMol = ltMols[0];
        String licMol = pickLicenseMolDifferentFrom(ltMol);
        System.assertNotEquals(
            null,
            licMol,
            'Org needs a License MethodofLicensure__c value different from the License Type audit method (' + ltMol + ')'
        );

        LicenseType__c lt = queryLicenseTypeForBranchTests();
        lt.SpecialPrivilegeAuditSelection__c = null;
        lt.SpecialPrivilege__c = null;
        lt.Audit_Method_of_Licensure_Selection__c = 'Query Null Method of Licensure';
        lt.Audit_Method_of_Licensure__c = ltMol;
        lt.AuditCushionPercent__c = 100;
        update lt;

        List<License__c> molRows = [SELECT Id FROM License__c WHERE LicenseType__c = :lt.Id];
        for (License__c lic : molRows) {
            lic.MethodofLicensure__c = licMol;
        }
        update molRows;

        List<License__c> scope = queryLicensesForExecute(lt.Id);
        System.assert(!scope.isEmpty(), 'Expected unflagged licenses for execute scope');
        new BatchFlagLicenseForAudit(lt.Id).execute(null, scope);
    }

    @IsTest
    static void testExecuteIsFromLicenseTypeClearsGenerateNotification() {
        prepareLicensesEligibleForAudit();
        LicenseType__c lt = queryLicenseTypeForCushionUpdate();
        lt.AuditCushionPercent__c = 100;
        update lt;

        List<License__c> scope = queryLicensesForExecute(lt.Id);
        System.assert(!scope.isEmpty(), 'Expected unflagged licenses for execute scope');
        new BatchFlagLicenseForAudit(lt.Id, true).execute(null, scope);
    }

    @IsTest
    static void testDefaultConstructorBatchRunsThroughFinish() {
        prepareLicensesEligibleForAudit();
        LicenseType__c lt = queryLicenseTypeForCushionUpdate();
        lt.AuditCushionPercent__c = 100;
        update lt;

        Test.startTest();
        Database.executeBatch(new BatchFlagLicenseForAudit(), 50);
        Test.stopTest();
    }

    @IsTest
    static void testFinishAfterDirectExecute() {
        prepareLicensesEligibleForAudit();
        LicenseType__c lt = queryLicenseTypeForCushionUpdate();
        lt.AuditCushionPercent__c = 100;
        update lt;

        List<License__c> scope = queryLicensesForExecute(lt.Id);
        BatchFlagLicenseForAudit batch = new BatchFlagLicenseForAudit(lt.Id);
        Test.startTest();
        batch.execute(null, scope);
        batch.finish(null);
        Test.stopTest();
    }
}