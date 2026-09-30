@isTest
private class InsurancePortalSubmissionBatchTest {
    private static testmethod void testInsurancePortalSubmissionBatch() {
        Database.executeBatch(new InsurancePortalSubmissionBatch(), 100);
        TestDataFactory.insertInsurancePortalSubmissions();
        Database.executeBatch(new InsurancePortalSubmissionBatch(), 100);
    }

    @IsTest 
    private static void DupTest(){
        Date licTypeEffectiveDate = Date.today().toStartOfMonth();
        Date licTypeExpireDate = licTypeEffectiveDate.addMonths(1).addDays(-1);

        LicenseType__c licTypeInsPort = new LicenseType__c();
        licTypeInsPort.Name = 'InsPort';
        licTypeInsPort.StartofRenewalPeriod__c = Date.today().addDays(-10);
        licTypeInsPort.LicenseTypeEffectiveDate__c = licTypeEffectiveDate;
        licTypeInsPort.DurationofLicenseInMonths__c = 1;
        licTypeInsPort.AbleToInactivate__c = true;        
        licTypeInsPort.DurationofLicenseInMonths__c = 10;
        licTypeInsPort.RollingLicensePeriod__c  = false;

        insert new LicenseType__c[]{licTypeInsPort};

        License__c licInsPort = new License__c();
        licInsPort.Name = 'InsPortLic';
        licInsPort.LicenseType__c = licTypeInsPort.Id;
        licInsPort.EffectiveExpireDate__c = licTypeExpireDate;
        licInsPort.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
        licInsPort.CEisConfirmed__c = true;
        licInsPort.ActiveInactive__c = 'Active';
        licInsPort.ThisLicenseRenewed__c = false;
        licInsPort.ExcludeFromInactivationProcess__c = true;

        insert new License__c[]{licInsPort};

        InsurancePortalSubmission__c insPor1 = new InsurancePortalSubmission__c();        
        insPor1.InsuranceType__c = 'Contractor';
        insPor1.PVLLicenseNumber__c = '34557';
        insPor1.TransactionType__c = 'CONT';
        insPor1.PolicyNumber__c = 'PT112532';
        insPor1.Status__c = 'Submitted';
        insPor1.SubmitterType__c = 'Licensed Insurance Agent';
        insPor1.Email__c = 'takashi.koyama@pacificpointcorp.com';

        InsurancePortalSubmission__c insPor2 = new InsurancePortalSubmission__c();       
        insPor2.InsuranceType__c = 'Contractor';
        insPor2.PVLLicenseNumber__c = '34557';
        insPor2.TransactionType__c = 'CONT';
        insPor2.PolicyNumber__c = 'PT112535';
        insPor2.Status__c = 'Submitted';
        insPor2.SubmitterType__c = 'Licensed Insurance Agent';
        insPor2.Email__c = 'takashi.koyama@pacificpointcorp.com';

        insert new InsurancePortalSubmission__c[]{insPor1, insPor2};

        Test.startTest();
        Database.executeBatch(new InsurancePortalSubmissionBatch(), 100);
        List<InsurancePortalSubmission__c> insPors = [Select Id, AdditionalComments__c, AuthorizedRepresentative__c, Email__c, Insurance__c, 
                ErrorReason__c, InsuranceType__c, InsurerAffordingCoverage__c, License__c, LimitEachOccurrence__c, 
                PolicyCancellationDate__c, PolicyCancellationDateDay__c, PolicyCancellationDateMonth__c, PolicyCancellationDateYear__c,
                PolicyEffectiveDate__c, PolicyEffectiveDateDay__c, PolicyEffectiveDateMonth__c, PolicyEffectiveDateYear__c, 
                PolicyExpirationDate__c, PolicyExpirationDateDay__c, PolicyExpirationDateMonth__c, PolicyExpirationDateYear__c, 
                PolicyNumber__c, PVLLicenseNumber__c, PVLLicenseType__c, PVLPortalUser__c, Status__c, SubmitterType__c,
                TransactionType__c from InsurancePortalSubmission__c 
                where Status__c = 'Submitted' and (SubmitterType__c = 'Licensed Insurance Agent'
                or (SubmitterType__c = 'Not Admitted Insurer or Leasing Company' and NonLicensedInsurerSubmittal_Approved__c = TRUE ))];
        Test.stopTest();

        Assert.areEqual(2, insPors.size());
    }
}