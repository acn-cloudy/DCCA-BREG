/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for the Input Lookup component - Simulates a lookup in lightning
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class InputLookupAuraController {
    
    /*
     * Loads the initial value of the given SObject type with ID "value"
     */
    @AuraEnabled
    public static String getCurrentValue(String type, String value)
    {
        if(String.isBlank(type))
        {
            return null;
        }
        
        ID lookupId = null;

        try
        {   
            lookupId = (ID)value;
        }
        catch(Exception e)
        {
            return null;
        }
        
        if(String.isBlank(lookupId))
        {
            return null;
        }
        
        SObjectType objType = Schema.getGlobalDescribe().get(type);

        if(objType == null)
        {
            return null;
        }

        String nameField = getSobjectNameField(objType);
        String query = 'Select Id, '+nameField+' From '+type+' Where Id = \''+lookupId+'\'';

        List<SObject> oList = Database.query(query);

        if(oList.size()==0) 
        {
            return null;
        }

        return (String) oList[0].get(nameField);
    }
    
    /*
     * Utility class for search results
    */
    public class SearchResult{
        public String value{get;Set;}
        public String id{get;set;}
    }
    
    /*
     * Returns the "Name" field for a given SObject (e.g. Case has CaseNumber, Account has Name)
    */
    private static String getSobjectNameField(SobjectType sobjType){
        
        //describes lookup obj and gets its name field
        String nameField = 'Name';
        Schema.DescribeSObjectResult dfrLkp = sobjType.getDescribe();
        for(schema.SObjectField sotype : dfrLkp.fields.getMap().values()){
            Schema.DescribeFieldResult fieldDescObj = sotype.getDescribe();
            if(fieldDescObj.isNameField() ){
                nameField = fieldDescObj.getName();
                break;
            }
        }
        return nameField;
    }
    
    /*
     * Searchs (using SOSL) for a given Sobject type
     */
    @AuraEnabled
    public static String searchSObject(String type, String searchString, String additionalFields, String additionalFilter)
    {
        if(String.isBlank(type) || String.isBlank(searchString))
        {
            return null;
        }
        
        SObjectType objType = Schema.getGlobalDescribe().get(type);

        if(objType == null)
        {
            return null;
        }
        
        String nameField = getSobjectNameField(objType);

        searchString = '{'+searchString+'}';

        String soslQuery = 'FIND :searchString IN NAME FIELDS RETURNING ' + type + ' (Id, ' + nameField;

        List<String> additionalFieldList = new List<String>();
        if (additionalFields != null) {
            additionalFieldList = additionalFields.split(',', 0);
        }

        if (!String.isBlank(additionalFields))
        {
            soslQuery += ', ' + additionalFields;
        }
        if (!String.isBlank(additionalFilter))
        {
            soslQuery += ' WHERE ' + additionalFilter;
        }
        
        soslQuery += ' ORDER BY ' + nameField + ') LIMIT 20';
        
        List<List<SObject>> results =  Search.query(soslQuery);
        
        List<SearchResult> output = new List<SearchResult>();

        if(results.size()>0)
        {
            for(SObject sobj : results[0])
            {
                SearchResult sr = new SearchResult();
                sr.id = (String)sobj.get('Id');

                if(String.isBlank(additionalFields))
                {
                    sr.value = (String)sobj.get(nameField);
                }
                else
                {   
                    sr.value = (String)sobj.get(nameField);

                    for(String field : additionalFieldList)
                    {
                        if(sobj.get(field.trim()) != null)
                        { 
                            if(field == 'Birthdate')
                            { 
                                sr.value += ' - ' + Date.valueOf(sobj.get(field.trim())).format();
                            }
                            else
                            {
                                sr.value += ' ' + String.valueOf(sobj.get(field.trim()));
                            }
                        }
                    }
                }

                output.add(sr);
            }
        }

        return JSON.serialize(output);
    }
    
      
}