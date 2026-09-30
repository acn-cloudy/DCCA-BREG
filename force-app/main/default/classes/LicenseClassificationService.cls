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
public with sharing class LicenseClassificationService {
    

    private static List<LicenseClassification__c> licenseClassificationIdToBeUpdate = new List<LicenseClassification__c>();

    //00005655 : New
    public static void updateLicensePrefix(SObject so) {
        updateLicensePrefix(null, so);
    }

    //00005655 : Update
    public static void updateLicensePrefix(SObject oldSo, SObject so) {
        LicenseClassification__c licenseClassification = (LicenseClassification__c) so;
        LicenseClassification__c oldLicenseClassification = null;
        if(oldSO != null ) {
            oldLicenseClassification = (LicenseClassification__c) oldSo;
        }

        if(oldLicenseClassification == null 
           && licenseClassification.Classification__c != null
           && licenseClassification.Status__c != null 
           && licenseClassification.Status__c == 'C - Current, Valid & In Good Standing') {
            licenseClassificationIdToBeUpdate.add(licenseClassification);
        }

        if(oldLicenseClassification != null 
           && (licenseClassification.Classification__c != oldLicenseClassification.Classification__c
           || licenseClassification.Status__c != oldLicenseClassification.Status__c)) {
            licenseClassificationIdToBeUpdate.add(licenseClassification);
        }
    }

    // call domain now 00006113
    public static void updateLicensePrefix(List<LicenseClassification__c> records) {
        List<String> licenseIds = (List<String>)(new LicenseClassificationDomain(records)).getFieldValues('License__c');
        Map<Id, List<SObject>> licenseToLicenseClassificationMap = new Map<Id, List<SObject>>();
        // if the License.LicenseType.LicensePrefix="CT"
        licenseToLicenseClassificationMap.putAll(new PVL_Selector().getSObjectRecordsByField('LicenseClassification__c', 'License__c', licenseIds, 
                'AND Status__c = \'C - Current, Valid & In Good Standing\' and License__r.LicenseType__r.LicensePrefix__c = \'CT\'', 'CreatedDate', ',Classification__r.Code__c')
                                                                   .getMapByIdField('License__c'));
                                                                   
        //List<String> licenseIds = (List<String>)JSON.deserialize(JSON.serialize(licenseToLicenseClassificationMap.keySet()), List<String>.class);
        List<SObject> licenseRecords = new PVL_Selector().getSObjectRecordsByField('License__c', 'Id', licenseIds, '', 'CreatedDate', '')
                                                          .getSObjectList();

        Map<String, String> licenseIdToClassPrefix_M = (new LicenseClassificationDomain(records)).doClassPrefix(licenseToLicenseClassificationMap);

        system.debug('x1' + licenseIdToClassPrefix_M);
        // get all License__c for updating ClassPrefix__c field
        List<License__c> licenseToUpdate 
            = (new LicenseDomain((List<License__c>)licenseRecords)).updateClassPrefix(licenseIdToClassPrefix_M);
        system.debug('x2' + licenseToUpdate);
        update licenseToUpdate;
    }

    public static void runFinally(List<LicenseClassification__c> licenseClassifications) {
        if(Trigger.isAfter != null && Trigger.isAfter) {
            if(!licenseClassificationIdToBeUpdate.isEmpty()) {
                updateLicensePrefix(licenseClassificationIdToBeUpdate);
                licenseClassificationIdToBeUpdate.clear();
            }
        }
    }

    public static Map<String, Boolean> checkClassNames(List<String> licenseIds) {
        List<LicenseClassification__c> licenseClassifications 
            = LicenseClassificationSelector.getLicenseClassifications(licenseIds);
        Map<String, List<LicenseClassification__c>> classifications 
            = (new LicenseClassificationDomain(licenseClassifications)).getLicenseId2Classifications();
        Map<String, Boolean> licenseWithAllClasses = new Map<String, Boolean>();
        for(String employeelicenseId: classifications.keySet()) {
            List<LicenseClassification__c> records = classifications.get(employeeLicenseId);
            licenseWithAllClasses.put(employeeLicenseId, 
                (new LicenseClassificationDomain(records)).checkHasAllClassification());
        }
        return licenseWithAllClasses;
    }
}