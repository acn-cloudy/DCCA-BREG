public class BREGGetFeeForService {
    /**
     * @description Method to get fees for a service. Currently performs only strict comparizon of field values
     * @author  | 07-02-2025
     * @param fieldsToSelect Set of fields' api names to select
     * @param filters List of single-entry maps {fieldApiName => value}. Using a list allows the same field to appear
     *                multiple times with different values. If picklist, value may be a comma-separated string or List<Object>.
     * @return List<breg_Fee__c>
     **/
    @AuraEnabled
    public static List<breg_Fee__c> getFees(List<String> fieldsToSelect, Map<String, Object> filters, String orderBy, String filterLogic) {
        List<Map<String, Object>> filterList = new List<Map<String, Object>>();
        for (String fieldName : filters.keySet()) {
            filterList.add(new Map<String, Object>{ fieldName => filters.get(fieldName) });
        }
        return getFeesComplexFilter(fieldsToSelect, filterList, orderBy, filterLogic);
    }

    public static List<breg_Fee__c> getFeesComplexFilter(
        List<String> fieldsToSelect,
        List<Map<String, Object>> filters,
        String orderBy,
        String filterLogic
    ) {
        // Target object to query (replace with your actual object name)
        String objectName = 'breg_Fee__c';

        // Describe the object
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = targetType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

        // Build SOQL parts
        String baseQuery = 'SELECT ' + String.join(fieldsToSelect, ',') + ' FROM ' + objectName;

        // Use a 1-based map so that skipped filters leave gaps that buildWhereClause can handle.
        // filterIdx always increments, even for skipped/invalid filters, so filterLogic indices
        // stay aligned with the original position in the filters list.
        Integer filterIdx = 0;
        Map<Integer, String> clauseMap = new Map<Integer, String>();

        for (Map<String, Object> filter : filters) {
            filterIdx++;
            if (filter == null || filter.isEmpty()) continue;
            String fieldName = new List<String>(filter.keySet())[0];
            Object filterValue = filter.get(fieldName);

            Schema.DisplayType fieldType;
            if (fieldName.contains('.')) {
                fieldType = new FieldTypeResolver().getFieldType(fieldName, objectName);
            } else if (!fieldMap.containsKey(fieldName)) {
                continue; // Skip unknown fields
            } else {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                fieldType = fieldDescribe.getType();
            }

            if (filterValue == null) {
                clauseMap.put(filterIdx, fieldName + ' = NULL');
                continue;
            }

            String newClause = null;

            switch on fieldType {
                when Picklist {
                    List<String> values = new List<String>();

                    if (filterValue instanceof List<Object>) {
                        for (Object val : (List<Object>) filterValue) {
                            if (val != null) {
                                values.add(String.escapeSingleQuotes(String.valueOf(val).trim()));
                            }
                        }
                    } else if (filterValue instanceof String) {
                        String value = (String) filterValue;
                        if (!String.isBlank(value)) {
                            for (String val : value.split(',')) {
                                if (!String.isBlank(val)) {
                                    values.add(String.escapeSingleQuotes(val.trim()));
                                }
                            }
                        }
                    }

                    if (!values.isEmpty()) {
                        newClause = values.size() == 1
                            ? fieldName + ' = \'' + values[0] + '\''
                            : fieldName + ' IN (\'' + String.join(values, '\', \'') + '\')';
                    }
                }
                when Boolean {
                    if (filterValue instanceof Boolean) {
                        newClause = fieldName + ' = ' + String.valueOf((Boolean) filterValue);
                    }
                }
                when String, TextArea, Email, Phone, Url {
                    if (filterValue instanceof List<Object>) {
                        List<Object> rawList = (List<Object>) filterValue;
                        List<String> values = new List<String>();
                        for (Object val : rawList) {
                            if (val != null)
                                values.add('\'' + String.escapeSingleQuotes(String.valueOf(val)) + '\'');
                        }
                        if (!values.isEmpty()) {
                            newClause = fieldName + ' IN (' + String.join(values, ', ') + ')';
                        }
                    } else {
                        String value = (String) filterValue;
                        if (!String.isBlank(value)) {
                            newClause = fieldName + ' = \'' + String.escapeSingleQuotes(value.trim()) + '\'';
                        }
                    }
                }
                // when Date, DateTime {
                //     if (filterValue instanceof Date || filterValue instanceof DateTime) {
                //         newClause = fieldName + ' = ' + String.valueOf(filterValue);
                //     }
                // }
                when Double, Currency, Integer, Percent, Long {
                    if (filterValue instanceof Decimal || filterValue instanceof Integer || filterValue instanceof Long) {
                        newClause = fieldName + ' = ' + String.valueOf(filterValue);
                    }
                }
                when Reference {
                    String value = (String) filterValue;
                    if (!String.isBlank(value)) {
                        newClause = fieldName + ' = \'' + String.escapeSingleQuotes(value.trim()) + '\'';
                    }
                }
                when else {
                    // Other field types can be added as needed
                }
            }

            if (newClause != null) {
                clauseMap.put(filterIdx, newClause);
            }
        }

        // Build final query
        String finalQuery = baseQuery;
        String fullWhereClause = buildWhereClause(clauseMap, filterLogic);
        finalQuery += fullWhereClause;
        if (!String.isBlank(orderBy)) {
            finalQuery += ' ORDER BY ' + String.escapeSingleQuotes(orderBy);
        }

        // Execute dynamic SOQL
        return (List<breg_Fee__c>) Database.query(finalQuery);
    }

    /**
     * Backward-compatible overload: converts a positional list to a 1-based map and delegates.
     */
    public static String buildWhereClause(List<String> whereClauses, String filterLogic) {
        if (whereClauses == null || whereClauses.isEmpty()) return '';
        Map<Integer, String> clauseMap = new Map<Integer, String>();
        for (Integer i = 0; i < whereClauses.size(); i++) {
            clauseMap.put(i + 1, whereClauses[i]);
        }
        return buildWhereClause(clauseMap, filterLogic);
    }

    /**
     * Builds a WHERE clause from a 1-based map of index → condition string.
     * Indices absent from the map (skipped/empty filters) are silently dropped and the
     * filterLogic expression is simplified accordingly (e.g. "1 AND (2 OR 3)" with index 1
     * absent becomes "(2 OR 3)").
     */
    public static String buildWhereClause(Map<Integer, String> clauseMap, String filterLogic) {
        if (clauseMap == null || clauseMap.isEmpty()) return '';

        if (String.isBlank(filterLogic)) {
            return ' WHERE ' + String.join(new List<String>(clauseMap.values()), ' AND ');
        }

        List<String> tokens = tokenizeFilterLogic(filterLogic);
        FilterLogicParser parser = new FilterLogicParser(tokens, clauseMap);
        String result = parser.parseExpr();
        return String.isBlank(result) ? '' : ' WHERE ' + result;
    }

    private static List<String> tokenizeFilterLogic(String filterLogic) {
        List<String> tokens = new List<String>();
        for (String rawToken : filterLogic.split('\\s+')) {
            if (String.isBlank(rawToken))
                continue;

            // Extract leading '('
            Integer start = 0;
            while (start < rawToken.length() && rawToken.substring(start, start + 1) == '(') {
                tokens.add('(');
                start++;
            }

            // Extract trailing ')'
            Integer endPosition = rawToken.length();
            List<String> trailingParens = new List<String>();
            while (endPosition > start && rawToken.substring(endPosition - 1, endPosition) == ')') {
                trailingParens.add(')');
                endPosition--;
            }

            if (start < endPosition) {
                tokens.add(rawToken.substring(start, endPosition));
            }
            tokens.addAll(trailingParens);
        }
        return tokens;
    }

    private static String negateCondition(String clause) {
        String c = clause.trim().toLowerCase();
        if (c.contains(' in ')) {
            return replaceIgnoreCase(c, ' IN ', ' NOT IN ');
        } else if (c.endsWith('= null')) {
            return replaceIgnoreCase(c, '= null', '!= NULL');
        } else if (c.contains('=')) {
            return clause.replace('=', '!=');
        }

        return 'NOT (' + clause + ')';
    }

    private static String replaceIgnoreCase(String original, String search, String replacement) {
        String regex = '(?i)' + Pattern.quote(search);
        return original.replaceAll(regex, replacement);
    }

    /**
     * Recursive-descent parser for filterLogic expressions.
     *
     * Grammar:
     *   expr   := term ( ('AND' | 'OR') term )*
     *   term   := 'NOT'? factor
     *   factor := '(' expr ')' | NUMBER
     *
     * When a NUMBER maps to an absent/skipped clause (null), the operand is treated as
     * "no condition" and the surrounding AND/OR is simplified:
     *   null AND x  →  x       null OR x  →  x
     *   x AND null  →  x       x OR null  →  x
     *   null AND null → null   null OR null → null
     */
    private class FilterLogicParser {
        private List<String> tokens;
        private Integer pos;
        private Map<Integer, String> clauseMap;

        public FilterLogicParser(List<String> tokens, Map<Integer, String> clauseMap) {
            this.tokens = tokens;
            this.pos = 0;
            this.clauseMap = clauseMap;
        }

        public String parseExpr() {
            String left = parseTerm();
            while (pos < tokens.size()) {
                String op = tokens[pos];
                if (!op.equalsIgnoreCase('AND') && !op.equalsIgnoreCase('OR')) break;
                pos++;
                String right = parseTerm();
                left = combine(left, op.toUpperCase(), right);
            }
            return left;
        }

        private String parseTerm() {
            Boolean hasNot = false;
            Boolean notBeforeGroup = false;
            if (pos < tokens.size() && tokens[pos].equalsIgnoreCase('NOT')) {
                hasNot = true;
                notBeforeGroup = (pos + 1 < tokens.size() && tokens[pos + 1] == '(');
                pos++;
            }
            String result = parseFactor();
            if (hasNot && result != null) {
                // NOT before a group → prefix with NOT (valid SOQL: NOT (a OR b))
                // NOT before a number → rewrite the clause itself (!=, NOT IN, etc.)
                result = notBeforeGroup ? 'NOT ' + result : negateCondition(result);
            }
            return result;
        }

        private String parseFactor() {
            if (pos >= tokens.size()) return null;
            String token = tokens[pos];

            if (token == '(') {
                pos++;
                String grouped = parseExpr();
                if (pos < tokens.size() && tokens[pos] == ')') pos++;
                // Preserve explicit grouping with parens so that e.g. "A OR B" inside
                // a group stays "(A OR B)" when composed with an outer AND.
                return grouped == null ? null : '(' + grouped + ')';
            }

            if (Pattern.matches('^\\d+$', token)) {
                pos++;
                return clauseMap.get(Integer.valueOf(token)); // null if skipped
            }

            return null;
        }

        // Combine two operands, dropping nulls (absent conditions) transparently.
        private String combine(String left, String op, String right) {
            if (left == null) return right;
            if (right == null) return left;
            return left + ' ' + op + ' ' + right;
        }
    }

    public class FieldTypeResolver {
        public FieldTypeResolver() {
        }

        public Schema.DisplayType getFieldType(String fullFieldPath, String startingObject) {
            List<String> parts = fullFieldPath.split('\\.');
            if (parts.isEmpty()) {
                throw new IllegalArgumentException('Invalid field path');
            }

            return resolveFieldTypeRecursive(startingObject, parts, 0);
        }

        private Schema.DisplayType resolveFieldTypeRecursive(String currentObject, List<String> parts, Integer index) {
            if (index >= parts.size()) {
                throw new IllegalArgumentException('Field path incomplete');
            }

            String fieldName = parts[index].replaceFirst('__r$', '__c');

            Schema.SObjectType objType = Schema.getGlobalDescribe().get(currentObject);
            if (objType == null) {
                throw new IllegalArgumentException('Invalid object: ' + currentObject);
            }

            Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
            if (!fieldMap.containsKey(fieldName)) {
                throw new IllegalArgumentException('Field not found: ' + fieldName + ' on object ' + currentObject);
            }

            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();

            if (index == parts.size() - 1) {
                return fieldDescribe.getType();
            }

            if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
                throw new IllegalArgumentException('Field ' + fieldName + ' is not a relationship field');
            }

            // Get referenced object name
            List<Schema.SObjectType> references = fieldDescribe.getReferenceTo();
            if (references.isEmpty()) {
                throw new IllegalArgumentException('No related object found for field: ' + fieldName);
            }

            String nextObject = references[0].getDescribe().getName();
            return resolveFieldTypeRecursive(nextObject, parts, index + 1);
        }
    }
}