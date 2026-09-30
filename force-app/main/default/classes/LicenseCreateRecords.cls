/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Creates Transaction and Transaction Line records when a License is created
* Covered by LicenseCreateRecordsTest
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-IC071819 - Created for PVL phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author Irene Cahilo - Pacificpoint
* @created 07/18/19
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class LicenseCreateRecords {
	@InvocableMethod
	public static void licenseCreateLicenseReqRecords(List<License__c> licenseList){
		List<LicenseRequirements__c> licenseRequirementsToCreateList = new List<LicenseRequirements__c>();
		Set<Id> applicationIds = new Set<Id>();
		Set<Id> licenseTypeIds = new Set<Id>(); //From License
		Set<Id> classificationIds = new Set<Id>(); //From License's License Type
		Set<String> categorySet = new Set<String>(); //From License's Application

		for(License__c l : licenseList){
			applicationIds.add(l.Application__c);
			licenseTypeIds.add(l.LicenseType__c);
		}

		//Retrieve Classifications
		List<Classification__c> classificationList = [SELECT Id, LicenseType__c FROM Classification__c WHERE LicenseType__c =: licenseTypeIds];
		Map<Id, Set<Id>> licenseTypeIdClassifications = new Map<Id, Set<Id>>(); //Group by License Type Id
		for(Classification__c c : classificationList){
			classificationIds.add(c.Id);
			if(!licenseTypeIdClassifications.containsKey(c.LicenseType__c)){
				licenseTypeIdClassifications.put(c.LicenseType__c, new Set<Id>());
			}
			licenseTypeIdClassifications.get(c.LicenseType__c).add(c.Id);
		}

		//To Retrieve the Type for Category
		List<Application__c> applicationList = [SELECT Id, Type__c FROM Application__c WHERE Id =: applicationIds];
		Map<Id, String> applicationTypeMap = new Map<Id, String>();
		for(Application__c app : applicationList){
			applicationTypeMap.put(app.Id, app.Type__c);
			categorySet.add(app.Type__c);
		}

		//Retrieve the License Type Requirements
		List<LicenseTypeRequirements__c> licenseTypeRequirementsList = [SELECT Id, Name, LicenseType__c, Requirement__c, Classification__c, Type__c,
		Requirement__r.RequirementShortDescription__c, Requirement__r.RequirementLongDescription__c
		 FROM LicenseTypeRequirements__c WHERE Status__c = 'Active'
		AND LicenseType__c in: licenseTypeIds AND Type__c in: categorySet AND Classification__c in: classificationIds];

		Map<String, Set<Id>> licenseTypeCategoryRequirementId = new Map<String, Set<Id>>(); //LicenseType & Category, License Type Requirement Id
		Map<Id, LicenseTypeRequirements__c> licenseTypeRequirementsMap = new Map<Id, LicenseTypeRequirements__c>();
		for(LicenseTypeRequirements__c ltr : licenseTypeRequirementsList){
			String keyName = ltr.LicenseType__c + ltr.Type__c;
			if(!licenseTypeCategoryRequirementId.containsKey(keyName)){
				licenseTypeCategoryRequirementId.put(keyName, new Set<Id>());
			}
			licenseTypeCategoryRequirementId.get(keyName).add(ltr.Id);
			licenseTypeRequirementsMap.put(ltr.Id, ltr);
		}

		for(License__c license : licenseList){
			String applicationCategory = applicationTypeMap.get(license.Application__c);
			String keyName = license.LicenseType__c + applicationCategory;
			if(licenseTypeCategoryRequirementId.containsKey(keyName)) {
				for (Id ltrId : licenseTypeCategoryRequirementId.get(keyName)) {
					LicenseTypeRequirements__c ltr = licenseTypeRequirementsMap.get(ltrId);
					LicenseRequirements__c licenseRequirement = new LicenseRequirements__c();
					licenseRequirement.Name = ltr.Name;
					// licenseRequirement.LicenseType__c = license.LicenseType__c;
					licenseRequirement.RequirementLongDescription__c = ltr.Requirement__r.RequirementLongDescription__c;
					licenseRequirement.RequirementShortDescription__c = ltr.Requirement__r.RequirementShortDescription__c;
					licenseRequirement.Requirement__c = ltr.Requirement__c;
					licenseRequirement.License__c = license.Id;
					licenseRequirementsToCreateList.add(licenseRequirement);
				}
			}
		}

		if(!licenseRequirementsToCreateList.isEmpty()){
			insert licenseRequirementsToCreateList;
		}
	}
}