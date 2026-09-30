/*
 * -----------------------------------------------------------------------------------
 * Description
 * Controller for RenewalNotificationPCOCTEntity VF page
 * -----------------------------------------------------------------------------------
 * Covered by: RenewalNotificationPocCtEntityCtrlTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04192022 - Created for PVL Case 00021210
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 04/19/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class RenewalNotificationPocCtEntityController {
    public String sortBy {
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

    public List<DisplayData> displayRecords {
        get; set;
    }

    public void generateLicenses(String notificationIds) {
        List<String> licenseIds = new List<String>();
        if (notificationIds != null) {
            List<String> notificationIdList = notificationIds.split(',');
            List<Notification__c> notifications = NotificationSelector.getNotifications(notificationIdList);

            for (Notification__c notification : notifications) {
                if (notification.Content__c != null) {
                    licenseIds.addAll(notification.Content__c.split(','));
                }
            }
        }

        if (recordId != null) {
            licenseIds.add(recordId);
        }
        Set<String> insuranceTypeFilter =
                new Set<String>{'LP - Liability / Property Damage',
                                'LI - Liability',
                                'WC - Workers Compensation',
                                'SI - Exclusion from Workers Comp.',
                                'SL - Self-Insured for W/C (Entity OK\'d By Labor Dept)',
                                'SM - No HI Employees - Submit Workers Comp Prior to Hiring',
                                'SW - Workers Comp Thru Leasing Co.',
                                'SX - Exemption No Longer Allowed',
                                'WP - Submit Prior to Hiring Hi Empl - Evidence of WC Not Submitted'};
        String query =
                'SELECT Id, ' +
                'Name, ' +
                'RenewalMailToCountry__c, ' +
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
                '(SELECT Id, ClassificationName__c ' +
                ' FROM LicenseClassifications__r WHERE EndDate__c = NULL' +
                ' AND Status__c = \'C - Current, Valid & In Good Standing\'' +
                ' LIMIT 7),' +
                ' (SELECT Id, Type__c, Surety__c, PolicyNumber__c, TermDate__c ' +
                ' FROM Insurance_Bonds__r WHERE Type__c IN :insuranceTypeFilter ' +
                ' AND (Status__c = \'Active\' OR Status__c = \'Waived\')' +
                ' AND (TermDate__c = null OR TermDate__c >= :dToday)' +
                ' AND (CancelDate__c = null OR CancelDate__c >= :dToday)' +
                ' ORDER BY EffectiveDate__c ASC' +
                '),' +
                '(' +
                'SELECT Id,' +
                'EmployeeLicense__r.Name,' +
                'PositionStatus__c,' +
                'EmployeeLicenseType__c,' +
                'EmployeeLicense__r.LicenseeNameFormula__c' +
                ' FROM AssociatedEmployee__r' +
                ' WHERE EmploymentStatus__c = \'Employed\'' +
                ' AND (EndDate__c = null OR EndDate__c >= TODAY)' +
                ' AND EmployeeLicenseType__c <> \'PCFR\'' +
                ')' +
                ' FROM License__c ' +
                ' WHERE Id IN :licenseIds';
        if (this.sortBy == 'address') {
            query +=
            +' ORDER BY RenewalMailToCountry__c DESC, RenewalMailToZipCodeBlank__c, RenewalMailToZipCodeHI__c, ' +
                    ' RenewalMailToZipCodeSpecial__c, RenewalMailToZipCode__c ';
        } else {
            query += ' ORDER BY LicenseNumberFormula__c';
        }

        records = Database.query(query);

        for (License__c record : records) {
            if (record.LicenseType__r.OtherRenewalRequirements1__c != null) {
                record.LicenseType__r.OtherRenewalRequirements1__c =
                    RenewalNotificationController.normalizeRenewalRequirementsFontSize(
                        record.LicenseType__r.OtherRenewalRequirements1__c
                            .replaceAll('<p>', '<div>')
                            .replaceAll('<p ', '<div ')
                            .replaceAll('</p>', '</div>')
                    );
            }

            if (record.LicenseType__r.OtherRenewalRequirements2__c != null) {
                record.LicenseType__r.OtherRenewalRequirements2__c =
                    RenewalNotificationController.normalizeRenewalRequirementsFontSize(
                        record.LicenseType__r.OtherRenewalRequirements2__c
                            .replaceAll('<p>', '<div>')
                            .replaceAll('<p ', '<div ')
                            .replaceAll('</p>', '</div>')
                    );
            }

            Boolean wcBondFound = false;
            Boolean lpBondFound = false;
            DisplayData dd = new DisplayData(record);

            for (InsuranceBond__c ins : record.Insurance_Bonds__r) {
                if ((ins.Type__c.startsWith('WC') || ins.Type__c.startsWith('SI') || ins.Type__c.startsWith('SL') || ins.Type__c.startsWith('SM') || ins.Type__c.startsWith('SW') || ins.Type__c.startsWith('SX') || ins.Type__c.startsWith('WP')) && !wcBondFound) {
                    wcBondFound = true;
                    dd.wcIns = ins;
                }

                if ((ins.Type__c.startsWith('LP') || ins.Type__c.startsWith('LI')) && !lpBondFound) {
                    lpBondFound = true;
                    dd.lpIns = ins;
                }
            }

            displayRecords.add(dd);
        }
    }

    public RenewalNotificationPocCtEntityController() {
        String notificationIds = System.currentPageReference()
                .getParameters()
                .get('notificationIds');
        sortBy = System.currentPageReference().getParameters().get('sortby');
        recordId = System.currentPageReference().getParameters().get('id');
        dToday = Date.today();
        displayRecords = new List<DisplayData>();
        generateLicenses(notificationIds);
    }

    public class DisplayData{
        public License__c license{
            get;set;
        }

        public InsuranceBond__c wcIns {
            get;set;
        }

        public InsuranceBond__c lpIns {
            get;set;
        }

        public DisplayData(License__c lic) {
            this.license = lic;
        }
    }
}