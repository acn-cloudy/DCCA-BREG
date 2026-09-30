@IsTest
public class PVLApplicationStatusTestFactory {
    public static Account createPersonAccount(String key, String phone, String bpid) {
        Account accountRecord = new Account(
            FirstName = 'PVL',
            LastName = 'Caller ' + key,
            RecordTypeId = personAccountRecordTypeId(),
            Phone = phone,
            BPID__c = bpid
        );
        insert accountRecord;
        return accountRecord;
    }

    public static Application__c createApplication(Id accountId, String key) {
        return createApplication(accountId, key, 'A1 - Application Submitted, Awaiting Review', Date.today().addDays(30), null);
    }

    public static Application__c createApplication(
        Id accountId,
        String key,
        String status,
        Date respondByDate,
        String applicationPhone
    ) {
        return createApplication(
            accountId,
            key,
            status,
            respondByDate,
            applicationPhone,
            'LICN - New License',
            null
        );
    }

    public static Application__c createApplication(
        Id accountId,
        String key,
        String status,
        Date respondByDate,
        String applicationPhone,
        String type,
        String onlineApplicationType
    ) {
        LicenseType__c licenseType = new LicenseType__c(Name = 'PVL IVR ' + key);
        insert licenseType;

        Application__c applicationRecord = new Application__c(
            Applicant__c = accountId,
            LicenseType__c = licenseType.Id,
            Type__c = type,
            Phase__c = 'A - Application Received',
            Status__c = status,
            ApplicationReceivedDate__c = Date.today().addDays(-7),
            A3StartDate__c = System.now().addDays(-3),
            DeficiencyDueDate__c = Date.today().addDays(20),
            ApplicationRespondbyDate__c = respondByDate,
            CC_Applicant_Phone__c = applicationPhone,
            OnlineApplicationType__c = onlineApplicationType
        );
        insert applicationRecord;
        return applicationRecord;
    }

    public static Application__c queryApplicationForFreshness(Id applicationId) {
        return [
            SELECT
                Id,
                Status__c,
                Phase__c,
                Type__c,
                OnlineApplicationType__c,
                ApplicationReceivedDate__c,
                A3StartDate__c,
                DeficiencyDueDate__c,
                ApplicationRespondbyDate__c,
                CreatedDate,
                LastModifiedDate,
                SystemModstamp,
                CurrentLicense__c,
                CurrentLicense__r.Status__c,
                CurrentLicense__r.SystemModstamp,
                CurrentLicense__r.EffectiveExpireDate__c,
                CurrentLicense__r.ForfeitureDate__c,
                CurrentLicense__r.ThisLicenseRenewed__c,
                DependentLicense__c,
                DependentLicense__r.Status__c,
                DependentLicense__r.SystemModstamp,
                DependentLicense2__c,
                DependentLicense2__r.Status__c,
                DependentLicense2__r.SystemModstamp,
                DependentApplication__c,
                DependentApplication__r.Status__c,
                DependentApplication__r.SystemModstamp,
                DependencyRequired__c,
                LicenseType__r.Name,
                LicenseType__r.DependencyRequired__c,
                LicenseType__r.X2ndDependencyRequired__c,
                LicenseType__r.RequiresInsurance__c
            FROM Application__c
            WHERE Id = :applicationId
        ];
    }

    public static IVR_Application_Status_Snapshot__c createSnapshot(
        Id applicationId,
        String status,
        String policy,
        Datetime verifiedAt
    ) {
        IVR_Application_Status_Snapshot__c snapshot = new IVR_Application_Status_Snapshot__c(
            Application__c = applicationId,
            Application_Key__c = String.valueOf(applicationId),
            IVR_Status__c = status,
            IVR_Status_Verified_At__c = verifiedAt,
            IVR_Response_Policy__c = policy,
            Freshness_State__c = 'fresh_enough',
            Source_Status__c = status,
            Source_Status_SystemModstamp__c = verifiedAt,
            Last_Relevant_Job_Completed_At__c = verifiedAt,
            Reason_Codes__c = null
        );
        insert snapshot;
        return snapshot;
    }

    public static PVLApplicationStatusService.RequestEnvelope request(String phone, String last4) {
        PVLApplicationStatusService.RequestEnvelope envelope = new PVLApplicationStatusService.RequestEnvelope();
        envelope.correlationId = 'corr-' + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        envelope.ccassSessionId = 'session-1';
        envelope.callId = 'call-1';
        envelope.ani = '+1' + PVLApplicationStatusPhoneMatchClient.normalizePhone(phone);
        envelope.locale = 'en-US';
        envelope.path = 'PHONE_LAST4';
        envelope.payload = new PVLApplicationStatusService.Payload();
        envelope.payload.phoneNumber = phone;
        envelope.payload.phoneSource = 'CALLER_ENTERED';
        envelope.payload.ssnLast4 = last4;
        return envelope;
    }

    private static Id personAccountRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byDeveloperName =
            Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();
        if (byDeveloperName.containsKey('PersonAccount')) {
            return byDeveloperName.get('PersonAccount').getRecordTypeId();
        }
        return Account.SObjectType.getDescribe().getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
    }
}