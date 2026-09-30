@isTest
private class PVL_Pocket_ID_PDFControllerTest {
	private static testMethod void testUnit() {
		TestDataFactory.createLicense();
		List<License__c> licenses = [
			SELECT Id, FlaggedforAudit__c, TypeofEntity__c, LicenseType__c, Privilege__c
			FROM License__c
		];
		List<LicenseType__c> types = [
			SELECT Id, LicenseType__c
			FROM LicenseType__c
			WHERE id = :licenses.get(0).LicenseType__c
		];
		types.get(0).LicenseType__c = 'Test types';
		update types;
		licenses.get(0).Privilege__c = 'aac - dsdk- ds';
		licenses.get(0).TypeofEntity__c = 'I - Individual';
		update licenses;
		Test.startTest();
		PageReference myVfPage = Page.PVL_Pocket_ID_PDF;
		Test.setCurrentPage(myVfPage);

		// Put Id into the current page Parameters
		ApexPages.currentPage().getParameters().put('id', licenses.get(0).Id);
		PVL_Pocket_ID_PDFController con = new PVL_Pocket_ID_PDFController();
		con.getPriviledge();
		con.getLicenseType();
	}

	@isTest
	private static void testSetupLicense() {
		TestDataFactory.createLicense();
		List<License__c> licenses = [
			SELECT
				Id,
				FlaggedforAudit__c,
				TypeofEntity__c,
				LicenseType__c,
				Privilege__c,
				BusinessStreet__c,
				BusinessCity__c,
				BusinessState__c,
				BusinessZipCode__c,
				MailingStreet__c,
				MailingCity__c,
				MailingState__c,
				MailingZipCode__c,
				ResidenceStreet__c,
				ResidenceCity__c,
				ResidenceState__c,
				ResidenceZipCode__c,
				SoleOwner__c
			FROM License__c
		];
		licenses.get(0).BusinessStreet__c = 'test street';
		licenses.get(0).BusinessCity__c = 'Honolulu';
		licenses.get(0).BusinessState__c = 'HI';
		licenses.get(0).BusinessZipCode__c = '964632';
		update licenses;
		Test.startTest();

		ApexPages.currentPage().getParameters().put('id', licenses.get(0).Id);
		PVL_Pocket_ID_PDFController con = new PVL_Pocket_ID_PDFController();

		licenses.get(0).BusinessStreet__c = null;
		licenses.get(0).BusinessCity__c = null;
		licenses.get(0).BusinessState__c = null;
		licenses.get(0).BusinessZipCode__c = null;
		licenses.get(0).MailingStreet__c = 'test street';
		licenses.get(0).MailingCity__c = 'Honolulu';
		licenses.get(0).MailingState__c = 'HI';
		licenses.get(0).MailingZipCode__c = '964632';
		update licenses;
		con = new PVL_Pocket_ID_PDFController();
	}
}