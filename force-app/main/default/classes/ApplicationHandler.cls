/*
* ─────────────────────────────────────────────────────────
* class for the Application Handller used to handle 
* Application trigger
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
* 05-20-2020 PacPoint:RdG - Case# 8363 - Validation Check: License to have Insurances w/ valid term dates before an Application can be updated to HC
* 10-06-2023 PacPoint:EA - Case# 30984 - Create a New Visualforce Email Templates for ADDP Approved Letter Email and New Apex Trigger to Send the Email
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class ApplicationHandler implements ITrigger{
    public static Boolean bypassInsuranceValidation = false;
    public ApplicationHandler() {}

    public void bulkBefore() {
        if(Trigger.isUpdate) {
            List<Application__c> appForRenewalSnapshot = new List<Application__c>();
            List<Application__c> newApps = (List<Application__c>) Trigger.new;
            Map<Id, Application__c> oldAppMap = (Map<Id, Application__c>) Trigger.oldMap;
            Set<String> statusFilter = new Set<String>{
                    'D1 - Awaiting Dependency Review',
                    'D2 - Continuing Education Missing',
                    'HC - Application Completed'
                    };

            for (Application__c app : newApps) {
                if ((statusFilter.contains(app.Status__c) &&
                                app.OnlineApplicationType__c == 'Online Renewal/Restore' &&
                                app.OnlineRenewalClasses__c == null &&
                                app.OnlineRenewalInsurance__c == null &&
                                app.OnlineRenewalEmployment__c == null &&
                                oldAppMap.get(app.Id).Status__c != app.Status__c) ||
                        (app.PopulateOnlineRenewalFields__c)) {
                    app.PopulateOnlineRenewalFields__c = false;
                    appForRenewalSnapshot.add(app);
                }
            }

            if (!appForRenewalSnapshot.isEmpty()) {
                ApplicationService.takeRenewalSnapshot(appForRenewalSnapshot);
            }
            ApplicationService.captureLicenseRecord(newApps);

        }
    }

    public void beforeUpdate(List<SObject> newlstObj,List<SObject> oldlstObj,Map<Id,SObject> newMapObj, Map<Id,SObject> oldMapObj) {}
    public void beforeInsert(List<SObject> newlstObj) {}
    public void bulkAfter() {
        if(Trigger.isUpdate) {
            List<String> applicationIdsForCheckOutFormGeneration = new List<String>();
            for (Application__c app : (List<Application__c>) Trigger.new) {
                if (app.GenerateCheckoutForm__c) {
                    applicationIdsForCheckOutFormGeneration.add(app.Id);
                }
            }

            if (!applicationIdsForCheckOutFormGeneration.isEmpty()) {
                //case 00020872
                ApplicationService.generateCheckoutForm(applicationIdsForCheckOutFormGeneration);
            }
        }
    }
    public void beforeInsert(SObject so) {
        //00005043 capture applicaiton if phase is L - License Review
        ApplicationService.captureLLicenseReview(so);
        ApplicationService.ensureRenewByPermitToPracticeValue(so);
    }

    public void afterInsert(SObject so) {
        // 00003563: Application Type "LICN" or "RNEW", Create Application requirements based on LicenseTypeRequirements
        ApplicationService.captureLicenseTypeCheck(so);
        // 00003450: Trigger on Application to mark Application Classification Records that are not on Dependent License or Dependent Applicaiton
        ApplicationService.updateApplicationClassification(so);
        // 00005439: On Application Type: "REAC - Reactivation", Created Related Application Requirements based on CurrentLicense__c
        ApplicationService.populateLicenseRequirements(so);
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
        //PacPoint:RdG - Case# 8363 - Validation Check: License to have Insurances w/ valid term dates before an Application can be updated to HC
        if(!bypassInsuranceValidation) ApplicationService.validationLicenseRenew(oldSo, so);  
        //00005043 capture applicaiton if phase is L - License Review
        ApplicationService.captureLLicenseReview(oldSo, so);
        // Case id 00005902 Dymatic Create PDF 
        ApplicationService.PDFGeneration(oldSo, so);
        // 00014255
        ApplicationService.generateOnlineRenewalCopy(oldSo, so);
        ApplicationService.ensureRenewByPermitToPracticeValue(so);
        

        // 00029513
        ApplicationService.captureSendApprovedForExamLetterEmail(oldSo, so);

        // 00030984
        ApplicationService.captureSendADDPApprovedLetterEmail(oldSo, so);
    }

    public void beforeUnDelete(SObject so) {} 
    public void afterUpdate(SObject oldSo, SObject so) {
        // 00003563: Application Type "LICN" or "RNEW", Create Application Requirements based on LicenseTypeRequirements
        ApplicationService.captureLicenseTypeCheck(oldSo, so);
        // 00003450: Trigger on Application to mark Application Classification Records that are not on Dependent License or Dependent Applicaiton
        ApplicationService.updateApplicationClassification(oldSo, so);
        // 00008048
        ApplicationService.captureLicensePeriodChange(oldSo, so);
        
    }

    public void beforeDelete(SObject so){} 
    public void afterDelete(SObject so) {} 
    public void afterUnDelete(SObject so) {} 
    public void andFinally() {
        ApplicationService.runFinally(Trigger.new);
    }
}