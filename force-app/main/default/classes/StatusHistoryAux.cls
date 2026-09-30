/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Generic class that inserts history records for different objects
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class StatusHistoryAux {

    public static void LogStatus(List<sObject> newList, Map<Id, sObject> oldMap, String statusField, String parentObject, String parentField) {
        
        String cuId = UserInfo.getUserId();
        User cUser = [SELECT FirstName, LastName FROM User WHERE Id = :cuId];
        String cuName = cUser.FirstName + ' ' + cUser.LastName;
        Map<String, DateTime> endDate = new Map<String, DateTime>();
        Map<String, DateTime> closedCaseDateTime = new Map<String, DateTime>();

        List<sObject> eligibleList = new List<sObject>();
        for (sObject newObj : newList) {
            if (oldMap != null) {
                sObject oldObj = oldMap.get(newObj.Id);
                if (newObj.get(statusField) != oldObj.get(statusField)) {
                    eligibleList.add(newObj);
                }
                if(statusField == 'Status__c' && oldObj.get(statusField) != 'Closed'
                    && newObj.get(statusField) == 'Closed' && parentObject== 'SEBCase__c'){

                        if(newObj.get('ClosedDateTime__c') != null) {
                            endDate.put(newObj.Id, (Datetime)newObj.get('ClosedDateTime__c'));
                            closedCaseDateTime.put((String) newObj.Id, (Datetime)newObj.get('ClosedDateTime__c'));
                        } else {
                            endDate.put(newObj.Id, System.now());
                        }
                        
                }
            } else {
                eligibleList.add(newObj);
            }
        }
        
        List<StatusHistory__c> toInsert = new List<StatusHistory__c>();
        List<StatusHistory__c> toUpdate = new List<StatusHistory__c>();
        
        List<sObject> eligibleWithHistory = database.query('SELECT Id, ' + statusField + ', CreatedDate, (SELECT Id, StatusValue__c, EndDate__c FROM StatusHistories__r ORDER BY EndDate__c DESC) FROM ' + parentObject + ' WHERE Id IN :eligibleList');
        for (sObject obj : eligibleWithHistory) {
            List<sObject> histories = obj.getSObjects('StatusHistories__r');
            StatusHistory__c oldHist = null;
            if (histories != null && histories.size() > 0) {
                if (oldMap != null) {
                    StatusHistory__c shl1 = null; // Either one with the right status and no End Date
                    StatusHistory__c shl2 = null; // Or the last one created
                    for (sObject sho : histories) {
                        StatusHistory__c sh = (StatusHistory__c)sho;
                        if (sh.StatusValue__c == (String)oldMap.get(obj.Id).get(statusField) && sh.EndDate__c == null) {
                            shl1 = sh;
                        }
                        if (sh.EndDate__c != null && (shl2 == null || shl2.EndDate__c < sh.EndDate__c)) {
                            shl2 = sh;
                        }
                    }
                    if (shl1 != null) {
                        if(closedCaseDateTime.containsKey(obj.Id) ) {
                            shl1.EndDate__c = closedCaseDateTime.get(obj.Id);
                        } else {
                            shl1.EndDate__c = DateTime.now();
                        }
                        
                        toUpdate.add(shl1);
                    } else if (shl2 != null) {
                        StatusHistory__c hist = new StatusHistory__c();
                        hist.put(parentField, obj.Id);
                        hist.StartDate__c = shl2.EndDate__c;
                        hist.StatusValue__c = (String)oldMap.get(obj.Id).get(statusField);
                        hist.EndDate__c = DateTime.now();
                        hist.ModifiedByName__c = cuName;
                        hist.ModifiedByID__c = cuId;
                        toInsert.add(hist);
                    }
                }
            } else if (oldMap != null) {
                // This is the situation of a status update without previous hisotry records
                StatusHistory__c hist = new StatusHistory__c();
                hist.put(parentField, obj.Id);
                hist.StartDate__c = (DateTime)obj.get('CreatedDate');
                hist.StatusValue__c = (String)oldMap.get(obj.Id).get(statusField);
                hist.EndDate__c = DateTime.now();
                hist.ModifiedByName__c = cuName;
                hist.ModifiedByID__c = cuId;
                toInsert.add(hist);
                
            }
            
            StatusHistory__c hist = new StatusHistory__c();
            hist.put(parentField, obj.Id);
            hist.StartDate__c = DateTime.now();
            hist.StatusValue__c = (String)obj.get(statusField);
            if(closedCaseDateTime.containsKey(obj.Id)) {
                hist.StartDate__c = closedCaseDateTime.get(obj.Id);
                hist.EndDate__c = null;
            } else {
                hist.EndDate__c = endDate.get(obj.Id);
            }
            
            hist.ModifiedByName__c = cuName;
            hist.ModifiedByID__c = cuId;
            toInsert.add(hist);
        }
        
        if (toUpdate.size() > 0) {
            update toUpdate;
        }
        if (toInsert.size() > 0) {
            insert toInsert;
        }
    }
}