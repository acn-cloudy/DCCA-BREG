/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Creates Transaction and Transaction Line records when a License is created
* Covered by LicenseCreateRecordsTest
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-CZ042320 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author Chris Zhuang - Pacificpoint
* @created 04/23/20
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public with sharing class LicenseUpdateTransactionRecords {
    @InvocableMethod
	public static void updateTransactionRecords(List<License__c> licenseList){
        List<Transaction__c> transactionToUpdateList = new List<Transaction__c>();
        Map<Id, Id> appToLicenseIdMap = new Map<Id, Id>();

		for(License__c l : licenseList){
            if (l.Application__c != null) {
                appToLicenseIdMap.put(l.Application__c, l.Id);
            }
		}

		//To Retrieve Transaction Records
		List<Transaction__c> transactionList = [SELECT Id, Application__c, License__c FROM Transaction__c WHERE Application__c in: appToLicenseIdMap.keySet()];
        //Map<Id, List<Transaction__c>> applicationTransactionMap = new Map<Id, List<Transaction__c>>();
		for(Transaction__c trans : transactionList) {
            trans.License__c = appToLicenseIdMap.get(trans.Application__c);
			transactionToUpdateList.add(trans);
		}

		if(!transactionToUpdateList.isEmpty()){
			update transactionToUpdateList;
		}
	}
}