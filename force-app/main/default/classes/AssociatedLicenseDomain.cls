public class AssociatedLicenseDomain extends SObjectDomain{
    public AssociatedLicenseDomain(List<AssociatedLicense__c> associatedLicenses) {
        super(associatedLicenses);
    }

    public Set<String> getEntityLicenseIds() {
        Set<String> licenseIdSet = new Set<String>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            licenseIdSet.add(record.EntityLicense__c);
        }
        return licenseIdSet;
    }
    public Map<String, AssociatedLicense__c> getMostRecentExpiredLicense() {
        Map<String, AssociatedLicense__c> licenses = new Map<String, AssociatedLicense__c>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            licenses.put(record.EmployeeLicense__c, record);
        }
        for(String employeeLicenseId: licenses.keySet()) {
            AssociatedLicense__c record = licenses.get(employeeLicenseId);
            if(record.EntityLicense__r.Status__c != 'ZT - Remain Forfeited Due To Failure To Provide Proof Of Continuous Coverage of Insurance or Bond' ) {
                licenses.remove(employeeLicenseId);
            }
        }
        
        return licenses;
    }
    public Map<String, String> getEmployeeId2EntityId() {
        Map<String, String> employeeId2EntityId = new Map<String, String>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            employeeId2EntityId.put(record.EmployeeLicense__c , record.EntityLicense__c);
        }
        return employeeId2EntityId;
    }

    public Map<String, List<AssociatedLicense__c>> filterAssociatedLicensesByEntityId(Map<String, String> employee2EntityId) {
        Map<String, List<AssociatedLicense__c>> associatedLicenseMap = new Map<String, List<AssociatedLicense__c>>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            String employeeId = record.EmployeeLicense__c;
            String entityId = employee2EntityId.get(employeeId);
            if(record.EntityLicense__c != entityId) {
                List<AssociatedLicense__c> associatedLicenses = new List<AssociatedLicense__c>();
                if(associatedLicenseMap.containsKey(employeeId)) {
                    associatedLicenses = associatedLicenseMap.get(employeeId);
                }
                associatedLicenses.add(record);
                associatedLicenseMap.put(employeeId, associatedLicenses);
            }
        }
        return associatedLicenseMap;
    }
    
    // 00028240
    public Map<String, AssociatedLicense__c> getEmployeeId2AssociatedLicenses() {
        Map<String, AssociatedLicense__c> employeeId2AssociatedLicense = new Map<String, AssociatedLicense__c>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            employeeId2AssociatedLicense.put(record.EmployeeLicense__c, record);
        }
        return employeeId2AssociatedLicense;
    }

    public Set<String> getMRAssociatedLicenses() {
        Set<String> licenseIds = new Set<String>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            if(record.EmployeeLicense__r.LicenseType__r.Name == 'MR') licenseIds.add(record.EntityLicense__c);
        }

        return licenseIds;
        
    }
    public Set<String> getNoneMRAssociatedLicenses() {
        Set<String> licenseIds = new Set<String>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            if(record.EmployeeLicense__r.LicenseType__r.Name != 'MR') licenseIds.add(record.EmployeeLicense__c);
        }
        
        return licenseIds;   
    }

    public Set<String> getEntityLicenseIdsByClassificationCheck(Map<String, Boolean> licenseIdsForCheck) {
        Set<String> entityLicenseIds = new Set<String>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            if(licenseIdsForCheck.containsKey(record.EmployeeLicense__c) 
                && licenseIdsForCheck.get(record.EmployeeLicense__c)) {
                entityLicenseIds.add(record.EntityLicense__c);
            }
        }
        return entityLicenseIds;
    }

    public Set<String> filterEntityLicenseIdsByPrincipal(List<String> dependentLicenseIds) {
        Set<String> licenseIdFilter = new Set<String>();
        List<AssociatedLicense__c> pAssociatedLicenses = filterPositionStatus(new Set<String>{'P - PRINCIPAL'});
        List<String> pAssociatedLicenseIds = (List<String>) getFieldValues('EntityLicense__c');
        Map<String, List<AssociatedLicense__c>> entityId2Records = getEntityId2Records();
        
        Map<String, Set<String>> renewMap = new Map<String, Set<String>>();
        for(AssociatedLicense__c record: (list<AssociatedLicense__c>) records) {
            if(dependentLicenseIds.contains(record.EmployeeLicense__c)) {
                
                Set<String> perEmployeeIds = new Set<String>();
                if(renewMap.containsKey(record.EntityLicense__c)) {
                    perEmployeeIds = renewMap.get(record.EntityLicense__c);
                }
                perEmployeeIds.add(record.EmployeeLicense__c);
                renewMap.put(record.EntityLicense__c, perEmployeeIds);
            }
        }
        
        for(String lId: renewMap.KeySet()) {
            List<AssociatedLicense__c> aLicenses = entityId2Records.get(lId);
            Set<String> employeeIds = renewMap.get(lId);
            if(aLicenses != null && employeeIds != null && aLicenses.size() == employeeIds.size() && pAssociatedLicenseIds.contains(lId)) {
                licenseIdFilter.add(lId);
            }
        }
        return licenseIdFilter;
    }

    public Map<String, List<AssociatedLicense__c>> getEntityId2Records() {
        Map<String, List<AssociatedLicense__c>> result = new Map<String, List<AssociatedLicense__c>>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            List<AssociatedLicense__c> associatedRecords = new List<AssociatedLicense__c>();
            if(result.containsKey(record.EntityLicense__c)) {
                associatedRecords = result.get(record.EntityLicense__c);
            }
            associatedRecords.add(record);
            result.put(record.EntityLicense__c, associatedRecords);
        }
        return result;
    }
    public Boolean checkBSCAssociatedLicenses(Set<String> checklist, Map<String, List<LicenseClassification__c>> classMap) {
        Boolean isValid = !records.isEmpty();
        Set<String> result = new Set<String>();
        result.addAll(checklist);
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            String employeeLicenseId = record.EmployeeLicense__c;
            List<LicenseClassification__c> employeeClassifications = classMap.get(employeeLicenseId);
            if(employeeClassifications == null ) {
                employeeClassifications = new List<LicenseClassification__c>();
            }
            result = (new LicenseClassificationDomain(employeeClassifications)).checkClassifcationNames(result);
        }
        if(!result.isEmpty()) {
            isValid = false;
        }
        return isValid;
    }
    public Boolean checkAssociatedLicenses(Set<String> checklist, Map<String, List<LicenseClassification__c>> classMap) {
        Boolean isValid = !records.isEmpty();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            String employeeLicenseId = record.EmployeeLicense__c;
            List<LicenseClassification__c> employeeClassifications = classMap.get(employeeLicenseId);
            if(employeeClassifications == null ) {
                employeeClassifications = new List<LicenseClassification__c>();
            }
            System.debug('checkList' + checkList);
            Set<String> result = (new LicenseClassificationDomain(employeeClassifications)).checkClassifcationNames(checkList);
            System.debug('result' + result);
            if(!result.isEmpty()) {
                isValid = false;
            }
        }
        return isValid;
    }

    public List<AssociatedLicense__c> filterPositionStatus(Set<String> positionStatuses) {
        List<AssociatedLicense__c> filteredRecords = new List<AssociatedLicense__c>();
        for(AssociatedLicense__c record: (List<AssociatedLicense__c>) records) {
            if(positionStatuses.contains(record.PositionStatus__c)) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }
}