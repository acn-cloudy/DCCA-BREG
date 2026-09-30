public without sharing class FieldUtils {
    public class Bitset {
        public Map<String,Integer> AlphaNumCharCodes {get;set;}
        public Map<String, Integer> Base64CharCodes { get; set; }
        public Bitset(){
            LoadCharCodes();
        }
        //Method loads the char codes
        private void LoadCharCodes() {
            AlphaNumCharCodes = new Map<String,Integer>{
                'A'=>65,'B'=>66,'C'=>67,'D'=>68,'E'=>69,'F'=>70,'G'=>71,'H'=>72,'I'=>73,'J'=>74,
                'K'=>75,'L'=>76,'M'=>77,'N'=>78,'O'=>79,'P'=>80,'Q'=>81,'R'=>82,'S'=>83,'T'=>84,
                'U'=>85,'V'=> 86,'W'=>87,'X'=>88,'Y'=>89,'Z'=>90    
            };
            Base64CharCodes = new Map<String, Integer>();
            //lower case
            Set<String> pUpperCase = AlphaNumCharCodes.keySet();
            for(String pKey : pUpperCase){
                //the difference between upper case and lower case is 32
                AlphaNumCharCodes.put(pKey.toLowerCase(),AlphaNumCharCodes.get(pKey)+32);
                //Base 64 alpha starts from 0 (The ascii charcodes started from 65)
                Base64CharCodes.put(pKey,AlphaNumCharCodes.get(pKey) - 65);
                Base64CharCodes.put(pKey.toLowerCase(),AlphaNumCharCodes.get(pKey) - (65) + 26);
            }
            //numerics
            for (Integer i=0; i<=9; i++){
                AlphaNumCharCodes.put(string.valueOf(i),i+48);
                //base 64 numeric starts from 52
                Base64CharCodes.put(string.valueOf(i), i + 52);
            }
        }
        /*
        	Effect: Method takes a validFor string and tests it against a set of controlling indexes
        	Postcondition: Returns a list of all controlling indexes for which the validFor string test True
        */
        public List<Integer> testBits(String pValidFor,List<Integer> nList){
        	List<Integer> results = new List<Integer>();
			//the list of bytes (not derived from n)
            List<Integer> pBytes = new List<Integer>();
            //multiply by 6 since base 64 uses 6 bits (not derived form n)
            Integer bytesBeingUsed = (pValidFor.length() * 6)/8;
            //will be used to hold the full decimal value (not derived from n)
            Integer pFullValue = 0;
            //must be more than 1 byte
            if (bytesBeingUsed <= 1)
                return results;
            //get the base64bytes
            for(Integer i=0;i<pValidFor.length();i++){
                //get currenct character value
                pBytes.Add((Base64CharCodes.get((pValidFor.Substring(i, i+1)))));
            }   
            //calculate the full decimal value
            for (Integer i = 0; i < pBytes.size(); i++)
            {
                Integer pShiftAmount = (pBytes.size()-(i+1))*6;//used to shift by a factor 6 bits to get the value
                if(pBytes[i] == null ) continue;
                pFullValue = pFullValue + (pBytes[i] << (pShiftAmount));
            }
            //now we don't want to always be declaring memory, so let's set the initial 
            //variables
            Integer bit;
            Integer targetOctet;
            Integer shiftBits;
            Integer tBitVal;
            Integer n;
            Integer nListSize = nList.size();
            for(Integer i=0; i<nListSize; i++){
            	n = nList[i];
	            //calculate the target bit for comparison
	            bit = 7 - (Math.mod(n,8)); 
	            //calculate the octet that has in the target bit
	            targetOctet = (bytesBeingUsed - 1) - (n >> bytesBeingUsed); 
	            //the number of bits to shift by until we find the bit to compare for true or false
	            shiftBits = (targetOctet * 8) + bit;
	            //& is to set the same set of bits for testing
				//shift to the bit which will dictate true or false
				//Math.Pow(2, shiftBits) == 2 << (shiftBits+1)
	            tBitVal = ((Integer)(2 << (shiftBits-1)) & pFullValue) >> shiftBits;
	            if (tBitVal==1)
	            	results.add(n);
            }
            return results;
        }
    }
     /*
     * @Summary: Entity to represent a json version of a picklist entry
     * so that the validFor property becomes exposed
    */
    public class TPicklistEntry{
        public string active {get;set;}
        public string defaultValue {get;set;}
        public string label {get;set;}
        public string value {get;set;}
        public string validFor {get;set;}
        public TPicklistEntry(){}
    }
    public class PicklistOption {
        public PicklistOption(String value, String label){
            this.value = value;
            this.label = label;
        }
        public String value;
        public String label;
    }
    public class FieldEntry {
        public String objName {set;get;}
        public String apiName {set;get;}
        public String dependentFieldName {set;get;}
        public List<PicklistOption> options {set;get;}
        public Map<String, List<PicklistOption>> dependentOptions {set;get;}
    }

    public class PicklistExceptionMap {
        public PicklistExceptionMap(String fromObj, String fromField, String toObject, String toField){
            this.fromObj = fromObj;
            this.fromField = fromField;
            this.toObject = toObject;
            this.toField = toField;
        }
        public String fromObj {set;get;}
        public String fromField {set;get;}
        public String toObject {set;get;}
        public String toField {set;get;}
    }
    public static PicklistExceptionMap[] getPicklistExceptions(){
        return new List<PicklistExceptionMap>{
            new PicklistExceptionMap('Account','PersonMailingState', 'Application__c', 'ResidenceStateOnlineRenewal1__c' )
        };
    }
    
    public static Map<String, FieldEntry> fillOptions(String entryStr) {
        List<FieldEntry> entries = (List<FieldEntry>)JSON.deserialize(entryStr, List<FieldEntry>.class);
        return fillOptions(entries);
    }
    
    public static Map<String, FieldEntry> fillOptions(List<FieldEntry> entries) {
        Map<String, FieldEntry> entryMap = new Map<String, FieldEntry>();
        for(FieldEntry entry: entries) {
            if(entryMap.containsKey(entry.objName + '.' + entry.apiName)){
                continue;
            }
            if(entry.dependentFieldName != null ) {
                entry.dependentOptions 
                    = getDependentOptions(entry.objName, entry.dependentFieldName, entry.apiName);
            } else {
                entry.options 
                    = getPicklistOptions(entry.objName, entry.apiName);
            }
            entryMap.put(entry.objName + '.' + entry.apiName, entry);
        }
        return entryMap;
    }
    @AuraEnabled
    public static String getPicklistValues(String objectName, String fieldName) {
        return JSON.serialize(getPicklistOptions(objectName, fieldName));
    }


    
    public static List<PicklistOption> getPicklistOptions(String pObjName, String fieldName) {
        Schema.SObjectType pType = Schema.getGlobalDescribe().get(pObjName);
        Map<String, Schema.SObjectField> objFieldMap = pType.getDescribe().fields.getMap();
        System.debug('####pObjName####' + pObjName);
        System.debug('####fieldName####' + fieldName);
        List<Schema.PicklistEntry> dep_ple = objFieldMap.get(fieldName).getDescribe().getPicklistValues();

        // Check for exceptions like Account.PersonMailingState where mocking picklist but want values from Salesforce
        PicklistExceptionMap[] exceptionMaps = getPicklistExceptions();
        PicklistExceptionMap matchingException;
        for (PicklistExceptionMap exc : exceptionMaps) {
            if (exc.fromObj == pObjName && exc.fromField == fieldName) {
                matchingException = exc;
                break;
            }
        }
        if(matchingException!=null){
            Schema.SObjectType exceptionType = Schema.getGlobalDescribe().get(matchingException.toObject);
            Map<String, Schema.SObjectField> exceptionFieldMap = exceptionType.getDescribe().fields.getMap();
            dep_ple = exceptionFieldMap.get(matchingException.toField).getDescribe().getPicklistValues();
        }

        List<PicklistOption> picklistSelections = new List<PicklistOption>();
        //load all dep entries
        List<Schema.PicklistEntry> objEntries = new List<Schema.PicklistEntry>();
        List<PicklistEntry> objDS_Entries = new List<PicklistEntry>();
        //add all entries
        for(Integer pDependentIndex=0; pDependentIndex<dep_ple.size(); pDependentIndex++){        	
            //get the pointer to the dependent index
           	Schema.PicklistEntry dep_entry = dep_ple[pDependentIndex];
           	objEntries.add(dep_entry);
           	
        } 
        //serialize once        
        objDS_Entries = (List<PicklistEntry>)JSON.deserialize(JSON.serialize(objEntries), List<PicklistEntry>.class);
        
        for (PicklistEntry objDepPLE : objDS_Entries) {
        	picklistSelections.add((new PicklistOption(objDepPLE.getValue(), objDepPLE.getLabel())));
        }
        return picklistSelections;
    }
    public static Map<String,List<PicklistOption>> getDependentOptions(String pObjName, 
            String pControllingFieldName, String pDependentFieldName) {
            
        Map<String,List<PicklistOption>> objResults = new Map<String,List<PicklistOption>>();
        //get the string to sobject global map
        Map<String,Schema.SObjectType> objGlobalMap = Schema.getGlobalDescribe();
        if (!Schema.getGlobalDescribe().containsKey(pObjName))
            return objResults;
        //get the type being dealt with
        Schema.SObjectType pType = Schema.getGlobalDescribe().get(pObjName);
        return GetDependentOptionsImpl(pType,pControllingFieldName,pDependentFieldName);
    }
    
    public static Map<String,List<PicklistOption>> GetDependentOptionsImpl(Schema.SObjectType pType, 
            String pControllingFieldName, String pDependentFieldName) {
        
        Map<String,List<PicklistOption>> objResults = new Map<String,List<PicklistOption>>();
        if (pType==null)
            return objResults;
        Bitset BitSetInstance = new Bitset();
        Map<String, Schema.SObjectField> objFieldMap = pType.getDescribe().fields.getMap();
        //verify field names
        if (!objFieldMap.containsKey(pControllingFieldName) || !objFieldMap.containsKey(pDependentFieldName))
            return objResults;     
        //get the control values   
        List<Schema.PicklistEntry> ctrl_ple = objFieldMap.get(pControllingFieldName).getDescribe().getPicklistValues();
        //get the dependent values
        List<Schema.PicklistEntry> dep_ple = objFieldMap.get(pDependentFieldName).getDescribe().getPicklistValues();
        objFieldMap = null;
        List<Integer> lstControllingIndexes = new List<Integer>();
        //iterate through the values and get the ones valid for the controlling field name
        //set up the results
        for(Integer pControllingIndex=0; pControllingIndex<ctrl_ple.size(); pControllingIndex++){        	
            //get the pointer to the entry
            Schema.PicklistEntry ctrl_entry = ctrl_ple[pControllingIndex];
            //get the label
            String pControllingLabel = ctrl_entry.getValue();
            //create the entry with the label
            objResults.put(pControllingLabel,new List<PicklistOption>());
            //keep track of the controlling indexes
            lstControllingIndexes.add(pControllingIndex);
        }
        //load all dep entries
        List<Schema.PicklistEntry> objEntries = new List<Schema.PicklistEntry>();
        List<TPicklistEntry> objDS_Entries = new List<TPicklistEntry>();
        //add all entries
        for(Integer pDependentIndex=0; pDependentIndex<dep_ple.size(); pDependentIndex++){        	
            //get the pointer to the dependent index
           	Schema.PicklistEntry dep_entry = dep_ple[pDependentIndex];
           	objEntries.add(dep_entry);
           	
        } 
        //serialize once        
        objDS_Entries = (List<TPicklistEntry>)JSON.deserialize(JSON.serialize(objEntries), List<TPicklistEntry>.class);
        List<Integer> validIndexes;
        for (TPicklistEntry objDepPLE : objDS_Entries){
        	//if valid for is empty, skip    
            if (objDepPLE.validFor==null || objDepPLE.validFor=='') {
                continue;
            }
            System.debug('##objDepPLE.validFor##' + objDepPLE.validFor);
            System.debug('##lstControllingIndexes##' + lstControllingIndexes);
            //get the test for the controlling indexes
            validIndexes = BitSetInstance.testBits(objDepPLE.validFor,lstControllingIndexes);
            for (Integer validIndex : validIndexes){            	
	            //get the label
	            String pControllingLabel = ctrl_ple[validIndex].getValue();
	            if(pControllingLabel == null || pControllingLabel == '')
	                continue;
                objResults.get(pControllingLabel).add((new PicklistOption(objDepPLE.value, objDepPLE.label)));
            }
        }
        objEntries = null;
        objDS_Entries = null;
        return objResults;
    }

}