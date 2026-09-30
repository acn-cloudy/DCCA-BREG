public with sharing class InvocableSpringCMDocGen {
    @InvocableMethod(label='SpringCM DocGen' category='SpringCM')
    public static void invokeSpringCMDocGen(Input[] inputs) {
        for(Input i : inputs) {
    	    XmlStreamWriter w = new XmlStreamWriter();
	        w.writeStartElement(null, 'Params', null);
            w.writeStartElement(null, 'RecordId', null);
            w.writeCharacters(i.recordId);
            w.writeEndElement();
            w.writeStartElement(null, 'TemplateName', null);
        	w.writeCharacters(i.template);
            w.writeEndElement();
            w.writeStartElement(null, 'DocumentName', null);
        	w.writeCharacters(i.docName);
            w.writeEndElement();
            w.writeStartElement(null, 'FolderName', null);
        	w.writeCharacters(i.getFolderName());
            w.writeEndElement();
            w.writeStartElement(null, 'FolderPath', null);
        	w.writeCharacters(i.getPath());
            w.writeEndElement();
            w.writeStartElement(null, 'SObjectType', null);
        	w.writeCharacters(i.getSOBjectName());
            w.writeEndElement();
            w.writeEndElement();
            System.debug('xml: ' + w.getXmlString());
            if (i.getSOBjectName() == 'Case')
				SpringCMRestHelper.startWorkflow('DCCA DocGen', w.getXmlString(), null);  // for DCCA complaint case  
            else
				SpringCMRestHelper.startWorkflow('InvocableDocGen', w.getXmlString(), UserInfo.getSessionId());    
			//SpringCMRestHelper.startWorkflow('DCCA DocGen', w.getXmlString(), null);      
        }
    }
    public class Input {
        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
        @InvocableVariable(label='DocGen Template' required=true)
        public String template;
        @InvocableVariable(label='Document Name' required=true)
        public String docName;
        @InvocableVariable(label='Record Name' required=true)
 		public String recordName;
        
        public String getFolderName(){
            switch on this.getSObjectName(){
                when 'Application__c' {
                    return 'Application - ' + this.recordName;
                } when 'AccountContactRelation' { //for testing
                    return 'TEST';
                } When 'Case'{
                  return 'Case - ' + this.recordName;  
                } 
                when else {
                    throw new InvocableSpringCMDocGenException('Object type, ' + this.getSObjectName() + ' is not configured for this class');
                }
            }
        }
        
        public String getPath(){
            switch on this.getSObjectName(){
                when 'Application__c' {
                    return './PVL/Applications/';
                }when 'Case' {
                    return './Salesforce/Case/';
                } when else {
                    throw new InvocableSpringCMDocGenException('Object type, ' + this.getSObjectName() + ' is not configured for this class');
                }
            }
        }
        
        public String getSOBjectName(){
            return this.recordId.getSobjectType().getDescribe().getName();
        }
    }

    public class InvocableSpringCMDocGenException extends Exception {}
}