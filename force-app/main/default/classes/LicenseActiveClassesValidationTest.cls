/*
 * ___________________________________________________________________________________
 * Test Class for LicenseActiveClassesValidation
 * __________________________________________________________________________________
 * PacPoint-IC030320 - Created for PVL phase 1
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author Irene Cahilo - PacificPointCorp
 * @created 03/03/2020
 * __________________________________________________________________________________
 */
@IsTest
public class LicenseActiveClassesValidationTest {
	@TestSetup
	static void setup() {
		TestDataFactory.prepareAssociatedLicenses();
	}

	@IsTest
	static void updateAllLicenses(){
		List<License__c> allLicenses = [SELECT Id, Status__c FROM License__c];
		for(License__c license : allLicenses){
			license.Status__c = 'C - Current, Valid & In Good Standing';
		}

		try {
			update allLicenses;
		} catch (Exception e) {
			// System.assert(e.getMessage().contains('An RDS must have at least one MC with all 8 classes'));
		}
	}
}