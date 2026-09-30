/*
* ─────────────────────────────────────────────────────────
* Used for testing Suspense Batch Job
* Suspense records
* ─────────────────────────────────────────────────────────
* PacPoint-CZ091520- Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp
* @created      2020-09-15
* ───────────────────────────────────────────────────────────
* Changes
* 00010827 - Batch Job for Suspense Record Deletion
* ───────────────────────────────────────────────────────────
*/
@isTest(SeeAllData=false)
public with sharing class SuspenseDeletionBatchJobTest {
    @TestSetup
    static void makeData(){
        TestDataFactory.prepareAssociatedLicenses();
        List<License__c> licenses =  [Select Id, FlaggedforAudit__c from License__c] ;
        List<AssociatedLicense__c> associatedRecords = [Select Id from AssociatedLicense__c ];
        for(AssociatedLicense__c record: associatedRecords) {
            record.PositionStatus__c = 'P - PRINCIPAL';
        }
        update associatedRecords;
        TestDataFactory.insertInsuranceBonds(licenses);
        List<Suspense__c> suspenses = new List<Suspense__c>();
        Integer index = 0;
        for(License__c record: licenses) {
            Suspense__c suspense = new Suspense__c();
            suspense.License__c = record.Id;
            suspense.InsuranceType__c = 'BD - Bond';
            suspense.SuspenseDueDate__c = System.today() + 10;
            if(index == 0) {
                suspense.Delete__c = true;
            } else if(index == 1) {
                suspense.MaintenanceType__c = 'NPRM - NO PRINCIPAL RME';
            } else if(index == 2) {
                suspense.MaintenanceType__c = 'NFEM - NO FIRM DUE TO EMPLOYMENT TERMINATION';
            } else {
                suspense.MaintenanceType__c = 'NFRM - RME WITHOUT EMPLOYMENT' ;
            }
            index ++;
            suspenses.add(suspense);
        }
        
        insert suspenses;
    }
    public static testMethod void test_SuspenseDeletionBatchJobTest() {
        Test.StartTest();
        List<LicenseType__c> ltypes = [Select Id, RequiresInsurance__c from LicenseType__c];
        for(LicenseType__c ltype: ltypes) {
            ltype.RequiresInsurance__c = true;
        }
        update ltypes;

        List<Suspense__c> suspenses = [Select Id, Name, License__c, InsuranceType__c, License__r.LicenseType__r.RequiresInsurance__c, MaintenanceType__c, Delete__c from Suspense__c];
        /* run SuspenseDeletionBatchJobTest class */
        SuspenseDeletionBatchJob abj = new SuspenseDeletionBatchJob();
        Database.executeBatch(abj, 50);
        abj.execute(null, suspenses);
        Test.StopTest();
    }
}