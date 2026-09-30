global class SpringCMRestHelper {
    public static void StartWorkflow (List <SObject> listofsobjects, String sfType, String workflowname, String sId) {
        if (String.isBlank(workflowname)) return;
        if (String.isBlank(sfType)) return;
        if (listofsobjects.isEmpty()) return;

        System.debug(UserInfo.getSessionId());
        
        String xml = buildWorkflowXML(listofsobjects, sfType);

        startWorkflow(workflowname, xml, sId);
    }
    
    public static void StartWorkflowWithRecordType(Map<SObject,string> listofsobjects, String sfType, String workflowname, String sId) {
        if (String.isBlank(workflowname)) return;
        if (String.isBlank(sfType)) return;
        if (listofsobjects.isEmpty()) return;

        System.debug(UserInfo.getSessionId());
        
        String xml = buildWorkflowXML(listofsobjects, sfType);

        startWorkflow(workflowname, xml, sId);
    }

    webservice static void StartWorkflowWithRecordType(String sfId, String sfType, String workflowname, String sId, string recordType) {
        if (String.isBlank(workflowname)) return;
        if (String.isBlank(sfType)) return;
        if (String.isBlank(sfId)) return;
        
        String xml = buildWorkflowXML(sfType, sfId, recordType);

        startWorkflow(workflowname, xml, sId);
    }
    
    webservice static void StartWorkflow(String sfId, String sfType, String workflowname, String sId) {
        if (String.isBlank(workflowname)) return;
        if (String.isBlank(sfType)) return;
        if (String.isBlank(sfId)) return;
        
        String xml = buildWorkflowXML(sfType, sfId, '');

        startWorkflow(workflowname, xml, sId);
    }

    private static String buildWorkflowXML(List<SObject> listofsobjects, string sfType) {
        String xml = '';
        for (SObject obj : listofsobjects) {
            xml += buildWorkflowXML(sfType, obj.Id, '');
        }
        return String.isEmpty(xml) ? xml : '<salesforce>' + xml + '</salesforce>';
    }
    
    private static String buildWorkflowXML(Map<SObject,String> listofsobjects, string sfType) {
        String xml = '';
        Set<sObject> objs = listofsobjects.keyset();
        for (SObject obj : objs) {
            string recordType = listofsobjects.get(obj);
            xml += buildWorkflowXML(sfType, obj.Id, recordType);
        }
        return String.isEmpty(xml) ? xml : '<salesforce>' + xml + '</salesforce>';
    }

    public static String buildWorkflowXML(String objecttype, string sfId, string recordType) {
        if (objecttype == null || objecttype == '') return null;
        System.debug('Type: '+objecttype);
        
        SpringCMEos.SpringCMUtilities.EOSObject eosObject = SpringCMEos.SpringCMUtilities.createEOSObject(sfId, objecttype);
        string xml = '';
        xml += '<object>';
        xml += '<id>' +  eosObject.getsfId() + '</id>';
        xml += '<type>Salesforce.' + eosObject.getsfType() + '</type>';
        xml += '<foldername>' + eosObject.getfoldername().escapeXml() + '</foldername>';
        xml += '<path>' +  eosObject.getPath().escapeXml() + '</path>';
        xml += '<recordType>' + recordType + '</recordType>';
        xml += '</object>';
        return xml;
    }
    
    @future(callout=true)
    public static void startWorkflow(String workflowname, String xml, String session) {
        System.debug('session: ' + session);
        SpringCMService springcm = new SpringCMService();
        if (springcm.apiBaseUrl == null) return;
        SpringCMWorkflow workflow = new SpringCMWorkflow(workflowname, xml);
        workflow = springcm.startWorkflow(workflow); 
        System.debug('workflow: ' + workflow);
    }

    public static void startWorkflow(String workflowname, String xml) {
        SpringCMService springcm = new SpringCMService();
        if (springcm.apiBaseUrl == null) return;
        SpringCMWorkflow workflow = new SpringCMWorkflow(workflowname, xml);
        workflow = springcm.startWorkflow(workflow);        
    }

    
}