public with sharing class BREGAnnualRobotComparison {

    public class ValuePair {
        public Object caseValue;
        public Object accountValue;

        public ValuePair(Object caseValue, Object accountValue) {
            this.caseValue = caseValue;
            this.accountValue = accountValue;
        }
    }

    public class ComparisonDiff {
        public String fieldName;
        public String label;
        public Object caseValue;
        public Object accountValue;
        public String caseValueNormalized;
        public String accountValueNormalized;

        public ComparisonDiff(String fieldName, String label, ValuePair values) {
            this.fieldName = fieldName;
            this.label = label;
            this.caseValue = values == null ? null : values.caseValue;
            this.accountValue = values == null ? null : values.accountValue;
            this.caseValueNormalized = normalizeValue(fieldName, this.caseValue);
            this.accountValueNormalized = normalizeValue(fieldName, this.accountValue);
        }
    }

    public class ComparisonResult {
        public Boolean hasDifferences;
        public List<ComparisonDiff> diffs;

        public ComparisonResult() {
            this.hasDifferences = false;
            this.diffs = new List<ComparisonDiff>();
        }
    }

    private static final Set<String> NORMALIZED_NUMERIC_FIELDS = new Set<String>{
        'breg_Per_Value__c',
        'breg_Stock_Amount__c',
        'breg_Number_of_Issued_Shares__c',
        'breg_Paid_Shares__c',
        'breg_Number_of_initial_members__c',
        'breg_Membership_Fees_Received__c',
        'breg_Number_of_Shareholders__c'
    };

    private static final Set<String> CASE_ENTITY_TYPES_WITH_INITIAL_MEMBERS = new Set<String>{ 'A2', 'C2', 'C5', 'C6' };
    private static final Set<String> CASE_ENTITY_TYPES_WITH_MEMBERSHIP_FEES = new Set<String>{ 'A2', 'C2' };
    private static final Set<String> CASE_ENTITY_TYPES_WITH_SHAREHOLDERS = new Set<String>{ 'A1', 'C1' };
    private static final String INDIVIDUAL_TYPE = 'Individual';
    private static final String AGENT_ROLE = 'Agent';
    private static final String TITLES_FIELD = 'breg_Officer_Director_Titles__c';
    private static final String TO_REMOVE_FIELD = 'breg_To_Remove__c';
    private static final String AGENT_DETAILS_CHANGED = System.Label.BREG_AnnualRobot_Agent_Details_Changed;
    private static final String AFFILIATION_ADDED = System.Label.BREG_AnnualRobot_Affiliation_Added;
    private static final String AFFILIATION_REMOVED = System.Label.BREG_AnnualRobot_Affiliation_Removed;
    private static final String AFFILIATION_MARKED_FOR_REMOVAL = System.Label.BREG_AnnualRobot_Affiliation_Marked_For_Removal;
    private static final String AFFILIATION_NAME_CHANGED = System.Label.BREG_AnnualRobot_Affiliation_Name_Changed;
    private static final String AFFILIATION_DETAILS_CHANGED = System.Label.BREG_AnnualRobot_Affiliation_Details_Changed;
    private static final String AFFILIATION_COMPLETELY_DIFFERENT = System.Label.BREG_AnnualRobot_Affiliation_Completely_Different;
    private static final String STOCK_ADDED = System.Label.BREG_AnnualRobot_Stock_Added;
    private static final String STOCK_REMOVED = System.Label.BREG_AnnualRobot_Stock_Removed;
    private static final String STOCK_DETAILS_CHANGED = System.Label.BREG_AnnualRobot_Stock_Details_Changed;
    private static final String STOCK_COMPLETELY_DIFFERENT = System.Label.BREG_AnnualRobot_Stock_Completely_Different;

    private static final List<String> CASE_ENTITY_COMPARE_FIELDS = new List<String>{
        'breg_Name_of_the_Entity__c|Name|Name',
        'breg_Entity_Type__c|breg_Entity_Type__c|Entity Type',
        'breg_Entity_Nature_Of_Business__c|breg_Purpose__c|Nature Of Business',
        'breg_Mailing_Address__Street__s|breg_Mailing_Address__Street__s|Mailing Street',
        'breg_Mailing_Address_Number_and_Street_2__c|breg_Mailing_Address_Street_2__c|Mailing Street 2',
        'breg_Mailing_Address__City__s|breg_Mailing_Address__City__s|Mailing City',
        'breg_Mailing_Address__StateCode__s|breg_Mailing_Address__StateCode__s|Mailing State',
        'breg_Mailing_Address__CountryCode__s|breg_Mailing_Address__CountryCode__s|Mailing Country',
        'breg_Mailing_Address__PostalCode__s|breg_Mailing_Address__PostalCode__s|Mailing Postal Code',
        'breg_Company_Address__Street__s|BillingStreet|Company Street',
        'breg_Company_Address_Street2__c|breg_Billing_Address_Street_2__c|Company Street 2',
        'breg_Company_Address__City__s|BillingCity|Company City',
        'breg_Company_Address__StateCode__s|BillingStateCode|Company State',
        'breg_Company_Address__CountryCode__s|BillingCountryCode|Company Country',
        'breg_Company_Address__PostalCode__s|BillingPostalCode|Company Postal Code'
    };

    private static List<String> getCaseEntityMappingsForEntityType(String entityType) {
        List<String> mappings = new List<String>(CASE_ENTITY_COMPARE_FIELDS);
        if (CASE_ENTITY_TYPES_WITH_INITIAL_MEMBERS.contains(entityType)) {
            mappings.add('breg_Number_of_initial_members__c|breg_Number_of_initial_members__c|NumberOfInitialMembers');
        }
        if (CASE_ENTITY_TYPES_WITH_MEMBERSHIP_FEES.contains(entityType)) {
            mappings.add('breg_Membership_Fees_Received__c|breg_Membership_Fees_Received__c|MembershipFeesReceived');
        }
        if (CASE_ENTITY_TYPES_WITH_SHAREHOLDERS.contains(entityType)) {
            mappings.add('breg_Number_of_Shareholders__c|breg_Number_of_Shareholders__c|NumberOfShareholders');
        }
        return mappings;
    }

    private static final List<String> AFFILIATION_COMPARE_FIELDS = new List<String>{
        'breg_Role__c',
        'breg_Type__c',
        'breg_Entity_Name__c',
        'breg_Entity_Location__c',
        'breg_Entity_Location_Country__c',
        'breg_First_Name__c',
        'breg_Last_Name__c',
        'breg_Address__CountryCode__s',
        'breg_Address__Street__s',
        'breg_Address_Street_2__c',
        'breg_Address__StateCode__s',
        'breg_Address__City__s',
        'breg_Address__PostalCode__s',
        'breg_Officer_Director_Titles__c'
    };

    private static final List<String> STOCK_COMPARE_FIELDS = new List<String>{
        'breg_Class_Series__c',
        'breg_Per_Value__c',
        'breg_Class_Detail__c',
        'breg_Number_of_Issued_Shares__c',
        'breg_Paid_Shares__c',
        'breg_Remarks__c',
        'breg_Stock_Amount__c',
        'breg_Stock_Class__c'
    };

    public static ComparisonResult compareAnnualCaseToEntity(Case caseRecord, Account entityRecord) {
        List<String> mappings = entityRecord == null
            ? new List<String>()
            : getCaseEntityMappingsForEntityType(entityRecord.breg_Entity_Type__c);
        return compareAnnualCaseToEntity(caseRecord, entityRecord, mappings);
    }

    public static ComparisonResult compareAnnualData(
        Case caseRecord,
        Account entityRecord,
        List<breg_Account_Affiliation__c> caseAffiliations,
        List<breg_Account_Affiliation__c> entityAffiliations,
        List<breg_Stock__c> caseStocks,
        List<breg_Stock__c> entityStocks
    ) {
        ComparisonResult result = compareAnnualCaseToEntity(caseRecord, entityRecord);
        result.diffs.addAll(compareAffiliations(caseAffiliations, entityAffiliations));
        result.diffs.addAll(compareStocks(caseStocks, entityStocks));
        result.hasDifferences = !result.diffs.isEmpty();
        return result;
    }

    private static ComparisonResult compareAnnualCaseToEntity(Case caseRecord, Account entityRecord, List<String> mappings) {
        ComparisonResult result = new ComparisonResult();
        if (caseRecord == null || entityRecord == null || mappings == null) {
            return result;
        }

        List<ComparisonDiff> diffs = compareCaseToEntity(caseRecord, entityRecord, mappings);
        result.diffs = diffs;
        result.hasDifferences = !diffs.isEmpty();
        return result;
    }

    private static List<ComparisonDiff> compareCaseToEntity(SObject caseRecord, SObject entityRecord, List<String> mappings) {
        List<ComparisonDiff> diffs = new List<ComparisonDiff>();
        if (caseRecord == null || entityRecord == null || mappings == null) {
            return diffs;
        }

        for (String mapping : mappings) {
            if (String.isBlank(mapping)) {
                continue;
            }

            List<String> parts = mapping.split('\\|');
            if (parts.size() < 3) {
                continue;
            }

            String caseField = parts[0];
            String entityField = parts[1];
            String label = parts[2];
            Object caseValue = caseRecord.get(caseField);
            Object entityValue = entityRecord.get(entityField);

            if (hasDiff(caseField, caseValue, entityValue)) {
                diffs.add(new ComparisonDiff(caseField, label, new ValuePair(caseValue, entityValue)));
            }
        }

        return diffs;
    }

    private static List<ComparisonDiff> compareAffiliations(List<breg_Account_Affiliation__c> caseAffiliations, List<breg_Account_Affiliation__c> entityAffiliations) {
        List<ComparisonDiff> diffs = new List<ComparisonDiff>();
        if (caseAffiliations == null) {
            caseAffiliations = new List<breg_Account_Affiliation__c>();
        }
        if (entityAffiliations == null) {
            entityAffiliations = new List<breg_Account_Affiliation__c>();
        }

        breg_Account_Affiliation__c caseAgent = findAgent(caseAffiliations);
        breg_Account_Affiliation__c entityAgent = findAgent(entityAffiliations);
        addAgentDifference(caseAgent, entityAgent, diffs);

        List<breg_Account_Affiliation__c> remainingEntityAffiliations = getNonAgentAffiliations(entityAffiliations);
        for (breg_Account_Affiliation__c caseAffiliation : getNonAgentAffiliations(caseAffiliations)) {
            if (caseAffiliation.breg_To_Remove__c == true) {
                diffs.add(new ComparisonDiff(TO_REMOVE_FIELD, AFFILIATION_MARKED_FOR_REMOVAL, new ValuePair(caseAffiliation, null)));
                continue;
            }

            Integer matchIndex = findBestAffiliationMatchIndex(caseAffiliation, remainingEntityAffiliations);
            if (matchIndex == -1) {
                diffs.add(new ComparisonDiff('breg_Account_Affiliation__c', AFFILIATION_ADDED, new ValuePair(caseAffiliation, null)));
                continue;
            }

            breg_Account_Affiliation__c entityAffiliation = remainingEntityAffiliations.remove(matchIndex);
            addAffiliationDifference(caseAffiliation, entityAffiliation, diffs);
        }

        for (breg_Account_Affiliation__c entityAffiliation : remainingEntityAffiliations) {
            diffs.add(new ComparisonDiff('breg_Account_Affiliation__c', AFFILIATION_REMOVED, new ValuePair(null, entityAffiliation)));
        }
        return diffs;
    }

    private static breg_Account_Affiliation__c findAgent(List<breg_Account_Affiliation__c> affiliations) {
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            if (affiliation != null && affiliation.breg_Role__c == AGENT_ROLE) {
                return affiliation;
            }
        }
        return null;
    }

    private static List<breg_Account_Affiliation__c> getNonAgentAffiliations(List<breg_Account_Affiliation__c> affiliations) {
        List<breg_Account_Affiliation__c> nonAgentAffiliations = new List<breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c affiliation : affiliations) {
            if (affiliation != null && affiliation.breg_Role__c != AGENT_ROLE) {
                nonAgentAffiliations.add(affiliation);
            }
        }
        return nonAgentAffiliations;
    }

    private static void addAgentDifference(
        breg_Account_Affiliation__c caseAgent,
        breg_Account_Affiliation__c entityAgent,
        List<ComparisonDiff> diffs
    ) {
        if (caseAgent == null && entityAgent == null) {
            return;
        }
        if (caseAgent == null || entityAgent == null || caseAgent.breg_To_Remove__c == true || countAffiliationFieldDiffs(caseAgent, entityAgent) > 0) {
            diffs.add(new ComparisonDiff('breg_Account_Affiliation__c', AGENT_DETAILS_CHANGED, new ValuePair(caseAgent, entityAgent)));
        }
    }

    private static Integer findBestAffiliationMatchIndex(breg_Account_Affiliation__c caseAffiliation, List<breg_Account_Affiliation__c> candidates) {
        if (candidates.isEmpty()) {
            return -1;
        }

        Integer bestIndex = 0;
        Integer bestScore;
        for (Integer i = 0; i < candidates.size(); i++) {
            Integer score = countAffiliationFieldDiffs(caseAffiliation, candidates[i]);
            if (bestScore == null || score < bestScore) {
                bestScore = score;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    private static Integer countAffiliationFieldDiffs(breg_Account_Affiliation__c left, breg_Account_Affiliation__c right) {
        Integer count = 0;
        for (String fieldName : AFFILIATION_COMPARE_FIELDS) {
            if (isAffiliationFieldDifferent(left, right, fieldName)) {
                count++;
            }
        }
        return count;
    }

    private static void addAffiliationDifference(
        breg_Account_Affiliation__c caseAffiliation,
        breg_Account_Affiliation__c entityAffiliation,
        List<ComparisonDiff> diffs
    ) {
        Integer differenceCount = countAffiliationFieldDiffs(caseAffiliation, entityAffiliation);
        if (differenceCount == 0) {
            return;
        }

        if (hasOnlyAffiliationNameChanged(caseAffiliation, entityAffiliation, differenceCount)) {
            diffs.add(new ComparisonDiff('breg_Account_Affiliation__c', AFFILIATION_NAME_CHANGED, new ValuePair(caseAffiliation, entityAffiliation)));
        } else if (differenceCount == AFFILIATION_COMPARE_FIELDS.size()) {
            diffs.add(new ComparisonDiff('breg_Account_Affiliation__c', AFFILIATION_COMPLETELY_DIFFERENT, new ValuePair(caseAffiliation, entityAffiliation)));
        } else {
            diffs.add(new ComparisonDiff('breg_Account_Affiliation__c', AFFILIATION_DETAILS_CHANGED, new ValuePair(caseAffiliation, entityAffiliation)));
        }
    }

    private static Boolean hasOnlyAffiliationNameChanged(
        breg_Account_Affiliation__c caseAffiliation,
        breg_Account_Affiliation__c entityAffiliation,
        Integer differenceCount
    ) {
        if (caseAffiliation.breg_Type__c == INDIVIDUAL_TYPE) {
            return differenceCount <= 2 &&
                (
                    isAffiliationFieldDifferent(caseAffiliation, entityAffiliation, 'breg_First_Name__c') ||
                    isAffiliationFieldDifferent(caseAffiliation, entityAffiliation, 'breg_Last_Name__c')
                );
        }
        return differenceCount == 1 && isAffiliationFieldDifferent(caseAffiliation, entityAffiliation, 'breg_Entity_Name__c');
    }

    private static List<ComparisonDiff> compareStocks(List<breg_Stock__c> caseStocks, List<breg_Stock__c> entityStocks) {
        List<ComparisonDiff> diffs = new List<ComparisonDiff>();
        if (caseStocks == null) {
            caseStocks = new List<breg_Stock__c>();
        }
        if (entityStocks == null) {
            entityStocks = new List<breg_Stock__c>();
        }

        List<breg_Stock__c> remainingEntityStocks = new List<breg_Stock__c>(entityStocks);

        for (breg_Stock__c caseStock : caseStocks) {
            if (caseStock == null) {
                continue;
            }

            Integer matchIndex = findBestStockMatchIndex(caseStock, remainingEntityStocks);
            if (matchIndex == -1) {
                diffs.add(new ComparisonDiff('breg_Stock__c', STOCK_ADDED, new ValuePair(caseStock, null)));
                continue;
            }

            breg_Stock__c entityStock = remainingEntityStocks.remove(matchIndex);
            addStockDifference(caseStock, entityStock, diffs);
        }

        for (breg_Stock__c entityStock : remainingEntityStocks) {
            diffs.add(new ComparisonDiff('breg_Stock__c', STOCK_REMOVED, new ValuePair(null, entityStock)));
        }
        return diffs;
    }

    private static Integer findBestStockMatchIndex(breg_Stock__c caseStock, List<breg_Stock__c> candidates) {
        if (candidates.isEmpty()) {
            return -1;
        }

        Integer bestIndex = 0;
        Integer bestScore;
        for (Integer i = 0; i < candidates.size(); i++) {
            Integer score = countStockFieldDiffs(caseStock, candidates[i], STOCK_COMPARE_FIELDS);
            if (bestScore == null || score < bestScore) {
                bestScore = score;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    private static Integer countStockFieldDiffs(breg_Stock__c left, breg_Stock__c right, List<String> fieldNames) {
        Integer count = 0;
        for (String fieldName : fieldNames) {
            if (hasDiff(fieldName, left.get(fieldName), right.get(fieldName))) {
                count++;
            }
        }
        return count;
    }

    private static void addStockDifference(breg_Stock__c caseStock, breg_Stock__c entityStock, List<ComparisonDiff> diffs) {
        Integer differenceCount = countStockFieldDiffs(caseStock, entityStock, STOCK_COMPARE_FIELDS);
        if (differenceCount == 0) {
            return;
        }

        String label = differenceCount == STOCK_COMPARE_FIELDS.size()
            ? STOCK_COMPLETELY_DIFFERENT
            : STOCK_DETAILS_CHANGED;
        diffs.add(new ComparisonDiff('breg_Stock__c', label, new ValuePair(caseStock, entityStock)));
    }

    @TestVisible
    private static String normalizeValue(String fieldName, Object value) {
        String normalized = value == null ? '' : String.valueOf(value).trim();
        Boolean isNumericField = NORMALIZED_NUMERIC_FIELDS.contains(fieldName);

        if (String.isBlank(normalized)) {
            return isNumericField ? '0' : '';
        }

        if (isNumericField) {
            normalized = normalized.replace(',', '').replace('.', '');
        }

        return normalized.toLowerCase();
    }

    private static Boolean hasDiff(String fieldName, Object caseValue, Object entityValue) {
        return normalizeValue(fieldName, caseValue) != normalizeValue(fieldName, entityValue);
    }

    private static Boolean isAffiliationFieldDifferent(
        breg_Account_Affiliation__c caseAffiliation,
        breg_Account_Affiliation__c entityAffiliation,
        String fieldName
    ) {
        Object caseValue = caseAffiliation.get(fieldName);
        Object entityValue = entityAffiliation.get(fieldName);
        if (fieldName == TITLES_FIELD && String.isBlank((String) caseValue) && String.isNotBlank((String) entityValue)) {
            return false;
        }
        return hasDiff(fieldName, caseValue, entityValue);
    }
}