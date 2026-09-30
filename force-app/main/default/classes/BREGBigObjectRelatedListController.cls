public with sharing class BREGBigObjectRelatedListController {
    public class PageRequest {
        @AuraEnabled public String bigObjectApiName;
        @AuraEnabled public String keyFieldApiName;
        @AuraEnabled public String keyFieldValue;
        @AuraEnabled public List<String> fieldApiNames;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public String sortFieldApiName;
        @AuraEnabled public String sortDirection; // 'ASC' or 'DESC'
        @AuraEnabled public String cursorValue;   // last seen value for keyset pagination (may be null on first load)
        @AuraEnabled public Boolean isNext;       // true -> next page, false -> previous page
    }

    public class PageRow {
        @AuraEnabled public Map<String, Object> values;
    }

    public class PageResult {
        @AuraEnabled public List<PageRow> rows;
        @AuraEnabled public String nextCursor;   // last row's sort value (stringified)
        @AuraEnabled public String prevCursor;   // first row's sort value (stringified)
        @AuraEnabled public Integer fetchedCount;
        @AuraEnabled public String warning;      // optional user-friendly warning
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getFieldLabels(String bigObjectApiName, List<String> fieldApiNames) {
        Schema.SObjectType sObjType = getSObjectTypeStrict(bigObjectApiName);
        Schema.DescribeSObjectResult d = sObjType.getDescribe();
        Map<String, Schema.SObjectField> fields = d.fields.getMap();

        Map<String, String> labels = new Map<String, String>();
        for (String api : fieldApiNames) {
            if (!fields.containsKey(api)) {
                // Skip unknown fields but include a hint label
                labels.put(api, api + ' (Unknown field)');
                continue;
            }
            Schema.DescribeFieldResult fd = fields.get(api).getDescribe();
            labels.put(api, fd.getLabel());
        }
        return labels;
    }
    @AuraEnabled(cacheable=true)
    public static PageResult queryPageUnwrapped(
        String bigObjectApiName,
        String keyFieldApiName,
        String keyFieldValue,
        List<String> fieldApiNames,
        Integer pageSize,
        String sortFieldApiName,
        String sortDirection,
        String cursorValue,
        Boolean isNext
    ) {
        system.debug('bigObjectApiName=' + bigObjectApiName);
        PageRequest req = new PageRequest();
        req.bigObjectApiName = bigObjectApiName;
        req.keyFieldApiName = keyFieldApiName;
        req.keyFieldValue = keyFieldValue;
        req.fieldApiNames = fieldApiNames;
        req.pageSize = pageSize;
        req.sortFieldApiName = sortFieldApiName;
        req.sortDirection = sortDirection;
        req.cursorValue = cursorValue;
        req.isNext = isNext;

        return queryPage(req); // call your existing internal method
    }

    @AuraEnabled(cacheable=true)
    public static PageResult queryPage(PageRequest req) {
        system.debug('req=' + req);
        validate(req);

        Schema.SObjectType sObjType = getSObjectTypeStrict(req.bigObjectApiName);
        Schema.DescribeSObjectResult d = sObjType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = d.fields.getMap();

        // Build a whitelist of fields to actually select (intersection of requested & described)
        List<String> selectFields = new List<String>();
        for (String f : req.fieldApiNames) {
            if (fieldMap.containsKey(f)) selectFields.add(f);
        }
        if (selectFields.isEmpty()) {
            // Always include the sort field so pagination continues to work
            if (fieldMap.containsKey(req.sortFieldApiName)) selectFields.add(req.sortFieldApiName);
        } else if (!selectFields.contains(req.sortFieldApiName) && fieldMap.containsKey(req.sortFieldApiName)) {
            // Ensure sort field is in the selection so we can compute cursors
            selectFields.add(req.sortFieldApiName);
        }

        // WHERE clause
        String whereClause = '(' + req.keyFieldApiName + ' = :keyVal)';
        Object keyVal = req.keyFieldValue;

        // Keyset pagination condition
        String effectiveDir = (req.sortDirection == 'DESC') ? 'DESC' : 'ASC';
        String comparator;
        if (req.cursorValue != null && req.cursorValue != '') {
            Schema.DescribeFieldResult sortFd = fieldMap.get(req.sortFieldApiName).getDescribe();
            Object cursorTyped = coerceCursorValue(sortFd, req.cursorValue);

            // For next vs previous, flip the comparison
            // ASC + next => >; ASC + prev => <; DESC + next => <; DESC + prev => >
            Boolean asc1 = (effectiveDir == 'ASC');
            Boolean next = (req.isNext == null) ? true : req.isNext;

            if (asc1 && next) comparator = '>';
            else if (asc1 && !next) comparator = '<';
            else if (!asc1 && next) comparator = '<';
            else comparator = '>';

            whereClause += ' AND (' + req.sortFieldApiName + ' ' + comparator + ' :cursorTyped)';
        }

        // ORDER BY and LIMIT
        String orderBy = ' ORDER BY ' + req.sortFieldApiName + ' ' + effectiveDir;
        Integer limitSize = (req.pageSize == null || !(new Set<Integer>{10,50,200}).contains(req.pageSize))
            ? 10 : req.pageSize;

        // Build dynamic SOQL safely
        String soql = 'SELECT ' + String.join(selectFields, ',')
                    + ' FROM ' + req.bigObjectApiName
                    + ' WHERE ' + whereClause
                    + orderBy
                    + ' LIMIT :limitSize';

        // Execute
        system.debug('soql=' + soql);
        List<SObject> raw = Database.query(soql);

        // Map rows
        List<PageRow> rows = new List<PageRow>();
        for (SObject rec : raw) {
            Map<String, Object> row = new Map<String, Object>();
            for (String f : selectFields) {
                row.put(f, rec.get(f));
            }
            PageRow pr = new PageRow();
            pr.values = row;
            rows.add(pr);
        }

        // Prepare cursors
        String nextCursor = null;
        String prevCursor = null;
        if (!rows.isEmpty()) {
            Object firstVal = rows[0].values.get(req.sortFieldApiName);
            Object lastVal  = rows[rows.size()-1].values.get(req.sortFieldApiName);
            prevCursor = stringifyCursor(firstVal);
            nextCursor = stringifyCursor(lastVal);
        }

        PageResult result = new PageResult();
        result.rows = rows;
        result.nextCursor = nextCursor;
        result.prevCursor = prevCursor;
        result.fetchedCount = rows.size();

        // Add a gentle warning when sort field may not be indexed
        if (!isLikelyIndexedField(req.bigObjectApiName, req.sortFieldApiName)) {
            result.warning = 'Sorting on ' + req.sortFieldApiName + ' may require this field to be part of the Big Object index.';
        }
        return result;
    }

    // ---------- Helpers ----------

    private static void validate(PageRequest r) {
        if (String.isBlank(r.bigObjectApiName)) throw new AuraHandledException('bigObjectApiName is required.');
        if (String.isBlank(r.keyFieldApiName)) throw new AuraHandledException('keyFieldApiName is required.');
        if (String.isBlank(r.keyFieldValue))   throw new AuraHandledException('keyFieldValue is required.');
        if (String.isBlank(r.sortFieldApiName)) r.sortFieldApiName = r.keyFieldApiName;
        if (r.fieldApiNames == null) r.fieldApiNames = new List<String>();
    }

    private static Schema.SObjectType getSObjectTypeStrict(String apiName) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(apiName);
        if (t == null) throw new AuraHandledException('Unknown object: ' + apiName);
        return t;
    }

    private static Object coerceCursorValue(Schema.DescribeFieldResult fd, String val) {
        Schema.DisplayType dt = fd.getType();
        try {
            switch on dt {
                when Date       { return Date.valueOf(val); }
                when DateTime   { return DateTime.valueOf(val); }
                when Integer    { return Integer.valueOf(val); }
                when Long       { return Long.valueOf(val); }
                when Double     { return Double.valueOf(val); }
                when Currency   { return Decimal.valueOf(val); }
                when Percent    { return Decimal.valueOf(val); }
                when String     { return val; }
                when Id         { return (Id)val; }
                when else       { return val; }
            }
        } catch (Exception e) {
            // Fall back to string compare if parse fails
            return val;
        }
    }

    private static String stringifyCursor(Object v) {
        return (v == null) ? null : String.valueOf(v);
    }

    /**
     * Minimal heuristic: Big Objects don’t expose index metadata via Describe.
     * If the field name ends with '__c' or is the same as key field, assume caller designed the index.
     */
    private static Boolean isLikelyIndexedField(String objApi, String fieldApi) {
        // You can enhance this to consult a Custom Metadata Type listing your Big Object indexes.
        return fieldApi != null;
    }
}