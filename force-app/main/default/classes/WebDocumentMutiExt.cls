public with sharing class WebDocumentMutiExt {
    public String content {set;get;}
    public WebDocumentMutiExt(ApexPages.StandardController stdController) {
        String queryId = System.currentPageReference().getParameters().get('queryId');
        String otherIds = System.currentPageReference().getParameters().get('otherIds');  // only one temp
        // String recordId = stdController.getId();
        // content = updateIDContent(recordId, queryId);
        // if(otherIds != null && otherIds.length() > 0) {
        //     String[] otherIdsList = otherIds.split(',');
        // 	for (String otherId : otherIdsList) {
        //         content = content + '<div style="page-break-after:always;" />';  // page break
		// 		content = content + updateIDContent(otherId, queryId);
        // 	}
        // }
     
    }
    
    // public String updateIDContent(String id, String queryId) {
    //     DocGeneratorSettings__c setting = [Select Id, TemplateContent__c from DocGeneratorSettings__c where Id =: id];
    //     string tempContent = setting.TemplateContent__c;
    //     List<DocGeneratorDataSource__c> newDataSources 
    //         = [Select Id, DataType__c, Query__c, ParentSourceName__c,
    //            ParentSourceField__c, SourceName__c, 
    //            Row_Specs__c from DocGeneratorDataSource__c 
    //             where DocGeneratorSettings__c =: id order by Name];
    //     List<DocGeneratorFeed> feeds = (new DocGeneratorDataSourceDomain(newDataSources)).generateRecords(queryId, null);
	// 	return updateContent(tempContent, feeds);
    // }


    // public String updateContent(String content, List<DocGeneratorFeed> feeds) {
    //     for(DocGeneratorFeed feed: feeds) {
    //         if(feed.valueMap != null ) {
    //             for(String key : feed.valueMap.keyset()) {
    //                 content = content.replace(key, feed.valueMap.get(key));
    //             }
    //         }
    //         if(feed.valueMaps != null ) {
    //             String strs= '<table class="MsoTableGrid"  style="font-family:Courier New, Courier, monospace"><tbody>';
                
    //             for(Map<String, String> valueMap: feed.valueMaps) {
    //                  String row = feed.rowSpecs;
    //                 for(String key : valueMap.keyset()) {
    //                     row = row.replace(key, valueMap.get(key));
    //                 }
    //                 row = row.replace('{!'+feed.phaseObject + '.childrenTable}', 
    //                 '{!'
    //                 + feed.phaseObject 
    //                 + '.' + valueMap.get('{!'+feed.phaseObject+'.Id}') 
    //                 + '.childrenTable}' );
                     
    //                 strs = strs + row;
    //             }
                
                
    //             strs = strs + '</tbody></table>';
    //             content = content.replace('{!' +feed.phaseObject + 'Table}', strs);
                
    //         }
    //         if(feed.childrenValues != null ) {
    //             Map<String, String> idToStrs = new Map<String, String>();
    //             for(String key: feed.childrenValues.keySet()) {
    //                 List<Map<String, String>> values = feed.childrenValues.get(key);
    //                 String strs= '<table class="MsoTableGrid"  style="font-family:Courier New, Courier, monospace"><tbody>';
    //                 for(Map<String, String> valueMap: values) {
    //                     String row = feed.rowSpecs;
    //                     for(String unit : valueMap.keyset()) {
    //                         row = row.replace(unit, valueMap.get(unit));
    //                     }
    //                     row = row.replace('{!'+feed.phaseObject + '.childrenTable}', 
    //                     '{!'
    //                     + feed.phaseObject 
    //                     + '.' + valueMap.get('{!'+feed.phaseObject+'.Id}') 
    //                     + '.childrenTable}' );
                        
    //                     strs = strs + row;
    //                 }
    //                 strs = strs + '</tbody></table>';
    //                 idToStrs.put(key, strs);
    //             }
    //             for(String idValue: idToStrs.keyset()) {
    //                 String replaceableItem = '{!' + feed.parentSource 
    //                         + '.' + idValue 
    //                         + '.childrenTable}';
    //                 content = content.replace(replaceableItem, idToStrs.get(idValue));
    //             }

    //         }
    //     }

        
    //     content = content.replace('{!today}', GlobalUtilities.convertDate(Date.today()));
    //     return content;
    // }
}