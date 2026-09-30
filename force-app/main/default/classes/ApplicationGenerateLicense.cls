/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Application Generate License
* Creates the license for the Application
* Updates the License Classification records for the Current License
* Covered by ApplicationGenerateLicenseTest
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author PacPoint-IC071819 - Created for PVL phase 1
* @created 07/30/2019
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest
public class ApplicationGenerateLicense {
	/**public static void generateLicense(List<Application__c> applicationList, Map<Id, Application__c> applicationOldMap) {
		Date todaysDate = Date.today();

		//For Case 1, throw error
		// Set<String> typeToThrowError = new Set<String>();
		// typeToThrowError.add('ADDC - Additional Class');
		// typeToThrowError.add('RNEW - Renewal');
		// typeToThrowError.add('LICN - New License');

		//For Case 2: Set of License Code Types that are allowed when generating a license
		Set<String> createLicenseCodeTypes = new Set<String>();
		createLicenseCodeTypes.add('LICN - New License');
		createLicenseCodeTypes.add('RNEW - Renewal');

		//For Case 3: Set of Application Classifications Status
		Set<String> appClassStatusToInclude = new Set<String>();
		appClassStatusToInclude.add('P - Passed Exam--Class to be Licensed');
		appClassStatusToInclude.add('NE - No Exam Required--Class to be Licensed');

		//Set of Application Classification Status to not include when retrieving the records
		Set<String> appClassStatusNotIncluded = new Set<String>();
		appClassStatusNotIncluded.add('H - Class Deferred by Board');
		appClassStatusNotIncluded.add('CW - Class Withdrawn by Applicant');
		appClassStatusNotIncluded.add('U - Class No Longer Needed Due To Upgrade To Higher Class');

		Set<Id> applicationIdSet = new Set<Id>();
		Set<Id> generateLicenseIsChanged = new Set<Id>();
		for(Application__c app : applicationList){
			//  Application.GenereateLicense=true => the user changes the Phase of the Application to "H - License Generation". 
			// 00004719
			if(app.Phase__c != applicationOldMap.get(app.Id).Phase__c
				&& app.Phase__c == 'H - License Generation'){
				applicationIdSet.add(app.Id);
				generateLicenseIsChanged.add(app.Id);
			}
			// else{
			// 	generateLicenseIsChanged.put(app.Id, false);
			// }
		}

		List<ApplicationClassifications__c> applicationClassificationList = [SELECT Id, Classification__c, Comments__c, Status__c, Application__c
						FROM ApplicationClassifications__c 
						WHERE Application__c in: applicationIdSet AND (Status__c = null Or Status__c NOT IN :appClassStatusNotIncluded)];
		System.debug('#####applicationClassificationList####' + applicationClassificationList);
		//Application Id, List of Application Classifications
		Map<Id, List<ApplicationClassifications__c>> applicationClassificationsMap = new Map<Id, List<ApplicationClassifications__c>>();
		for(ApplicationClassifications__c ac : applicationClassificationList){
			if(!applicationClassificationsMap.containsKey(ac.Application__c)){
				applicationClassificationsMap.put(ac.Application__c, new List<ApplicationClassifications__c>());
			}
			applicationClassificationsMap.get(ac.Application__c).add(ac);
		}
		System.debug('#####applicationClassificationsMap####' + applicationClassificationsMap);
		List<License__c> licensesToCreate = new List<License__c>(); //For Case 2
		List<LicenseClassification__c> licenseClassificationToCreate = new List<LicenseClassification__c>(); //For Case 3

		for(Application__c applicationRecord : applicationList){
			//Case 1: Throw error
			// 00004719
			// Deactivated as requested.
			// if(applicationRecord.Phase__c <> 'H - License Generation' && !typeToThrowError.contains(applicationRecord.Type__c) && generateLicenseIsChanged.get(applicationRecord.Id) ){
			// 	applicationRecord.addError('A License can only be generated if the Phase is License Generation and type = is a new application, classification or renewal.');
			// }
			
			//Case 2: Create License Record
			if(createLicenseCodeTypes.contains(applicationRecord.Type__c) 
				&& generateLicenseIsChanged.contains(applicationRecord.Id) ){
				//Create the License Record
				License__c licenseRecord = new License__c();
				licenseRecord.Application__c = applicationRecord.Id;
				licenseRecord.Name = applicationRecord.Name;
				licenseRecord.LicenseType__c = applicationRecord.LicenseType__c;
				licenseRecord.Licensee__c = applicationRecord.Applicant__c;
				licenseRecord.DependentLicense__c = applicationRecord.DependentLicense__c;
				if(applicationRecord.DependentApplication__c != null){
					licenseRecord.Application__c = applicationRecord.DependentApplication__c;
				}
				if(applicationRecord.LicenseType__r.LicenseTypeExpireDate__c != null){
					//Set the date 2 months before the Expiration Date
					licenseRecord.EffectiveExpireDate__c = applicationRecord.LicenseType__r.LicenseTypeExpireDate__c.addMonths(-2);
				}
				licensesToCreate.add(licenseRecord);
			//Case 3
			}else if(applicationRecord.CurrentLicense__c != null &&
							applicationRecord.Type__c == 'ADDC - Additional Class' &&
							generateLicenseIsChanged.contains(applicationRecord.Id)){
				
				if (applicationClassificationsMap.containsKey(applicationRecord.Id)) {
					for (ApplicationClassifications__c ac : applicationClassificationsMap.get(applicationRecord.Id)) {
						if(appClassStatusToInclude.contains(ac.Status__c)){
							//Create License Classification Records from the retrieved Application Classification records
							LicenseClassification__c licenseClassificationRecord = new LicenseClassification__c();
							licenseClassificationRecord.License__c = applicationRecord.CurrentLicense__c;
							licenseClassificationRecord.Status__c = 'C - Current, Valid & In Good Standing';
							licenseClassificationRecord.Classification__c = ac.Classification__c;
							licenseClassificationRecord.EffectiveStartDate__c = todaysDate;

							licenseClassificationToCreate.add(licenseClassificationRecord);
						}
					}
				}
			}
		}
		***/
		/***
		//Continuation for Case 2
		if(!licensesToCreate.isEmpty()){
			insert licensesToCreate;
			System.debug('#####licensesToCreate####' + licensesToCreate);
			//Create the License Classification Records
			List<LicenseClassification__c> licenseClassificationsToCreate = new List<LicenseClassification__c>();
			Map<Id, Id> applicationLicenseId = new Map<Id, Id>();

			for(License__c licenseRecord : licensesToCreate) {
				if (applicationClassificationsMap.containsKey(licenseRecord.Application__c)) {
					for (ApplicationClassifications__c ac : applicationClassificationsMap.get(licenseRecord.Application__c)) {
						LicenseClassification__c licenseClassificationRecord = new LicenseClassification__c();
						licenseClassificationRecord.License__c = licenseRecord.Id;
						licenseClassificationRecord.Classification__c = ac.Classification__c;

						licenseClassificationsToCreate.add(licenseClassificationRecord);
					}
				}
				applicationLicenseId.put(licenseRecord.Application__c, licenseRecord.Id);
			}
			***/
			/****
			*	My apologies, we have to change the req one more time. To avoid hardcoding the values 
			*	of the license on creation, I will be creating a pb for the license creation. 
			*	Can u please change your trigger? at this point we only want to do number 4:
			*	Application.Classification records associated license (Current License on the Application record) 
			*	when the button is clicked and the Type="ADDC - Additional Class" . Should populate the "Application 
			*	Classification" records with status <> ("H - Class Deferred by Board", "CW - Class Withdrawn by Applicant",
			*	"U - Class No Longer Needed Due to Upgrade to Higher Class") 
			*	
			* */
			//Update the Application Record's Current License with the newly created license
			// for(Application__c app : applicationList){
			// 	if(applicationLicenseId.containsKey(app.Id)){
			// 		app.CurrentLicense__c = applicationLicenseId.get(app.Id);
			// 	}
			// }
/****
			if (!licenseClassificationsToCreate.isEmpty()) {
				// insert licenseClassificationsToCreate;
			}
		}
		

		//Continuation for Case 3
		// if (!licenseClassificationToCreate.isEmpty()) {
		// 	insert licenseClassificationToCreate;
		// }

	}
	**/
}