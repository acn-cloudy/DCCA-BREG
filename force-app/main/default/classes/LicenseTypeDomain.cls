/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Application Record Create component
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
*  PacPoint-AZ200919 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class LicenseTypeDomain extends SObjectDomain{
    public LicenseTypeDomain(List<LicenseType__c> licenseTypes) {
        super(licenseTypes);
    }
    // 00005294 get Id 2 License Type
    public Map<String, LicenseType__c> getIdToLicenseType() {
        Map<String, LicenseType__c> idTolicenseType = new Map<String, LicenseType__c>();
        for(Sobject record: records) {
            LicenseType__c licenseType = (LicenseType__c) record;
            idTolicenseType.put(licenseType.Id, licenseType);
        }
        return idTolicenseType;
    }
    // 00005676 to have the default page layou set if the page layout is empty.
    public void updateWithDefaultPageLayout(PVLSettings__mdt setting) {
        for(SObject record: records) {
            LicenseType__c licenseType = (LicenseType__c)record;
            if(String.isBlank(licenseType.ApplicationPageLayout__c ) ) {
                licenseType.ApplicationPageLayout__c = setting.ApplicationWizardPageLayoutDefault__c;
            }
        }
    }

    /******00006486 ****used to get list of License Types***/
    public List<License__c> filterLicensesByCushionPercent(Map<String, List<License__c>> licenseTypeId2Licenses) {
        List<License__c> licensesForUpdate = new List<License__c>();
        for(LicenseType__c licenseType: (List<LicenseType__c>) records) {
            if(licenseType.AuditCushionPercent__c == null) {
                continue;
            }
            Decimal percentage = licenseType.AuditCushionPercent__c/100;
            List<License__c> licenses = licenseTypeId2Licenses.get(licenseType.Id);
            if(licenses == null) continue;
            Integer totalSize = licenses.size();
            System.debug('######totalsize####' + totalSize);
            
            Integer numForUse = Integer.valueOf(totalSize * percentage);
            if(percentage > 0 && totalSize >0 && numForUse  == 0) {
                numForUse = 1;
            } else if(numForUse == 0) continue; 
            Integer modCap = totalSize/numForUse;
            Integer maxModNumber = modCap;
            Integer luckyNumber = Integer.valueof((Math.random() * maxModNumber));
            for(Integer i=0;i < licenses.size(); i++) {
                if(Math.mod(i, modCap) == luckyNumber) {
                    licenses.get(i).FlaggedforAudit__c = true;
                    licenses.get(i).GenerateFlaggedForAuditNotification__c = true;
                    licensesForUpdate.add(licenses.get(i));
                }
            }
        }
        return licensesForUpdate;
    }
}