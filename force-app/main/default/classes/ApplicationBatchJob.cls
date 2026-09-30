/*
* ─────────────────────────────────────────────────────────
* Used for Application Batch Job
* Application records
* ─────────────────────────────────────────────────────────
* PacPoint-CZ050919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp
* @created      2019-09-05
* ───────────────────────────────────────────────────────────
* Changes
* 00005003 - Creation of a batch job that will Set Application to AW when Complete By Date is reached during A Phase
* 00005344 - Creation of batch job to set the status to HD on the Application
* 00005654 - Update Batch Job of case 5003
* ───────────────────────────────────────────────────────────
*/
global with sharing class ApplicationBatchJob implements schedulable, Database.Batchable<SObject> {
    /* variables */
    public String objectType;
    public String filterCriteria;
    public String selectFields;
    
    /* construction */
    global ApplicationBatchJob() {
        /* default settings */
        Date today120 = System.today() - 120;
        Datetime localDate = Datetime.newInstance(today120.year(), today120.month(), today120.day(), 00, 00, 00);
        String gmtDate = localDate.format('yyyy-MM-dd', 'GMT');

        objectType = 'Application__c';
        // Change due to the case 000012287
        // filterCriteria = '((Phase__c <> \'H - License Generation\' AND CompleteApplicationBy__c = YESTERDAY) OR (Phase__c <> \'H - License Generation\' AND NoticeofFeesSentDate__c <= ' + gmtDate + ') OR CompleteExamBy__c = YESTERDAY) AND IsApplicationTerminated__c = False';
        // filterCriteria = '(Phase__c <> \'H - License Generation\' '
        //  + ' AND ((Type__c != \'RNEW - Renewal\' and CompleteApplicationBy__c <= YESTERDAY) '
        //  + ' OR (Type__c = \'RNEW - Renewal\' and CurrentLicense__r.EffectiveCheckDate__c <= YESTERDAY)))';
        // filterCriteria = '(Phase__c <> \'H - License Generation\')';
        // Change due to the case 00015503
        filterCriteria = 'Type__c <> \'RSTR - Restore - No A/I Status\' and ' 
            +' (Status__c = \'A1 - Application Submitted, Awaiting Review\''
            + ' or  Status__c = \'A2 - Deficient, Awaiting Notice\' or '
            + ' Status__c = \'A3 - Deficiency Notice Sent\' or '
            + ' Status__c = \'D1 - Awaiting Dependency Review\''
            + ' OR Status__c = \'D2 - Continuing Education Missing\')'
            + ' AND ((Type__c != \'RNEW - Renewal\' and CompleteApplicationBy__c <= YESTERDAY) '
         + ' OR (Type__c = \'RNEW - Renewal\' and CurrentLicense__r.EffectiveCheckDate__c <= YESTERDAY))';
        selectFields = 'Id, Name, Status__c, BoardProgramName__c,  ActiveInactive__c, Phase__c, CurrentLicense__c, CurrentLicense__r.Id, CurrentLicense__r.Status__c, CompleteExamBy__c, CompleteApplicationBy__c, NoticeofFeesSentDate__c, IsApplicationTerminated__c';
    }

    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return ApplicationSelector.getApplicationsQueryLocator(objectType, selectFields, filterCriteria);
    }

    /* batch execute class */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        /* process the records */
        // Change due to the case 000012287
        List<Application__c> applications = (List<Application__c>) scope;
        List<Application__c> applicationsForTerminate = (new ApplicationDomain(applications)).terminateApplication();
        List<Application__c> applicationsDReviewsForTerminate = (new ApplicationDomain(applications)).terminateHDApplicationForDReview();
        List<Application__c> applicationForRealstateCommission = (new ApplicationDomain(applications)).terminateHDApplicationForRealstateCommission();
        List<Application__c> appsForUpdate = new List<Application__c> ();
        appsForUpdate.addAll(applicationsDReviewsForTerminate);
        appsForUpdate.addAll(applicationsForTerminate);
        // 1)  We need to update the Application.ActiveInactive__c = Inactive AND SAVE
        appsForUpdate.addAll(applicationForRealstateCommission);
        Database.update(appsForUpdate, true);
        
        // 2)  Then we need to set the Application.Status__c = HC and save again. 
        (new ApplicationDomain(applicationForRealstateCommission)).updateToHCApplicationCompleted();
        Database.update(applicationForRealstateCommission, true);
        // Update current license status to TX - Terminated and Refunded
        Database.update((new ApplicationDomain(applicationsDReviewsForTerminate
            )).updateCurrentLicenseToTerminatedAndRefunded(), true);
    }

    /* batch finish class */
    global void finish(Database.BatchableContext context) {
        /* To send confirmation emails or execute post-processing operations. */
    }

    /* method to execute the schedulable context */
    global void execute(SchedulableContext context) {
        /* process loan account records in batches of 1000 records.  The job will produce on file per 1000 loan__Loan_Disbursal_Transaction__c */
        Database.executeBatch(new ApplicationBatchJob(), 100);
    }
}