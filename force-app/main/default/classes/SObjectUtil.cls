public inherited sharing class SObjectUtil implements ISObjectUtil {

    public static final SObjectUtil INSTANCE = (SObjectUtil)fflibe_Applicationimpl.SERVICE.newInstance(SObjectUtil.class);
    
    // returns a Set<Id>, just pass in the field api name that is an Id field and the list that you want to collect Ids from.
    public static Set<Id> getSetIds(sObject[] soList, String idField) {
        if (soList == null) { return null; }
        Set<Id> ids = new Set<Id>();
        for (sObject so : soList) {
            ids.add((Id)getFieldValue(so, idField));
        }
        return ids;
    }

    public static Set<String> getSetStrings(sObject[] soList, String field) {
        if (soList == null) { return null; }
        Set<String> values = new Set<String>();
        for (sObject so : soList) {
            values.add((String)getFieldValue(so, field));
        }
        return values;
    }

    // field here can be e.g. 'Name' or 'Account.Name' or 'Contact.Account.Name' etc.
    @TestVisible
    static Object getFieldValue(SObject so, String field) {
        String[] fieldSplit = field.split('\\.');
        Integer i;
        SObject relatedSo = so;
        for (i = 0; i < fieldSplit.size() - 1; i++) {
            relatedSo = relatedSo.getSObject(fieldSplit[i]);
        }
        return relatedSo.get(fieldSplit[i]);
    }

    // e.g. if you have a list of contacts, get list of Contact.Account with relationship name = 'Account'
    public static SObject[] convertToLookupList(SObject[] listToConvert, String relationshipField, String relationshipName) {
        SObject[] ret = new List<SObject>();
        Set<Id> ids = new Set<Id>();
        for (SObject so : listToConvert) {
            Id relationId = (Id)so.get(relationshipField);
            if (relationId != null && !ids.contains(relationId)) {
                ids.add(relationId);
                ret.add(so.getSObject(relationshipName));
            }
        }
        return ret;
    }

    // to make data mockable
    public SObject[] getChildRelationship(SObject so, String childRelationshipName) {
        try {
            SObject[] objectsToReturn = so.getSObjects(childRelationshipName);
            return objectsToReturn == null ? new List<SObject>() : objectsToReturn;
        } catch (System.SObjectException e) {
            // so.getSObjects(childRelationshipName) can throw this error even if the relationship name is valid...
            if (e.getMessage().contains('SObject row was retrieved via SOQL without querying the requested field')) {
                return new List<SObject>();
            }
            throw e;
        }
    }

}