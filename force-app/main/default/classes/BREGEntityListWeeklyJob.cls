public with sharing class BREGEntityListWeeklyJob extends BREGBatchInterface {
    public override BatchProcessingResult processRecords(Map<Id, SObject> recordsMap, String sObjectType) {
        BatchProcessingResult result = new BatchProcessingResult();
        List<breg_Entity_List_Result__c> results = (List<breg_Entity_List_Result__c>) recordsMap.values();

        result.recordsToUpsert = checkDifferences(results);
        return result;
    }

    public static Map<Id, SObject> checkDifferences(List<breg_Entity_List_Result__c> scope) {
        Map<Id, SObject> resultToUpdate = new Map<Id, SObject>();
        Map<Id, List<Id>> accOrderByEntityList = new Map<Id, List<Id>>();
        Map<Id, Set<Id>> accIdsByEntityList = new Map<Id, Set<Id>>();
        Set<Id> allAccIds = collectAllAccountIds(scope, accOrderByEntityList, accIdsByEntityList);
        if (allAccIds.isEmpty())
            return resultToUpdate;

        Schema.FieldSet fs = Schema.SObjectType.Account.FieldSets.BREG_Entity_List_Builder_Fields;
        List<Schema.FieldSetMember> fms = fs.getFields();
        Map<Id, SObject> accById = queryAccounts(allAccIds, fms);
        Map<Id, Map<String, Integer>> txCountsByAcc = queryTransactionAggregates(allAccIds);
        Set<String> allCodes = new Set<String>();
        for (Map<String, Integer> perAcc : txCountsByAcc.values()) {
            allCodes.addAll(perAcc.keySet());
        }

        Map<String, String> descByCode = queryTransactionDescriptions(allAccIds, allCodes);
        Map<String, String> codeLabelMap = getPicklistLabels();

        for (breg_Entity_List_Result__c entityListResult : scope) {
            try {
                List<Id> accOrder = accOrderByEntityList.get(entityListResult.Id);
                Set<Id> accIds = accIdsByEntityList.get(entityListResult.Id);
                if (accIds == null || accIds.isEmpty())
                    continue;

                String finalCsv = buildCsv(accOrder, accById, fms);
                if (!Test.isRunningTest())
                    DocuSignAPI.uploadEntityListFile(entityListResult.breg_Entity_List__c, finalCsv);

                String diffText = buildDiffText(accIds, txCountsByAcc, descByCode, codeLabelMap);
                resultToUpdate.put(
                    entityListResult.breg_Entity_List__c,
                    new breg_Entity_List__c(Id = entityListResult.breg_Entity_List__c, breg_Difference_for_a_week__c = diffText)
                );
                if (!Test.isRunningTest())
                    System.enqueueJob(new BREGStartDocusignWorkflow('BREG EntityList Download Document', entityListResult.breg_Entity_List__c, null, 'EntityList Weekly Job', false)); //TODO add param for related case for log record
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'EntityList ' + entityListResult.Id + ' failed: ' + e.getMessage());
            }
        }
        return resultToUpdate;
    }

    // --- Helpers ---

    public static Set<Id> collectAllAccountIds(
        List<breg_Entity_List_Result__c> scope,
        Map<Id, List<Id>> accOrderByEntityList,
        Map<Id, Set<Id>> accIdsByEntityList
    ) {
        Set<Id> allAccIds = new Set<Id>();
        for (breg_Entity_List_Result__c entityListResult : scope) {
            Blob csvBlob;
            if (Test.isRunningTest()) {
                Account testAcc = [SELECT Id, Name FROM Account WHERE Name = 'Test Entity Job Acc' LIMIT 1];
                csvBlob = Blob.valueOf('"AccountId","AccountName","TransactionCode"\n' + '"' + testAcc.Id + '","' + testAcc.Name + '","AD-1"\n');
            } else {
                csvBlob = DocuSignAPI.getDocumentBlob(entityListResult.breg_Docusign_Document_Id__c, false);
            }

            String csvText = csvBlob.toString();
            List<List<String>> rows = parseCsv(csvText);
            Set<Id> accIds = new Set<Id>();
            List<Id> accOrder = new List<Id>();
            for (Integer i = 1; i < rows.size(); i++) {
                if (rows[i].isEmpty())
                    continue;
                String raw = rows[i][0]?.trim();
                if (String.isNotBlank(raw)) {
                    try {
                        Id aid = (Id) raw;
                        if (accIds.add(aid)) {
                            accOrder.add(aid);
                            allAccIds.add(aid);
                        }
                    } catch (Exception e) {
                    }
                }
            }
            accOrderByEntityList.put(entityListResult.Id, accOrder);
            accIdsByEntityList.put(entityListResult.Id, accIds);
        }
        return allAccIds;
    }

    public static Map<Id, SObject> queryAccounts(Set<Id> accIds, List<Schema.FieldSetMember> fms) {
        String soql = 'SELECT Id';
        for (Schema.FieldSetMember fm : fms) {
            if (fm.getFieldPath() != 'Id') {
                soql += ',' + fm.getFieldPath();
            }
        }
        soql += ' FROM Account WHERE Id IN :accIds';
        return new Map<Id, SObject>((List<SObject>) Database.query(soql));
    }

    public static Map<Id, Map<String, Integer>> queryTransactionAggregates(Set<Id> accIds) {
        Map<Id, Map<String, Integer>> txCountsByAcc = new Map<Id, Map<String, Integer>>();
        for (AggregateResult ar : [
            SELECT breg_Account__c accId, breg_Transaction_Code__c code, COUNT(Id) cnt
            FROM breg_Transaction__c
            WHERE breg_Account__c IN :accIds AND CreatedDate = LAST_N_DAYS:7
            GROUP BY breg_Account__c, breg_Transaction_Code__c
        ]) {
            Id aid = (Id) ar.get('accId');
            String code = (String) ar.get('code');
            Integer c = (Integer) ar.get('cnt');
            if (!txCountsByAcc.containsKey(aid)) {
                txCountsByAcc.put(aid, new Map<String, Integer>());
            }
            Map<String, Integer> perAcc = txCountsByAcc.get(aid);
            perAcc.put(code, perAcc.containsKey(code) ? perAcc.get(code) + c : c);
        }
        return txCountsByAcc;
    }

    public static Map<String, String> queryTransactionDescriptions(Set<Id> accIds, Set<String> codes) {
        Map<String, String> descByCode = new Map<String, String>();
        if (!codes.isEmpty()) {
            for (breg_Transaction__c tx : [
                SELECT breg_Transaction_Code__c, breg_Description__c
                FROM breg_Transaction__c
                WHERE breg_Account__c IN :accIds AND CreatedDate = LAST_N_DAYS:7 AND breg_Transaction_Code__c IN :codes
                LIMIT 50000
            ]) {
                String code = tx.breg_Transaction_Code__c;
                if (!descByCode.containsKey(code) && !String.isBlank(tx.breg_Description__c)) {
                    descByCode.put(code, tx.breg_Description__c);
                }
            }
        }
        return descByCode;
    }

    public static Map<String, String> getPicklistLabels() {
        Map<String, String> codeLabelMap = new Map<String, String>();
        Schema.DescribeFieldResult dfr = breg_Transaction__c.breg_Transaction_Code__c.getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            codeLabelMap.put(pe.getValue(), pe.getLabel());
        }
        return codeLabelMap;
    }

    public static String buildCsv(List<Id> accOrder, Map<Id, SObject> accById, List<Schema.FieldSetMember> fms) {
        String csvContent = '';
        List<String> fieldPaths = new List<String>();

        for (Schema.FieldSetMember fm : fms) {
            csvContent += csvEscape(fm.getLabel()) + ',';
            fieldPaths.add(fm.getFieldPath());
        }
        csvContent = csvContent.removeEnd(',');
        csvContent += '\n';

        for (Id aid : accOrder) {
            SObject acc = accById.get(aid);
            if (acc == null)
                continue;

            for (String fieldPath : fieldPaths) {
                Object v = acc.get(fieldPath);
                csvContent += csvEscape(v == null ? '' : String.valueOf(v)) + ',';
            }
            csvContent = csvContent.removeEnd(',');
            csvContent += '\n';
        }

        return csvContent;
    }

    public static String buildDiffText(
        Set<Id> accIds,
        Map<Id, Map<String, Integer>> txCountsByAcc,
        Map<String, String> descByCode,
        Map<String, String> codeLabelMap
    ) {
        Map<String, Integer> mergedCounts = new Map<String, Integer>();
        Set<Id> accsWithTx = new Set<Id>();
        for (Id aid : accIds) {
            if (txCountsByAcc.containsKey(aid)) {
                accsWithTx.add(aid);
                for (String code : txCountsByAcc.get(aid).keySet()) {
                    Integer c = txCountsByAcc.get(aid).get(code);
                    mergedCounts.put(code, mergedCounts.containsKey(code) ? mergedCounts.get(code) + c : c);
                }
            }
        }
        Integer noChangesCount = accIds.size() - accsWithTx.size();

        Datetime endDt = Datetime.now();
        Datetime startDt = endDt.addDays(-7);
        String pattern = 'yyyy-MM-dd';
        String headerText = 'Changes for period ' + startDt.format(pattern) + ' - ' + endDt.format(pattern) + ':';

        List<String> diffLines = new List<String>();
        diffLines.add(headerText);
        for (String code : mergedCounts.keySet()) {
            String label = codeLabelMap.containsKey(code) ? codeLabelMap.get(code) : code;
            String txDesc = descByCode.containsKey(code) ? ' (' + descByCode.get(code) + ')' : '';
            diffLines.add(label + txDesc + ' - ' + String.valueOf(mergedCounts.get(code)) + ' records;');
        }
        diffLines.add('NO CHANGES - ' + String.valueOf(noChangesCount) + ' records.');

        return String.join(diffLines, '\n');
    }

    public static String csvEscape(String s) {
        if (s == null)
            s = '';
        return '"' + s.replace('"', '""') + '"';
    }

    private static List<List<String>> parseCsv(String text) {
        List<List<String>> result = new List<List<String>>();
        if (String.isBlank(text))
            return result;

        List<String> lines = text.split('\n');

        for (String line : lines) {
            line = line.replace('\r', '');
            if (line == '')
                continue;

            List<String> row = new List<String>();
            List<String> rawFields = line.split(',', -1);
            for (String field : rawFields) {
                field = field.trim();
                if (field.startsWith('"') && field.endsWith('"') && field.length() >= 2) {
                    field = field.substring(1, field.length() - 1);
                    field = field.replace('""', '"');
                }
                row.add(field);
            }
            result.add(row);
        }
        return result;
    }
}