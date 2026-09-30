/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* 
* - checkLicenseStatus : Find and set the status of Licenses with License Types Start of RenewalPerios = Today
* Covered by LicenseUpdateStatusTest
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Irene Cahilo - PacificPointCorp 
* @created      PacPoint-IC071819 - Created for PVL Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class LicenseUpdateStatus {
	public static void checkLicenseStatus(List<License__c> licensesToUpdate) {
		
		Map<String, String> licenseStatusToChangeInto = new Map<String, String>(); //License Status To Change Into; From -> To
		licenseStatusToChangeInto.put('C - Current, Valid & In Good Standing', 'R - Valid Thru Expiration Date, Subject To Renewal');
		licenseStatusToChangeInto.put('CR - Current/Next Renewal Paid', 'R - Valid Thru Expiration Date, Subject To Renewal');
		licenseStatusToChangeInto.put('CM - Current, Valid & In Good Standing/Maint. Requirement Due', 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');

		for(License__c licenseRecord : licensesToUpdate){
			//Change Status based on the licenseStatusToChangeInto Map
			licenseRecord.Status__c = licenseStatusToChangeInto.get(licenseRecord.Status__c);
		}

		if(!licensesToUpdate.isEmpty()){
			update licensesToUpdate;
		}
	}
	public static void checkLicenseStatus() {
		List<License__c> licensesToUpdate = new List<License__c>(); //List of Licenses to Update
		Date todaysDate = Date.today(); //Retrieve today's date

		List<String> licenseStatusToInclude = new List<String>();//Only licenses with this status
		licenseStatusToInclude.add('C - Current, Valid & In Good Standing');
		licenseStatusToInclude.add('CR - Current/Next Renewal Paid');
		licenseStatusToInclude.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');

		Map<String, String> licenseStatusToChangeInto = new Map<String, String>(); //License Status To Change Into; From -> To
		licenseStatusToChangeInto.put('C - Current, Valid & In Good Standing', 'R - Valid Thru Expiration Date, Subject To Renewal');
		licenseStatusToChangeInto.put('CR - Current/Next Renewal Paid', 'R - Valid Thru Expiration Date, Subject To Renewal');
		licenseStatusToChangeInto.put('CM - Current, Valid & In Good Standing/Maint. Requirement Due', 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');

		//Retrieve License Types with Start of Renewal Period value of Today
		//and related Licenses with Status from licenseStatusToInclude variable
		List<LicenseType__c> licenseTypeList = [SELECT Id, (SELECT Id, Status__c FROM Licenses__r WHERE Status__c IN: licenseStatusToInclude)
		FROM LicenseType__c WHERE StartofRenewalPeriod__c =: todaysDate];

		for (LicenseType__c lt : licenseTypeList){
			//Checks if there are related licenses
			if(!lt.Licenses__r.isEmpty()){
				//For each License record, update the status
				for(License__c licenseRecord : lt.Licenses__r){
					//Change Status based on the licenseStatusToChangeInto Map
					licenseRecord.Status__c = licenseStatusToChangeInto.get(licenseRecord.Status__c);
					licensesToUpdate.add(licenseRecord);
				}
			}
		}

		if(!licensesToUpdate.isEmpty()){
			update licensesToUpdate;
		}

	}
}