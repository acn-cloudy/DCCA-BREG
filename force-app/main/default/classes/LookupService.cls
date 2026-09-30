public with sharing class LookupService {
    private static final Integer MAX_RESULTS = 50;

    @AuraEnabled(cacheable=true)
    public static List<SObject> getSearchResults(
        String searchTerm,
        String fieldList,
        String sobjectName,
        String extraCondition,
        String fieldsToSearch
    ) {
        String query = getQueryString(
            searchTerm,
            fieldList,
            sobjectName,
            extraCondition,
            fieldsToSearch
        );
        System.debug(query);
        try {
            if(searchTerm.length() == 1) {
                return Database.query(query);
            } else {
                return Search.query(query).get(0);
            }
            
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static String getQueryString(
        String searchTerm,
        String fieldList,
        String sobjectName,
        String extraCondition,
        String fieldsToSearch
    ) {         
        fieldList = String.isBlank(fieldList) ? 'Id' : fieldList;
        List<String> listOfFieldsToSearch = String.isBlank(fieldsToSearch)
            ? new List<String>()
            : fieldsToSearch.split(',');
        if(extraCondition == null) 
            extraCondition = '';
        else if(searchTerm.length() == 1) {
            extraCondition = ' and ' + extraCondition;
            extraCondition = extraCondition.replace(' where ', '') ;
        }
        String query ;            
        if(searchTerm.length() > 1) {
            query = 'FIND \'' + 
            searchTerm +
            +'*\' IN ALL FIELDS RETURNING ' +
            sobjectName + 
            ' ('+fieldList+ ' '
            + extraCondition + ') LIMIT ' +
            MAX_RESULTS;
        } else {
            query = 'Select ' + fieldList +  ' from '+ sobjectName +' where Name like \'%' 
                + searchTerm + '%\' ' + extraCondition + ' LIMIT ' + MAX_RESULTS;
        }   
        
        return query;
    }

    
}