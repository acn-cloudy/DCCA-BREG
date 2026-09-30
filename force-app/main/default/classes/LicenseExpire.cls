/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  checkLicenseStatus : Find and set the status of Licenses with License Types Start of RenewalPerios = Today
 *  Covered by LicenseUpdateStatusTest
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @author       Chris Zhuang - PacificPointCorp
 *  @created      PacPoint-CZ082619 - Created for PVL Phase 1
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes
 * @modifiedBy Chris L 07/28/2021 Case 00015491
 * @modifiedBy Takashi K 01/16/2023 Case 00027124
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class LicenseExpire implements schedulable, Database.Batchable<SObject>, Database.Stateful {
	/*
	 * variables
	 */
	public final static String transactionType = 'DELQ - DELINQUENT';
	public final static String remarks = 'License was Forfeited.';
	private Map<Id, Date> associateLicense2ExpireDate = new Map<Id, Date>();
	final static Set<String> statusToCheckSet = new Set<String>{
		'C - Current, Valid & In Good Standing',
		'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
		'R - Valid Thru Expiration Date, Subject To Renewal',
		'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due'
	};

	private List<Id> entityIds = new List<Id>();

	public String query;

	global LicenseExpire() {
		query =
			'SELECT Id, ' +
			'Status__c, ' +
			'LicenseType__c,' +
			'NonRenewalDate__c, ' +
			'ForfeitureDate__c, ' +
			'RestorationDeadline__c, ' +
			'LicenseType__r.ClassStatusDuetoLossof_Dependent__c, ' +
			'EffectiveExpireDate__c, ' +
			'LicenseType__r.DurationofRestorationInMonths__c, ' +
			'LicenseType__r.StatusDuetoNonRenewal__c, ' +
			'LicenseType__r.ClassStatusDueToNonRenewal__c, ' +
			'LicenseType__r.Entity__c, ' +
			'LicenseType__r.StatusDuetoLossofDependent__c, ' +
			'LicenseType__r.NextLicensePeriod__c ' +
			'FROM License__c WHERE (Status__c = \'R - Valid Thru Expiration Date, Subject To Renewal\' ' +
			'OR Status__c =  \'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due\' ' +
			'OR Status__c = \'Z1 - Susp Due To 1)Loss Of Bond By Licensee And/Or Dependent Or 2)Loss of RME, If Def Not Cured by Renewal, Must Re-Apply\' ' +
			'OR Status__c = \'Z - Current & Valid, But Subject To Disciplinary Requirement\' ' +
			'OR Status__c = \'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement\') ' +
			'AND EffectiveExpireDate__c < Today ';
	}
	/*
	 * batch start class
	 */
	global DataBase.QueryLocator Start(Database.BatchableContext context) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext context, List<SObject> scope) {
		List<License__c> records = (List<License__c>) scope;
		// Get String List for
		List<String> licenseIds = (new LicenseDomain(records)).getIds();
		List<Application__c> applications = ApplicationSelector.getApplicationsForRenew(licenseIds);
		List<Application__c> applicationsForFilter = (new ApplicationDomain(applications))
			.filterApplicationsByRenewalDate();
		List<String> currentLicenseIdsForExclude = (List<String>) (new ApplicationDomain(
				applicationsForFilter
			))
			.getFieldValues('CurrentLicense__c');
		Set<String> licenseIdSetForExclude = new Set<String>(currentLicenseIdsForExclude);
		List<License__c> recordsForUpdate = (new LicenseDomain(records))
			.filteroutLicenseFromSet(licenseIdSetForExclude);
		List<String> rIds = (new LicenseDomain(recordsForUpdate)).getIds();
		// Map<Id, String> entityLicenseIdStatusMap = new Map<Id, String>();
		for (License__c lc : recordsForUpdate) {

			if (lc.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal') {
				lc.Status__c = 'D - Forfeited; Needs to Restore';
			}

			if (lc.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due') {
				lc.Status__c = 'DM - Forfeited/Maintenance Requirement Due';
			}

			if (
				lc.Status__c ==
				'Z1 - Susp Due To 1)Loss Of Bond By Licensee And/Or Dependent Or 2)Loss of RME, If Def Not Cured by Renewal, Must Re-Apply'
			) {
				lc.Status__c = 'DM - Forfeited/Maintenance Requirement Due';
			}

			if (
				lc.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement' ||
				lc.Status__c ==
				'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement'
			) {
				lc.Status__c = 'ZD - Forfeited Disciplined License; Needs To Restore';
				lc.CancelDate__c = Date.today();
			}

			lc.NonRenewalDate__c = lc.EffectiveExpireDate__c;
			lc.ForfeitureDate__c = lc.EffectiveExpireDate__c;

			Date effectiveDate = lc.EffectiveExpireDate__c;
			Integer months = Integer.valueOf(lc.LicenseType__r.DurationofRestorationInMonths__c);
			if (months != null) {
				lc.RestorationDeadline__c = effectiveDate.addMonths(months);
			}
		}

		
		List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getAssociatedLicenses(
			rIds
		);
		List<AssociatedLicense__c> employeeAssociatedLicenses = AssociatedLicenseSelector.getAssociatedEmployeeLicenses(
			rIds
		);
		for (AssociatedLicense__c associatedLicense : associatedLicenses) {
			if (associatedLicense.EmploymentStatus__c == 'Employed') {
				associateLicense2ExpireDate.put(
					associatedLicense.Id,
					associatedLicense.EntityLicense__r.EffectiveExpireDate__c
				);
			}
		}
		for (AssociatedLicense__c associatedLicense : employeeAssociatedLicenses) {
			if (associatedLicense.EmploymentStatus__c == 'Employed') {
				associateLicense2ExpireDate.put(
					associatedLicense.Id,
					associatedLicense.EmployeeLicense__r.EffectiveExpireDate__c
				);
			}
		}

		if (!recordsForUpdate.isEmpty()) {
			update recordsForUpdate;
		}
		// 00007322
		// query the licenseclassifications;
		List<String> updatedLicenseIds = (new LicenseDomain(recordsForUpdate)).getIds();
		List<LicenseClassification__c> licenseClassifications = LicenseClassificationSelector.getLicenseClassifications(
			updatedLicenseIds
		);
		Map<String, License__c> recordMap = new Map<String, License__c>(recordsForUpdate);
		(new LicenseClassificationDomain(licenseClassifications))
			.updateStatusBasedOnLicenseType(recordMap);
		if (!licenseClassifications.isEmpty()) {
			update licenseClassifications;
		}
		List<PVLProcess__e> processes = new List<PVLProcess__e>();
		// if (!associateLicense2ExpireDate.isEmpty()) {
		// 	PVLProcess__e tALProcess = new PVLProcess__e();
		// 	tALProcess.Type__c = 'Terminate Associated License';
		// 	tALProcess.Payload__c = JSON.serialize(associateLicense2ExpireDate);
		// 	processes.add(tALProcess);
		// }
		if(!recordsForUpdate.isEmpty() ) {
			PVLProcess__e ibProcess = new PVLProcess__e();
			ibProcess.Type__c = 'Terminate Insurance Bonds';
			ibProcess.Payload__c = JSON.serialize(updatedLicenseIds);
			processes.add(ibProcess);

		}

		if (!processes.isEMpty()) {
			EventBus.publish(processes);
		}

		// Case 27124
		if(!recordsForUpdate.isEmpty() ) {
			List<LicenseHistory__c> licenseHistories = new List<LicenseHistory__c>();			

			for (License__c lc : recordsForUpdate) {
				LicenseHistory__c licenseHistory = new LicenseHistory__c();
				licenseHistory.License__c = lc.ID;
				licenseHistory.TransactionType__c = transactionType;
				licenseHistory.EffectiveDate__c = lc.EffectiveExpireDate__c + 1;
				licenseHistory.LicensePeriod__c = lc.LicenseType__r.NextLicensePeriod__c;
				licenseHistory.Remarks__c = remarks;
				licenseHistories.add(licenseHistory);
			}

			insert licenseHistories;

		}
	}

	public void execute(System.SchedulableContext context) {
		Database.executeBatch(new LicenseExpire(), 100);
	}
	/*
	 * batch finish class
	 */
	global void finish(Database.BatchableContext context) {
		Database.executeBatch(new AssociatedLicenseExpire(associateLicense2ExpireDate), 50);
		// if(!employeeLicenseIdStatusMap.isEmpty()) {
		//    Database.executeBatch(new EmployeeLicenseStatus(employeeLicenseIdStatusMap), 100);
		// }
		// if(!entityIds.isEmpty()) {
		//     Database.executeBatch(new AssociatedLicensesStatusUpdate(entityIds), 100);
		// }
	}
}