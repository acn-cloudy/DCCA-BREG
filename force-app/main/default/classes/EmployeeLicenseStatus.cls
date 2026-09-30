/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* EmployeeLicenseStatus : Update employee license with StatusDuetoLossofDependent__c from License Type
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
* 
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
global class EmployeeLicenseStatus implements Database.Batchable<SObject>, Database.Stateful {
	public Map<Id, String> employeeLicenseIdStatusMap;
    public String query;
    global EmployeeLicenseStatus(Map<Id, String> employeeLicenseIdStatusMap) {
        System.debug('employeeLicenseIdStatusMap' + employeeLicenseIdStatusMap);
        this.employeeLicenseIdStatusMap = employeeLicenseIdStatusMap;
        List<String> idStrList = new List<String>();
        for (Id singleId : employeeLicenseIdStatusMap.keySet()) {
            idStrList.add('\'' + singleId + '\'');
        }
        String idStr = '( ' + String.join(idStrList, ',') + ') ';
        query = 'SELECT Id, Status__c FROM License__c where Id IN ' + idStr;
    }
    
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        System.debug('scope' + scope);
        System.debug('employeeLicenseIdStatusMap2' + employeeLicenseIdStatusMap);
        List<License__c> records = (List<License__c>) scope;
        List<License__c> recordsForUpdate = new List<License__c>();
        for (License__c lc : records) {
            if (employeeLicenseIdStatusMap.containsKey(lc.Id)) {
             	lc.Status__c = employeeLicenseIdStatusMap.get(lc.Id);
                recordsForUpdate.add(lc);
            }
        }
        
        if (!recordsForUpdate.isEmpty()) {
            update recordsForUpdate;
        }
    }
	/* batch finish class */
    global void finish(Database.BatchableContext context) {
        /* To send confirmation emails or execute post-processing operations. */
    }
   
}