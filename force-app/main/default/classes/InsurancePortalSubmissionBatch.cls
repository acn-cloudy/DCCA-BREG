global class InsurancePortalSubmissionBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    public String query ;
    public List<Id> allLicenseIds = new List<Id>();
    global InsurancePortalSubmissionBatch() {
        query = 'Select Id, AdditionalComments__c, AuthorizedRepresentative__c, Email__c, Insurance__c, '
            +'ErrorReason__c, InsuranceType__c, InsurerAffordingCoverage__c, License__c, LimitEachOccurrence__c, '
            +'PolicyCancellationDate__c, PolicyCancellationDateDay__c, PolicyCancellationDateMonth__c, PolicyCancellationDateYear__c,'
            +' PolicyEffectiveDate__c, PolicyEffectiveDateDay__c, PolicyEffectiveDateMonth__c, PolicyEffectiveDateYear__c, '
            +'PolicyExpirationDate__c, PolicyExpirationDateDay__c, PolicyExpirationDateMonth__c, PolicyExpirationDateYear__c, '
            +'PolicyNumber__c, PVLLicenseNumber__c, PVLLicenseType__c, PVLPortalUser__c, Status__c, SubmitterType__c,'
            +' TransactionType__c from InsurancePortalSubmission__c '
            + ' where Status__c = \'Submitted\' and ( SubmitterType__c = \'Licensed Insurance Agent\' ' 
            + ' or (SubmitterType__c = \'Not Admitted Insurer or Leasing Company\' and NonLicensedInsurerSubmittal_Approved__c = TRUE ))';
    }
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        LicenseService.disableUpdateAssociatedEntity = true;
        List<InsurancePortalSubmission__c> portalSubmissions = (List<InsurancePortalSubmission__c> )scope;
        List<InsurancePortalSubmission__c> filteredRecordsForInsurance = (new InsurancePortalSubmissionDomain(
            portalSubmissions)).filterInsurancePortalSubmissionForBondCreate();
        List<InsuranceBond__c> bonds = (new InsurancePortalSubmissionDomain(filteredRecordsForInsurance)).createInsuranceCoverage();

        // If the duplicate rule is an alert rule, we can try to bypass it
        Database.DMLOptions dml = new Database.DMLOptions(); 
        dml.DuplicateRuleHeader.AllowSave = true;
       
        List<Database.SaveResult> results = Database.insert(bonds, dml);
        for(Integer i= 0;i< results.size(); i++) {
            if(results.get(i).isSuccess()) {
                filteredRecordsForInsurance.get(i).Insurance__c = results.get(i).getId();
                filteredRecordsForInsurance.get(i).Status__c = 'Successfully Processed';
            } else {
                filteredRecordsForInsurance.get(i).Status__c = 'Error';
            }
        }
        


        List<InsurancePortalSubmission__c> recordsForCancellation = (new InsurancePortalSubmissionDomain(portalSubmissions)).filterInsurancePortalSubmissionForCancellation();
        List<String> licenseIds = (List<String>) (new InsurancePortalSubmissionDomain(recordsForCancellation)).getFieldValues('License__c');
        List<InsuranceBond__c> insuranceBondForCancellation = InsuranceBondSelector.getInsuranceBonds(licenseIds);
        Map<String, List<InsurancePortalSubmission__c>> insurancePortalSubmissionMap = (new InsurancePortalSubmissionDomain(
            recordsForCancellation)).convertLicenseIdToInsurancePortalSubmission();
        
        List<InsuranceBond__c> bondsForUpdate = (new InsuranceBondDomain(
                insuranceBondForCancellation)).updateInsuranceBondForCancellation(insurancePortalSubmissionMap);
        
        List<Database.SaveResult> updateResults = Database.update(bondsForUpdate, dml);
        
        Map<String, String> messageMap = new Map<String, String>();
        for(Database.SaveResult savedResult : updateResults) {
            if(savedResult.isSuccess()) {
                messageMap.put(savedResult.getId(), 'Successfully Processed');
            } else {
                messageMap.put(savedResult.getId(), 'Error');
            }
        }

        List<InsurancePortalSubmission__c> cancelledSubmissionsForUpdate = (new InsuranceBondDomain(insuranceBondForCancellation)).updateInsuranceSubmissionStatus(
            insurancePortalSubmissionMap, messageMap);
        List<String> cancelledSubmissionIds = (new InsurancePortalSubmissionDomain(cancelledSubmissionsForUpdate)).getIds();
        Set<String> cancelledSubmissionIdSet = new Set<String>();
        cancelledSubmissionIdSet.addAll(cancelledSubmissionIds);
        filteredRecordsForInsurance.addAll(cancelledSubmissionsForUpdate);
        /****** Set the InsurancePortalSubmission__c.Status__c = "Error"

Set the Error Reason = "Unable to find a matching Insurance Record" 
 */
        filteredRecordsForInsurance.addAll((new InsurancePortalSubmissionDomain(recordsForCancellation)).failRemainingCancelledInsurancePortalSubmission(cancelledSubmissionIdSet));
        update filteredRecordsForInsurance;
        allLicenseIds.addAll(licenseIds);

    }
    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new InsurancePortalSubmissionBatch(), 50);
	}
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        if(!allLicenseIds.isEmpty()) {
            Database.executeBatch(new BatchUpdateActiveEmployeeLicenseNum(allLicenseIds), 50);
            allLicenseIds.clear();
        }
    }
}