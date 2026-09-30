/*
 * ___________________________________________________________________________________
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL03312020 - Created for
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/31/2020
 * __________________________________________________________________________________
 */
public class InsuranceBondHandler implements ITrigger{
    public void bulkBefore() {
        if (Trigger.isInsert) {
            InsuranceBondService.populateGapInInsurance(Trigger.new);
        }

        if (Trigger.isUpdate) {
            List<InsuranceBond__c> insuranceToUpdate = new List<InsuranceBond__c>();
            List<InsuranceBond__c> ins = (List<InsuranceBond__c>) Trigger.new;
            Map<Id, InsuranceBond__c> oldMap = (Map<Id, InsuranceBond__c>)Trigger.oldMap;
            for (InsuranceBond__c i : ins) {
                if (i.Status__c == 'Active' && oldMap.get(i.Id).EffectiveDate__c != i.EffectiveDate__c) {
                    insuranceToUpdate.add(i);
                }

                //Added by Sohan 02/05/26
                if (i.Type__c == 'BD - Bond' && i.Status__c == 'Inactive' && oldMap.get(i.Id).Status__c == 'Active' && i.License__c != null) {
                    i.CancelDate__c = Date.today();
                }
                //
            }

            if (!insuranceToUpdate.isEmpty()) {
                InsuranceBondService.populateGapInInsurance(insuranceToUpdate);
            }
        }
    }

    public void bulkAfter() {
        //Added by Sohan 02/02/26
        //Updated by Akanksha 05/05/26 - capture the just-inactivated bond IDs
        //so the service can exclude them from the "another Active Bond" check.
        if (Trigger.isUpdate) {
            Set<Id> licenseIdSet = new Set<Id>();
            Set<Id> inactivatedBondIdSet = new Set<Id>();
            List<String> ctLicenseIdList = new List<String>();
            List<InsuranceBond__c> ins = (List<InsuranceBond__c>) Trigger.new;
            Map<Id, InsuranceBond__c> oldMap = (Map<Id, InsuranceBond__c>)Trigger.oldMap;
            for (InsuranceBond__c i : ins) {
                if (i.Type__c == 'BD - Bond' && i.Status__c == 'Inactive' && oldMap.get(i.Id).Status__c == 'Active' && i.License__c != null) {
                    licenseIdSet.add(i.License__c);
                    inactivatedBondIdSet.add(i.Id);
                }
            }

            for(License__c ctLicense: [SELECT Id FROM License__c WHERE Id IN :licenseIdSet AND (LicenseType__r.Name = 'CT - Entity' OR LicenseType__r.Name = 'CT - Sole Proprietor')]){
                ctLicenseIdList.add(ctLicense.Id);
            }

            if (!ctLicenseIdList.isEmpty()) {
                InsuranceBondService.updateLicensesLikeIndSuspenseBatch(ctLicenseIdList, inactivatedBondIdSet);
            }
        }
        //
    }

    public void beforeInsert(SObject so) {
       
    }

    public void beforeUpdate(List<SObject> newlstObj,
                             List<SObject> oldlstObj,
                             Map<Id, SObject> newMapObj,
                             Map<Id, SObject> oldMapObj) {
    }

    public void beforeUpdate(SObject oldSo, SObject so) {

    }

    public void beforeDelete(SObject so) {
    }

    public void beforeUnDelete(SObject so) {
    }

    public void afterInsert(SObject so) {
        // commented as requested from 00009219
        // 7741 to capture the inactive Status
        // InsuranceBondService.captureActiveStatus(so);
        InsuranceBondService.captureSubmittedInsurance(so);
    }

    public void afterUpdate(SObject oldSo, SObject so) {
        // commented as requested from 00009219
        // 7741 to capture the inactive Status
        // InsuranceBondService.captureInactiveStatus(oldSo, so);
        InsuranceBondService.captureSubmittedInsurance(oldSo, so);
    }

    public void beforeInsert(List<SObject> newlstObj) {
    }

    public void afterDelete(SObject so) {
    }

    public void afterUnDelete(SObject so) {
    }

    public void andFinally() {
        /****commented as requested in case 00009219
         * if(Trigger.isAfter) {
            List<InsuranceBond__c> ins = (Trigger.isDelete ? (List<InsuranceBond__c>) Trigger.old : (List<InsuranceBond__c>) Trigger.new); //Updated by Rumina - 28/07/2020
            InsuranceBondService.updateLicenseStatusViaType(ins);
        }***/
        if(Trigger.isAfter) {
            InsuranceBondService.runLicenseChecks(Trigger.new);
        }
    }
}