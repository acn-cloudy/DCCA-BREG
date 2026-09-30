public class AssociatedLicenseService {
    // 00008669
    public static Set<String> licenseIdsEmploymentCount = new Set<String>();
    public static Map<String, Date> employeeLicenseWithEndDate = new Map<String, Date>();
    

    public static List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
    public static void captureEmploymentStatusChange(SObject oldSo, SObject so) {
        AssociatedLicense__c record = (AssociatedLicense__c) so;
        AssociatedLicense__c oldRecord = (AssociatedLicense__c) oldSo;
        if(record.EmploymentStatus__c != oldRecord.EmploymentStatus__c) {
            licenseIdsEmploymentCount.add(record.EmployeeLicense__c);
            if(record.EmploymentStatus__c == 'Terminated') {
                System.debug('#######LicenseService.entityLicenseIdsUpdatedToZT#####'+ LicenseService.entityLicenseIdsUpdatedToZT);
                System.debug('#######record.EntityLicense__c####' + record.EntityLicense__c);
                if(LicenseService.entityLicenseIdsUpdatedToZT.containsKey(record.EntityLicense__c)) {
                    License__c entityLicense = LicenseService.entityLicenseIdsUpdatedToZT.get(record.EntityLicense__c);
                    AssociatedLicense__c rec = record.clone();
                    rec.EntityLicense__r = entityLicense;
                    LicenseService.ztEmployeeLicenseWithEndDate.put(record.EmployeeLicense__c, rec);
                }
            }
        }
        if(record.EndDate__c != null) {
            employeeLicenseWithEndDate.put(record.EmployeeLicense__c, record.EndDate__c);
            employeeLicenseWithEndDate.put(record.EntityLicense__c, record.EndDate__c);
        }
        
    }
    // 00009088
    public static void captureEmploymentStatusChange(SObject so) {
        AssociatedLicense__c record = (AssociatedLicense__c) so;
        if(record.EmploymentStatus__c == 'Employed') {
            licenseIdsEmploymentCount.add(record.EmployeeLicense__c);
        }
    }

    public static void countLicenseRecords() {
        if(licenseIdsEmploymentCount.isEmpty()) return;
        List<String> licenseIds = new List<String>(licenseIdsEmploymentCount);
        List<License__c> licenses = LicenseSelector.getLicenses(licenseIds);
        licenseIdsEmploymentCount.clear();
        List<AggregateResult> results = AssociatedLicenseSelector.getEntityLicenseCount(licenseIds);
        Map<String, Integer> employeeLicenseCount = new Map<String, Integer>();
        for(AggregateResult result: results) {
            Integer num = (Integer)result.get('numCount');
            String employeeLicenseId = (String) result.get('EmployeeLicense__c');
            employeeLicenseCount.put(employeeLicenseId, num);
        }
        (new LicenseDomain(licenses)).updateNumOfActiveEmployers(employeeLicenseCount);
        update licenses;
    }

    /**
     * VPVL-13: When BIC License is terminated or ended, check if its associated RB-Entity 
     * has any other active BIC. If no Active BIC is found but the entity has an active RBO:
     * 1. Update RB-Entity's LossofBICDate__c field with today's date (suspense creation moved to midnight batch)
     * 2. Place the RBO licenses status as CM
     * Created by: Akanksha Reddy Anthireddygari
     * Created date: 01/12/2026
     */
    public static void captureBicTerminationForRbEntity(SObject oldSo, SObject so) {
        AssociatedLicense__c record = (AssociatedLicense__c) so;
        AssociatedLicense__c oldRecord = (AssociatedLicense__c) oldSo;
        
        // Check if this is a BIC position
        if (record.Position__c != 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)') {
            return;
        }
        
        // Check if BIC is terminated or ended
        Boolean isTerminated = (oldRecord.EmploymentStatus__c != 'Terminated' && record.EmploymentStatus__c == 'Terminated');
        Boolean isEnded = (oldRecord.EndDate__c == null || oldRecord.EndDate__c > Date.today()) 
                         && record.EndDate__c != null 
                         && record.EndDate__c <= Date.today();
        
        if (!isTerminated && !isEnded) {
            return;
        }
        
        // Get the RB-Entity license ID
        Id rbEntityId = record.EntityLicense__c;
        if (rbEntityId == null) {
            return;
        }
        
        // Get employment end date
        Date employmentEndDate = record.EndDate__c != null ? record.EndDate__c : Date.today();
        
        // Query for RB-Entity license to verify it's an RB-Entity
        List<License__c> rbEntityLicenses = [
            SELECT Id, LicenseType__r.Name, LicenseType__r.AutoForfeitureStatus__c,
                LicenseType__r.NumberofDaysUntilAutoForfeiture__c
            FROM License__c
            WHERE Id = :rbEntityId
            AND LicenseType__r.Name = 'RB - Entity'
        ];
        
        if (rbEntityLicenses.isEmpty()) {
            return;
        }
        
        License__c rbEntity = rbEntityLicenses[0];
        
        // Check if RB-Entity has any other active BIC (excluding the current one being terminated)
        List<AssociatedLicense__c> otherActiveBics = [
            SELECT Id
            FROM AssociatedLicense__c
            WHERE EntityLicense__c = :rbEntityId
            AND Id != :record.Id
            AND Position__c = 'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)'
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
        ];
        
        // If there are other active BICs, no action needed
        if (!otherActiveBics.isEmpty()) {
            return;
        }
        
        // Check if RB-Entity has active RBO licenses
        // RBO licenses are associated where EmployeeLicense__c = RB-Entity Id and EntityLicenseType__c = 'RBO'
        List<AssociatedLicense__c> activeRboLicenses = [
            SELECT Id, EntityLicense__c, EntityLicense__r.Id, EntityLicense__r.Status__c,
                EntityLicense__r.ActiveInactive__c, EndDate__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c = :rbEntityId
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            AND EntityLicenseType__c = 'RBO'
            AND EntityLicense__r.ActiveInactive__c = 'Active'
        ];
        
        if (activeRboLicenses.isEmpty()) {
            return;
        }
        
        // Prepare list for DML operations
        List<License__c> licensesToUpdate = new List<License__c>();
        
        // 1. Update RB-Entity with Loss of BIC Date (suspense creation moved to midnight batch)
        License__c rbEntityToUpdate = new License__c();
        rbEntityToUpdate.Id = rbEntityId;
        rbEntityToUpdate.LossofBICDate__c = Date.today();
        licensesToUpdate.add(rbEntityToUpdate);
        
        // 2. Update RBO licenses status to CM
        Set<Id> rboLicenseIds = new Set<Id>();
        for (AssociatedLicense__c al : activeRboLicenses) {
            if (al.EntityLicense__c != null) {
                rboLicenseIds.add(al.EntityLicense__c);
            }
        }
        
        if (!rboLicenseIds.isEmpty()) {
            List<License__c> rboLicenses = [
                SELECT Id, Status__c
                FROM License__c
                WHERE Id IN :rboLicenseIds
            ];
            
            for (License__c rboLicense : rboLicenses) {
                // Update status to CM only if not already CM
                if (rboLicense.Status__c != 'CM - Current, Valid & In Good Standing/Maint. Requirement Due') {
                    License__c rboToUpdate = new License__c();
                    rboToUpdate.Id = rboLicense.Id;
                    rboToUpdate.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
                    licensesToUpdate.add(rboToUpdate);
                }
            }
        }
        
        // Perform DML operation
        if (!licensesToUpdate.isEmpty()) {
            update licensesToUpdate;
        }
    }

    private static final Set<String> SUPERVISOR_LOSS_LICENSE_TYPES = new Set<String>{
        'MFTP', 'MHCP', 'PSYP'
    };

    /**
     * When an associated license linking a supervisor entity to an employee license is
     * terminated or ended, inactivate the employee license when its license type is
     * MFTP, MHCP, or PSYP and no other active associations remain.
     */
    public static void captureLossOfSupervisor(SObject oldSo, SObject so) {
        AssociatedLicense__c record = (AssociatedLicense__c) so;
        AssociatedLicense__c oldRecord = (AssociatedLicense__c) oldSo;

        Boolean isTerminated = (oldRecord.EmploymentStatus__c != 'Terminated'
            && record.EmploymentStatus__c == 'Terminated');
        Boolean isEnded = (oldRecord.EndDate__c == null || oldRecord.EndDate__c > Date.today())
            && record.EndDate__c != null
            && record.EndDate__c <= Date.today();

        if (!isTerminated && !isEnded) {
            return;
        }

        Id relatedLicenseId = record.EmployeeLicense__c;
        if (relatedLicenseId == null) {
            return;
        }

        List<License__c> relatedLicenses = [
            SELECT Id, ActiveInactive__c, LicenseType__r.Name
            FROM License__c
            WHERE Id = :relatedLicenseId
            AND LicenseType__r.Name IN :SUPERVISOR_LOSS_LICENSE_TYPES
            AND ActiveInactive__c != 'Inactive'
        ];

        if (relatedLicenses.isEmpty()) {
            return;
        }

        if (![
            SELECT Id
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c = :relatedLicenseId
            AND Id != :record.Id
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c = null OR EndDate__c > TODAY)
            LIMIT 1
        ].isEmpty()) {
            return;
        }

        update new License__c(
            Id = relatedLicenseId,
            ActiveInactive__c = 'Inactive'
        );
    }
    // end
}