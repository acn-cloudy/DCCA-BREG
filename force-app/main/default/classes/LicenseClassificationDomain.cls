/*
* ─────────────────────────────────────────────────────────
* class for the Application Handller used to handle 
* Application trigger
* ─────────────────────────────────────────────────────────
* PacPoint-CZ190919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-09-19
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class LicenseClassificationDomain extends SObjectDomain{
    public LicenseClassificationDomain(List<LicenseClassification__c> licenseClassifications) {
        super(licenseClassifications);
    }

    // Used to update ClassPrefix__c on Lincese object.
    public Map<String, String> doClassPrefix(Map<Id, List<SObject>> licenseToLicenseClassificationMap) {
        Map<String, String> licenseIdToClassPrefix_M = new Map<String, String>();
        for (Id key : licenseToLicenseClassificationMap.keySet()) {
            String classPrefix = '';
            Set<String> prefixSet = new Set<String>();
            prefixSet.add('C');
            for (Sobject so : licenseToLicenseClassificationMap.get(key)) {
                LicenseClassification__c lc = (LicenseClassification__c) so;
                String status = lc.Status__c;
                
                if(status != null) {
                    String statusCode = status.substring(0, 1);
                    prefixSet.add(statusCode);
                }
                prefixSet.add(lc.Classification__r.Code__c);
                // if (lc.Classification__r.Code__c == 'A') {
                //     classPrefix += 'A';
                // } else if (lc.Classification__r.Code__c == 'B') {
                //     classPrefix += 'B';
                // } else if (lc.Classification__r.Code__c == 'C') {
                //     classPrefix += 'C';
                // }
            }

            //Case 00006113 PacPoint-CL103119 - Created for PVL Phase 1
            // if (!classPrefix.endsWith('C')) {
            //     classPrefix += 'C';
            // }
            List<String> prefixList = new List<String> (prefixSet);
            prefixList.sort();   
            classPrefix = String.join(prefixList, '');
            // licenseIdToClassPrefix_M.put(key, sortStringABC(classPrefix));
            licenseIdToClassPrefix_M.put(key, classPrefix);
        }
        return licenseIdToClassPrefix_M;
    }

    //sort ABC
    public String sortStringABC(String inString) {
        if (inString == '' || inString == null)
        return '';
        
        List<String> stringCharacters = inString.split('');
        stringCharacters.sort();

        return string.join(stringCharacters, '');
    }

    public void updateStatusBasedOnLicenseType(Map<String, License__c> licenses) {
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            if(licenses.containsKey(record.License__c)) {
                record.Status__c = licenses.get(record.License__c).LicenseType__r.ClassStatusDueToNonRenewal__c;
                record.EndDate__c =  licenses.get(record.License__c).EffectiveExpireDate__c;
            }
        }
    }

    // add for case 7697
    public List<LicenseClassification__c> updateStatusBasedOnAssociatedLicense(Map<Id, List<String>> idToClassificationNameMap) {
        // 4. Check to make sure the Classification Name from step 1 is contained in at least one of the Classification records in Step 3.
        List<LicenseClassification__c> licenseClassificationsForUpdate = new List<LicenseClassification__c>();
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            if(idToClassificationNameMap.containsKey(record.License__c)) {
                // 5. For any LicenseClassification__c records under the triggering License__c record that do not exist in step 4, set the LicenseClassification__cStatius__c  =   License__c.LicenseType__c.ClassStatusDueto LossofDependent__c
                List<String> classificationNameList = idToClassificationNameMap.get(record.License__c);
                if (!classificationNameList.contains(record.ClassificationName__c)) {
                    record.Status__c = record.License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c;
                    licenseClassificationsForUpdate.add(record);
                }
            }
        }
        return licenseClassificationsForUpdate;
    }
    
    // add for case 7697
    public List<LicenseClassification__c> updateLicenseClassificationStatus() {
        // 2.2 Update all LicensesClassification__c records where LicenseClassification__c.Status__c = "C - Current, Valid & In Good Standing" to License__c.LicenseType__c.ClassStatusDueto LossofDependent__c
        List<LicenseClassification__c> licenseClassificationsForUpdate = new List<LicenseClassification__c>();
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
        	record.Status__c = record.License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c;
            licenseClassificationsForUpdate.add(record);
        }
        return licenseClassificationsForUpdate;
    }

    // 
    public Map<String, List<LicenseClassification__c>> getLicenseId2Classifications() {
        Map<String, List<LicenseClassification__c>> classifications = new Map<String, List<LicenseClassification__c>>();
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            List<LicenseClassification__c> cClassifications = new List<LicenseClassification__c>();
            if(classifications.containsKey(record.License__c)) {
                cClassifications = classifications.get(record.License__c);
            }
            cClassifications.add(record);
            classifications.put(record.License__c, cClassifications);
        }
        return classifications;
    }

    public Map<String, Set<String>> getLicenseeId2LicenseSet() {
        Map<String, Set<String>> cMap = new Map<String, Set<String>>();
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            Set<String> licenseIds = new Set<String>();
            if(cMap.containsKey(record.License__r.Licensee__c)) {
                licenseIds = cMap.get(record.License__r.Licensee__c);
            }
            licenseIds.add(record.License__c);
            cMap.put(record.License__r.Licensee__c, licenseIds);
        }
        return cMap;
    }

    public Set<String> getClassifcationNames() {
        Set<String> checklist = new Set<String> ();
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            checklist.add(record.ClassificationName__c);
        }
        return checklist;
    }

    public Set<String> checkClassifcationNames(Set<String> checklist) {
        Set<String> checkListSet = new Set<String>();
        checkListSet.addAll(checklist);
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            checkListSet.remove(record.ClassificationName__c);
        }
        return checkListSet;
    }

    public Boolean checkHasAllClassification() {
        Set<String> checklist = new Set<String> {
            'A1 Engine Repair','A2 Automatic Transmission/Transaxle', 'A3 Manual Drive Train and Axles',
            'A4 Suspension and Steering', 'A5 Brakes', 'A6 Electrical/Electronic Systems',
            'A7 Heating and Air Conditioning', 'A8 Engine Performance'};
        for(LicenseClassification__c record: (List<LicenseClassification__c>) records) {
            checklist.remove(record.ClassificationName__c);
        }
        return checklist.isEmpty();
    }

}