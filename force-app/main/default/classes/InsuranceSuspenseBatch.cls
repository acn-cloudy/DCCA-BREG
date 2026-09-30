/*
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  We need to create a batch job that runs at 2am every morning that looks at all the Licenses with a
 *  Current and Active Status and checks to see if they meet the required Insurance/Bond from the License Type.
 *  If the License does not meet the criteria, salesforce will create a suspense record.
 *  We also need to create a button on the PVL homepage called "Run Insurance Suspense Job" that will fire this batch job
 *  Covered by LicenseUpdateStatusTest
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Initial implementation
 *  @created      PacPoint-AZ081320 - Created for PVL case 00009176
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 *  Changes       PacPoint-AZ033122 - Updated for PVL case 00028166
 *  ─────────────────────────────────────────────────────────────────────────────────────────────────
 */
global class InsuranceSuspenseBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private List<String> licenseIdCheck;
    public final Set<String> statusToCheckSet = new Set<String>{
            'C - Current, Valid & In Good Standing',
            'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            'R - Valid Thru Expiration Date, Subject To Renewal',
            'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due'
            };
    public final Set<String> statusC = new Set<String>{
            'D - Forfeited; Needs to Restore',
            'DM - Forfeited/Maintenance Requirement Due'
            };

    global String query = 'SELECT Id, ' +
                            'InsuranceBondLossDuringRenewal__c, ' +
                            'ExcludefromHistoryProcessing__c, ' +
                            'EffectiveExpireDate__c, ' +
                            'CancelDate__c, ' +
                            'Privilege__c, ' +
                            'HistoryTransactionType__c, ' +
                            'Ins_Expire_Cancel_Date__c, ' +
                            'InsuranceBondTermDate__c, ' +
                            'Insurance_Bond_Cancel_Date__c, ' +
                            'DependentLicense__r.CancelDate__c, ' +
                            'GenerateRMELosesEntityNotification__c, ' +
                            'LicenseType__r.StatusDuetoRequiredINSInactive__c, ' +
                            'LicenseType__r.NumberOfDaysUntilInsAutoForfeiture__c, ' +
                            'LicenseType__r.NumberOfDaysUntilAutoForfeiture__c, ' +
                            'GenerateLossOfINSBondNotification__c, Status__c, ' +
                            'LicenseType__r.InsuranceBondTypesRequired__c, ' +
                            'LicenseType__r.StatusDueToLossOfInsurance__c, ' +
                            'LicenseType__r.LicenseTypeEffectiveDate__c, ' +
                            'LicenseType__r.BreakinInsuranceCoverageAllowed__c, ' +
                            'LicenseType__r.NextLicensePeriodExpireDate__c ' +
                            'FROM License__c ' +
                            'WHERE (Status__c IN :statusC OR Status__c IN :statusToCheckSet) ' +
                            'AND ActiveInactive__c =\'Active\' ' +
                            'AND LicenseType__r.RequiresInsurance__c = true';

    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        licenseIdCheck = new List<String>();
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        Map<String, License__c> licensesForHistoryFlow = new Map<String, License__c>();

        List<License__c> records = (List<License__c>) scope;
        Map<String, License__c> licenseMap = new Map<String, License__c>(records);
        List<String> licenseIds = (new LicenseDomain(records)).getIds();
        List<InsuranceBond__c> insuranceBonds = InsuranceBondSelector.getInsuranceBonds(licenseIds);
        Map<String, List<InsuranceBond__c>> insuranceBondsMap = (new InsuranceBondDomain(insuranceBonds)).getLicenseId2InsuranceBonds();
        Map<String, Set<String>> recordsForCheck = new Map<String, Set<String>>();
        List<String> licenseIdsForSuspense = new List<String>();

        Map<String, License__c> licenseRecords = new Map<String, License__c>();

        for (License__c record : records) {
            String insuranceBondTypeRequired = record.LicenseType__r.InsuranceBondTypesRequired__c;
            List<String> requiredInsuranceBondsTypes = new List<String>();
            List<InsuranceBond__c> insuranceBondRecords = insuranceBondsMap.get(record.Id);
            if (insuranceBondRecords == null) {
                insuranceBondRecords = new List<InsuranceBond__c>();
            }

            if (insuranceBondTypeRequired != null) {
                Set<String> missingRequiredTypes = (new InsuranceBondDomain(insuranceBondRecords)).getMissingRequiredTypes(record);

                requiredInsuranceBondsTypes = insuranceBondTypeRequired.split(';');
                Set<String> requiredTypeSet = new Set<String>();
                requiredTypeSet.addAll(requiredInsuranceBondsTypes);

                for(String type: requiredInsuranceBondsTypes) {
                    if(InsuranceBondService.insuranceBondSubstitutes.containsKey(type)) {
                        requiredTypeSet.addAll(InsuranceBondService.insuranceBondSubstitutes.get(type));
                    }
                }

                List<InsuranceBond__c> filteredRecords = (new InsuranceBondDomain(insuranceBondRecords)).filterInsuranceBonds(record, requiredTypeSet);

                System.debug('#####missingRequiredTypes#####' + missingRequiredTypes);

                if (!missingRequiredTypes.isEmpty()) {
                    // No
                    recordsForCheck.put(record.Id, missingRequiredTypes);
                    licenseIdsForSuspense.add(record.Id);
                }else {
                    // Yes
                    // Uncheck License.InsuranceBondLossDuringRenewal__c
                    // if record status = D, DM, R, RM go next, otherwise, it will
                    if (statusC.contains(record.Status__c)) {
                        Map<String, Set<String>> pendingTypeInsuranceBondIdMap = new Map<String, Set<String>>(); 
                        for (insuranceBond__c ib : filteredRecords) {
                            if (ib.Status__c == 'Pending') {
                                if (!pendingTypeInsuranceBondIdMap.containsKey(ib.Type__c)) {
                                    pendingTypeInsuranceBondIdMap.put(ib.Type__c, new Set<String>());
                                }
                                pendingTypeInsuranceBondIdMap.get(ib.Type__c).add(ib.Id);
                            }
                        }

                        for (InsuranceBond__c bondRecord : filteredRecords) {
                            // Is License.InsuranceBond.TermDate OR License.InsuranceBondCancelDate <= License.EffectiveExpireDate__c
                            // Check checkbox InsuranceBondLossDuringRenewal__c
                            if ((bondRecord.CancelDate__c != null && bondRecord.CancelDate__c <= record.EffectiveExpireDate__c) && !pendingTypeInsuranceBondIdMap.containsKey(bondRecord.Type__c)) {
                                record.InsuranceBondLossDuringRenewal__c = true;
                                licenseRecords.put(record.Id, record);
                            }
                            if ((bondRecord.TermDate__c != null && bondRecord.TermDate__c <= record.EffectiveExpireDate__c) && !pendingTypeInsuranceBondIdMap.containsKey(bondRecord.Type__c)) {
                                record.InsuranceBondLossDuringRenewal__c = true;
                                licenseRecords.put(record.Id, record);
                            }
                        }
                    }

                    if (!licenseRecords.containsKey(record.Id) && record.InsuranceBondLossDuringRenewal__c) {
                        record.InsuranceBondLossDuringRenewal__c = false;
                        licenseRecords.put(record.Id, record);
                    }
                }
            }
        }

        List<Suspense__c> suspenseRecords = new List<Suspense__c>();
        List<License__c> licensesForUpdate = new List<License__c>();
        Set<String> licenseIdSet = new Set<String>();
        
        if (!recordsForCheck.isEmpty()) {
            // IS there a valid Insurance Bond record that meets the criteria?
            // No
            //Check InsuranceBondLossDuringRenewal__c checkbox
            for (String recordId : recordsForCheck.KeySet()) {
                License__c record = licenseMap.get(recordId);
                record.InsuranceBondLossDuringRenewal__c = true;
                licenseRecords.put(record.Id, record);
            }

            List<Suspense__c> suspenses = SuspenseSelector.getSuspenseByIds(
                    licenseIdsForSuspense
            );
            Map<String, Set<String>> insuranceBondsTypes = (new SuspenseDomain(suspenses)).getLicenseId2InsuranceBondsTypes();


            if (insuranceBondsTypes == null)
                insuranceBondsTypes = new Map<String, Set<String>>();
            for (String licenseId : licenseIdsForSuspense) {
                Set<String> missingInsuranceBondTypes = recordsForCheck.get(licenseId);
                Set<String> existingInsuranceBondTypes = insuranceBondsTypes.get(
                        licenseId
                );

                if (existingInsuranceBondTypes == null)
                    existingInsuranceBondTypes = new Set<String>();
                for (String insuranceBondType : existingInsuranceBondTypes) {
                    missingInsuranceBondTypes.remove(insuranceBondType);
                }

                if (!missingInsuranceBondTypes.isEmpty()) {
                    License__c record = licenseMap.get(licenseId);
                    if (licenseRecords.containsKey(record.Id)) {
                        record = licenseRecords.get(licenseId);
                    }
                    // if record status = D, DM, R, RM go next, otherwise, it will skip
                    if (statusC.contains(record.Status__c)) {
                        continue;
                    }

                    // Create Suspense record
                    for (String insuranceType : missingInsuranceBondTypes) {
                        Suspense__c suspenseRec = new Suspense__c();
                        suspenseRec.InsuranceType__c = insuranceType;
                        suspenseRec.License__c = record.Id;
                        Decimal days = record.LicenseType__r.NumberOfDaysUntilInsAutoForfeiture__c;
                        if (days == null)
                            days = 0;
                        suspenseRec.SuspenseDueDate__c = System.today()
                                .addDays(Integer.valueOf(days));
                        suspenseRec.SuspenseStatus__c = record.LicenseType__r.StatusDueToLossOfInsurance__c;
                        suspenseRecords.add(suspenseRec);
                        record.ExcludefromHistoryProcessing__c = true;
                        
                        record.GenerateLossOfINSBondNotification__c = true;
                        record.Status__c = record.LicenseType__r.StatusDuetoRequiredINSInactive__c;


                        licensesForHistoryFlow.put(record.Id, record); //case 00026144
                        //00028332 Set Ins Cancel/Term Date
                        Date insExpireCancelDate = Date.today().addDays(1);
                        if(record.InsuranceBondTermDate__c != null) insExpireCancelDate = record.InsuranceBondTermDate__c.addDays(1);
                        else if(record.Insurance_Bond_Cancel_Date__c != null) insExpireCancelDate = record.Insurance_Bond_Cancel_Date__c.addDays(1);
                        record.Ins_Expire_Cancel_Date__c = insExpireCancelDate;
                        // end

                        if (!licenseIdSet.contains(record.Id)) {
                            licenseRecords.put(record.Id, record);
                            licenseIdSet.add(record.Id);
                        }
                    }
                }
            }
        }
        if(!suspenseRecords.isEmpty()) insert suspenseRecords;
        if(!licenseRecords.isEmpty()) update licenseRecords.values();


        //case 00026144
        if(!licensesForHistoryFlow.isEmpty()) {
            List<String> ids = new List<String>();
            ids.addAll(licensesForHistoryFlow.keySet());
            PVLProcess__e processUnit = new PVLProcess__e();
            processUnit.Type__c = 'CallLicenseHistoryFlow';
            processUnit.Payload__c = JSON.serialize(ids);
            EventBus.publish(processUnit);

            licenseIdCheck.addAll(ids);
        }
    }

    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new InsuranceSuspenseBatch(), 100);
    }
    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {
        // kick off another session for associated licenses:
        Database.executeBatch(new AssociatedInsuranceSuspenseBatch(licenseIdCheck), 50);
    }
}