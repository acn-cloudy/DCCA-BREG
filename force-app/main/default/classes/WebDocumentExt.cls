/*
* ─────────────────────────────────────────────────────────
* Used for WebPDF and WordDocument generation
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
public without sharing class WebDocumentExt {
    public String content {set;get;}
    public WebDocumentExt(ApexPages.StandardController stdController) {
        String queryId = System.currentPageReference().getParameters().get('queryId');
        String queryIds = System.currentPageReference().getParameters().get('queryIds');
        
        String recordId = stdController.getId();
        DocGeneratorSettings__c setting = [Select Id, TemplateContent__c from DocGeneratorSettings__c where Id =: recordId];
        content = setting.TemplateContent__c;
        List<DocGeneratorDataSource__c> rawDataSources 
            = [Select Id, DataType__c, Query__c, ParentSourceName__c,
               ParentSourceField__c, SourceName__c, DefaultValue__c,
               Row_Specs__c from DocGeneratorDataSource__c 
                where DocGeneratorSettings__c =: recordId order by Name];
        List<DocGeneratorDataSource__c> dataSources = (new DocGeneratorDataSourceDomain(rawDataSources)).filterDataSourceWithQuery();
        List<DocGeneratorFeed> feeds = (new DocGeneratorDataSourceDomain(dataSources)).generateRecords(queryId, queryIds);
        updateContent(feeds);
    }
    public String updateContent(List<DocGeneratorFeed> feeds) {
        
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
}