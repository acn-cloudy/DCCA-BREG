/****
 * Controller for the visualforce RenewalNotification
 * Created By: Alvin Zhou
 *
 *
 * **** */
public class RenewalNotificationController {
    public LicenseType__c licenseType { get; set; }

    public String sortby { get; set; }

    public String sUrl { get; set; }

    public Date dToday { get; set; }

    public Decimal validYear { get; set; }

    public String recordId { get; set; }

    public String licenseeNameRBA { get; set; }

    public List<License__c> records { get; set; }

    public List<AssociatedLicense__c> associatedLicenses { get; set; }

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

        License__c tempLicForLicType = [
            SELECT
                Id,
                LicenseType__r.Name
            FROM License__c
            WHERE Id = :licenseIds[0]
        ];

        String assocEntitiesSubQuery = '(' +
            'SELECT Id,' +
            'Position__c,' +
            'EntityName__c,' +
            'EntityLicense__r.BusinessStreet__c,' +
            'EntityLicense__r.BusinessCity__c,' +
            'EntityLicense__r.BusinessState__c,' +
            'EntityLicense__r.BusinessZipCode__c,' +
            'PositionStatus__c,' +
            'EntityLicense__r.Name,' +
            'EntityLicense__r.LicenseeName__c' +
            ' FROM AssociatedEntities__r' +
            ' WHERE EmploymentStatus__c = \'Employed\'' +
            ' AND (EndDate__c = null OR EndDate__c >= TODAY)' +
            ' AND (EntityPrincipal__c = TRUE OR PositionStatus__c = \'P - PRINCIPAL\')' +
            ' ORDER BY EffectiveDate__c desc' +
            ')';

        if (tempLicForLicType.LicenseType__r.Name == 'RS' || tempLicForLicType.LicenseType__r.Name == 'RB - Broker') {
            assocEntitiesSubQuery = '(' +
                'SELECT Id,' +
                'Position__c,' +
                'EntityName__c,' +
                'EntityLicense__r.BusinessStreet__c,' +
                'EntityLicense__r.BusinessCity__c,' +
                'EntityLicense__r.BusinessState__c,' +
                'EntityLicense__r.BusinessZipCode__c,' +
                'PositionStatus__c,' +
                'EntityLicense__r.Name,' +
                'EntityLicense__r.LicenseeName__c' +
                ' FROM AssociatedEntities__r' +
                ' WHERE EmploymentStatus__c = \'Employed\'' +
                ' AND (EndDate__c = null OR EndDate__c >= TODAY)' +
                ' ORDER BY EffectiveDate__c desc' +
                ')';
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
            'EmployerStreet__c,' +
            'EmployerCity__c,' +
            'EmployerState__c,' +
            'EmployerZipcode__c,' +
            'EmployerName__c,' +
            'EmployerCountry__c,' +
            'LateActiveInactiveRenewalFee__c,' +
            'LicenseType__r.Name,' +
            'LicenseType__r.ValidYear__c,' +
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
            'LicenseType__r.PreviousRestorationDeadline__c,' +
            'LicenseType__r.PreviousLicensePeriodEffectiveDate__c,' +
            'LicenseType__r.PreviousLicensePeriodExpireDate__c,' +
            'FEIN__c,' +
            '(SELECT Id, ClassificationName__c ' +
            ' FROM LicenseClassifications__r WHERE (EndDate__c = null OR EndDate__c >= TODAY)' +
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
                assocEntitiesSubQuery + ',' +
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
                record.LicenseType__r.OtherRenewalRequirements1__c = formatOtherRenewalRequirementsHtml(
                    record.LicenseType__r.OtherRenewalRequirements1__c
                );
            }
            if (record.LicenseType__r.OtherRenewalRequirements2__c != null) {
                record.LicenseType__r.OtherRenewalRequirements2__c = formatOtherRenewalRequirementsHtml(
                    record.LicenseType__r.OtherRenewalRequirements2__c
                );
            }
            if (record.LicenseType__r.ValidYear__c != null){
                validYear = record.LicenseType__r.ValidYear__c;
            }
            
        }
    }

    public RenewalNotificationController() {
        String notificationIds = System.currentPageReference()
            .getParameters()
            .get('notificationIds');
        sortby = System.currentPageReference().getParameters().get('sortby');
        recordId = System.currentPageReference().getParameters().get('id');
        generateLicenses(notificationIds);
        dToday = Date.today();
    }

    private static final List<String> RENEWAL_REQUIREMENTS_BOLD_PHRASES = new List<String>{
        'INACTIVE STATUS?',
        'NAME CHANGED?',
        'BUSINESS RELOCATED?',
        'PRINCIPAL THERAPIST CHANGED?'
    };

    public static String formatOtherRenewalRequirementsHtml(String html) {
        if (String.isBlank(html)) {
            return html;
        }

        String formatted = html.replaceAll('<p>', '<div>')
            .replaceAll('<p ', '<div ')
            .replaceAll('</p>', '</div>');

        formatted = normalizeRenewalRequirementsFontSize(formatted);

        for (String phrase : RENEWAL_REQUIREMENTS_BOLD_PHRASES) {
            String escapedPhrase = phrase.replace('?', '\\?');
            formatted = formatted.replaceAll(
                '(?i)(?<!<strong>)(?<!<b>)' + escapedPhrase + '(?!</strong>)(?!</b>)',
                '<strong>' + phrase + '</strong>'
            );
        }

        return formatted;
    }

    /**
     * Removes inline font-size styling that the rich-text editor stores on
     * fragments of the Other Renewal Requirements text (e.g. "RENEW ONLINE AT:"
     * or the URL), so the rendered output inherits a single, consistent size
     * from the component wrapper instead of rendering parts oversized.
     */
    public static String normalizeRenewalRequirementsFontSize(String html) {
        if (String.isBlank(html)) {
            return html;
        }

        // Drop font-size declarations from any inline style attribute.
        String normalized = html.replaceAll('(?i)font-size\\s*:\\s*[^;"\']*;?', '');
        // Drop size attributes from legacy/pasted <font> tags.
        normalized = normalized.replaceAll('(?i)(<font[^>]*?)\\s+size\\s*=\\s*"[^"]*"', '$1');
        // Neutralize heading tags that would otherwise render in a large font.
        normalized = normalized.replaceAll('(?i)<h[1-6][^>]*>', '<div>')
            .replaceAll('(?i)</h[1-6]>', '</div>');

        return normalized;
    }

}