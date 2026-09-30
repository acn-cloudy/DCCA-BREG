public with sharing class PVLApplicationStatusSelector {
    public static final Set<String> CLOSED_APPLICATION_STATUSES = new Set<String>{
        'HC - Application Completed',
        'HD - Application Terminated',
        'AW - Application Withdrawal',
        'HW - Application Withdrawn',
        'B7 - Denial Letter Sent',
        'EY - Cease Processing',
        'L5 - Rejected, Notice Sent',
        'BW - Board Phase Withdrawal'
    };

    public static List<Application__c> selectOpenApplications(Id accountId) {
        if (accountId == null) {
            return new List<Application__c>();
        }

        return [
            SELECT
                Id,
                Status__c,
                Type__c,
                LicenseType__c,
                LicenseType__r.Name,
                ApplicationReceivedDate__c,
                A3StartDate__c,
                DeficiencyDueDate__c,
                ApplicationRespondbyDate__c
            FROM Application__c
            WHERE Applicant__c = :accountId
            AND Status__c NOT IN :CLOSED_APPLICATION_STATUSES
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
    }
}