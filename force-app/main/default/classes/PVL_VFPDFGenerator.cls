public class PVL_VFPDFGenerator {
    public static void createFile(String recordId, String pageName, String notificationId, String docName) {
        PageReference pdf = new PageReference('/apex/' + pageName);
        pdf.getParameters().put('id', recordId);
        
        Blob content;
        if(!test.isRunningTest()) content = pdf.getContent();
        else content = Blob.valueOf('test');
        SpringCMConnector.createFile(recordId, docname, content);

        // Attach the file to Notification
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.VersionData = content;
        cv.Title = docName;
        cv.PathOnClient = '/'+docName;
        cv.FirstPublishLocationId = notificationId;
        insert cv;
        
    }

    public class QueueClass implements Queueable, Database.AllowsCallouts {
        public String recordId;
        public String pageName;
        public String notificationId;
        public String docName;

        public QueueClass(String recordId, String pageName, String notificationId, String docName) {
            this.recordId = recordId; 
            this.pageName = pageName; 
            this.notificationId = notificationId;
            this.docName = docName;
        }
        public void execute(QueueableContext context) {
            createFile(recordId, pageName, notificationId, docName);
        }
    }

    public static void producePDFToFile(String recordId, String pageName, String notificationId, String docName) {
        System.enqueueJob(new QueueClass(recordId, pageName, notificationId, docName));
    }
}