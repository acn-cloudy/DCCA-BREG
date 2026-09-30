public class PVL_PDFGenerator {
    public class FileGeneratorException extends Exception{}
    public static Boolean checkIfCreateSpringCM = true;
    public static Map<String, String> generateIds(String recordId, String docGeneratorName, String notificationId) {
        Map<String, String> idMap = new Map<String, String>();
        try {
            List<DocGeneratorSettings__c>  docGeneratorSettings = [Select Id, DocumentType__c, DocumentTemplateName__c from DocGeneratorSettings__c where Name =: docGeneratorName];
            if(!docGeneratorSettings.isEmpty() ) {
                List<DocGeneratorDataSource__c> dataSources = [Select Id, Name, SourceName__c, Query_conditions__c from DocGeneratorDataSource__c where DocGeneratorSettings__c =: docGeneratorSettings.get(0).Id order by Name];
                String queryId = recordId;
                List<String> queryIdList = new List<String>();
    
                Map<String, List<String>> fieldValuesMap = new Map<String, List<String>>();
    
                for(DocGeneratorDataSource__c source: dataSources) {
                    List<String> unitQueryIds = new List<String>();
                    String queryConditions, lowerQuery, fieldStr;
                    if(source.Query_conditions__c != null) {
                        try {
                            queryConditions = source.Query_conditions__c;
                            lowerQuery = queryConditions.toLowerCase();
                            fieldStr = queryConditions.substring(7, lowerQuery.indexOf(' from'));
                            List<String> rawFieldList = fieldStr.split(',');
                            List<String> fieldList = new List<String>();
                            for(String fieldQuery: rawFieldList) {
                                fieldList.add(fieldQuery.trim());
                            }
                            String queryField = fieldList.get(0);
                            List<String> unitRecordIds = new List<String>();
        
                            for(String fieldKey: fieldValuesMap.keySet()) {
                                if(queryConditions.indexOf(fieldKey)!= -1) {
                                    queryConditions = queryConditions.replace(fieldKey, ':unitRecordIds');
                                    unitRecordIds = fieldValuesMap.get(fieldKey);
                                }
                            }
                            System.debug('#####fieldValuesMap####' +fieldValuesMap);
                            System.debug('#####queryConditions####' +queryConditions);
                            if(queryConditions.contains('{!')) {
                                continue;
                            }
                            List<SObject> soRecords = Database.query(queryConditions);
                            
                            for(SObject soUnit: soRecords) {
                                String unitValue = (String)soUnit.get(queryField);
                                unitQueryIds.add(unitValue);
                            }
                            String str = '{!'+source.SourceName__c + '.' + queryField + '}';
                            
                            fieldValuesMap.put(str, unitQueryIds);
        
                            queryIdList.addAll(unitQueryIds);
                        
                        } catch(Exception ex) {
                            // Catch the exception for the query conditions is not null.
                            String exceptionMessage= '###############Exception in query condition####################';
                            exceptionMessage += '#############lowerQuery#################' + lowerQuery;
                            exceptionMessage += '#############fieldStr#################' + fieldStr;
                            exceptionMessage += '#############Error#################' + ex.getMessage();
                            throw new FileGeneratorException(exceptionMessage);
                        }
                    }
                }
                String queryIds = String.join( queryIdList, ',');
                
                idMap.put('id', docGeneratorSettings.get(0).Id);
                idMap.put('queryId', recordId);
                idMap.put('queryIds', queryIds);
            }} catch (FileGeneratorException fEx) {
                //update notification record
                // query notification record
                NotificationService.updateErrorStatus(notificationId, fEx.getmessage());
            } catch(Exception ex) {
                NotificationService.updateErrorStatus(notificationId, ex.getmessage());
            }
            return idMap;
    }
    public static String updateContent(String content, List<DocGeneratorFeed> feeds) {
        for(DocGeneratorFeed feed: feeds ) {
            if(feed.valueMap != null ) {
                for(String key : feed.valueMap.keyset()) {
                    content = content.replace(key, feed.valueMap.get(key));
                }
            }
            if(feed.valueMaps != null && !feed.valueMaps.isEmpty()) {
                String strs= '<table class="MsoTableGrid"  style="font-family:Courier New, Courier, monospace"><tbody>';
                
                for(Map<String, String> valueMap: feed.valueMaps) {
                     String row = feed.rowSpecs;
                    for(String key : valueMap.keyset()) {
                        String value = valueMap.get(key);
                        if(value == 'null' ) value = '';
                        row = row.replace(key, value);
                    }
                    row = row.replace('{!'+feed.phaseObject + '.childrenTable}', 
                    '{!'
                    + feed.phaseObject 
                    + '.' + valueMap.get('{!'+feed.phaseObject+'.Id}') 
                    + '.childrenTable}' );
                     
                    strs = strs + row;
                }
                strs = strs + '</tbody></table>';
                content = content.replace('{!' +feed.phaseObject + 'Table}', strs);
            } else if(feed.valueMaps != null && feed.valueMaps.isEmpty()) {
                String defaultValue = feed.defaultValue;
                if(defaultValue == null ) defaultValue = '';
                content = content.replace('{!' +feed.phaseObject + 'Table}', defaultValue);
            }
            if(feed.childrenValues != null ) {
                Map<String, String> idToStrs = new Map<String, String>();
                for(String key: feed.childrenValues.keySet()) {
                    List<Map<String, String>> values = feed.childrenValues.get(key);
                    String strs= '<table class="MsoTableGrid"  style="font-family:Courier New, Courier, monospace"><tbody>';
                    for(Map<String, String> valueMap: values) {
                        String row = feed.rowSpecs;
                        for(String unit : valueMap.keyset()) {
                            String value = valueMap.get(unit);
                            if(value == 'null' ) value = '';
                            row = row.replace(unit, value);
                        }
                        row = row.replace('{!'+feed.phaseObject + '.childrenTable}', 
                        '{!'
                        + feed.phaseObject 
                        + '.' + valueMap.get('{!'+feed.phaseObject+'.Id}') 
                        + '.childrenTable}' );
                        
                        strs = strs + row;
                    }
                    strs = strs + '</tbody></table>';
                    idToStrs.put(key, strs);
                }
                for(String idValue: idToStrs.keyset()) {
                    String replaceableItem = '{!' + feed.parentSource 
                            + '.' + idValue 
                            + '.childrenTable}';
                    content = content.replace(replaceableItem, idToStrs.get(idValue));
                }
            } 
        }
        content = content.replace('{!today}', GlobalUtilities.convertDate(Date.today()));
        for(DocGeneratorFeed feed: feeds ) {
        if(feed.valueMaps != null ) {
                for(Map<String, String> valueMap: feed.valueMaps) {
                    String replaceableItem = '{!'
                        + feed.phaseObject 
                        + '.' + valueMap.get('{!'+feed.phaseObject+'.Id}') 
                        + '.childrenTable}';
                    System.debug('###replaceableItem###' + replaceableItem);
                    content = content.replace(replaceableItem, '');
                }
            }
        }
        content = content.replace('<p>', '<div>');
        content = content.replace('<p ', '<div ');
        content = content.replace('</p>', '</div>');
        content = content.replace(' ',' ');
        return content;
    }

    public static String getContent(String idValue, String docGeneratorName, String notificationId) {
        Map<String, String> idMap = generateIds(idValue, docGeneratorName, notificationId);
        String recordId = idMap.get('id');
        String queryId = idMap.get('queryId');
        String queryIds = idMap.get('queryIds');
        
        
        DocGeneratorSettings__c setting = [Select Id, TemplateContent__c from DocGeneratorSettings__c where Id =: recordId];
        String content = setting.TemplateContent__c;
        List<DocGeneratorDataSource__c> rawDataSources 
            = [Select Id, DataType__c, Query__c, ParentSourceName__c,
               ParentSourceField__c, SourceName__c, DefaultValue__c,
               Row_Specs__c from DocGeneratorDataSource__c 
                where DocGeneratorSettings__c =: recordId order by Name];
        List<DocGeneratorDataSource__c> dataSources = (new DocGeneratorDataSourceDomain(rawDataSources)).filterDataSourceWithQuery();
        List<DocGeneratorFeed> feeds = (new DocGeneratorDataSourceDomain(dataSources)).generateRecords(queryId, queryIds);
        return updateContent(content, feeds);
    }

    public static PageReference generateURL(String recordId, String docGeneratorName) {
        PageReference pageRef ;
        List<DocGeneratorSettings__c> docGeneratorSettings = [Select Id, DocumentType__c, DocumentTemplateName__c from DocGeneratorSettings__c where Name =: docGeneratorName];
        if(!docGeneratorSettings.isEmpty() ) {
            String docType = docGeneratorSettings.get(0).DocumentType__c;
            List<DocGeneratorDataSource__c> dataSources = [Select Id, Name, SourceName__c, Query_conditions__c from DocGeneratorDataSource__c where DocGeneratorSettings__c =: docGeneratorSettings.get(0).Id order by Name];
            String queryId = recordId;
            List<String> queryIdList = new List<String>();

            Map<String, List<String>> fieldValuesMap = new Map<String, List<String>>();
            for(DocGeneratorDataSource__c source: dataSources) {
                List<String> unitQueryIds = new List<String>();
                if(source.Query_conditions__c != null) {
                    String queryConditions = source.Query_conditions__c;
                    String lowerQuery = queryConditions.toLowerCase();
                    String fieldStr = queryConditions.substring(7, lowerQuery.indexOf(' from'));
                    List<String> rawFieldList = fieldStr.split(',');
                    List<String> fieldList = new List<String>();
                    for(String fieldQuery: rawFieldList) {
                        fieldList.add(fieldQuery.trim());
                    }
                    String queryField = fieldList.get(0);
                    List<String> unitRecordIds = new List<String>();

                    for(String fieldKey: fieldValuesMap.keySet()) {
                        if(queryConditions.indexOf(fieldKey)!= -1) {
                            queryConditions = queryConditions.replace(fieldKey, ':unitRecordIds');
                            unitRecordIds = fieldValuesMap.get(fieldKey);
                        }
                    }
                    System.debug('#####fieldValuesMap####' +fieldValuesMap);
                    System.debug('#####queryConditions####' +queryConditions);
                    if(queryConditions.contains('{!')) {
                        continue;
                    }
                    List<SObject> soRecords = Database.query(queryConditions);
                    
                    for(SObject soUnit: soRecords) {
                        String unitValue = (String)soUnit.get(queryField);
                        unitQueryIds.add(unitValue);
                    }
                    String str = '{!'+source.SourceName__c + '.' + queryField + '}';
                    
                    fieldValuesMap.put(str, unitQueryIds);

                    queryIdList.addAll(unitQueryIds);
                }

            }
            String queryIds = String.join( queryIdList, ',');

            
            

            if(docType == 'Word') {
                pageRef = Page.WordDocument	;
            } else if(docType == 'PDF') {
                pageRef = Page.WebPDF;
            }
            pageRef.getParameters().put('id', docGeneratorSettings.get(0).Id);
            pageRef.getParameters().put('queryId', recordId);
            pageRef.getParameters().put('queryIds', queryIds);
            return pageRef;
        }
        return null;
    }   
    public static void createFiles(String recordId, String docGeneratorName, String notificationId) {
        try {
            List<DocGeneratorSettings__c>  docGeneratorSettings = [Select Id, DocumentType__c, DocumentTemplateName__c from DocGeneratorSettings__c where Name =: docGeneratorName];
            if(!docGeneratorSettings.isEmpty() ) {
                List<DocGeneratorDataSource__c> dataSources = [Select Id, Name, SourceName__c, Query_conditions__c from DocGeneratorDataSource__c where DocGeneratorSettings__c =: docGeneratorSettings.get(0).Id order by Name];
                String queryId = recordId;
                List<String> queryIdList = new List<String>();
    
                Map<String, List<String>> fieldValuesMap = new Map<String, List<String>>();
    
                for(DocGeneratorDataSource__c source: dataSources) {
                    List<String> unitQueryIds = new List<String>();
                    String queryConditions, lowerQuery, fieldStr;
                    if(source.Query_conditions__c != null) {
                        try {
                        queryConditions = source.Query_conditions__c;
                        lowerQuery = queryConditions.toLowerCase();
                        fieldStr = queryConditions.substring(7, lowerQuery.indexOf(' from'));
                        List<String> rawFieldList = fieldStr.split(',');
                        List<String> fieldList = new List<String>();
                        for(String fieldQuery: rawFieldList) {
                            fieldList.add(fieldQuery.trim());
                        }
                        String queryField = fieldList.get(0);
                        List<String> unitRecordIds = new List<String>();
    
                        for(String fieldKey: fieldValuesMap.keySet()) {
                            if(queryConditions.indexOf(fieldKey)!= -1) {
                                queryConditions = queryConditions.replace(fieldKey, ':unitRecordIds');
                                unitRecordIds = fieldValuesMap.get(fieldKey);
                            }
                        }
                        System.debug('#####fieldValuesMap####' +fieldValuesMap);
                        System.debug('#####queryConditions####' +queryConditions);
                        if(queryConditions.contains('{!')) {
                            continue;
                        }
                        List<SObject> soRecords = Database.query(queryConditions);
                        
                        for(SObject soUnit: soRecords) {
                            String unitValue = (String)soUnit.get(queryField);
                            unitQueryIds.add(unitValue);
                        }
                        String str = '{!'+source.SourceName__c + '.' + queryField + '}';
                        
                        fieldValuesMap.put(str, unitQueryIds);
    
                        queryIdList.addAll(unitQueryIds);
                    
                    } catch(Exception ex) {
                        // Catch the exception for the query conditions is not null.
                        String exceptionMessage= '###############Exception in query condition####################';
                        exceptionMessage += '#############lowerQuery#################' + lowerQuery;
                        exceptionMessage += '#############fieldStr#################' + fieldStr;
                        exceptionMessage += '#############Error#################' + ex.getMessage();
                        throw new FileGeneratorException(exceptionMessage);
                    }
                }
                }
                String queryIds = String.join( queryIdList, ',');
    
                String docType = docGeneratorSettings.get(0).DocumentType__c;
                PageReference pageRef ;
    
                if(docType == 'Word') {
                    pageRef = Page.WordDocument	;
                } else if(docType == 'PDF') {
                    pageRef = Page.WebPDF;
                }
                pageRef.getParameters().put('id', docGeneratorSettings.get(0).Id);
                pageRef.getParameters().put('queryId', recordId);
                pageRef.getParameters().put('queryIds', queryIds);
                
                Blob content;
                
                if(Test.isRunningTest()) {
                    content = Blob.valueOf('test');
                } else {
                    try {
                        content = pageRef.getContent();
                    } catch(Exception ex) {
                        String exceptionMessage= '###############Exception in File Generate ####################';
                        exceptionMessage += '#############Page URL#################' + pageRef.getUrl();
                        exceptionMessage += '#############id#################' + docGeneratorSettings.get(0).Id;
                        exceptionMessage += '#############queryId#################' + recordId;
                        exceptionMessage += '#############queryIds#################' + queryIds;
                        exceptionMessage += '#############Error#################' + ex.getMessage();
                        throw new FileGeneratorException(exceptionMessage);
                    }
                    
                }
                
                String extensions = '';
                if(docType == 'Word') {
                    extensions = '.doc';
                } else if(docType == 'PDF') {
                    extensions = '.pdf';
                }
                String docName = docGeneratorSettings.get(0).DocumentTemplateName__c + extensions;
                
                
                
                Notification__c notification = NotificationSelector.getNotifications(notificationId).get(0);
                if(notification.License__c != null ) recordId = notification.License__c;
                if(notification.SaveRecordId__c != null) recordId = notification.SaveRecordId__c;
                List<SpringCMDocument> result = new List<SpringCMDocument>();
                if(checkIfCreateSpringCM) {
                    result = SpringCMConnector.createFile(recordId, docname, content);
                } else {
                    if(notification.SendtoPrinter__c) {
                        ContentVersion cv = new ContentVersion();
                        cv.ContentLocation = 'S';
                        cv.VersionData = content;
                        cv.Title = docName;
                        cv.PathOnClient = '/'+docName;
                        insert cv;
                        ContentVersion cDoc = [Select ContentDocumentId from ContentVersion Where Id =: cv.Id];
                        String contentDocumentId = cDoc.ContentDocumentId;
                        ContentDocumentLink cDe = new ContentDocumentLink();
                        cDe.ContentDocumentId = cDoc.ContentDocumentId;
                        cDe.LinkedEntityId = notificationId;
                        cDe.ShareType = 'I';
                        cDe.Visibility = 'AllUsers';
                        insert cDe;
                    }
                }
                NotificationService.updateSuccessStatus(notificationId, result);
            }} catch (FileGeneratorException fEx) {
                //update notification record
                // query notification record
                NotificationService.updateErrorStatus(notificationId, fEx.getmessage());
            } catch(Exception ex) {
                NotificationService.updateErrorStatus(notificationId, ex.getmessage());
            }   
    }

    public class QueueClass implements Queueable, Database.AllowsCallouts {
        public String recordId;
        public String docGeneratorName;
        public String notificationId;
        public Integer counter ;
        public QueueClass(String recordId, String docGeneratorName, String notificationId) {
            this.recordId = recordId; 
            this.docGeneratorName = docGeneratorName; 
            this.notificationId = notificationId;
        }

        public QueueClass(String recordId, String docGeneratorName, String notificationId, Integer counter) {
            this.recordId = recordId; 
            this.docGeneratorName = docGeneratorName; 
            this.notificationId = notificationId;
            this.counter = counter;
        }
        public void execute(QueueableContext context) {
            System.attachFinalizer(new FinalizerClass(recordId, docGeneratorName, notificationId, counter));
            createFiles(recordId, docGeneratorName, notificationId);
        }
    }
    
    public class FinalizerClass implements Finalizer {
        private Integer counter = 1;
        public String recordId;
        public String docGeneratorName;
        public String notificationId;

        public FinalizerClass(String recordId, String docGeneratorName, String notificationId, Integer counter) {
            this.recordId = recordId; 
            this.docGeneratorName = docGeneratorName; 
            this.notificationId = notificationId;
            this.counter = counter;
        }
        public void execute(FinalizerContext ctx) {
            List<Notification__c> records = NotificationSelector.getNotifications(recordId);
            if(!records.isEmpty() && records.get(0).Status__c == 'Failed' && counter < 3) {
                this.counter ++;
                System.enqueueJob(new QueueClass(recordId, docGeneratorName, notificationId, counter));
            }

        }
    }
    public static void producePDFToFile(String recordId, String docGeneratorName, String notificationId) {
        System.enqueueJob(new QueueClass(recordId, docGeneratorName, notificationId));
    }

    @Future(callout=true)
    public static void producePDFToFile(String recordId, String docGeneratorName) {
        List<DocGeneratorSettings__c>  docGeneratorSettings = [Select Id, DocumentType__c, DocumentTemplateName__c from DocGeneratorSettings__c where Name =: docGeneratorName];
        if(!docGeneratorSettings.isEmpty()) {
            String docType = docGeneratorSettings.get(0).DocumentType__c;
            PageReference pageRef = generateURL(recordId, docGeneratorName);
            
            Blob content;
            if(Test.isRunningTest()) {
                content = Blob.valueOf('test');
            } else {
                content = pageRef.getContent();
            }
            
            String extensions = '';
            if(docType == 'Word') {
                extensions = '.doc';
            } else if(docType == 'PDF') {
                extensions = '.pdf';
            }
            String docName = docGeneratorSettings.get(0).DocumentTemplateName__c + extensions;
            SpringCMConnector.createFile(recordId, docname, content);
        }
    }
}