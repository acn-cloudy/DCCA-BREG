/*
 * ___________________________________________________________________________________
 * Run Number of Active Classes Validation on License update
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-IC021920 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author irene.cahilo@pacificpointcorp.com
 * @created 2/19/2020
 * __________________________________________________________________________________
 */
public class LicenseActiveClassesValidation {
	public static void runNumberOfActiveClassesValidation(List<License__c> licensesToUpdate, Map<Id, License__c> licenseOldMap) {
		String currentStatus = 'C - Current, Valid & In Good Standing'; //License and License Classification Status
		String previousStatus = 'CP - Current Pending'; //License Status
		String licenseTypeName = 'RDS'; //License Type Name
		String employeeLicenseStatus = 'C - Current, Valid & In Good Standing'; //Employee License Status to be checked
		Map<Id, License__c> licenseMap = new Map<Id, License__c>();

		List<Id> licenseIds = new List<Id>();
		for(License__c licenseRecord : licensesToUpdate){
			//Check the current and previous License Status
			if(licenseRecord.Status__c == currentStatus
					&& licenseOldMap.get(licenseRecord.Id).Status__c == previousStatus
					&& licenseRecord.LicenseTypeName__c == licenseTypeName ){

				licenseIds.add(licenseRecord.Id);
			}
		}
        if(licenseIds.isEmpty()) return;
		
		//Retrieves the child License Classification and Associated License(Entity License) Records
		//Filters the child License Classification records depending on the Status
		//Filters the child Associated License records depending on the Employee License Status
		List<License__c> licenseList = [SELECT Id, LicenseType__c,
		(SELECT Id, ClassificationName__c, Status__c FROM LicenseClassifications__r WHERE Status__c =: currentStatus),
		(SELECT Id, EmployeeLicenseStatus__c, ActiveAClasses__c, ActiveMClasses__c, ActiveTClasses__c FROM AssociatedEmployee__r WHERE EmployeeLicenseStatus__c =: employeeLicenseStatus)
		FROM License__c WHERE Id IN: licenseIds];

		//Add the retrieved licenses to the Map
		for(License__c l : licenseList){
			licenseMap.put(l.Id, l);
		}

		for (License__c license : licensesToUpdate){
			if(licenseIds.contains(license.Id)){
				Boolean licenseClassificationValid = false;
				Boolean associatedLicenseValid = false;

				//Condition 1
				//License Classification "Name" Starts with A
				//Associated License "Employee License's Active A Classes" is greater than 8
				if(!licenseMap.get(license.Id).LicenseClassifications__r.isEmpty()){
					for(LicenseClassification__c lc : licenseMap.get(license.Id).LicenseClassifications__r){
						if(lc.ClassificationName__c.startsWith('A')){
							licenseClassificationValid = true;
						}
					}
				}
				if(!licenseMap.get(license.Id).AssociatedEmployee__r.isEmpty()){
					for(AssociatedLicense__c ae : licenseMap.get(license.Id).AssociatedEmployee__r){
						if(ae.ActiveAClasses__c >= 8){
							associatedLicenseValid = true;
						}
					}
				}
				System.debug('#####condition 1####licenseClassificationValid#####'+ licenseClassificationValid 
					+ '#####associatedLicenseValid####'+associatedLicenseValid);

				//Condition 2
				//License Classification "Name" Contains 'Motorcycle & Motor Scooter'
				//Associated License "Employee License's Active M Classes" is greater than 1
				if(!licenseClassificationValid || !associatedLicenseValid){
					licenseClassificationValid = false;
					associatedLicenseValid = false;
					if(!licenseMap.get(license.Id).LicenseClassifications__r.isEmpty()){
						for(LicenseClassification__c lc : licenseMap.get(license.Id).LicenseClassifications__r){
							if(lc.ClassificationName__c.contains('Motorcycle & Motor Scooter')){
								licenseClassificationValid = true;
							}
						}
					}
					if(!licenseMap.get(license.Id).AssociatedEmployee__r.isEmpty()){
						for(AssociatedLicense__c ae : licenseMap.get(license.Id).AssociatedEmployee__r){
							if(ae.ActiveMClasses__c >= 1){
								associatedLicenseValid = true;
							}
						}
					}
					System.debug('#####condition 2####licenseClassificationValid#####'+ licenseClassificationValid 
					+ '#####associatedLicenseValid####'+associatedLicenseValid);
				}

				//Condition 3
				//License Classification "Name" Starts with T
				//Associated License "Employee License's Active T Classes" is greater than 7
				if(!licenseClassificationValid || !associatedLicenseValid){
					licenseClassificationValid = false;
					associatedLicenseValid = false;
					if(!licenseMap.get(license.Id).LicenseClassifications__r.isEmpty()){
						for(LicenseClassification__c lc : licenseMap.get(license.Id).LicenseClassifications__r){
							if(lc.ClassificationName__c.startsWith('T')){
								licenseClassificationValid = true;
							}
						}
					}
					if(!licenseMap.get(license.Id).AssociatedEmployee__r.isEmpty()){
						for(AssociatedLicense__c ae : licenseMap.get(license.Id).AssociatedEmployee__r){
							if(ae.ActiveTClasses__c >= 7){
								associatedLicenseValid = true;
							}
						}
					}
					System.debug('#####condition 3####licenseClassificationValid#####'+ licenseClassificationValid 
					+ '#####associatedLicenseValid####'+associatedLicenseValid);
				}

				//If either one is Invalid, set both to Invalid
				if(!(licenseClassificationValid && associatedLicenseValid)){
					licenseClassificationValid = false;
					associatedLicenseValid = false;
				}

				//Checks if both child License Classification and Associated License Records are INVALID
				if(!(licenseClassificationValid && associatedLicenseValid)){
					license.addError('An RDS needs to have at least one MC with all 8a or 7t classes.');
				}

			}
		}
	}
}