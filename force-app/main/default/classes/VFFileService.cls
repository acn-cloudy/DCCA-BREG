public class VFFileService {
    @InvocableMethod(label = 'Create File In SpringCM' description = 'Create File In SpringCM')
    public static void createFiles(List<String> strs) {
        String str = strs.get(0);
        Map<String, String> lid2Page = (Map<String, String>) JSON.deserialize(str, Map<String, String>.class);
        createFileInfos(lid2Page);
        
    }
    @future(callout=true) 
    public static void createFileInfos(Map<String, String> lid2Page) {
        List<String> recordIds = new List<String>();
        Integer Index = 0;
        for(String recordId: lid2Page.keyset()) {
            if(index == 9) break;
            String docName = lid2Page.get(recordId);
            String pageName = docName.replace(' ', '').replace('-', '');
            PageReference pageRef = new PageReference('/apex/'+pageName);
            pageRef.getParameters().put('Id', recordId);
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
                // String docName = 'License Post Card(' +index + ').pdf';
                docName = docName + '.pdf';
                List<SpringCMDocument> result = SpringCMConnector.createFile(recordId, docname, content);
            }
            recordIds.add(recordId);
            Index ++;
        }
        for(String recordId: recordIds) {
            lid2Page.remove(recordId);
        }
        if(!lid2Page.isEmpty()) {
            PVLProcess__e process = new PVLProcess__e();
            process.Type__c = 'Generate PDF From VF';
            process.Payload__c = JSON.serialize(lId2Page);
            EventBus.publish(process);
        }
    }
}