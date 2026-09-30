/*
* ─────────────────────────────────────────────────────────
* Global Selector Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ170919 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2019-09-19
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
public with sharing class PVL_Selector {
    /* variables */
    String queryFields;
    List<SObject> sObjectList;
    Set<Id> IdsSet;
    Map<Id,List<SObject>> sObjectListMap;
    Map<Id,Map<Date, SObject>> sObjectListDateMap;
    Map<String,List<SObject>> sObjectListExtMap;
    List<AggregateResult> sObjectAggregateResult;
    Map<Id,AggregateResult> sObjectAggregateResultsMap;
    Map<Id,List<AggregateResult>> sObjectAggregateResultListMap;
    DataBase.QueryLocator queryLocator;

    /* constructors */
    public PVL_Selector(){
        this.IdsSet = new Set<Id>();
        this.queryFields = '';
        this.sObjectList = new List<SObject>();
        this.sObjectListMap = new Map<Id,List<SObject>>();
        this.sObjectListDateMap = new Map<Id,Map<Date, SObject>>();
        this.sObjectListExtMap = new Map<String,List<SObject>>();
        this.sObjectAggregateResult = new List<AggregateResult>();
        this.sObjectAggregateResultsMap = new Map<Id,AggregateResult>();
        this.sObjectAggregateResultListMap = new Map<Id,List<AggregateResult>>();
    }
    
    /* batch job selector 1, no flag */
    public PVL_Selector getQueryLocatorByFieldWithName(String objectType, String filterCriteria) {
        this.queryLocator = Database.getQueryLocator(String.format('SELECT {0} FROM {1} WHERE {2} ' ,
                                new List<String>{this.getQueryFieldsAddRelatedName(objectType).convertToString(), objectType, filterCriteria}));
        return this;
    }

    /* batch job selector 2, no flag with sorting */
    public PVL_Selector getQueryLocatorByField(String objectType, String filterCriteria, String orderByField) {
        this.queryLocator = Database.getQueryLocator(String.format('SELECT {0} FROM {1} WHERE {2} ORDER BY {3}' ,
                                new List<String>{this.getQueryFields(objectType).convertToString(), objectType, filterCriteria, orderByField}));
        return this;
    }

    /* no flags with Ids*/
    public PVL_Selector getSObjectRecordsByField(String objectType, List<String> fieldAPINames, List<Id> recordIds, String orderByField) {
        this.sObjectList = Database.Query(String.format('SELECT {0} FROM {1} WHERE Id IN :recordIds ORDER BY {2} DESC ' ,
                                          new List<String>{String.join(fieldAPINames, ','), objectType , orderByField}));
        return this;
    }

    /* no flags with Ids*/
    public PVL_Selector getSObjectRecordsByField(String objectType, String filterField, List<Id> recordIds, String orderByField) {
        this.sObjectList = Database.Query(String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds ORDER BY {3} DESC ' ,
                                          new List<String>{this.getQueryFields(objectType).convertToString(), objectType , filterField, orderByField}));
        return this;
    }
    
    /* retrive sObject with relationship fields */
    public PVL_Selector getSObjectRecordsByField(String objectType, String filterField, List<Id> recordIds, String orderByField, String relationalFields) {
        this.sObjectList = Database.Query(String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds ORDER BY {3} DESC ' ,
                                          new List<String>{this.getQueryFields(objectType).convertToString() + relationalFields, objectType , filterField, orderByField}));
        return this;
    }

    /* including boolean flags */
    public PVL_Selector getSObjectRecordsByField(String objectType, String filterField, List<Id> recordIds, String filterFlag, Boolean filterFlagValue, String orderByField) {
        this.sObjectList = Database.Query(String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} = {4} ORDER BY {5} DESC ' ,
                                          new List<String>{this.getQueryFields(objectType).convertToString(), objectType , filterField, filterFlag, String.ValueOf(filterFlagValue), orderByField}));
        return this;
    }

    /* including boolean and number/text flag */
    public PVL_Selector getSObjectRecordsByField(String objectType, String filterField, List<Id> recordIds, String filterOne, String filterOneValue, String filterTwo, String filterTwoValue, String orderByField, String orderByDirection){
        List<String> tempStringLIst = new List<String>{this.getQueryFields(objectType).convertToString(), objectType, filterField, filterOne, filterOneValue, filterTwo, filterTwoValue, orderByField, orderByDirection};
        
        this.sObjectList = Database.Query(String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} = {4} AND {5} = {6} ORDER BY {7} {8} ',tempStringLIst));
        return this;
    }

    /* used most by chris z */
    public PVL_Selector getSObjectRecordsByField(String objectType, String filterField, List<Id> recordIds, String filterCriteria, String orderByField, String extraFields) {
        this.sObjectList = Database.Query(String.format('SELECT {0} {1} FROM {2} WHERE {3} IN: recordIds {4} ORDER BY {5} ASC ',
                                          new List<String>{this.getQueryFields(objectType).convertToString(), extraFields, objectType , filterField, filterCriteria, orderByField}));
        return this;
    }

    /* just check all records with two filters */
    public PVL_Selector getSObjectRecordsByField(String objectType, String filterFlagOne, String filterFlagValueOne, String filterFlagTwo, String filterFlagValueTwo, String orderByField) {
        this.sObjectList = Database.Query(String.format('SELECT {0} FROM {1} WHERE {2} = {3} AND {4} = {5} ORDER BY {6} DESC ' ,
                                          new List<String>{this.getQueryFields(objectType).convertToString(), objectType , filterFlagOne, '\'' + filterFlagValueOne + '\'', filterFlagTwo, '\'' + filterFlagValueTwo + '\'', orderByField}));
        return this;
    }
    
    /* aggregate results */
    /* two boolean values */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String groupByField, String filterFlag, String filterFlagValue, String filterFlag2, String filterFlagValue2){
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, filterFlag, String.ValueOf(filterFlagValue), filterFlag2, String.ValueOf(filterFlagValue2), groupByField};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} = {4} AND {5} = {6} GROUP BY {7} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }

    /* two boolean values and two filters */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String groupByField, String filterFlag, String filterFlagValue, String filterFlag2, String filterFlagValue2, String filterFlag3, String filterFlagValue3, String filterFlag4){
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, filterFlag, String.ValueOf(filterFlagValue), filterFlag2, String.ValueOf(filterFlagValue2), filterFlag3, String.ValueOf(filterFlagValue3), filterFlag4, groupByField};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} = {4} AND {5} = {6} AND {7} = {8} AND {9} = today GROUP BY {10} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }

    /* string filter */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String groupByField, String stringFilter, String stringFilterOperator, String stringFilterValue){
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, stringFilter, stringFilterOperator, String.ValueOf(stringFilterValue), groupByField};
        
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} {4} {5} GROUP BY {6} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }

    /* one flag */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String groupByField, String filterFlag, Boolean filterFlagValue) {
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, groupByField, filterFlag, String.ValueOf(filterFlagValue)};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {4} = {5} GROUP BY {3} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }
    
    /* three flags */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String filterFlagOne, Boolean filterFlagValueOne, String filterFlagTwo, Boolean filterFlagValueTwo, String  filterFlagThree, Boolean filterFlagValueThree,  String groupByField) {
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, filterFlagOne, String.ValueOf(filterFlagValueOne), filterFlagTwo, String.ValueOf(filterFlagValueTwo), filterFlagThree, String.ValueOf(filterFlagValueThree), groupByField};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} = {4} AND {5} = {6} AND {7} = {8} GROUP BY {9} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }
    
    /* four flags */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String filterFlagOne, Boolean filterFlagValueOne, String filterFlagTwo, Boolean filterFlagValueTwo, String  filterFlagThree, Boolean filterFlagValueThree, String filterFlagFour, Boolean filterFlagValueFour, String groupByField) {
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, filterFlagOne, String.ValueOf(filterFlagValueOne), filterFlagTwo, String.ValueOf(filterFlagValueTwo), filterFlagThree, String.ValueOf(filterFlagValueThree), filterFlagFour, String.ValueOf(filterFlagValueFour), groupByField};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds AND {3} = {4} AND {5} = {6} AND {7} = {8} AND {9} = {10} GROUP BY {11} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }

    /* no flags */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String groupByField) {
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, groupByField};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds GROUP BY {3} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }

    /* no flags with filterCriteria */
    public PVL_Selector getAggregateResultByField(String fieldsString, String objectType, String filterField, List<Id> recordIds, String filterCriteria, String groupByField) {
        List<String> tempString = new List<String>{fieldsString, objectType, filterField, filterCriteria, groupByField};
        String queryString = String.format('SELECT {0} FROM {1} WHERE {2} IN :recordIds {3} GROUP BY {4} ', tempString);
        this.sObjectAggregateResult = Database.Query(queryString);
        return this;
    }

    public PVL_Selector getQueryFields(String sObjectName) {
        String queryFields = '';
        Schema.DescribeSObjectResult dsResult = getDescribeSObject(sObjectName);
        for(String key : dsResult.fields.getMap().keySet()) {
            if (key != 'lastvieweddate' && key != 'lastreferenceddate' && key != 'parentid' && key != 'accesstype' && key != 'isreadonly')
                queryFields += key + ',';
        }
        this.queryFields = queryFields;
        return this;
    }

    public PVL_Selector getQueryFieldsAddRelatedName(String sObjectName) {
        String queryFields = '';
        Schema.DescribeSObjectResult dsResult = getDescribeSObject(sObjectName);
        for(String key : dsResult.fields.getMap().keySet()) {
            if (key != 'lastvieweddate' && key != 'lastreferenceddate' && key != 'parentid' && key != 'accesstype' && key != 'isreadonly') {
                Schema.DisplayType fieldType = dsResult.fields.getMap().get(key).getDescribe().getType();
                if (fieldType == Schema.DisplayType.REFERENCE) {
                    if (key.contains('__c') && key.right(3) == '__c')
                        queryFields += key + ',' + key.removeEnd('__c') + '__r.Name,';
                    else 
                        queryFields += key + ',';
                } else {
                    queryFields += key + ',';
                }
            }
        }
        this.queryFields = queryFields;
        return this;
    }

    public String convertToString() {
        this.queryFields = this.queryFields.removeEnd(',');
        return this.queryFields;
    }

    public DataBase.QueryLocator getDataBaseQueryLocator() {
        return this.queryLocator;
    }

    public Map<Id,List<SObject>> getMapByIdField(String idField) {
        Map<Id,List<SObject>> tempMap = new Map<Id,List<SObject>>();
        /* update to handle relationship fields only 1 level up */
        Boolean flag = false;
        if (idField.contains('__r.')) {
            flag = true; 
        }
        for(SObject obj : this.SObjectList) {
            if (!flag) {
                if(!tempMap.containsKey((Id)obj.get(idField))) {
                    tempMap.put((Id)obj.get(idField), new List<SObject>{obj});
                } else {
                    tempMap.get((Id)obj.get(idField)).add(obj);
                }
            } else {
                List<String> tempSplit_L = idField.split('\\.');
                if (tempSplit_L[0].right(3) == '__r') {
                    if(!tempMap.containsKey((Id)obj.getSObject(tempSplit_L[0]).get(tempSplit_L[1]))) {
                        tempMap.put((Id)obj.getSObject(tempSplit_L[0]).get(tempSplit_L[1]), new List<SObject>{obj});
                    } else {
                        tempMap.get((Id)obj.getSObject(tempSplit_L[0]).get(tempSplit_L[1])).add(obj);
                    }
                }
            }
        }
        this.sObjectListMap = tempMap;
        return this.sObjectListMap;
    }

    /* now, you can get map by any String field */
    public Map<String,List<SObject>> getMapByStringField(String inString) {
        Map<String,List<SObject>> tempMap = new Map<String,List<SObject>>();
        for(SObject obj:this.SObjectList) {
            if(!tempMap.containsKey((String)obj.get(inString))) {
                tempMap.put((String)obj.get(inString), new List<SObject>{obj});
            } else {
                tempMap.get((String)obj.get(inString)).add(obj);
            }
        }
        this.sObjectListExtMap = tempMap;
        return this.sObjectListExtMap;
    }

    /* we need add this for loan account snapshot */
    public Map<Id, Map<Date, SObject>> getMapByIdDateField(String idField, String dateField) {
        Map<Id, Map<Date, SObject>> tempMap = new Map<Id, Map<Date, SObject>>();
        //second loop to produce the map for Id => Map<Date, SObject>
        for(SObject obj:this.SObjectList) {
            DateTime tempDateTime = (DateTime)obj.get(dateField);
            if(!tempMap.containsKey((Id)obj.get(idField))) {
                tempMap.put((Id)obj.get(idField), new Map<Date, SObject>{tempDateTime.dateGmt() => obj});
            } else {
                tempMap.get((Id)obj.get(idField)).put(tempDateTime.dateGmt(), obj);
            }
        }
        this.sObjectListDateMap = tempMap;
        return this.sObjectListDateMap;
    }

    public Map<Id,AggregateResult> getAggregateMapByIdField(String idField) {
        Map<Id,AggregateResult> tempMap = new Map<Id,AggregateResult>();
        for(AggregateResult result : this.sObjectAggregateResult) {
            Id lAcc = (Id)result.get(idField);
            if(!tempMap.containsKey(lAcc)) {
                tempMap.put(lAcc,result);
            } else{
                //tempMap.get(lAcc).add(result);
            }
        }
        this.sObjectAggregateResultsMap = tempMap;
        return this.sObjectAggregateResultsMap;
    }
    
    public Map<Id,List<AggregateResult>> getAggregateListMapByIdField(String idField){
        Map<Id,List<AggregateResult>> tempMap = new Map<Id,List<AggregateResult>>();
        for(AggregateResult result : this.sObjectAggregateResult){
            Id lAcc = (Id)result.get(idField);
            if(!tempMap.containsKey(lAcc)){
                tempMap.put(lAcc, new List<AggregateResult>{result});
            }
            else{
                tempMap.get(lAcc).add(result);
            }
        }
        this.sObjectAggregateResultListMap = tempMap;
        return this.sObjectAggregateResultListMap;
    }

    public Set<Id> getIdsSet(String idField){
        Set<Id> tempSet = new Set<Id>();
        
        for(SObject obj : this.SObjectList){
                tempSet.add((Id)obj.get(idField));
        }
        this.IdsSet = tempSet;
        return this.IdsSet;
    }
    
    public Set<Id> getIdsSet(){
        return this.IdsSet;
    }
    
    public List<SObject> getSObjectList() {
        return this.sObjectList;
    }
    
    /* object the sObject describe */
    public Schema.DescribeSobjectResult getDescribeSObject(String SObjectName) {
        Schema.DescribeSobjectResult dsResult;
        if (SObjectName == 'Application__c'){
            dsResult = schema.sobjectType.Application__c;
        } else if(SObjectName == 'Transaction__c'){
            dsResult = schema.sobjectType.Transaction__c;
        } else if(SObjectName == 'TransactionLine__c'){
            dsResult = schema.sobjectType.TransactionLine__c;
        } else if(SObjectName == 'LicenseTypeCashierCode__c'){
            dsResult = schema.sobjectType.LicenseTypeCashierCode__c;
        } else if(SObjectName == 'ExamsRequired__c'){
            dsResult = schema.sobjectType.ExamsRequired__c;
        } else if(SObjectName == 'LicenseClassification__c'){
            dsResult = schema.sobjectType.LicenseClassification__c;
        } else if(SObjectName == 'License__c'){
            dsResult = schema.sobjectType.License__c;
        } else {
            return null;
        }
        return dsResult;
    }
}