public class CreateRecordCont {

        public class PicklistOption 
        {
            @AuraEnabled
            public string label { get; set; }
    
            @AuraEnabled
            public string value { get; set; }
            
            public PicklistOption(Schema.PicklistEntry plE) 
            {
                label = plE.getLabel();
                value = plE.getValue();
            }
        }
    
        @AuraEnabled
        public List<PicklistOption> statesOptions
        {
            get 
            {
                List<PicklistOption> optoReturn = new List<PicklistOption>();
                Schema.sObjectType objType = Account.getSObjectType();
                Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
                map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
                list<Schema.PicklistEntry> values = fieldMap.get('ShippingStateCode').getDescribe().getPickListValues();
                
                List<SelectOption> options = new List<SelectOption>();
                for (Schema.PicklistEntry v : values){
                    if (GenericCreatePaymentCtrl.USStates.contains(v.getLabel())) {
                    	optoReturn.add(new PicklistOption(v)); 
                    }
                }

                return optoReturn;
            }    
        }
    public class RTPicklist{
        public List<PicklistFeed> values {set;get;}
        public PicklistFeed defaultValue {set;get;}
    }
    public class PicklistFeed {
        public String label{set;get;}
        public String value{set;get;}

    }
    @AuraEnabled        
    public static String getPickListValuesIntoList(String objectType, String selectedField, String recordTypeName) {
        if(objecttype == 'PersonAccount') {
            objecttype = 'Account';
        }
        RecordType rt = [Select Id from RecordType where SObjectType =: objectType and name =: recordTypeName];
        HttpRequest httpRequest = new HttpRequest();
        String endPoint = 'callout:UI_API_Credentials/' +'/services/data/v46.0/ui-api/object-info/' 
                    + objectType + '/picklist-values/'+rt.Id+'/'+ selectedField;
        System.debug('###endPoint#' + endPoint);
        httpRequest.setEndpoint(endPoint);
        httpRequest.setMethod('GET');
        httpRequest.setHeader('Authorization','OAuth {!$Credential.OAuthToken}');
        // httpRequest.setHeader('Authorization', 'OAuth '+ UserInfo.getSessionId() );
        HttpResponse res = (new Http()).send(httpRequest);
        System.debug('###res###' + res.getBody());
        RTPicklist rtPicklist = (RTPicklist) JSON.deserialize( res.getBody(), RTPicklist.class);
        return JSON.serialize(rtPicklist);
    }
}