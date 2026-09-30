public without sharing class PVL_Pocket_ID_PDFController {
	// defination
	public Id licenseId { get; set; }
	public License__c lic { get; set; }
	public String street { get; set; }
	public String postcode { get; set; }
	public String state { get; set; }
	public String city { get; set; }

	public String getLicenseType() {
		if (lic != null && lic.LicenseType__r.LicenseType__c != null) {
			return lic.LicenseType__r.LicenseType__c.toUpperCase()
				.replace('- ENTITY', '')
				.replace('- SOLE PROPRIETOR', '')
				.replace('- RESPONSIBLE MANAGING EMPLOYEE', '');
		}
		return '';
	}
	public String getPriviledge() {
		if (lic != null && lic.Privilege__c != null) {
			String privilege = lic.Privilege__c.split('-').size() > 1
				? lic.Privilege__c.split('-')[1]
				: lic.Privilege__c;
			return privilege.toUpperCase();
		}
		return '';
	}
	//construction
	public PVL_Pocket_ID_PDFController() {
		licenseId = apexpages.currentpage().getparameters().get('id');
		lic = [
			SELECT
				Id,
				Name,
				LicenseeNameFormula__c,
				RenewalMailToStreet__c,
				Privilege__c,
				RenewalMailToCity__c,
				RenewalMailToState__c,
				RenewalMailToZipCode__c,
				LicenseType__r.LicenseType__c,
				PocketIDLicenseNumber__c,
				EffectiveExpireDate__c,
				LicenseType__r.EligibleforClassifications__c,
				LicenseType__r.LicensePrefix__c,
				ActiveInactiveFormula__c,
				TypeofEntity__c, //= "I - Individual" AND License__c.
				SoleOwner__c,
				PocketIDClassVerbiage__c,
				LicenseName__c,
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
				(
					SELECT Id, Name, Classification__r.Name
					FROM LicenseClassifications__r
					WHERE Status__c = 'C - Current, Valid & In Good Standing'
				)
			FROM License__c
			WHERE id = :licenseId
		];
		setupAddress(lic);
	}
	public void setupAddress(License__c lic) {
		if (lic.TypeofEntity__c == 'I - Individual' && !lic.SoleOwner__c) {
			street = lic.RenewalMailToStreet__c;
			city = lic.RenewalMailToCity__c;
			state = lic.RenewalMailToState__c;
			postcode = lic.RenewalMailToZipCode__c;
		} else if (lic.BusinessStreet__c != null) {
			street = lic.BusinessStreet__c;
			city = lic.BusinessCity__c;
			state = lic.BusinessState__c;
			postcode = lic.BusinessZipCode__c;
		} else if (lic.MailingStreet__c != null) {
			street = lic.MailingStreet__c;
			city = lic.MailingCity__c;
			state = lic.MailingState__c;
			postcode = lic.MailingZipCode__c;
		} else if (lic.ResidenceStreet__c != null && lic.SoleOwner__c) {
			street = lic.ResidenceStreet__c;
			city = lic.ResidenceCity__c;
			state = lic.ResidenceState__c;
			postcode = lic.ResidenceZipCode__c;
		}
	}
}