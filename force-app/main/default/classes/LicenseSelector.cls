/**** 
* ─────────────────────────────────────────────────────────
* class for selecting Data from the License
* ─────────────────────────────────────────────────────────
* PacPoint-AZ150819 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-08-15
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class LicenseSelector {
    public static List<License__c> getLicenses(List<String> licenseIds) {
        return [
                SELECT
                        Id,
                        Name,
                        TruncatedPVLBPID__c,
                        EffectiveExpireDate__c,
                        NotificationEmail__c,
                        fxLicenseTypeRequiresInsurance__c,
                        CurrentEmployerCount__c,
                        RenewalMailToCountry__c, ActiveInactive__c,
                        fxBreakinInsuranceCoverageAllowed__c,
                        LossofBond__c,
                        BondWaiver__c,
                        DependentLicense__c,
                        Status__c,
                        LossofWorkersComp__c,
                        LossofEntityDate__c,
                        LossofPrincipalRMEDate__c,
                        LossOfLiability__c,
                        ForfeitureDate__c,
                        LicenseTypeName__c,
                        LicenseType__r.ContinuousInsuranceRequired__c,
                        PreviousStatus__c,
                        LicenseeNameFormula__c,
                        LicenseType__r.Entity__c,
                        LicenseType__r.LicenseTypeExpireDate__c,
                        LicenseType__r.RunAuditDate__c,
                        LicenseType__r.LicenseTypeEffectiveDate__c,
                        LicenseType__r.NextLicensePeriodEffectiveDate__c,
                        LicenseType__r.NumberofDaysUntilAutoForfeiture__c,
                        LicenseType__r.Restorationdeadline__c,
                        LicenseType__r.AssociatedLicenseRelationship__c,
                        LicenseType__r.EntityPrincipalFlagUsed__c,
                        LicenseType__r.StartofRenewalPeriod__c,
                        LicenseType__r.InsuranceUpdateRequiredNotification__r.Name,
                        LicenseType__r.NoticeofLicensureEmailTemplate__c,
                        LicenseType__r.RenewalReminderEmailTemplate__c,
                        LicenseType__r.BreakinInsuranceCoverageAllowed__c,
                        LicenseType__r.RenewalFee__c,
                        LicenseType__r.InactiveFirmSoleOwnerRenewalFee__c,
                        LicenseType__r.AutoForfeitureStatus__c,
                        LicenseType__r.DependencyRequired__c,
                        LicenseType__r.RequiresallEmployeestoRenew__c,
                        LicenseType__r.RequiresInsurance__c,
                        LicenseType__r.InsuranceBondTypesRequired__c,
                        NotificationMailingStreet__c,
                        NotificationMailingCity__c,
                        NotificationMailingState__c,
                        NotificationMailingZipcode__c,
                        LicenseType__r.EndofRenewalPeriod__c,
                        LicenseType__r.StatusDueToLossOfInsurance__c,
                        LicenseType__r.NumberOfDaysUntilInsAutoForfeiture__c,
                        LicenseType__r.StatusDuetoRequiredINSInactive__c,
                        InsuranceBondTermDate__c,
                        Insurance_Bond_Cancel_Date__c,
                        CurrentGapinWorkersComp__c,
                        RenewalMailToStreet__c,
                        RenewalMailToCity__c,
                        RenewalMailToState__c,
                        RenewalMailToZipCode__c,
                        CurrentGapinBond__c,
                        CurrentGapinLiability__c,
                        PVL_Portal_User__c,
                        PVL_Portal_User__r.Email__c,
                        MethodofLicensure__c
                FROM License__c
                WHERE Id IN: licenseIds
                ORDER BY RenewalMailToCountry__c,
                        RenewalMailToZipCodeBlank__c,
                        RenewalMailToZipCodeHI__c,
                        RenewalMailToZipCodeSpecial__c,
                        RenewalMailToZipCode__c
        ];
    }
    public static List<License__c>  getLicensesByLicenseTypeId(String licenseTypeId, String firstId) {
        return [SELECT Id, LicenseeNameFormula__c, NotificationMailingStreet__c, NotificationMailingCity__c, NotificationMailingState__c, 
        NotificationMailingZipcode__c,LicenseType__r.Restorationdeadline__c, LicenseType__r.LicenseTypeExpireDate__c, LicenseType__r.StartofRenewalPeriod__c, LicenseType__r.EndofRenewalPeriod__c
        from License__c WHERE LicenseType__c =: licenseTypeId and Id >=: firstId limit 2000 ];
    }
    // CASE 00005439 
    public static List<LicenseRequirements__c> getRequirementsByLicenseIds(List<String> licenseIds) {
        return [SELECT Id, License__c, RequirementShortDescription__c, RequirementLongDescription__c, Requirement__c, ParentLicenseRequirement__c, IsDeficient__c
                FROM LicenseRequirements__c WHERE License__c in: licenseIds];
    }

    public static List<License__c> getLicenseByLicenseTypeStatusAndLicensee(String licenseTypeName, List<String> licenseeIds, String status) {
        return [Select Id, Status__c, Licensee__c from License__c where LicenseType__r.Name =: licenseTypeName and Licensee__c in: licenseeIds and Status__c =: status];
    }

    // CASE 00006040
    public static List<License__c>  getLicensesByLicenseTypeAndLicenseeAndStatus(String licenseTypeId, String licenseeId, List<String> statusList) {
        // 00006040
        // If License Type = DTT and Application.Licensetype.RestrictmorethanonelicenseperAccnt = true, any License Applies regardless of status. 
        return [SELECT Id, Status__c from License__c WHERE LicenseType__c =: licenseTypeId and Licensee__c =: licenseeId 
                and LicenseType__r.RestrictmorethanonelicenseperAccnt__c = true  and (Status__c in: statusList  or LicenseType__r.Name = 'DTT' )];
    }
    // Creation of a batch job that
    public static DataBase.QueryLocator getLicenseQueryLocator(String objectType, String selectFields, String filterCriteria) {
        return Database.getQueryLocator(String.format('SELECT {0} FROM {1} WHERE {2} ', new List<String>{selectFields, objectType, filterCriteria}));
    }
    
    // CASE 00037317
    public static List<License__c>  getLicensesAddressChangeDetails(Set<String> licenseIds) {
        return [
                SELECT Id, Mailing_Address_Update_from_Renewal__c, Business_Address_Update_from_Renewal__c, LicenseType__c
                FROM License__c
                WHERE Id IN :licenseIds 
            ];
    }
    
    // CASE 00037665
    public static List<License__c>  getLicensesCEStatus(Set<String> licenseIds) {
        return [SELECT Id FROM License__c WHERE Id IN :licenseIds AND (CEisConfirmed__c = true OR ExemptfromCE__c  = true)];
    }

    public static List<License__c> getLicensesByIdSet(Set<String> licenseIds) {
        return [Select Id, Status__c from License__c where Id in: licenseIds];
    }
}