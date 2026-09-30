/*
* ─────────────────────────────────────────────────────────
* class for selecting Data from the Application
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class ApplicationSelector {
    DataBase.QueryLocator queryLocator;
    public static List<Application__c> getDependentApps(Set<String> appIds) {
      return [Select Id, DependentApplication__c, 
         CurrentLicense__r.Id, CurrentLicense__r.DependentLicense__c 
         from Application__c where DependentApplication__c in: appIds ];

    }

    public static List<Application__c> getApplications(List<String> ids) {
        return getApplications(new Set<String>(ids));
    }
    public static List<Application__c> getApplications(Set<String> idSets) {
        return [Select Id, Name, LicenseType__c, TypeofEntity__c, Island__c, Status__c, ActiveInactive__c, Applicant__r.Name,
            CurrentLicenseYear__c, LicenseNumber__c, MethodofLicensure__c, CurrentLicense__c, LicensePeriod__c,
            OutstandingAmount__c, Type__c, Phase__c, OfficeNumber__c, PVL_FireRenewLicenseProcess__c, ApplyforTemporaryPermit__c,
            DependentLicense__c, LicenseType__r.DefaultClassStatus__c, LicenseType__r.Name, LicenseType__r.LicenseFees__c, CurrentLicense__r.Privilege__c,
            DependentLicense__r.Id, DependentLicense__r.LicenseNumberFormula__c, DependentLicense__r.Name, 
            DependentLicense__r.LicenseConsecutiveNumber__c,  DependentLicense__r.BranchNumber__c, DraftApplication__c, 
            DraftApplication__r.Status__c, DraftApplication__r.Id, BoardProgramName__c, CompleteApplicationBy__c, PhaseXStartDate__c, 
            LicenseType__r.DurationofTestEligibilityMonths__c, ApplicationReceivedDate__c,  LicenseType__r.CompletebyDuration__c
            from Application__c where Id in: idSets];
    }

    public static List<Application__c> getApplicationsByLicenseCode(Set<String> idSets, List<String> licenseTypCodes) {
        return [Select Id, LicenseTypeCode__c, Type__c, LicenseType__c, MethodofLicensure__c, TypeofEntity__c, DependentApplication__c, DependentLicense__c, Phase__c from Application__c where Id in: idSets and LicenseTypeCode__c  in: licenseTypCodes];
    }
    public static List<Application__c>  getApplicationsForRenew(List<String> currentLicenseIds) {
        String appType = 'RNEW - Renewal';
        String status = 'HC - Application Completed';

        return [Select Id, CurrentLicense__c, CurrentLicense__r.EffectiveExpireDate__c, 
            CurrentLicense__r.LicenseType__r.RenewalWindowInDays__c,LicensePeriodRNEW__c,
            LicenseType__r.PreviousLicensePeriod__c
            from Application__c where CurrentLicense__c in: currentLicenseIds 
            and Type__c = :appType and Status__c != :status];
    }

    /* Creation of a batch job that will set the status to "HD - Application Terminated" on all the Application records with Phase="A - Application Received" and "Complete Application By"= YESTERDAY */
    public static DataBase.QueryLocator getApplicationsQueryLocator(String objectType, String selectFields, String filterCriteria) {
        return Database.getQueryLocator(String.format('SELECT {0} FROM {1} WHERE {2} ', new List<String>{selectFields, objectType, filterCriteria}));
    }

    public static List<Application__c> getApplicationsByIds(List<String> ids) {
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c, SoleOwner__c, 
                CurrentLicense__r.SoleOwner__c, CurrentLicense__r.Privilege__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.LicenseType__r.NextLicensePeriodEffectiveDate__c, 
                CurrentLicense__r.LicenseType__r.NextLicensePeriodExpireDate__c,
                CurrentLicense__r.LicenseType__r.NextLicensePeriod__c,
                CurrentLicense__r.LicenseType__r.AuditType__c,
                CurrentLicense__r.FlaggedforAudit__c, CurrentLicense__r.LicenseRestriction__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, ActiveInactive__c, LicenseTypeCode__c,
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, ApplicationReceivedDate__c, 
                Status__c, Phase__c, RenewingPermittoPractice__c, OnlineApplicationType__c, LicenseType__c, CEisConfirmed__c 
                from Application__c 
                where Id in: ids
            ];
    }

    public static List<Application__c> getRenewalApplicationsByLicenseIds(List<String> licenseIds) {
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, LicenseTypeCode__c, ActiveInactive__c,
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__c,
                Status__c, Phase__c, LicenseType__c from Application__c 
                where CurrentLicense__c in: licenseIds and Type__c = 'RNEW - Renewal' and Status__c = 'D1 - Awaiting Dependency Review' 
                and SameAsLicenseTypeNextRenewPeriod__c = true
            ];
    }

    public static List<Application__c> getRNApplicationsByLicenseIds(List<String> licenseIds) {
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, LicenseTypeCode__c, ActiveInactive__c,
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__c,
                Status__c, Phase__c, LicenseType__c from Application__c 
                where CurrentLicense__c in: licenseIds and Type__c = 'RNEW - Renewal' 
                and (Status__c = 'D1 - Awaiting Dependency Review' or Status__c = 'HC - Application Completed') 
                and ActiveInactive__c != 'Inactive' and ApplicationRenewingInactive__c = false
                and SameAsLicenseTypeNextRenewPeriod__c = true
            ];
    }

    public static List<Application__c> getPrevRNApplicationsByLicenseIds(List<String> licenseIds) {
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, LicenseTypeCode__c, ActiveInactive__c,
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__c,
                Status__c, Phase__c, LicenseType__c from Application__c 
                where CurrentLicense__c in: licenseIds and Type__c = 'RNEW - Renewal' 
                and (Status__c = 'D1 - Awaiting Dependency Review' or Status__c = 'HC - Application Completed') 
                and ActiveInactive__c != 'Inactive' and ApplicationRenewingInactive__c = false
                and SameAsLicenseTypeRenewPeriod__c = true
            ];
    }

    public static List<Application__c> getD1RNApplicationsByLicenseIds(List<String> licenseIds) {
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, LicenseTypeCode__c, ActiveInactive__c,
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__c,
                Status__c, Phase__c, LicenseType__c from Application__c 
                where CurrentLicense__c in: licenseIds and Type__c = 'RNEW - Renewal' 
                and Status__c = 'D1 - Awaiting Dependency Review' 
                and ActiveInactive__c != 'Inactive' and ApplicationRenewingInactive__c = false
                and SameAsLicenseTypeNextRenewPeriod__c = true
            ];
    }

    public static List<Application__c> getPrevD1RNApplicationsByLicenseIds(List<String> licenseIds) {
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, LicenseTypeCode__c, ActiveInactive__c,
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c, CurrentLicense__c,
                Status__c, Phase__c, LicenseType__c from Application__c 
                where CurrentLicense__c in: licenseIds and Type__c = 'RNEW - Renewal' 
                and Status__c = 'D1 - Awaiting Dependency Review' 
                and ActiveInactive__c != 'Inactive' and ApplicationRenewingInactive__c = false
                and SameAsLicenseTypeRenewPeriod__c = true
            ];
    }

    public static List<Application__c> getRenewalApplications(List<String> licenseIds) {
        
        return [Select Id,  RNEWRSTRDate__c, CurrentLicense__r.Id, CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.LicenseType__r.LicenseTypeExpireDate__c, CurrentLicense__r.PreviousEffectiveExpiryDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c, CurrentLicense__r.Status__c, 
                LicensePeriodRNEW__c, Type__c, ApplicationRenewingInactive__c, Applicant__c,
                Status__c, Phase__c, LicenseType__c from Application__c 
                where CurrentLicense__c in: licenseIds and Type__c = 'RNEW - Renewal' and Status__c = 'D1 - Awaiting Dependency Review' 
                and SameAsLicenseTypeRenewPeriod__c = true
            ];
    }
    
    // create method that query application's LicenseType__r.ExamApprovalNotification__r.Name and NotificationEmail__c with Application Id set
    public static List<Application__c> getApplicationExamApprovalNotification(Set<String> appIds) {
        return [Select Id, LicenseType__r.ExamApprovalNotification__r.Name, NotificationEmail__c 
            from Application__c where Id in: appIds and NotificationEmail__c != null 
            and LicenseType__r.ExamApprovalNotification__c != null];
    }

    public static List<Application__c> getApplicationWithLicesneTypes(Set<String> appIds) {
        return [Select Id, LicenseType__r.ExamApprovalNotification__r.Name, NotificationEmail__c 
            from Application__c where Id in: appIds and NotificationEmail__c != null 
            and LicenseType__r.ExamApprovalNotification__c != null];

    }

    public static List<Application__c> getApplicationsForDependencyCheck(List<String> ids) {
        return [
            SELECT Id, Type__c, DateofLicensure__c, CurrentLicense__c, ActiveInactive__c, RNEWRSTRDate__c,
                LicenseType__r.X2ndDependencyRequired__c, LicenseType__r.D2CERequired__c, LicenseType__r.OneWayDependency__c                
            FROM Application__c
            WHERE Id IN :ids
        ];
    }
}