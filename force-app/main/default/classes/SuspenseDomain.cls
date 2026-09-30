public with sharing class SuspenseDomain extends SObjectDomain{
    public SuspenseDomain(List<Suspense__c> records) {
        super(records);
    }
    public Map<String, Set<String>> getLicenseId2InsuranceBondsTypes() {
        Map<String, Set<String>> insuranceBondsMap = new Map<String, Set<String>>();
        for(Suspense__c record: (List<Suspense__c>) records) {
            String licenseId = record.License__c;
            Set<String> insuranceBondTypes = new Set<String>();
            if(insuranceBondsMap.containsKey(licenseId)) {
                insuranceBondTypes = insuranceBondsMap.get(licenseId);
            }
            insuranceBondTypes.add(record.InsuranceType__c);
            insuranceBondsMap.put(licenseId, insuranceBondTypes);
        }
        return insuranceBondsMap;
    }
    //0000116600
    public Map<String, List<Suspense__c>> getLicenseId2Suspenses(Map<String, License__c> licenses) {
        Map<String, List<Suspense__c>> licenseId2Suspenses = new Map<String, List<Suspense__c>>();
        for(Suspense__c record: (List<Suspense__c>) records) {
            List<Suspense__c> suspenses = new List<Suspense__c>();
            License__c license = licenses.get(record.License__c);
            if(license.ForfeitureDate__c != record.SuspenseDueDate__c) {
                continue;
            }
            if(licenseId2Suspenses.containsKey(record.License__c)) {
                suspenses = licenseId2Suspenses.get(record.License__c);
            }
            suspenses.add(record);
            licenseId2Suspenses.put(record.License__c, suspenses);
        }
        return licenseId2Suspenses;
    }

    public List<Suspense__c> filterSupsensesByDueDate() {
        List<Suspense__c> filteredRecords = new List<Suspense__c>();
        for(Suspense__c record: (List<Suspense__c>) records) {
            Integer numberOfDays = Integer.valueOf(record.License__r.LicenseType__r.NumberOfDaysUntilAutoForfeiture__c);
            Date d = Date.today().addDays(numberOfDays);
            if(record.SuspenseDueDate__c == d) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    public set<String> getLicenseIds() {
        Set<String> licenseIds = new Set<String>();
        for(Suspense__c record: (List<Suspense__c>) records) {
            licenseIds.add(record.License__c);
        }
        return licenseIds;
    }

    
    public Map<String, List<Suspense__c>> getLicenseId2Suspenses() {
        Map<String, List<Suspense__c>> licenseId2Suspenses = new Map<String, List<Suspense__c>>();
        for(Suspense__c record: (List<Suspense__c>) records) {
            List<Suspense__c> suspenses = new List<Suspense__c>();
            if(licenseId2Suspenses.containsKey(record.License__c)) {
                suspenses = licenseId2Suspenses.get(record.License__c);
            }
            suspenses.add(record);
            licenseId2Suspenses.put(record.License__c, suspenses);
        }
        return licenseId2Suspenses;
    }
}