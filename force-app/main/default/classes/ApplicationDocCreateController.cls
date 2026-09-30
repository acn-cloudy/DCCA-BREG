public class ApplicationDocCreateController {
    public class Input {
        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
        @InvocableVariable(label='Notification Id' )
        public Id notificationId;
        @InvocableVariable(label='Template Name')
        public String templateName;
    }
    @InvocableMethod(label='Create PDF' category='Application')
    public static void createPDF(Input[] inputs) {
        
        Map<String, ContentVersion> notId2Blob = new Map<String, ContentVersion>();
        for(Input i: inputs) {
            String docName = i.templateName + '.pdf';
            PageReference ref = PVL_PDFGenerator.generateURL(i.recordId, i.templateName);
            Blob content = Test.isRunningTest() ? Blob.valueOf('test') : ref.getContent();
            ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.VersionData = content;
            cv.Title = docName;
            cv.PathOnClient = '/'+docName;
            notId2Blob.put(i.notificationId, cv);
        }
        for(Input i: inputs) {
            ContentVersion cv = notId2Blob.get(i.notificationId);
            insert cv;
            ContentVersion cDoc = [Select ContentDocumentId from ContentVersion Where Id =: cv.Id];
            String contentDocumentId = cDoc.ContentDocumentId;
            ContentDocumentLink cDe = new ContentDocumentLink();
            cDe.ContentDocumentId = cDoc.ContentDocumentId;
            cDe.LinkedEntityId = i.notificationId;
            cDe.ShareType = 'I';
            cDe.Visibility = 'AllUsers';
            insert cDe;
        }
    }
}