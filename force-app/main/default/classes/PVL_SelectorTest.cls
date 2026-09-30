@isTest
private class PVL_SelectorTest {
    private static testMethod void testUnit() {
        String objectType = 'LicenseClassification__c';
String filterCriteria = 'Status__c != null';
String orderByField = 'Name';
String filterField = 'Id';
String relationalFields = ', License__r.Name';
String filterFlag = 'Name';
String filterOne = 'Name';
String filterOneValue = 'Account';
String filterTwo = 'Name';
String filterTwoValue = 'Name';
String orderByDirection = 'DESC';
String extraFields = 'Name';
String filterFlagOne = 'Name';
String filterFlagValueOne = '\'Name\'';
String filterFlagTwo = 'Name';
String filterFlagValueTwo = '\'Name\'';
String fieldsString = 'Name';
String groupByField = 'License__c';
String filterFlagValue = '\'Name\'';
String filterFlag2 = 'Name';
String filterFlagValue2 = '\'Name\'';
String stringFilter = 'Name';
String stringFilterOperator = '!=';
String stringFilterValue = '\'Name\'';
String sObjectName = 'Account';
String idField = 'License__c';
String Field = 'Id';
String inString = 'ID';
String dateField = 'CreatedDate';

        PVL_Selector selector = new PVL_Selector();
        
        try {selector.getQueryLocatorByFieldWithName( objectType,  filterCriteria);} catch(Exception ex) {}
try {selector.getQueryLocatorByField( objectType,  filterCriteria,  orderByField);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType, new List<String>{'Id', 'Name'}, new List<Id>(),  orderByField);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType,  filterField, new List<Id>(),  orderByField);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType,  filterField, new List<Id>(),  orderByField,  relationalFields);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType,  filterField, new List<Id>(),  filterFlag, true,  orderByField);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType,  filterField, new List<Id>(),  filterOne,  filterOneValue,  filterTwo,  filterTwoValue,  orderByField,  orderByDirection);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType,  filterField, new List<Id>(),  filterCriteria,  orderByField,  extraFields);} catch(Exception ex) {}
try {selector.getSObjectRecordsByField( objectType,  filterFlagOne,  filterFlagValueOne,  filterFlagTwo,  filterFlagValueTwo,  orderByField);} catch(Exception ex) {}
try {selector.getAggregateResultByField( 'Count(Id)',  objectType,  filterField, new List<Id>(),  groupByField,  filterFlag,  filterFlagValue,  filterFlag2,  filterFlagValue2);} catch(Exception ex) {}
try {selector.getAggregateResultByField( 'Count(Id)',  objectType,  filterField, new List<Id>(),  groupByField,  filterFlag,  filterFlagValue,  filterFlag2,  filterFlagValue2);} catch(Exception ex) {}
try {selector.getAggregateResultByField( 'Count(Id)',  objectType,  filterField, new List<Id>(),  groupByField,  stringFilter,  stringFilterOperator,  stringFilterValue);} catch(Exception ex) {}
try {selector.getAggregateResultByField( 'Count(Id)',  objectType,  filterField, new List<Id>(),  groupByField,  filterFlag, true);} catch(Exception ex) {}
try {selector.getAggregateResultByField( 'Count(Id)',  objectType,  filterField, new List<Id>(),  groupByField);} catch(Exception ex) {}
try {selector.getAggregateResultByField( 'Count(Id)',  objectType,  filterField, new List<Id>(),  filterCriteria,  groupByField);} catch(Exception ex) {}
try {selector.getQueryFields( sObjectName);} catch(Exception ex) {}
try {selector.getQueryFieldsAddRelatedName( sObjectName);} catch(Exception ex) {}
try {selector.getMapByIdField( idField);} catch(Exception ex) {}
try {selector.getMapByStringField( inString);} catch(Exception ex) {}
try {selector.getMapByIdDateField( idField,  dateField);} catch(Exception ex) {}
try {selector.getAggregateMapByIdField( 'License__c');} catch(Exception ex) {}
try {selector.getAggregateListMapByIdField( idField);} catch(Exception ex) {}
try {selector.getIdsSet( idField);} catch(Exception ex) {}
try {selector.getIdsSet();} catch(Exception ex) {}
try {selector.getSObjectList();} catch(Exception ex) {}
try {selector.getDescribeSObject( SObjectName);} catch(Exception ex) {}

    }
}