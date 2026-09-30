/*
 * ___________________________________________________________________________________
 * Controller for the FileDetailCreator Lighthning Component
 * Covered by FileDetailCreatorControllerTest
 * __________________________________________________________________________________
 * PacPoint-CL013019 - Created for BREG phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author Chris Loyola - PacificPointCorp
 *
 * @created 01/30/2019
 * __________________________________________________________________________________
 */
public class FileDetailCreatorController {
    @AuraEnabled
    public static Boolean checkIfFileDetail(String recordId){
        List<Filing__c> records = [Select Id, Status__c, ShowGenericUploadButton__c from Filing__c where Id =: recordId];
        Boolean isValid = false;
        if(!records.isEmpty()) {
            isValid = records.get(0).Status__c != 'Filing Withdrawn';
        } else {
            isValid = true;
        }
        if(!isValid) {
            String errorMessage = 'This filing is Withdrawn. You can not upload documents on Withdrawn filings. To upload the document, please submit another Filing.';
            AuraHandledException exp = new AuraHandledException(errorMessage);
            exp.setMessage(errorMessage);
            throw exp;
        }
        return isValid;
    }

    @AuraEnabled
    public static List<AvailableRecordType> getAvailableRecordTypes() {
        List<RecordTypeInfo> rtis = FileDetails__c.sObjectType.getDescribe().getRecordTypeInfos();
        List<AvailableRecordType> result = new List <AvailableRecordType>();
        for (RecordTypeInfo rti : rtis) {
            if (rti.isMaster()) {
                continue;
            }

            if (rti.isAvailable()) {
                AvailableRecordType ar = new AvailableRecordType();
                ar.label = rti.getName();
                ar.id = rti.getRecordTypeId();
                ar.developerName = rti.getDeveloperName();
                ar.isDefault = rti.isDefaultRecordTypeMapping();
                result.add(ar);
            }
        }

        return result;
    }

    @AuraEnabled
    public static String saveRecord(String fileUrl, FileDetails__c record) {
        String filingId = record.Filing__c;
        User u = [Select Id, UserType from User where Id=: Userinfo.getUserId()];
        if(u.UserType == 'Standard' || checkIfFileDetail(filingId) ) {
            record.FileURL__c = fileUrl;
            insert record;
            String recordId = record.Id;
            System.enqueueJob(new QueueClass(fileUrl, recordId));
            return recordId;
        } 
        return record.Id;
    }

    @AuraEnabled
    public static Boolean isVisible(String recordId, String fieldName) {
        Boolean result = false;
        Id sObjectId = (Id) recordId;
        String objectName = sObjectId.getSObjectType().getDescribe().getName();
        String sql = 'SELECT ' + fieldName + ' FROM ' + objectName;
        sql += ' WHERE Id =:sObjectId';

        sObject record = Database.query(sql) ;
        result = (Boolean) record.get(fieldName);
        return result;
    }

    @AuraEnabled
    public static void deleteFileDetail(String fileDetailId) {
        delete [SELECT Id FROM FileDetails__c WHERE Id = :fileDetailId];
    }

    public class AvailableRecordType{
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String developerName;

        @AuraEnabled
        public Boolean isDefault;
    }

    // Add queue class to move the change to async in Queuue.
    public class QueueClass implements Queueable, Database.AllowsCallouts {
        public String fileUrl;
        public String recordId;
        public QueueClass (String fileUrl, String recordId) {
            this.recordId = recordId;
            this.fileUrl = fileUrl;
        }
        public void execute(QueueableContext context) {
            System.attachFinalizer(new FinalizerClass(fileUrl, recordId));
            SpringCMConnector.updateFilesAndFolder(new List<String>{fileUrl}, recordId);
        }
    }
    // Add Finalizer class to add error handling.
    public class FinalizerClass implements Finalizer {
        public String fileUrl;
        public String recordId;

        public FinalizerClass (String fileUrl, String recordId) {
            this.recordId = recordId;
            this.fileUrl = fileUrl;
        }
        
        // there is a limit that queuable class can not have more than 5, thus, it can retry for 5 times
        public void execute(FinalizerContext ctx) {
            String parentJobId = String.valueOf(ctx.getAsyncApexJobId());
            if (ctx.getResult() != ParentJobResult.SUCCESS) {
                System.enqueueJob(new QueueClass(fileUrl, recordId));
                ApplicationLogService.logApplicationError('Moving File And Folder Error', 
                    recordId, '', String.valueOf(ctx.getException()) );
            }
        }
    }
    
}