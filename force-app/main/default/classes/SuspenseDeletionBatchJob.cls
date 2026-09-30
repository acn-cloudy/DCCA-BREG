/*
* ─────────────────────────────────────────────────────────
* Used for Suspense Deletion Batch Job
* Suspense__c records
* ─────────────────────────────────────────────────────────
* PacPoint-CZ091520- Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp
* @created      2020-09-15
* ───────────────────────────────────────────────────────────
* Update
* @author       Takashi Koyama - PacificPointCorp
* @created      2022-12-02
* ───────────────────────────────────────────────────────────
* Changes
* 00010827 - Batch Job for Suspense Record Deletion
* 00026332 - Including a query for Suspense records with Delete__c = true 
* ───────────────────────────────────────────────────────────
*/
global with sharing class SuspenseDeletionBatchJob implements schedulable, Database.Batchable<SObject> {
    /* variables */
    public String objectType;
    public String filterCriteria;
    public String selectFields;
    
    /* construction */
    global SuspenseDeletionBatchJob() {
        /* default settings */
        //CASE: 00015663
        objectType = 'Suspense__c';
        filterCriteria = '(License__r.Status__c IN (\'C - Current, Valid & In Good Standing\', \'CM - Current, Valid & In Good Standing/Maint. Requirement Due\', \'Z - Current & Valid, But Subject To Disciplinary Requirement\', \'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement\', \'R - Valid Thru Expiration Date, Subject To Renewal\', \'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due\', \'CR - Current/Next Renewal Paid\') AND License__r.ActiveInactive__c = \'Active\' AND SuspenseDueDate__c > 2021-02-22 AND Historical__c = false) OR Delete__c = true';        
        selectFields = 'Id, Name, License__c, InsuranceType__c, License__r.LicenseType__r.RequiresInsurance__c, MaintenanceType__c, Delete__c';
    }

    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return SuspenseSelector.getSuspenseQueryLocator(objectType, selectFields, filterCriteria);
    }

    /* batch execute class */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        /* process the records */
        List<Suspense__c> delSuspense_L = new List<Suspense__c>();
		Set<Id> updatelicenseId_L = new Set<Id>();
        
        List<Id> licenseId_L = new List<Id>();
        SET<String> insuranceType_S = new SET<String>();
        List<InsuranceBond__c> insuranceBond_L = new List<InsuranceBond__c>();
        Map<Id, List<InsuranceBond__c>> insuranceBond_M = new Map<Id, List<InsuranceBond__c>>();
        Map<Id, List<AssociatedLicense__c>> associatedLicenseCASE1_M = new Map<Id, List<AssociatedLicense__c>>();
        Map<Id, List<AssociatedLicense__c>> associatedLicenseCASE2_M = new Map<Id, List<AssociatedLicense__c>>();
        for(sObject s : scope) {
            Suspense__c suspense = (Suspense__c)s;
            licenseId_L.add(suspense.License__c);
            if (InsuranceBondService.insuranceBondSubstitutes.containsKey(suspense.InsuranceType__c)) {
                insuranceType_S.addAll(InsuranceBondService.insuranceBondSubstitutes.get(suspense.InsuranceType__c));
            } else {
                insuranceType_S.add(suspense.InsuranceType__c);
            }
        }

        for(InsuranceBond__c ib : [SELECT id, License__c, Type__c, Status__c FROM InsuranceBond__c
                                   WHERE License__c IN: licenseId_L AND Type__c IN: insuranceType_S AND Status__c = 'Active']) {
            if (insuranceBond_M.containsKey(ib.License__c)) {
                insuranceBond_M.get(ib.License__c).add(ib);
            } else {
                insuranceBond_M.put(ib.License__c, new List<InsuranceBond__c>{ib});
            }
        }

        for(AssociatedLicense__c al1 : [SELECT id, EntityLicense__c FROM AssociatedLicense__c
                                        WHERE EntityLicense__c IN: licenseId_L 
                                        AND (
                                            (
                                                EntityLicense__r.LicenseType__r.Name != 'RB - Entity'
                                                AND (
                                                    (PositionStatus__c = 'P - PRINCIPAL' AND EntityLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'P - PRINCIPAL')
                                                    OR (PositionStatus__c = 'D - DESIGNATED' AND EntityLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'D - DESIGNATED')
                                                )
                                            )
                                            OR (EntityLicense__r.LicenseType__r.Name = 'RB - Entity' AND PositionStatus__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)')
                                        ) AND EmploymentStatus__c = 'Employed']) {
            if (associatedLicenseCASE1_M.containsKey(al1.EntityLicense__c)) {
            	associatedLicenseCASE1_M.get(al1.EntityLicense__c).add(al1);
           	} else {
            	associatedLicenseCASE1_M.put(al1.EntityLicense__c, new List<AssociatedLicense__c>{al1});
        	}
        }
        
        for(AssociatedLicense__c al2 : [SELECT id, EmployeeLicense__c FROM AssociatedLicense__c
                                        WHERE EmployeeLicense__c IN: licenseId_L AND EmploymentStatus__c = 'Employed' and 
                                        EntityLicenseStatus__c != 'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)']) {
            if (associatedLicenseCASE2_M.containsKey(al2.EmployeeLicense__c)) {
                associatedLicenseCASE2_M.get(al2.EmployeeLicense__c).add(al2);
            } else {
                associatedLicenseCASE2_M.put(al2.EmployeeLicense__c, new List<AssociatedLicense__c>{al2});
            }
        }
        
        for(sObject s : scope) {
            Suspense__c suspense = (Suspense__c)s;
            //CASE: 00010827
            if (suspense.License__r.LicenseType__r.RequiresInsurance__c != NULL &&
                suspense.InsuranceType__c != NULL &&
                suspense.License__r.LicenseType__r.RequiresInsurance__c == TRUE) {
                if (insuranceBond_M.containsKey(suspense.License__c)) {
                    delSuspense_L.add(suspense);
                    if (suspense.License__c != NULL) {
                    	updatelicenseId_L.add(suspense.License__c);
                    }
                }
            }

            //CASE: 00026332, Trigger 3: Delete__c = true
            if (suspense.Delete__c) {
                delSuspense_L.add(suspense);
            }
            else if (suspense.MaintenanceType__c == 'NPRM - NO PRINCIPAL RME' ) {
                //CASE: 00010824, Trigger 1: Delete Loss of Princ RME Suspense Records
                if (associatedLicenseCASE1_M.containsKey(suspense.License__c)) {
                    delSuspense_L.add(suspense);
                }
            }
            else if (suspense.MaintenanceType__c == 'NFRM - RME WITHOUT EMPLOYMENT' 
                || suspense.MaintenanceType__c == 'NFEM - NO FIRM DUE TO EMPLOYMENT TERMINATION') {

                //CASE: 00010824, Trigger 2: Delete Loss of Entity Records
                if (associatedLicenseCASE2_M.containsKey(suspense.License__c)) {
                    delSuspense_L.add(suspense);
                }
            }
        }

        if (delSuspense_L.size() > 0) {
            Database.delete(delSuspense_L);
        }
        
        if (updatelicenseId_L.size() > 0) {
        	List<License__c> updateLicense_L = [SELECT Id, InsuranceBondLossDuringRenewal__c FROM License__c WHERE Id IN: updatelicenseId_L];
            For (License__c lic : updateLicense_L) {
                lic.InsuranceBondLossDuringRenewal__c = false;
            }
            Database.update(updateLicense_L);
        }
    }

    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        /* To send confirmation emails or execute post-processing operations. */
    }

    /* method to execute the schedulable context */
    global void execute(SchedulableContext context) {
        /* process loan account records in batches of 1000 records.  The job will produce on file per 1000 loan__Loan_Disbursal_Transaction__c */
        Database.executeBatch(new SuspenseDeletionBatchJob(), 20);
    }
}