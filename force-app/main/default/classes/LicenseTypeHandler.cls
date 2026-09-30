/*
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Controller for the LicenseTypeHandler
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Initial implementation
 *  PacPoint-AZ011920 - Created for PVL phase 1
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * Changes
 *
 *
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
public with sharing class LicenseTypeHandler implements ITrigger {
	// Case Id 00012336
	// Reset Audit Trigger
	private static List<Id> resetAuditLTIds = new List<Id>();
	// 000014196
	private static List<Id> resetLicenseTypes = new List<Id>();

	//case 00021111
	private static Integer licenseTypeRenewalEmailBatchSize;

	//case 00035422
	private static List<Id> clearAuditLTIds = new List<Id>();

	// updated by akanksha on 29/12/2025 for case vpvl -204
	// Map to store DeficiencyNotification Id to Name mapping
	private static Map<Id, String> deficiencyNotificationNameMap = new Map<Id, String>();

	public LicenseTypeHandler() {
	}
	public void bulkBefore() {
		// updated by akanksha on 29/12/2025 for case vpvl -204
		// Collect DeficiencyNotification__c IDs that have changed or are being inserted
		Set<Id> deficiencyNotificationIds = new Set<Id>();
		
		if (Trigger.isUpdate) {
			Map<Id, LicenseType__c> oldMap = (Map<Id, LicenseType__c>) Trigger.oldMap;
			
			for (LicenseType__c newRecord : (List<LicenseType__c>) Trigger.new) {
				LicenseType__c oldRecord = oldMap.get(newRecord.Id);
				if (newRecord.DeficiencyNotification__c != oldRecord.DeficiencyNotification__c 
					&& newRecord.DeficiencyNotification__c != null) {
					deficiencyNotificationIds.add(newRecord.DeficiencyNotification__c);
				}
			}
		} else if (Trigger.isInsert) {
			for (LicenseType__c newRecord : (List<LicenseType__c>) Trigger.new) {
				if (newRecord.DeficiencyNotification__c != null) {
					deficiencyNotificationIds.add(newRecord.DeficiencyNotification__c);
				}
			}
		}
		
		// Query DocGeneratorSettings to get Name
		if (!deficiencyNotificationIds.isEmpty()) {
			List<DocGeneratorSettings__c> docSettings = [
				SELECT Id, Name 
				FROM DocGeneratorSettings__c 
				WHERE Id IN :deficiencyNotificationIds
			];
			
			for (DocGeneratorSettings__c setting : docSettings) {
				deficiencyNotificationNameMap.put(setting.Id, setting.Name);
			}
		}
	}
	public void beforeUpdate(
		List<SObject> newlstObj,
		List<SObject> oldlstObj,
		Map<Id, SObject> newMapObj,
		Map<Id, SObject> oldMapObj
	) {
	}
	public void beforeInsert(List<SObject> newlstObj) {
	}
	public void bulkAfter() {
	}
	public void beforeInsert(SObject so) {
		LicenseType__c record = (LicenseType__c) so;
		
		// updated by akanksha on 29/12/2025 for case vpvl -204
		// Set SpringCM_Deficiency_Letter__c when DeficiencyNotification__c is set on insert
		if (record.DeficiencyNotification__c != null && deficiencyNotificationNameMap.containsKey(record.DeficiencyNotification__c)) {
			record.SpringCM_Deficiency_Letter__c = deficiencyNotificationNameMap.get(record.DeficiencyNotification__c);
		}
	}
	public void afterInsert(SObject so) {
	}
	public void beforeUpdate(SObject oldSo, SObject so) {
		LicenseType__c record = (LicenseType__c) so;
		LicenseType__c oldRecord = (LicenseType__c) oldSo;

		// updated by akanksha on 29/12/2025 for case vpvl -204
		// Update SpringCM_Deficiency_Letter__c when DeficiencyNotification__c changes
		if (record.DeficiencyNotification__c != oldRecord.DeficiencyNotification__c) {
			if (record.DeficiencyNotification__c != null && deficiencyNotificationNameMap.containsKey(record.DeficiencyNotification__c)) {
				record.SpringCM_Deficiency_Letter__c = deficiencyNotificationNameMap.get(record.DeficiencyNotification__c);
			} else if (record.DeficiencyNotification__c == null) {
				// Clear SpringCM_Deficiency_Letter__c if DeficiencyNotification__c is cleared
				record.SpringCM_Deficiency_Letter__c = null;
			}
		}

		if (record.RunTaxClearanceCheck__c) {
			record.RunTaxClearanceCheck__c = false;
			Database.executeBatch(new TaxClearanceCheckBatch(record.Id), 50);
		}

		if (
			record.RunBatchUpdateToLicense__c &&
			record.RunBatchUpdateToLicense__c != oldRecord.RunBatchUpdateToLicense__c
		) {
			// Run batch.
			String fieldToUpdate = record.BatchUpdateField__c;
			String valueToUpdate = record.BatchUpdateValue__c;
			String licenseTypeId = record.Id;
			Database.executeBatch(
				new LicenseTypeBatchUpdateLicense(
					fieldToUpdate,
					valueToUpdate,
					licenseTypeId,
					record.BatchConditionField__c
				),
				40
			);
		}
		if (record.RunBatchUpdateToLicense__c) {
			record.RunBatchUpdateToLicense__c = false;
		}
		if (record.GenerateRenewalPostcards__c) {
			record.GenerateRenewalPostcards__c = false;
			if (record.PostcardContent__c != null && record.PostcardContent__c != '') {
				if (record.Name == 'DT') {
					Database.executeBatch(
						new GeneratePostCardBatch(
							record.Id,
							record.PostcardContent__c,
							' and RenewalMailToState__c = null and Privilege__c != \'A - Deep Sedation or General Anesthesia\'  and Privilege__c != \'B - Moderate Sedation\' ',
							' International'
						),
						2000
					);
					Database.executeBatch(
						new GeneratePostCardBatch(
							record.Id,
							record.PostcardContent__c,
							' and RenewalMailToState__c != null and Privilege__c != \'A - Deep Sedation or General Anesthesia\'  and Privilege__c != \'B - Moderate Sedation\' ',
							' Hawaii & Mainland'
						),
						2000
					);
				} else {
					Database.executeBatch(
						new GeneratePostCardBatch(
							record.Id,
							record.PostcardContent__c,
							' and RenewalMailToState__c = null  ',
							' International'
						),
						2000
					);
					Database.executeBatch(
						new GeneratePostCardBatch(
							record.Id,
							record.PostcardContent__c,
							' and RenewalMailToState__c != null ',
							' Hawaii & Mainland'
						),
						2000
					);
				}
			}
		}

		// 00014636
		// update 00021025
		if (record.GenerateRenewalNotice__c) {
			record.GenerateRenewalNotice__c = false;
			if (
				record.RenewalFormTemplateBulkRenewals__c != null &&
				record.RenewalFormTemplateBulkRenewals__c != ''
			) {
				Database.executeBatch(
					new GenerateRenewalNotificationBatch(
						record.Id,
						true,
						record.RenewalFormTemplateBulkRenewals__c
					),
					200
				);
			}
		}

		if (record.StarttheRenewalCycle__c) {
			record.StarttheRenewalCycle__c = false;
			Database.executeBatch(
				new LicenseTypeBatchUpdateLicense(
					'Status__c',
					'R - Valid Thru Expiration Date, Subject To Renewal',
					record.Id,
					'LicenseCStatus__c',
						true
				),
				40
			);
			Database.executeBatch(
				new LicenseTypeBatchUpdateLicense(
					'Status__c',
					'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
					record.Id,
					'LicenseCMStatus__c',
						true
				),
				40
			);
		}
		if (record.ResetLicenseType__c) {
			record.ResetLicenseType__c = false;
			resetLicenseTypes.add(record.Id);
		}
		if (record.FlagLicenseandRenewNotifications__c) {
			record.FlagLicenseandRenewNotifications__c = false;
			//Updated by Sohan 09/29/2025
			//Database.executeBatch(new BatchFlagLicenseBeforeAudit(record.Id, true), 200); 

			Set<String> auditStatusSet = null;
			Set<String> auditActiveInactiveSet = null;
			if(record.AuditStatuses__c != null){
				auditStatusSet = new Set<String>();
				auditStatusSet.addAll(record.AuditStatuses__c.split(';'));
			}
			if(record.AuditActiveInactive__c != null){
				auditActiveInactiveSet = new Set<String>();
				auditActiveInactiveSet.addAll(record.AuditActiveInactive__c.split(';'));
			}
			if(auditStatusSet != null || auditActiveInactiveSet != null){
				Database.executeBatch(new BatchFlagLicenseBeforeAudit(record.Id, true, auditStatusSet, auditActiveInactiveSet), 200); 
			}
			else{
				Database.executeBatch(new BatchFlagLicenseBeforeAudit(record.Id, true), 200); 
			}
			//
		}

		if (!oldRecord.SendRenewalEmailforallLicenses__c && record.SendRenewalEmailforallLicenses__c) {
			record.SendRenewalEmailforallLicenses__c = false;
			if (licenseTypeRenewalEmailBatchSize == null) {
				LicenseTypeSetting__mdt licenseTypeSetting = [
						SELECT
								Id,
								Value__c
						FROM LicenseTypeSetting__mdt
						WHERE DeveloperName = 'RenewalEmailBatchSize'
				];
				licenseTypeRenewalEmailBatchSize = Integer.valueOf(licenseTypeSetting.Value__c);
			}

			Database.executeBatch(new LicenseTypeRenewalEmailSender(record.Id, record.RenewalReminderEmailTemplate__c), licenseTypeRenewalEmailBatchSize);
		}
	}
	public void beforeUnDelete(SObject so) {
	}
	public void afterUpdate(SObject oldSo, SObject so) {
		LicenseType__c record = (LicenseType__c) so;
		LicenseType__c oldRecord = (LicenseType__c) oldSo;
		if (record.ResetAudit__c && record.ResetAudit__c != oldRecord.ResetAudit__c) {
			resetAuditLTIds.add(record.Id);
		}

		if(record.ClearAuditInformation__c && record.ClearAuditInformation__c != oldRecord.ClearAuditInformation__c){
			clearAuditLTIds.add(record.Id);
		}
	}
	public void beforeDelete(SObject so) {
	}
	public void afterDelete(SObject so) {
	}
	public void afterUnDelete(SObject so) {
	}
	public void andFinally() {
		if (Trigger.isAfter != null && Trigger.isAfter && !resetAuditLTIds.isEmpty()) {
			Database.executeBatch(new BatchLicenseResetAudit(resetAuditLTIds), 50);
			resetAuditLTIds.clear();
		}

		if (Trigger.isAfter != null && Trigger.isAfter && !clearAuditLTIds.isEmpty()) {
			Database.executeBatch(new ClearAuditInformation(clearAuditLTIds), 50);
			clearAuditLTIds.clear();
		}

		if (Trigger.isBefore != null && Trigger.isBefore && !resetLicenseTypes.isEmpty()) {
			Database.executeBatch(new LicenseTypeExpire(resetLicenseTypes), 50);
			resetLicenseTypes.clear();
		}
	}
}