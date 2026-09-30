public without sharing class BREGAnnualRobotValidationBatch implements Database.Batchable<SObject>, Database.Stateful {
    private static final String CSV_HEADER = 'CaseId,CaseWorkitemNumber,EntityId,EntityFile,EntityName,Status,OwnerId,OwnerName,FormCode,FormConfigEntityType,CreatedDate,Match,DifferenceCount';

    public Integer totalProcessed = 0;
    public Integer totalSkippedNoEntity = 0;
    public Integer totalWithDifferences = 0;
    public Integer totalNoDifferences = 0;

    private List<String> csvLines = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query =
            'SELECT ' +
            'Id, Status, breg_File__c, breg_Workitem_Number__c, breg_No_Changes__c, OwnerId, Owner.Name, ' +
            'breg_Form_Code__c, breg_Form_Configuration__r.breg_Entity_Type__c, CreatedDate, ' +
            'breg_Name_of_the_Entity__c, breg_Entity_Type__c, breg_Entity_Nature_Of_Business__c, ' +
            'breg_Mailing_Address__Street__s, breg_Mailing_Address_Number_and_Street_2__c, breg_Mailing_Address__City__s, ' +
            'breg_Mailing_Address__StateCode__s, breg_Mailing_Address__CountryCode__s, breg_Mailing_Address__PostalCode__s, ' +
            'breg_Company_Address__Street__s, breg_Company_Address_Street2__c, breg_Company_Address__City__s, ' +
            'breg_Company_Address__StateCode__s, breg_Company_Address__CountryCode__s, breg_Company_Address__PostalCode__s, ' +
            'breg_Number_of_initial_members__c, breg_Membership_Fees_Received__c, breg_Number_of_Shareholders__c, ' +
            'breg_Entity__c, ' +
            'breg_Entity__r.Name, breg_Entity__r.breg_File__c, breg_Entity__r.breg_Entity_Type__c, breg_Entity__r.breg_Purpose__c, ' +
            'breg_Entity__r.BillingStreet, breg_Entity__r.breg_Billing_Address_Street_2__c, breg_Entity__r.BillingCity, ' +
            'breg_Entity__r.BillingStateCode, breg_Entity__r.BillingCountryCode, breg_Entity__r.BillingPostalCode, ' +
            'breg_Entity__r.breg_Mailing_Address__Street__s, breg_Entity__r.breg_Mailing_Address_Street_2__c, ' +
            'breg_Entity__r.breg_Mailing_Address__City__s, breg_Entity__r.breg_Mailing_Address__StateCode__s, ' +
            'breg_Entity__r.breg_Mailing_Address__CountryCode__s, breg_Entity__r.breg_Mailing_Address__PostalCode__s, ' +
            'breg_Entity__r.breg_Number_of_initial_members__c, breg_Entity__r.breg_Membership_Fees_Received__c, ' +
            'breg_Entity__r.breg_Number_of_Shareholders__c ' +
            'FROM Case ' +
            'WHERE breg_No_Changes__c = false ' +
            'AND Status = \'Received\' ' +
            'AND Origin = \'Web\' ' +
            'AND RecordType.DeveloperName = \'BREG_Case\' ' +
            'AND breg_Form_Code__c LIKE \'ANN-%\' ' +
            'AND breg_Entity__c != null';

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Case> scope) {
        Set<Id> caseIds = new Set<Id>();
        Set<Id> entityIds = new Set<Id>();
        for (Case caseRecord : scope) {
            caseIds.add(caseRecord.Id);
            if (caseRecord.breg_Entity__c != null) {
                entityIds.add(caseRecord.breg_Entity__c);
            }
        }

        Map<Id, List<breg_Account_Affiliation__c>> caseAffsByCaseId = groupAffiliations(
            BREGAnnualRobotWithoutSharing.getCaseAffiliations(caseIds),
            'breg_Case__c'
        );
        Map<Id, List<breg_Account_Affiliation__c>> entityAffsByEntityId = groupAffiliations(
            BREGAnnualRobotWithoutSharing.getEntityAffiliations(entityIds),
            'breg_Entity__c'
        );
        Map<Id, List<breg_Stock__c>> caseStocksByCaseId = groupStocks(BREGAnnualRobotWithoutSharing.getCaseStocks(caseIds), 'breg_Case__c');
        Map<Id, List<breg_Stock__c>> entityStocksByEntityId = groupStocks(BREGAnnualRobotWithoutSharing.getEntityStocks(entityIds), 'breg_Account__c');

        for (Case caseRecord : scope) {
            totalProcessed++;

            if (caseRecord.breg_Entity__c == null || caseRecord.breg_Entity__r == null) {
                totalSkippedNoEntity++;
                continue;
            }

            BREGAnnualRobotComparison.ComparisonResult comparisonResult = BREGAnnualRobotComparison.compareAnnualData(
                caseRecord,
                caseRecord.breg_Entity__r,
                caseAffsByCaseId.get(caseRecord.Id),
                entityAffsByEntityId.get(caseRecord.breg_Entity__c),
                caseStocksByCaseId.get(caseRecord.Id),
                entityStocksByEntityId.get(caseRecord.breg_Entity__c)
            );

            if (comparisonResult.hasDifferences) {
                totalWithDifferences++;
            } else {
                totalNoDifferences++;
            }

            csvLines.add(buildCsvLine(caseRecord, comparisonResult));
        }
    }

    public void finish(Database.BatchableContext bc) {
        List<String> allCsvLines = new List<String>{ CSV_HEADER };
        allCsvLines.addAll(csvLines);
        String csvContent = String.join(allCsvLines, '\n');

        insert new ContentVersion(
            Title = 'BREG Annual Robot Validation Results ' + Datetime.now().format('yyyy-MM-dd HH:mm'),
            PathOnClient = 'annual_robot_validation_results.csv',
            VersionData = Blob.valueOf(csvContent)
        );

        System.debug(
            LoggingLevel.INFO,
            'BREGAnnualRobotValidationBatch finished. Processed=' +
                totalProcessed +
                ', SkippedNoEntity=' +
                totalSkippedNoEntity +
                ', WithDifferences=' +
                totalWithDifferences +
                ', NoDifferences=' +
                totalNoDifferences
        );
    }

    private static String buildCsvLine(Case caseRecord, BREGAnnualRobotComparison.ComparisonResult comparisonResult) {
        return String.join(
            new List<String>{
                caseRecord.Id,
                csvSafe(caseRecord.breg_Workitem_Number__c),
                caseRecord.breg_Entity__c,
                csvSafe(caseRecord.breg_Entity__r.breg_File__c),
                csvSafe(caseRecord.breg_Entity__r.Name),
                csvSafe(caseRecord.Status),
                caseRecord.OwnerId,
                csvSafe(caseRecord.Owner.Name),
                csvSafe(caseRecord.breg_Form_Code__c),
                csvSafe(caseRecord.breg_Form_Configuration__r?.breg_Entity_Type__c),
                csvSafe(String.valueOf(caseRecord.CreatedDate)),
                comparisonResult.hasDifferences ? 'No' : 'Yes',
                String.valueOf(comparisonResult.diffs.size())
            },
            ','
        );
    }

    private static String csvSafe(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return '"' + value.replace('"', '""') + '"';
    }

    private static Map<Id, List<breg_Account_Affiliation__c>> groupAffiliations(List<breg_Account_Affiliation__c> affiliations, String keyField) {
        Map<Id, List<breg_Account_Affiliation__c>> grouped = new Map<Id, List<breg_Account_Affiliation__c>>();
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            Id key = (Id) affiliation.get(keyField);
            if (!grouped.containsKey(key)) {
                grouped.put(key, new List<breg_Account_Affiliation__c>());
            }
            grouped.get(key).add(affiliation);
        }
        return grouped;
    }

    private static Map<Id, List<breg_Stock__c>> groupStocks(List<breg_Stock__c> stocks, String keyField) {
        Map<Id, List<breg_Stock__c>> grouped = new Map<Id, List<breg_Stock__c>>();
        for (breg_Stock__c stock : stocks) {
            Id key = (Id) stock.get(keyField);
            if (!grouped.containsKey(key)) {
                grouped.put(key, new List<breg_Stock__c>());
            }
            grouped.get(key).add(stock);
        }
        return grouped;
    }
}