/*
 * -----------------------------------------------------------------------------------
 * Description
 * Controller for RenewalNotificationwInsClasses VF page
 * -----------------------------------------------------------------------------------
 * Covered by: RenewalNotificationwInsClassesCtrlTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04192022 - Created for PVL Case 00021210
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 04/22/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class RenewalNotificationwInsClassesController {
    public String sortby {
        get; set;
    }

    public Date dToday {
        get; set;
    }

    public String recordId {
        get; set;
    }

    public List<License__c> records {
        get; set;
    }

    public void generateLicenses(String notificationIds) {
        List<String> licenseIds = new List<String>();
        if (notificationIds != null) {
            List<String> notificationIdList = notificationIds.split(',');
            List<Notification__c> notifications = NotificationSelector.getNotifications(
                    notificationIdList
            );
            for (Notification__c notification : notifications) {
                if (notification.Content__c != null) {
                    licenseIds.addAll(notification.Content__c.split(','));
                }
            }
        }

        if (recordId != null) {
            licenseIds.add(recordId);
        }
        String query =
                'SELECT Id, Name, RenewalMailToCountry__c, ' +
                'BoardProgramName__c,' +
                'LicenseTypeExpireDateYear__c,' +
                'RenewalFormPrivilegeText__c,' +
                'LicenseTypeEffectiveDateYear__c,' +
                'LicenseeNameFormula__c,' +
                'LicenseeNameRBA__c, ' +
                'NotificationLicenseNumber__c,' +
                'TruncatedPVLBPID__c,' +
                'RenewalMailToStreet__c,' +
                'RenewalMailToCity__c,' +
                'RenewalMailToState__c,' +
                'RenewalMailToZipCode__c,' +
                'RespondByDate__c, ' +
                'DBAEntity__c,' +
                'RenewalFormActiveInactiveText__c,' +
                'RenewalFormMethodofLicensure__c,' +
                'RenewalFormLicenseExpireDate__c,' +
                'RenewalFormPreviousLicensePeriod1__c,' +
                'RenewalFormPreviousLicensePeriod2__c,' +
                'RenewalFormRestorationDeadline__c,' +
                'ActiveInactiveRenewalFee__c,' +
                'LateActiveInactiveRenewalFee__c,' +
                'LicenseType__r.NextLicensePeriodEffectiveDate__c,' +
                'LicenseType__r.NextLicensePeriodExpireDate__c,' +
                'LicenseType__r.LicensePeriodYears__c,' +
                'LicenseType__r.LicenseType__c,' +
                'LicenseType__r.RenewalFee__c,' +
                'LicenseType__r.LicenseTypeExpireDate__c,' +
                'LicenseType__r.RestorationDeadLine__c,' +
                'LicenseType__r.LateRenewalFee__c,' +
                'LicenseType__r.OtherRenewalRequirements1__c,' +
                'LicenseType__r.OtherRenewalRequirements2__c,' +
                'FEIN__c,' +
                '(SELECT Id, ClassificationName__c,ClassificationName1__c ' +
                ' FROM LicenseClassifications__r WHERE (EndDate__c = NULL OR EndDate__c >= TODAY)' +
                ' AND Status__c = \'C - Current, Valid & In Good Standing\'' +
                ' LIMIT 7),' +
                ' (SELECT Id, Type__c, Surety__c, PolicyNumber__c, TermDate__c ' +
                ' FROM Insurance_Bonds__r WHERE Status__c = \'Active\' AND CancelDate__c = NULL' +
                ' LIMIT 1' +
                '),' +
                '(' +
                'SELECT Id,' +
                'EmployeeLicense__c,' +
                'EmployeeLicenseNumber__c,' +
                'EmployeeLicenseType__c,' +
                'EmploymentStatus__c,' +
                'EndDate__c,' +
                'EntityPrincipal__c,' +
                'EmployeeName__c' +
                ' FROM AssociatedEmployee__r WHERE ' +
                ' EmploymentStatus__c = \'Employed\'' +
                ' AND (EntityPrincipal__c = TRUE' +
                ' OR Position__c = \'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)\' ) ' +
                ' AND EndDate__c = NULL' +
                ' LIMIT 7 ' +
                '),' +
                '(' +
                'SELECT Id,' +
                'Position__c,' +
                'EntityLicense__r.Name,' +
                'EntityLicense__r.LicenseeName__c' +
                ' FROM AssociatedEntities__r' +
                ' WHERE EmploymentStatus__c = \'Employed\'' +
                ' AND (EndDate__c = null OR EndDate__c >= TODAY)' +
                '),' +
                '(' +
                'SELECT Id,' +
                'Account__r.Name,' +
                'Zipcode__c,' +
                'Address1__c,' +
                'Address2__c,' +
                'Address3__c,' +
                'City__c,' +
                'State__c' +
                ' FROM Associated_Accounts__r' +
                ' WHERE EndDate__c = NULL OR EndDate__c > today' +
                ' ORDER BY CreatedDate DESC' +
                ' LIMIT 1' +
                ')' +
                ' FROM License__c ' +
                ' WHERE Id IN :licenseIds';
        if (this.sortby == 'address') {
            query +=
            +' order by RenewalMailToCountry__c desc, RenewalMailToZipCodeBlank__c, RenewalMailToZipCodeHI__c, ' +
                    ' RenewalMailToZipCodeSpecial__c, RenewalMailToZipCode__c ';
        } else {
            query += ' ORDER BY LicenseNumberFormula__c';
        }
        records = Database.query(query);

        for (License__c record : records) {
            if (record.LicenseType__r.OtherRenewalRequirements1__c != null) {
                record.LicenseType__r.OtherRenewalRequirements1__c =
                    RenewalNotificationController.formatOtherRenewalRequirementsHtml(
                        record.LicenseType__r.OtherRenewalRequirements1__c
                    );
            }
            if (record.LicenseType__r.OtherRenewalRequirements2__c != null) {
                record.LicenseType__r.OtherRenewalRequirements2__c =
                    RenewalNotificationController.formatOtherRenewalRequirementsHtml(
                        record.LicenseType__r.OtherRenewalRequirements2__c
                    );
            }
        }
    }

    public RenewalNotificationwInsClassesController() {
        String notificationIds = System.currentPageReference()
                .getParameters()
                .get('notificationIds');
        sortby = System.currentPageReference().getParameters().get('sortby');
        recordId = System.currentPageReference().getParameters().get('id');
        generateLicenses(notificationIds);
        dToday = Date.today();
    }
}