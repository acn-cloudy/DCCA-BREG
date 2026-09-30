/*
* ─────────────────────────────────────────────────────────
* Used for the unit logic around
* DocGeneratorDataSources records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ251019 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-10-25
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class DocGeneratorDataSourceDomain extends SObjectDomain {
    public DocGeneratorDataSourceDomain(List<DocGeneratorDataSource__c> dataSources) {
        super(dataSources);    
    }
    public List<DocGeneratorFeed> generateRecords(String queryId, String queryIds) {
        List<String> queryIdList = new List<String>();
        if(queryIds != null ) {
            queryIdList = queryIds.split(',');
        }
        
        List<DocGeneratorFeed> feeds = new List<DocGeneratorFeed>();
        for(SObject record: records) {
            DocGeneratorDataSource__c dataSource = (DocGeneratorDataSource__c) record;
            String dataType = dataSource.DataType__c;
            String query = dataSource.Query__c ;
            
            DocGeneratorFeed feed = new DocGeneratorFeed();
            feed.parentField = dataSource.ParentSourceField__c;
            feed.parentSource = dataSource.ParentSourceName__c;
            feed.query = dataSource.Query__c;
            feed.defaultValue = dataSource.DefaultValue__c;
            String lowerQuery = query.toLowerCase();
            feed.phaseObject = dataSource.SourceName__c;
            feed.rowSpecs = dataSource.Row_Specs__c;
            System.debug('###feed.query###' + feed.query);
            System.debug('#####queryIdList#####' + queryIdList);
            System.debug('#####queryId#####' + queryId);
            String fieldStr = feed.query.substring(7, lowerQuery.indexOf(' from'));
            List<String> fields = new List<String>();
            for(String field: fieldStr.split(',')){
                fields.add(field.trim());
            }
            feed.fields = fields;

            if(dataType == 'Detail') {
                List<SObject> queryRecords = Database.query(query);
                System.debug('###queryRecords###' + queryRecords);
                if(!queryRecords.isEmpty()) {
                    SObject queryRecord = queryRecords.get(0);
                
                    feed.record = queryRecord;
                
                    feed.valueMap = new Map<String, String>();
                    for(String field: feed.fields) {
                        String strValue = '';
                        Object o;
                        o = feed.record.get(field);
                        if(o == null ) {

                        } else if(o instanceOf Date) {
                            Date dValue = Date.valueOf(o);
                            strValue = GlobalUtilities.convertDate(dValue);
                        } else {
                            strValue = o + '';
                        }
                        strValue = strValue.replace('\n', '<br>');
                        
                        String fieldApiName = '{!' + feed.phaseObject + '.' + field + '}';
                        feed.valueMap.put(fieldApiName, strValue);
                        System.debug('###feed.valueMap###' + feed.valueMap);
                }
            }
            } else if (dataType == 'Table') {
                List<SObject> records = Database.query(query);
                if(feed.parentSource != null && feed.parentField != null) {
                    feed.childrenValues = (new SObjectDomain(records)).convertValueMapList(feed.phaseObject, feed.fields, feed.parentField) ;
                } else {
                    feed.valueMaps = (new SObjectDomain(records)).convertValueMapList(feed.phaseObject, feed.fields) ;
                }
            } else if (dataType == 'Barcode') {
                SObject queryRecord = Database.query(query);
                feed.record = queryRecord;
                feed.valueMap = new Map<String, String>();
                for(String field: feed.fields) {
                    String strValue = '';
                    Object o;
                    o = feed.record.get(field);
                    if(o instanceOf Date) {
                        Date dValue = Date.valueOf(o);
                        strValue = GlobalUtilities.convertDate(dValue);
                    } else {
                        strValue = o + '';
                    }
                    // String sUrl = 'http://barcodes4.me/barcode/c39/'+strValue+'.png';
                    // String sUrl = 'https://barcode.tec-it.com/barcode.ashx?data=' + strValue 
                    //     + '&code=Code128&translate-esc=on';
                    // String sUrl = 'https://barcode.design/barcode.asp?bc2=8&bc3=3.5&bc4=1.2&bc5=1&bc6=1&bc7=Arial&bc8=15&bc9=1&bc1='+strValue;
                    
                    String imageStr = '<c:barcode data="'+strValue+'" />';
                    String fieldApiName = '{!' + feed.phaseObject + '.' + field + '}';
                    feed.valueMap.put(fieldApiName, imageStr);
                }
            } else if (dataType == 'Image') {
                List<SObject> queryResults = Database.query(query);
                if(queryResults.isEmpty())  {
                    continue;
                }
                SObject queryRecord = queryResults.get(0);
                feed.record = queryRecord;
                feed.valueMap = new Map<String, String>();
                String sUrl ;
                for(String field: feed.fields) {
                    String strValue = '';
                    Object o;
                    o = feed.record.get(field);
                    if(o instanceOf Date) {
                        Date dValue = Date.valueOf(o);
                        strValue = GlobalUtilities.convertDate(dValue);
                    } else {
                        strValue = o + '';
                    }
                    
                    if(strValue.contains('http')) {
                        sUrl = strValue;
                    } else {
                        sUrl = '/sfc/servlet.shepherd/version/download/'+strValue+'?asPdf=false&operationContext=CHATTER';
                    }
                    String imageStr = '<img alt="User-added image" width="100px" src="'+sUrl+ '"></img>';
                    String fieldApiName = '{!' + feed.phaseObject + '.' + field + '}';
                    feed.valueMap.put(fieldApiName, imageStr);
                }
            }
            feeds.add(feed);
        }
        return feeds;
    }

    public List<DocGeneratorDataSource__c> filterDataSourceWithQuery() {
        List<DocGeneratorDataSource__c> datasources = new List<DocGeneratorDataSource__c>();
        for(DocGeneratorDataSource__c record: (List<DocGeneratorDataSource__c>) records) {
            if(!String.isBlank(record.Query__c )) {
                datasources.add(record);
            }
        }
        return dataSources;
    }
    
}