public class ScreenSpringGen {
    @InvocableMethod(label='Screen DocGen' category='SpringCM')
    public static void invokeSpringCMDocGen(Input[] inputs) {
        List<String> recordIds = new List<String>();
        for(Input i: inputs) {
            recordIds.add(i.recordId);
        }
        List<Application__c> records = [Select Id, 
            SpringCM_Deficiency_Letter__c, NotificationEmail__c from Application__c where Id in: recordIds];
        Map<Id, Application__c> recordMap = new Map<Id, Application__c>(records);
        for(Input i : inputs) {
            Application__c record = recordMap.get(i.recordId);
    	    XmlStreamWriter w = new XmlStreamWriter();
	        w.writeStartElement(null, 'Params', null);
            w.writeStartElement(null, 'RecordId', null);
            w.writeCharacters(i.recordId);
            w.writeEndElement();
            w.writeStartElement(null, 'TemplateName', null);
        	w.writeCharacters(record.SpringCM_Deficiency_Letter__c);
            w.writeEndElement();
            w.writeStartElement(null, 'Email', null);
        	w.writeCharacters(record.NotificationEmail__c);
            w.writeEndElement();
            w.writeStartElement(null, 'DocumentName', null);
        	w.writeCharacters(i.docName);
            w.writeEndElement();
            w.writeStartElement(null, 'SendEmail', null);
        	w.writeCharacters(i.sendEmail + '');
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
			SpringCMRestHelper.startWorkflow('DocGenAndEmailProcess', w.getXmlString());            
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

        @InvocableVariable(label='Send Email')
 		public Boolean sendEmail;
        
        public String getFolderName(){
            switch on this.getSObjectName(){
                when 'Application__c' {
                    return 'Application - ' + this.recordName;
                } when 'AccountContactRelation' { //for testing
                    return 'TEST';
                } when else {
                    throw new ScreenSpringGenException('Object type, ' + this.getSObjectName() + ' is not configured for this class');
                }
            }
        }
        
        public String getPath(){
            switch on this.getSObjectName(){
                when 'Application__c' {
                    return './PVL/Applications/';
                } when else {
                    throw new ScreenSpringGenException('Object type, ' + this.getSObjectName() + ' is not configured for this class');
                }
            }
        }
        
        public String getSOBjectName(){
            return this.recordId.getSobjectType().getDescribe().getName();
        }
    }

    public class ScreenSpringGenException extends Exception {}
}