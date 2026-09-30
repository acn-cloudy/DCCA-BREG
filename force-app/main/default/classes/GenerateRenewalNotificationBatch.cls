global class GenerateRenewalNotificationBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
	public String pageName;
	public String query;
	public String recordId;
	public Integer index = 0;
	public String sortby;
	public List<String> notificationIds = new List<String>();
	public List<String> statusList = new List<String>();
	public String licenseTypeName;

	public Boolean isLicenseType = false;

	global GenerateRenewalNotificationBatch(String licenseId, String pageName) {
		query = 'Select Id from License__c where Id = \'' + licenseId + '\' ';
		this.pageName = pageName;
		this.recordId = licenseId;
	}
	global GenerateRenewalNotificationBatch(
		String licenseTypeId,
		Boolean isActive,
		String pageName
	) {
		this(licenseTypeId, isActive);
		this.pageName = pageName;
		this.sortby = 'address';
		this.isLicenseType = true;
	}

	global GenerateRenewalNotificationBatch(
		String licenseTypeId,
		Boolean isActive,
		String pageName,
		Boolean isAudit
	) {
		// case 00018532 make sure the privilege is only applied to the DT license type.
		if (isActive) {
			query =
				'Select Id from License__c where LicenseType__c = \'' +
				licenseTypeId +
				'\' and ActiveInactive__c != \'Inactive\' and FlaggedforAudit__c = true order by LicenseNumberFormula__c';
		} else {
			query =
				'Select Id from License__c where LicenseType__c = \'' +
				licenseTypeId +
				'\' and ActiveInactive__c = \'Inactive\' and FlaggedforAudit__c = true  order by LicenseNumberFormula__c';
		}
		this.pageName = pageName;
		this.recordId = licenseTypeId;
		this.isLicenseType = true;
	}

	global GenerateRenewalNotificationBatch(String licenseTypeId, Boolean isActive) {
		statusList.add('C - Current, Valid & In Good Standing');
		statusList.add('CM - Current, Valid & In Good Standing/Maint. Requirement Due');
		statusList.add('CR - Current/Next Renewal Paid');
		statusList.add('R - Valid Thru Expiration Date, Subject To Renewal');
		statusList.add('RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due');
		statusList.add('Z - Current & Valid, But Subject To Disciplinary Requirement');
		statusList.add('ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement');
		statusList.add('ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)');
		//query update 00021025
		//remove activeinactive__c filter

		LicenseType__c lt = [
				SELECT
						Id,
						Name,
						MethodofLicensureRenewalNotice__c,
						PrivilegeRenewalNotice__c
				FROM LicenseType__c
				WHERE Id = :licenseTypeId
		];

		String whereClause = '';
		if (lt.MethodofLicensureRenewalNotice__c != null && lt.PrivilegeRenewalNotice__c != null) {
			whereClause += ' (MethodofLicensure__c =\'' + lt.MethodofLicensureRenewalNotice__c + '\' ';
			whereClause += ' OR Privilege__c = \'' + lt.PrivilegeRenewalNotice__c + '\') ';
		}

		query = 'SELECT Id from License__c WHERE ' +
				' LicenseType__c = \'' + licenseTypeId + '\' ' +
				' AND RenewalNotificationFilter__c = true ' +
				' AND Status__c in: statusList ' +
				' AND FlaggedforAudit__c != true ';

		if (String.isNotEmpty(whereClause)) {
			query += ' AND ' + whereClause;
		}
		query += ' ORDER BY RenewalMailToCountry__c DESC, RenewalMailToZipCodeBlank__c, RenewalMailToZipCodeHI__c, ' +
				' RenewalMailToZipCodeSpecial__c, RenewalMailToZipCode__c';

		this.recordId = licenseTypeId;
		this.isLicenseType = true;
		this.licenseTypeName = lt.Name;
	}
	global DataBase.QueryLocator Start(Database.BatchableContext context) {
		return Database.getQueryLocator(query);
	}
	global void execute(Database.BatchableContext context, List<SObject> scope) {
		generateRenewalNotification();

		List<License__c> records = (List<License__c>) scope;
		List<String> recordIds = (new LicenseDomain(records)).getIds();
		String queryIds = String.join(recordIds, ',');

		Notification__c notification = new Notification__c();
		notification.Status__c = 'Completed';
		notification.Content__c = queryIds;
		notification.RecordId__c = recordId;
		insert notification;
		notificationIds.add(notification.Id);
	}

	global void finish(Database.BatchableContext context) {
		generateRenewalNotification();
		if(this.isLicenseType) {
			BatchJobFinishNotification notification = new BatchJobFinishNotification('Generate Renewal Notice In Bulk', this.licenseTypeName);
			notification.sendEmail();
		}
	}

	public void generateRenewalNotification() {
		if (notificationIds.isEmpty())
			return;
		index++;
		PageReference pageRef = new PageReference('/apex/' + pageName);
		String notificationIdStr = String.join(notificationIds, ',');
		pageRef.getParameters().put('notificationIds', notificationIdStr);
		pageRef.getParameters().put('sortby', sortby);

		Blob content;
		if (Test.isRunningTest()) {
			content = Blob.valueOf('test');
		} else {
			content = pageRef.getContent();
			// String docName = 'License Post Card(' +index + ').pdf';
			String docName = pageName + '(' + index + ').pdf';
			List<SpringCMDocument> result = SpringCMConnector.createFile(
				recordId,
				docname,
				content
			);
		}
		notificationIds.clear();
	}
}