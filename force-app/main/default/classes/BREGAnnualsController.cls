public without sharing class BREGAnnualsController {
    private static final List<String> notPopulatedStatuses = new List<String>{ 'N', 'D' };

    public class AnnualWrapper {
        @AuraEnabled
        public String filingYear;
        @AuraEnabled
        public String filingDueDate;
        @AuraEnabled
        public Datetime receivedDate;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String actionText;
        @AuraEnabled
        public String annualId;
    }

    public class AccountDataWrapper {
        @AuraEnabled
        public String accountId;
        @AuraEnabled
        public String accountName;
        @AuraEnabled
        public String accountStatus;
        @AuraEnabled
        public Boolean isInGoodStanding;
        @AuraEnabled
        public String fileNumber;
        @AuraEnabled
        public String entityType;
        @AuraEnabled
        public Date registrationDate;
        @AuraEnabled
        public List<AnnualWrapper> annuals;
    }

    @AuraEnabled(cacheable=true)
    public static AccountDataWrapper getAccountData(String fileNumber, Id accountId) {
        AccountDataWrapper result = new AccountDataWrapper();
        String fileNumberWithPercent = fileNumber + '%';
        Account acc = new Account();
        if (accountId != null) {
            acc = [
                SELECT Id, Name, breg_File__c, breg_Good_Standing__c, breg_Registration_Date__c, breg_Entity_Status__c, breg_Entity_Type__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
        } else {
            acc = [
                SELECT Id, Name, breg_File__c, breg_Good_Standing__c, breg_Registration_Date__c, breg_Entity_Status__c, breg_Entity_Type__c
                FROM Account
                WHERE breg_File__c LIKE :fileNumberWithPercent OR breg_File__c = :fileNumber
                LIMIT 1
            ];
        }

        List<breg_Annual__c> annuals = [
            SELECT
                Id,
                breg_Status__c,
                breg_Filing_Date__c,
                breg_Filing_Due_Date__c,
                breg_Filing_Year__c,
                breg_Received_Date__c,
                breg_Account__c,
                breg_Account__r.Name,
                breg_Account__r.breg_File__c,
                breg_Account__r.breg_Good_Standing__c,
                breg_Account__r.breg_Entity_Status__c,
                breg_Account__r.breg_Entity_Type__c,
                breg_Account__r.breg_Registration_Date__c
            FROM breg_Annual__c
            WHERE breg_Account__c = :acc.Id AND breg_Status__c IN :notPopulatedStatuses
            ORDER BY breg_Filing_Date__c ASC
        ];
        result.accountId = acc.Id;
        result.accountName = acc.Name;
        result.isInGoodStanding = acc.breg_Good_Standing__c;
        result.fileNumber = acc.breg_File__c;
        result.accountStatus = acc.breg_Entity_Status__c;
        result.entityType = acc.breg_Entity_Type__c;
        result.registrationDate = acc.breg_Registration_Date__c;
        if (annuals.size() > 0) {
            result.annuals = new List<AnnualWrapper>();
            for (breg_Annual__c an : annuals) {
                AnnualWrapper wrapper = new AnnualWrapper();
                wrapper.annualId = an.Id;
                wrapper.filingYear = String.valueOf(an.breg_Filing_Year__c);
                wrapper.filingDueDate = String.valueOf(an.breg_Filing_Due_Date__c);
                wrapper.receivedDate = an.breg_Received_Date__c;
                wrapper.status = an.breg_Status__c;

                if (an.breg_Status__c == 'D' || an.breg_Status__c == 'N') {
                    wrapper.actionText = 'Begin ' + wrapper.filingYear + ' Annual Report';
                } else if (an.breg_Status__c == 'F') {
                    wrapper.actionText = 'A change has been filed for this business.';
                } else {
                    wrapper.actionText = '';
                }

                result.annuals.add(wrapper);
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Account getAnnualFillingsForInternalUser(Id accountId) {
        Integer currentYear = Date.today().year();
        Set<String> yearsForAmendmentAllowed = new Set<String>{ String.valueOf(currentYear - 1), String.valueOf(currentYear - 2) };
        Account acc = [
            SELECT
                Id,
                breg_Entity_Type__c,
                (
                    SELECT Id, breg_Filing_Year__c, breg_Status__c, breg_Filing_Date__c, breg_Received_Date__c
                    FROM Annuals__r
                    WHERE breg_Status__c IN :notPopulatedStatuses OR breg_Filing_Year__c IN :yearsForAmendmentAllowed
                    ORDER BY breg_Filing_Year__c DESC
                )
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        return acc;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getProcessingPrices() {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();

        if (setting == null) {
            throw new AuraHandledException('BREG setting not found');
        }

        return new Map<String, Decimal>{
            'normal' => setting.Normal_Processing_Price__c,
            'expedited' => setting.Expedited_Processing_Price__c,
            'archive' => setting.Archive_Fee__c,
            'penalty' => setting.Penalty_Fee__c,
            'discount' => setting.Online_report_discount__c
        };
    }

    /**
     * Retrieves the Annual record Id for a given account and filing year.
     * @param accountId The Id of the Account
     * @param filingYear The filing year to search for
     * @return The Annual record Id, or null if not found
     */
    @AuraEnabled
    public static String getAnnualIdByAccountAndYear(Id accountId, String filingYear) {
        List<breg_Annual__c> annuals = [
            SELECT Id
            FROM breg_Annual__c
            WHERE breg_Account__c = :accountId
              AND breg_Filing_Year__c = :filingYear
            LIMIT 1
        ];
        return annuals.isEmpty() ? null : annuals[0].Id;
    }
}