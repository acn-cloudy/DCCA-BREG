public with sharing class InsuranceBondDomain extends SObjectDomain{
    public InsuranceBondDomain(List<InsuranceBond__c> insuranceBonds) {
        super(insuranceBonds);
    }
    public List<InsuranceBond__c> updateInsuranceBondForCancellation(
            Map<String, List<InsurancePortalSubmission__c>> insurancePortalSubmissionMap) {
        Map<String, String> typeValueMap = new Map<String, String>();
        typeValueMap.put('LP - Liability / Property Damage', 'General Liability');
        typeValueMap.put('LI - Liability', 'Liability');
        typeValueMap.put('WC - Workers Compensation', 'Workers Comp');                
        List<InsuranceBond__c> recordsForUpdate = new List<InsuranceBond__c>();
        for(InsuranceBond__c record: (List<InsuranceBond__c>)records) {
            if(record.Status__c != 'Active' && record.Status__c != 'Pending') continue;
            if(!typeValueMap.containsKey(record.Type__c) ) continue;
            String licenseId = record.License__c;
            String checkInsuranceType = typeValueMap.get(record.Type__c);
            List<InsurancePortalSubmission__c> insurancePortalSubmissions = insurancePortalSubmissionMap.get(licenseId);
            Boolean foundResult = false;
            for(InsurancePortalSubmission__c submission: insurancePortalSubmissions) {
                if(submission.InsuranceType__c == checkInsuranceType) {
                    foundResult = true;
                    record.CancelDate__c = submission.PolicyCancellationDate__c;
                    break;
                }
            }
            if(foundResult) {
                recordsForUpdate.add(record);
            }
                
            }
            return recordsForUpdate;
        }
    public List<InsurancePortalSubmission__c> updateInsuranceSubmissionStatus(
        Map<String, List<InsurancePortalSubmission__c>> insurancePortalSubmissionMap, 
        Map<String, String> messageMap) {
        Map<String, String> typeValueMap = new Map<String, String>();
        typeValueMap.put('LP - Liability / Property Damage', 'General Liability');
        typeValueMap.put('LI - Liability', 'Liability');
        typeValueMap.put('WC - Workers Compensation', 'Workers Comp');                
        List<InsurancePortalSubmission__c> submissions = new List<InsurancePortalSubmission__c>();
        Set<Id> submissionIdSet = new Set<Id>();
        for(InsuranceBond__c record: (List<InsuranceBond__c>)records) {
            if(record.Status__c != 'Active' && record.Status__c != 'Pending') continue;
            if(!typeValueMap.containsKey(record.Type__c) ) continue;
            String licenseId = record.License__c;
            String checkInsuranceType = typeValueMap.get(record.Type__c);
            List<InsurancePortalSubmission__c> insurancePortalSubmissions = insurancePortalSubmissionMap.get(licenseId);
            Boolean foundResult = false;
            for(InsurancePortalSubmission__c submission: insurancePortalSubmissions) {
                if(submission.InsuranceType__c == checkInsuranceType && !submissionIdSet.contains(submission.Id)) {
                    submission.Insurance__c = record.Id;
                    submission.Status__c = messageMap.get(record.Id);
                    submissions.add(submission);
                    submissionIdSet.add(submission.Id);
                    break;
                }
            }
        }
        return submissions;

    }
    public List<InsuranceBond__c> filterRecordsByIdSet(Set<String> idSet) {
        List<InsuranceBond__c> filteredRecords = new List<InsuranceBond__c>();
        for(InsuranceBond__c record: (List<InsuranceBond__c>)records) {
            if(idSet.contains(record.Id)) {
                filteredRecords.add(record);   
            }

        }
        return filteredRecords;
    }

    public Set<String> getInsuranceTypes() {
        Set<String> existingInsuranceTypeSet = new Set<String>();
        for(InsuranceBond__c record: (List<InsuranceBond__c>)records) {
            existingInsuranceTypeSet.add(record.Type__c);
        }
        return existingInsuranceTypeSet;
    }

    public List<InsuranceBond__c> filterInsuranceBonds(License__c license, Set<String> insuranceTypes) {
        Map<String, InsuranceBond__c> insuranceBondWithSameType = new Map<String, InsuranceBond__c>();
        // List<InsuranceBond__c> filteredRecords = new List<InsuranceBond__c>();
        Decimal breakinInsuranceAllowed = license.LicenseType__r.BreakinInsuranceCoverageAllowed__c;
        if(breakinInsuranceAllowed == null) {
            breakinInsuranceAllowed = 0;
        }

        for(InsuranceBond__c record: (List<InsuranceBond__c>)records) {
            if((record.Status__c == 'Active' || record.Status__c == 'Waived' || record.Status__c == 'Pending') &&
                (record.CurrentGapinInsurance__c== null 
                || record.CurrentGapinInsurance__c <= breakinInsuranceAllowed) && insuranceTypes.contains(record.Type__c)) {
                    
                if(insuranceBondWithSameType.containsKey(record.Type__c))  {
                    InsuranceBond__c existingRecord = insuranceBondWithSameType.get(record.Type__c);
                    if ((existingRecord.CancelDate__c != null && existingRecord.CancelDate__c <= license.EffectiveExpireDate__c ) 
                        || (existingRecord.TermDate__c != null && existingRecord.TermDate__c <= license.EffectiveExpireDate__c)) {
                        insuranceBondWithSameType.put(record.Type__c, record);
                    }
                } else {
                    insuranceBondWithSameType.put(record.Type__c, record);
                }
                

                //filteredRecords.add(record);
            }
        }
        return insuranceBondWithSameType.values();
    }

    public List<InsuranceBond__c> filterInsuranceBonds(License__c license) {
        List<InsuranceBond__c> filteredRecords = new List<InsuranceBond__c>();
        Decimal breakinInsuranceAllowed = license.LicenseType__r.BreakinInsuranceCoverageAllowed__c;
        if(breakinInsuranceAllowed == null) {
            breakinInsuranceAllowed = 0;
        }

        for(InsuranceBond__c record: (List<InsuranceBond__c>)records) {
            if((record.Status__c == 'Active' || record.Status__c == 'Waived' || record.Status__c == 'Pending') &&
                (record.CurrentGapinInsurance__c== null 
                || record.CurrentGapinInsurance__c <= breakinInsuranceAllowed)) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    public List<InsuranceBond__c> getActiveInsurancebonds(Date coverageThroughDate) {
        List<InsuranceBond__c> activeBonds = new List<InsuranceBond__c>();
        if (coverageThroughDate == null) {
            return activeBonds;
        }
        for (InsuranceBond__c record : (List<InsuranceBond__c>) records) {
            if (record.Status__c != 'Inactive'
                && (record.TermDate__c == null || record.TermDate__c > coverageThroughDate)
                && (record.CancelDate__c == null || record.CancelDate__c > coverageThroughDate)) {
                activeBonds.add(record);
            }
        }
        return activeBonds;
    }

    public List<InsuranceBond__c> getActiveInsurancebonds(License__c license) {
        return getActiveInsurancebonds(license.EffectiveExpireDate__c);
    }

    public List<InsuranceBond__c> getActiveInsurancebonds(Application__c app) {
        return getActiveInsurancebonds(app.CompleteApplicationBy__c);
    }

    public Set<String> getMissingRequiredTypes(License__c license) {
        Set<String> typeSetRequired = new Set<String>();

        Set<String> existingInsuranceBondTypes = new Set<String>();
        String insuranceBondTypeStr = license.LicenseType__r.InsuranceBondTypesRequired__c;
        // if insuranceBondTypeStr has no value, return empty list
        if(String.isBlank(insuranceBondTypeStr) ) {
            return typeSetRequired;
        }
        System.debug('####insuranceBondTypeStr#####' + insuranceBondTypeStr);
        List<String> typesRequired = insuranceBondTypeStr.split(';');
        
        typeSetRequired.addAll(typesRequired);

        List<InsuranceBond__c> filteredRecords = filterInsuranceBonds(license);

        List<String> insuranceTypes = (List<String>)(new InsuranceBondDomain(filteredRecords)).getFieldValues('Type__c');
        existingInsuranceBondTypes.addAll(insuranceTypes);

        System.debug('####existingInsuranceBondTypes#####' + existingInsuranceBondTypes);

        for(String requiredType: typesRequired) {
            if(existingInsuranceBondTypes.contains(requiredType)) {
                typeSetRequired.remove(requiredType);
            } else {
                Set<String> substituteTypes = InsuranceBondService.insuranceBondSubstitutes.get(requiredType);
                if(substituteTypes == null) continue;
                for(String substituteType: substituteTypes) {
                    if(existingInsuranceBondTypes.contains(substituteType)) {
                        typeSetRequired.remove(requiredType);
                    }
                }
            }
        }
        return typeSetRequired;
    }

    public Map<String, List<InsuranceBond__c>> getLicenseId2InsuranceBonds() {
        Map<String, List<InsuranceBond__c>> insuranceBondsMap = new Map<String, List<InsuranceBond__c>>();
        for(InsuranceBond__c record: (List<InsuranceBond__c>) records) {
            String licenseId = record.License__c;
            List<InsuranceBond__c> insuranceBonds = new List<InsuranceBond__c>();
            if(insuranceBondsMap.containsKey(licenseId)) {
                insuranceBonds = insuranceBondsMap.get(licenseId);
            }
            insuranceBonds.add(record);
            insuranceBondsMap.put(licenseId, insuranceBonds);
        }
        return insuranceBondsMap;
    }
}