/*
 * ___________________________________________________________________________________
 * Class for handling InsuranceBond Trigger
 * __________________________________________________________________________________
 * PacPoint-CL03312020 - Created for
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 3/31/2020
 * __________________________________________________________________________________
 */
public with sharing class InsuranceBondService {
    public final static Map<String, Set<String>> insuranceBondSubstitutes =  new Map<String, Set<String>>{
        'BD - Bond' => new Set<String>{
            'BX - Bond Exemption (All Boards)',
            'EX - Exemption',
            'LC - Line of Credit'
        },
        'BX - Bond Exemption (All Boards)' => new Set<String>{
            'BD - Bond'
        },
        'EX - Exemption' => new Set<String>{
            'BD - Bond'
        },
        'FS - Pre-Need Funeral Service Trust' => new Set<String>{
            'BD - Bond'
        },
        'LC - Line of Credit' => new Set<String>{
            'BD - Bond'
        },
        'PI - Pre-Need Interment (Burial) Services Trust' => new Set<String>{
            'BD - Bond'
        },
        'SI - Exclusion from Workers Comp.' => new Set<String>{
            'WC - Workers Compensation'
        },
        'SL - Self-Insured for W/C (Entity OK\'d By Labor Dept)' => new Set<String>{
            'WC - Workers Compensation'
        },        
        'SM - No HI Employees - Submit Workers Comp Prior to Hiring' => new Set<String>{
            'WC - Workers Compensation'
        },     
        'SW - Workers Comp Thru Leasing Co.' => new Set<String>{
            'WC - Workers Compensation'
        },
        'T1 - Client Trust Account #1' => new Set<String>{
            'BD - Bond',
            'T2 - Client Trust Account #2',
            'T3 - Client Trust Account #3',
            'LC - Line of Credit',
            'T4 - Client Trust Account #4',
            'T5 - Client Trust Account #5'
        },
        'T2 - Client Trust Account #2' => new Set<String>{
            'T1 - Client Trust Account #1',
            'T3 - Client Trust Account #3',
            'T4 - Client Trust Account #4',
            'T5 - Client Trust Account #5',
            'EX - Exemption'
        },
        'WC - Workers Compensation' => new Set<String>{
            'SI - Exclusion from Workers Comp.',
            'SL - Self-Insured for W/C (Entity OK\'d By Labor Dept)',
            'SW - Workers Comp Thru Leasing Co.',
            'SM - No HI Employees - Submit Workers Comp Prior to Hiring'
        }
    };
    private static Set<String> insuranceBondIdSet = new Set<String>();
    public static void populateGapInInsurance(List<InsuranceBond__c> insuranceBonds) {
        Set<String> types = new Set<String>();
        Set<Id> licenseIds = new Set<Id>();

        for (InsuranceBond__c i : insuranceBonds) {
            types.add(i.Type__c);
            licenseIds.add(i.License__c);
            
            Set<String> currentSubstitutes = insuranceBondSubstitutes.get(i.Type__c);
            if(currentSubstitutes != null) types.addAll(currentSubstitutes);
        }

        List<String> continousLics = new List<String>();
        for(License__c lic : [SELECT Id FROM License__c WHERE LicenseType__r.ContinuousInsuranceRequired__c = true AND Id IN :licenseIds]){
            continousLics.add(lic.Id);
        }

        List<InsuranceBond__c> relatedInsuranceBonds = [
                SELECT
                        Id,
                        Type__c,
                        TermDate__c,
                        CancelDate__c,
                        EffectiveDate__c,
                        License__c
                FROM InsuranceBond__c
                WHERE Type__c IN :types
                AND License__c IN :continousLics
                ORDER BY CreatedDate DESC
        ];

        Map<Id, Map<String, List<InsuranceBond__c>>> relatedInsuranceBondMap =
                new Map<Id, Map<String, List<InsuranceBond__c>>>();

        for (insuranceBond__c i : relatedInsuranceBonds) {
            if (!relatedInsuranceBondMap.containsKey(i.License__c)) {
                relatedInsuranceBondMap.put(i.License__c, new Map<String, List<InsuranceBond__c>>());
            }

            if (!relatedInsuranceBondMap.get(i.License__c).containsKey(i.Type__c)) {
                relatedInsuranceBondMap.get(i.License__c).put(i.Type__c, new List<InsuranceBond__c>());
            }

            relatedInsuranceBondMap.get(i.License__c).get(i.Type__c).add(i);
        }

        if (relatedInsuranceBonds.isEmpty()) {
            return;
        }

        
        for (InsuranceBond__c i : insuranceBonds) {
            Map<String, List<InsuranceBond__c>> sameLicenseMap = relatedInsuranceBondMap.get(i.License__c);
            if(sameLicenseMap == null) continue;
            List<InsuranceBond__c> sameTypes = sameLicenseMap.get(i.Type__c);
            
            InsuranceBond__c mostRecentSameType = null;
            InsuranceBond__c mostRecentSubstituteType = null;

            //Added by Sohan 02/13/26
            for(String bondType: sameLicenseMap.keySet()){
                if(bondType != i.Type__c && sameLicenseMap.get(bondType) != null){
                    mostRecentSubstituteType = sameLicenseMap.get(bondType)[0];
                    break;
                }
            }
            //

            //Commented by Sohan 02/13/26
            /*Set<String> substitutes = insuranceBondSubstitutes.get(i.Type__c);
            if(substitutes != null){
                for(String substitute : substitutes){
                    if(sameLicenseMap.get(substitute) != null){
                        mostRecentSubstituteType = sameLicenseMap.get(substitute)[0];
                        break;
                    }
                }
            }*/
            //

            if(sameTypes != null) { 
                if (i.Id == null){  //if new record
                    mostRecentSameType = sameTypes[0];
                } else if (sameTypes[0].Id == i.Id) {   //if same record use the next one
                    if (sameTypes.size() > 1) {
                        mostRecentSameType = sameTypes[1];
                    } else {
                        mostRecentSameType = null;
                    }
                } 
            }
            
            if(mostRecentSameType == null && mostRecentSubstituteType == null) continue;
            else if(mostRecentSameType == null && mostRecentSubstituteType != null) mostRecentSameType = mostRecentSubstituteType;
            else if(mostRecentSameType != null && mostRecentSubstituteType != null && (mostRecentSameType.TermDate__c < mostRecentSubstituteType.TermDate__c || mostRecentSubstituteType.TermDate__c == null)) mostRecentSameType = mostRecentSubstituteType;

            Date termDate = mostRecentSameType.TermDate__c;
            Date cancelDate = mostRecentSameType.CancelDate__c;

            //Updated by Akanksha 05/05/26 - guard diagnostic debug statements
            //against NPE; mostRecentSubstituteType can still be null here
            //(only mostRecentSameType is guaranteed non-null past the if/else
            //chain above).
            if(mostRecentSubstituteType != null) System.debug('Most recent Sub Id '+mostRecentSubstituteType.Id);
            if(mostRecentSameType != null) System.debug('Most recent Id '+mostRecentSameType.Id);
            
            if ((termDate == null && cancelDate == null) || i.EffectiveDate__c == null) {
                continue;
            }
            
            if (termDate == null && i.EffectiveDate__c != null) {
                i.CurrentGapInInsurance__c = (Decimal)cancelDate.daysBetween(i.EffectiveDate__c);
                i.CurrentGapInInsurance__c = i.CurrentGapInInsurance__c > 0 ? i.CurrentGapInInsurance__c : null;
                continue;
            }

            if (cancelDate == null && i.EffectiveDate__c != null) {
                i.CurrentGapInInsurance__c = (Decimal) termDate.daysBetween(i.EffectiveDate__c);
                i.CurrentGapInInsurance__c = i.CurrentGapInInsurance__c > 0 ? i.CurrentGapInInsurance__c : null;
                continue;
            }

            if (cancelDate!= null && cancelDate < termDate ) {
                i.CurrentGapInInsurance__c = (Decimal)cancelDate.daysBetween(i.EffectiveDate__c);
                i.CurrentGapInInsurance__c = i.CurrentGapInInsurance__c > 0 ? i.CurrentGapInInsurance__c : null;
                continue;
            } else if(termDate != null) {
                i.CurrentGapInInsurance__c = (Decimal) termDate.daysBetween(i.EffectiveDate__c);
                i.CurrentGapInInsurance__c = i.CurrentGapInInsurance__c > 0 ? i.CurrentGapInInsurance__c : null;
            }
        }
    }

    public static void captureSubmittedInsurance(SObject so) {  
        captureSubmittedInsurance(null, so);
    }

    public static void captureSubmittedInsurance(SObject oldSo, SObject so) {
        InsuranceBond__c record = (InsuranceBond__c) so;
        if(oldSo == null 
            && (record.Status__c == 'Active' || record.Status__c == 'Waived' || record.Status__c == 'Pending')) {
            checkLicenseStatus(record);

        } else if(oldSo != null) {
            InsuranceBond__c oldRecord = (InsuranceBond__c) oldSo;
            if(record.Status__c != oldRecord.Status__c && record.Status__c == 'Active') {
                checkLicenseStatus(record);
            }
        }
    }

    public static void checkLicenseStatus(InsuranceBond__c record) {
        if(record.LicenseStatus__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due' 
             || record.LicenseStatus__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due') {
            insuranceBondIdSet.add(record.Id);
        }
    }

    public static Set<String> checkForExpiringInsuranceBond(List<InsuranceBond__c> recordsForCheck) {
        Set<String> licenseIds = (new InsuranceBondDomain(recordsForCheck)).getLicenseId2InsuranceBonds().keySet();
        
        // To check if the license has any suspension reocrds
        // Also check to make sure license doesn't hold any 
        // active suspense record(Suspense.License__c = related License 
        // that triggered this process AND (Suspense.Historical__c = false OR Suspense.Delete__c = false OR Suspense.SuspenseDueDate__c < TODAY))
        List<Suspense__c> suspenses = SuspenseSelector.getDueSuspenses(licenseIds);
        Set<String> licenseIdsWithSuspenses = (new SuspenseDomain(suspenses)).getLicenseIds();
        licenseIds.removeAll(licenseIdsWithSuspenses);


        //Run the insurance check process to make sure license holds the required insurance records that will not expire soon
        // Check to see if there is any insurance bond record that is Active/Pending/Waived & has the Ins/Bond about to expire = true
        // If there is, then loop through all insurance bond records for this license, 
        // to find another insurance record with the same insurance type & status = Active/Pending/Waived & Ins/Bond about to expire = false
        List<String> licenseIdList = new List<String>();
        licenseIdList.addAll(licenseIds);
        List<InsuranceBond__c> insuranceBonds = InsuranceBondSelector.getInsuranceBonds(licenseIdList);

        Map<String, List<InsuranceBond__c>> licenseId2InsuranceBonds = (new InsuranceBondDomain(insuranceBonds)).getLicenseId2InsuranceBonds();
        // Create a set to track licenses that need to be picked up
        // Create a set to track licenses that need to be picked up
        Set<String> licensesToPickUp = new Set<String>();

        for(String licenseId: licenseId2InsuranceBonds.keySet()) {
            List<InsuranceBond__c> insuranceBondRecords = licenseId2InsuranceBonds.get(licenseId);
            
            // Create maps to track bonds by type
            Set<String> typeHasExpiringBond = new Set<String>();
            Set<String> typeHasReplacementBond = new Set<String>();
            
            // Single loop through all bonds for this license
            for(InsuranceBond__c record : insuranceBondRecords) {
                // Only consider active/waived/pending bonds
                if(record.Status__c == 'Active' || record.Status__c == 'Waived' || record.Status__c == 'Pending') {
                    String bondType = record.Type__c;
                    
                    // Track if this type has an expiring bond
                    if(record.INSAbouttoExpire__c == true) {
                        typeHasExpiringBond.add(bondType);
                    } 
                    // Track if this type has a replacement bond
                    else {
                        typeHasReplacementBond.add(bondType);
                    }
                }
            }
            System.debug('typeHasReplacementBond:' + typeHasReplacementBond);
            System.debug('typeHasExpiringBond:' + typeHasExpiringBond);
            for(String bondType: typeHasReplacementBond) {
                typeHasExpiringBond.remove(bondType);
                Set<String> replacementTypes = insuranceBondSubstitutes.get(bondType);
                if(replacementTypes != null) {
                    for(String replacementType: replacementTypes) {
                        typeHasExpiringBond.remove(replacementType);
                    }
                }
            }
            System.debug('typeHasReplacementBond1:' + typeHasReplacementBond);
            System.debug('typeHasExpiringBond1:' + typeHasExpiringBond);
            if(typeHasExpiringBond.isEmpty()) {
                licensesToPickUp.add(licenseId);
            }
        }
        return licensesToPickUp;
    }

    public static void runLicenseChecks(List<InsuranceBond__c> records) {
        if(!insuranceBondIdSet.isEmpty()) {
            //check for the insuranceBondIdSet is 
            List<InsuranceBond__c> recordsForCheck = (new InsuranceBondDomain(records)).filterRecordsByIdSet(insuranceBondIdSet);
            Set<String> licensesToPickUp = checkForExpiringInsuranceBond(recordsForCheck);
            if(licensesToPickUp.isEmpty()) return ;
            List<License__c> licensesForUpdate = new List<License__c>();
            List<License__c> licenses = LicenseSelector.getLicensesByIdSet(licensesToPickUp);
            
            for(License__c record : licenses) {
                if(record.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due') {
                    record.Status__c = 'C - Current, Valid & In Good Standing';
                    licensesForUpdate.add(record);
                }
    
                if(record.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due') {
                    record.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal';
                    licensesForUpdate.add(record);
                }

            }

            if(!licensesForUpdate.isEmpty()) {
                update licensesForUpdate;
            }

            insuranceBondIdSet.clear();

        }
    }
    
    //Added by Akanksha 05/05/26 - ZT is a permanent state. When the
    //overnight insurance suspense job pushes a license to ZT it also
    //inactivates the bond, which would otherwise re-fire this job and
    //downgrade the license to ZI (a temporary state). The license must
    //stay in ZT, so this job is skipped for licenses already in ZT.
    @TestVisible
    private static final String ZT_LICENSE_STATUS =
        'ZT - Remain Forfeited Due To Failure To Provide Proof Of Continuous Coverage of Insurance or Bond';

    //Added by Sohan 02/02/26
    //Updated by Akanksha 05/05/26 - skip the entire bond suspense job when
    //License__c.BondWaiver__c = TRUE (licenses with a bond waiver are exempt),
    //skip when another Active "BD - Bond" record still exists on the license
    //(the current bond can flip to Inactive but the suspense job must NOT
    //run), and skip when the license is already in ZT (permanent state).
    public static void updateLicensesLikeIndSuspenseBatch(List<String> licenseIdList){
        updateLicensesLikeIndSuspenseBatch(licenseIdList, new Set<Id>());
    }

    public static void updateLicensesLikeIndSuspenseBatch(List<String> licenseIdList, Set<Id> excludedBondIdSet){
        if(licenseIdList == null || licenseIdList.isEmpty()) return;
        if(excludedBondIdSet == null) excludedBondIdSet = new Set<Id>();

        //Added by Akanksha 05/05/26 - find licenses that still have ANOTHER
        //Active "BD - Bond" record (besides the one(s) just inactivated).
        //When such a record exists, the current bond is allowed to go inactive
        //but the suspense job must NOT run for that license.
        Set<Id> licenseIdsWithAnotherActiveBond = new Set<Id>();
        for(InsuranceBond__c bond : [
            SELECT Id, License__c
            FROM InsuranceBond__c
            WHERE License__c IN :licenseIdList
                AND Type__c = 'BD - Bond'
                AND Status__c = 'Active'
                AND Id NOT IN :excludedBondIdSet
        ]){
            licenseIdsWithAnotherActiveBond.add(bond.License__c);
        }

        List<License__c> licensesQueried = LicenseSelector.getLicenses(licenseIdList);
        List<Suspense__c> suspenseRecords = new List<Suspense__c>();
        List<License__c> licensesToUpdate = new List<License__c>();
        Map<String, License__c> licensesForHistoryFlow = new Map<String, License__c>();

        for(License__c record: licensesQueried){
            //Updated by Akanksha 05/05/26 - the entire bond suspense job
            //only runs if License__c.BondWaiver__c = FALSE. The bond itself
            //still flips to Inactive (handled in InsuranceBondHandler.bulkBefore),
            //but no suspense record / status change / letter is created.
            if(record.BondWaiver__c == true) continue;

            //Updated by Akanksha 05/05/26 - if another Active "BD - Bond"
            //still exists on this license, the current bond can go Inactive
            //but the rest of the suspense job must be skipped.
            if(licenseIdsWithAnotherActiveBond.contains(record.Id)) continue;

            //Updated by Akanksha 05/05/26 - ZT is a permanent state. The bond
            //is allowed to go Inactive but the rest of the job must NOT run,
            //otherwise the license would be downgraded to the temporary ZI
            //status. The license must remain in ZT.
            if(record.Status__c == ZT_LICENSE_STATUS) continue;

            Suspense__c suspenseRec = new Suspense__c();
            suspenseRec.InsuranceType__c = 'BD - Bond';
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


            licensesForHistoryFlow.put(record.Id, record); 
            Date insExpireCancelDate = Date.today().addDays(1);
            //if(record.InsuranceBondTermDate__c != null) insExpireCancelDate = record.InsuranceBondTermDate__c.addDays(1);
            //else if(record.Insurance_Bond_Cancel_Date__c != null) insExpireCancelDate = record.Insurance_Bond_Cancel_Date__c.addDays(1);
            record.Ins_Expire_Cancel_Date__c = insExpireCancelDate;
            licensesToUpdate.add(record);
        }

        if(!suspenseRecords.isEmpty()) insert suspenseRecords;
        if(!licensesToUpdate.isEmpty()) update licensesToUpdate;
        
        
        if(!licensesForHistoryFlow.isEmpty()) {
            List<String> ids = new List<String>();
            ids.addAll(licensesForHistoryFlow.keySet());
            PVLProcess__e processUnit = new PVLProcess__e();
            processUnit.Type__c = 'CallLicenseHistoryFlow';
            processUnit.Payload__c = JSON.serialize(ids);
            EventBus.publish(processUnit);
        }
    }
    //
    
}