/*
 * ___________________________________________________________________________________
 * License Mass Scanner Controller
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-CL11212019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/21/2019
 * __________________________________________________________________________________
 */

public class LicenseMassScannerController {

    public static final Set<String> VALID_LICENSE_STATUSES = new Set<String>{
            'R - Valid Thru Expiration Date, Subject To Renewal',
            'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
            'D - Forfeited; Needs to Restore',
            'DM - Forfeited/Maintenance Requirement Due'
            };

    private static Map<String, Schema.SObjectField> fieldsFieldMap;

    @AuraEnabled
    public static Map<String, List<Map<String, String>>> getPickListEntries() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        result.put('Status__c', getPickListEntries('Status__c'));
        result.put('Type__c', getPickListEntries('Type__c'));
        result.put('RenewingPermitToPractice__c', getPickListEntries('RenewingPermitToPractice__c'));
        result.put('RenewByPermitToPractice__c', getPickListEntries('RenewByPermitToPractice__c'));
        return result;
    }

    @AuraEnabled
    public static String printResult(String scanResult) {
        PageReference vfPage;
        vfPage = Page.LicenseScannerResult;
        vfPage.getParameters().put('scanResult', scanResult);

        String fileName = 'license_scan_result ' + Datetime.now().format('MM-dd-y hh-mm a') + '.pdf';
        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.PathOnClient = fileName;
        cv.Title = fileName;
        Blob versionData = Test.isRunningTest() ? Blob.valueOf('test') : vfPage.getContentAsPDF();
        cv.VersionData = versionData;
        insert cv;

        String fullFileURL = URL.getSalesforceBaseUrl().toExternalForm();
        return fullFileURL + '/sfc/servlet.shepherd/version/download/' + cv.Id;
    }

    @AuraEnabled
    public static ScanResult scanRenewalUpdate(List<String> licenseNumbers,
                                               Boolean renewInactive,
                                               String status) {
        ScanResult result = new ScanResult();

        //find matching license records
        Map<Id, License__c> licensesMap = new Map<Id, License__c>([
                SELECT
                        Id,
                        Name,
                        Status__c,
                        LicenseType__c,
                        CEisConfirmed__c,
                        ActiveInactive__c,
                        LastTaxClearanceStatus__c,
                        LicenseType__r.AbleToInactivate__c,
                        LicenseType__r.X2ndDependencyRequired__c,
                        LicenseType__r.CERequired__c,
                        LicenseType__r.RequiresInsurance__c,
                        LicenseType__r.ContinuousInsuranceRequired__c,
                        LicenseType__r.InsuranceBondTypesRequired__c,
                        LicenseType__r.TaxIDRequired__c,
                        EffectiveExpireDate__c,
                        LastTaxClearanceDate__c,
                        FlaggedforAudit__c,
                        (SELECT Id,
                                 TermDate__c,
                                 CancelDate__c,
                                 Type__c
                        FROM Insurance_Bonds__r
                        WHERE Status__c != 'Inactive')
                FROM License__c
                WHERE Name IN :licenseNumbers
                AND LicenseType__c != null
        ]);

        Map<String, License__c> licenseNumberLicenseMap = new Map<String, License__c>();
        List<Id> validLicenseIds = new List<Id>();
        Map<Id, String> licenseIdLicenseTypeIdMap = new Map<Id, String>();
        Map<Id, LicenseType__c> licenseTypeMap = new Map<Id, LicenseType__c>();
        Map<Id, Map<String, List<InsuranceBond__c>>> licenseIdInBondTypeMap =
                new Map<Id, Map<String, List<InsuranceBond__c>>>();

        for (License__c lc : licensesMap.values()) {
            licenseNumberLicenseMap.put(lc.Name, lc);

            if (!licenseTypeMap.containsKey(lc.LicenseType__c)) {
                licenseTypeMap.put(lc.LicenseType__c, lc.LicenseType__r);
            }

            for (InsuranceBond__c ins : lc.Insurance_Bonds__r) {
                if (!licenseIdInBondTypeMap.containsKey(lc.Id)) {
                    licenseIdInBondTypeMap.put(lc.Id, new Map<String, List<InsuranceBond__c>>());
                }

                if (!licenseIdInBondTypeMap.get(lc.Id).containsKey(ins.Type__c)) {
                    licenseIdInBondTypeMap.get(lc.Id).put(ins.Type__c, new List<InsuranceBond__c>());
                }

                licenseIdInBondTypeMap.get(lc.Id).get(ins.Type__c).add(ins);
            }
        }

        //filter out invalid and valid license numbers
        for (String ln : licenseNumbers) {
            if (ln == '')continue;
            if (!licenseNumberLicenseMap.containsKey(ln)) {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = ln;
                notFound.Status__c = 'Error';
                notFound.Comments__c = 'License Not Found';
                result.failed.add(notFound);

                continue;
            }

            License__c lc = licenseNumberLicenseMap.get(ln);

            if (lc.LicenseType__c != null && renewInactive && !lc.LicenseType__r.AbleToInactivate__c) {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = ln;
                notFound.Status__c = 'Error';
                notFound.Comments__c = 'License is not eligible to renew inactive';
                result.failed.add(notFound);

                continue;
            }

            if (lc.FlaggedforAudit__c &&
                    !lc.CEisConfirmed__c &&
                    status.contains('HC')) {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = ln;
                notFound.Status__c = 'Error';
                notFound.Comments__c =
                        'This License has been Flagged for Audit and the CE Has not been confirmed. Please check the "CE is Confirmed" checkbox on the License if the CE has been confirmed. If the CE has not been confirmed, the License can not be renewed.';
                result.failed.add(notFound);

                continue;
            }


            //store valid license  record Ids
            validLicenseIds.add(lc.Id);

            //store license type Ids
            licenseIdLicenseTypeIdMap.put(lc.Id, lc.LicenseType__c);
        }

        //find existing applications with Type='RNEW - Renewal'
        Map<Id, Application__c> existingApplicationsRnew = new Map<Id, Application__c>([
                SELECT
                        Id,
                        Name,
                        CurrentLicense__c,
                        CompleteApplicationBy__c,
                        LicenseType__c,
                        ActiveInactive__c,
                        ApplicationReceivedDate__c,
                        DependentLicense2__c,
                        DependentLicense2__r.ActiveInactive__c,
                        DependentLicense2__r.Status__c,
                        LicenseType__r.X2ndDependencyRequired__c,
                        LicenseType__r.RequiresInsurance__c,
                        LicenseType__r.ContinuousInsuranceRequired__c,
                        LicenseType__r.InsuranceBondTypesRequired__c,
                        LicenseType__r.TaxIDRequired__c,
                        LicenseType__r.StartofRenewalPeriod__c,
                        LicenseType__r.NextLicensePeriod__c,
                        LicenseType__r.PreviousLicensePeriod__c,
                        LicensePeriodRNEW__c,
                        ApplicationRenewingInactive__c,
                        Phase__c,
                        Status__c,
                        Type__c
                FROM Application__c
                WHERE CurrentLicense__c IN :validLicenseIds
                AND (Type__c = 'RNEW - Renewal' OR Type__c = 'RSTR - Restore - No A/I Status')
                AND Status__c != 'HC - Application Completed'
                AND LicenseType__c IN :licenseIdLicenseTypeIdMap.values()
                AND LicensePeriodRNEW__c != null
        ]);

        //store license Ids with matching Rnew - Rnewal applications grouped by LicenseId, LicenseTypId, LicensePeriod
        Map<Id, Map<Id, Map<String, List<Application__c>>>> licenseIdApplicationRnewMap =
                new Map<Id, Map<Id, Map<String, List<Application__c>>>>();

        //store license Ids with  matching Rnew - Rnewal applications grouped by LicenseId, LicenseTypId
        Map<Id, Map<Id, List<Application__c>>> licenseIdApplicationRnewMap2 =
                new Map<Id, Map<Id, List<Application__c>>>();

        for (Application__c app : existingApplicationsRnew.values()) {
            if (!licenseIdApplicationRnewMap.containsKey(app.CurrentLicense__c)) {
                licenseIdApplicationRnewMap.put(app.CurrentLicense__c, new Map<Id, Map<String, List<Application__c>>>());
            }

            if (!licenseIdApplicationRnewMap.get(app.CurrentLicense__c).containsKey(app.LicenseType__c)) {
                licenseIdApplicationRnewMap.get(app.CurrentLicense__c).put(app.LicenseType__c, new Map<String, List<Application__c>>());
            }

            if (!licenseIdApplicationRnewMap2.containsKey(app.CurrentLicense__c)) {
                licenseIdApplicationRnewMap2.put(app.CurrentLicense__c, new Map<Id, List<Application__c>>());
            }

            if (!licenseIdApplicationRnewMap2.get(app.CurrentLicense__c).containsKey(app.LicenseType__c)) {
                licenseIdApplicationRnewMap2.get(app.CurrentLicense__c).put(app.LicenseType__c, new List<Application__c>());
            }

            String licensePeriod = Date.today() < app.LicenseType__r.StartofRenewalPeriod__c ?
                    app.LicenseType__r.PreviousLicensePeriod__c : app.LicenseType__r.NextLicensePeriod__c;

            if (licensePeriod == app.LicensePeriodRNEW__c) {
                if (!licenseIdApplicationRnewMap.get(app.CurrentLicense__c).get(app.LicenseType__c).containsKey(licensePeriod)) {
                    licenseIdApplicationRnewMap.get(app.CurrentLicense__c).get(app.LicenseType__c).put(licensePeriod, new List<Application__c>());
                }

                licenseIdApplicationRnewMap.get(app.CurrentLicense__c).get(app.LicenseType__c).get(licensePeriod).add(app);
                licenseIdApplicationRnewMap2.get(app.CurrentLicense__c).get(app.LicenseType__c).add(app);
            }
        }

        for (Id validLicenseId : validLicenseIds) {
            //if license has matching application
            Id licenseTypeId = licenseIdLicenseTypeIdMap.get(validLicenseId);
            Map<Id, Map<String, List<Application__c>>> licenseTypeIdMatchedApplicationsMap =
                    licenseIdApplicationRnewMap.get(validLicenseId);

            if (licenseTypeIdMatchedApplicationsMap != null &&
                            licenseTypeIdMatchedApplicationsMap.get(licenseTypeId) != null &&
                    !licenseTypeIdMatchedApplicationsMap.get(licenseTypeId).isEmpty()) {

                Map<String, List<Application__c>> appsByLicensePeriod =
                        licenseTypeIdMatchedApplicationsMap.get(licenseTypeId);

                Boolean hasMultipleApplicationsTimePeriods = false;
                String timePeriodWithMultipleApplications;

                //Check if Multiple applications found with the same time periods
                for (String licensePeriod : appsByLicensePeriod.keySet()) {
                    if (!appsByLicensePeriod.get(licensePeriod).isEmpty() &&
                            appsByLicensePeriod.get(licensePeriod).size() > 1) {
                        hasMultipleApplicationsTimePeriods = true;
                        timePeriodWithMultipleApplications = licensePeriod;
                        break;
                    }
                }

                if (!hasMultipleApplicationsTimePeriods) {
                    List<Application__c> apps = licenseIdApplicationRnewMap2.get(validLicenseId).get(licenseTypeId);
                    Map<String, Boolean> hasAllRequiredInsuranceMap = ApplicationService.isHcRenewalValidationFail(apps);
                    for (Application__c app : apps) {
                        //Start Process check for required insurance bond
                        LicenseType__c licenseType = licenseTypeMap.get(licenseTypeId);
                        if (status.startsWith('HC') &&
                                licenseType.RequiresInsurance__c &&
                                        licenseType.InsuranceBondTypesRequired__c != null &&
                                (app.ActiveInactive__c == 'Active' || app.ActiveInactive__c == null)) {
                            License__c license = licensesMap.get(validLicenseId);
                            //Boolean hasAllRequiredInsurance = ApplicationService.isValidHcRenewal(app);
                            Boolean hasAllRequiredInsurance = hasAllRequiredInsuranceMap.get(app.Id) != null ? hasAllRequiredInsuranceMap.get(app.Id) : false;

                            if (hasAllRequiredInsurance) {
                                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                                notFound.LicenseNumber__c = license.Name;
                                notFound.Status__c = 'Error';
                                notFound.Comments__c =
                                        'This License can not renew because it does not have valid insurance one day after the end of the license period';
                                result.failed.add(notFound);
                                continue;
                            }
                        }
                        //End Process check for required insurance bond

                        /*
                         * ******
                         * // 00008826
                         * Specs
                         * =============================
                         * Apply new custom validation logic:
                         * AND( ISPICKVAL( Phase__c, 'L - License Review') || ISPICKVAL( Phase__c, 'H - License Generation'),
                         * LicenseType__r.X2ndDependencyRequired__c = true,
                         * OR( ISBLANK (DependentLicense2__c),
                         * NOT( ISPICKVAL(DependentLicense2__r.ActiveInactive__c, 'Active'))
                         * )
                         * )
                         * Display Comment::
                         * "2nd Dependency is required for the License Type. Please populate the Dependent License field on the Application. The 2nd Dependency License must be active before the Application can move to Phase L."
                         */
                        if ((app.Phase__c == 'L - License Review' || app.Phase__c == 'H - License Generation') &&
                                licenseType.X2ndDependencyRequired__c && (app.DependentLicense2__c == null ||
                                                app.DependentLicense2__r.ActiveInactive__c != 'Active' ||
                                                app.DependentLicense2__r.Status__c !=
                                                'C - Current, Valid & In Good Standing')) {
                            // condition updated for case 00008935
                            RenewalScanningResults__c errorRecord = new RenewalScanningResults__c();
                            errorRecord.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                            errorRecord.License__c = validLicenseId;
                            errorRecord.Status__c = 'Error';
                            errorRecord.Comments__c =
                                    '2nd Dependency is required for the License Type. Make sure the Dependent License 2 field is populated and that the Dependent License 2 is Active with a Status of C.';
                            result.failed.add(errorRecord);
                            continue;
                        }
                        // end


                        Date effectiveExpireDate = licensesMap.get(validLicenseId).EffectiveExpireDate__c;
                        Date lastClearanceDate = licensesMap.get(validLicenseId).LastTaxClearanceDate__c;
                        String activeInactive = licensesMap.get(validLicenseId).ActiveInactive__c;
                        if (status.startsWith('HC') &&
                                licenseType.TaxIDRequired__c &&
                                        (activeInactive == 'Active' && app.ApplicationRenewingInactive__c != true)) {
                            License__c lic = licensesMap.get(validLicenseId);
                            if (app.Type__c == 'RNEW - Renewal' &&
                                    (lastClearanceDate < effectiveExpireDate.addMonths(-6) ||
                                    lic.LastTaxClearanceStatus__c != 'Approved / Compliant')
                            ) {
                                RenewalScanningResults__c errorRecord = new RenewalScanningResults__c();
                                errorRecord.LicenseNumber__c = lic.Name;
                                errorRecord.License__c = validLicenseId;
                                errorRecord.Status__c = 'Error';
                                errorRecord.Comments__c =
                                        'A tax clearance within 6 months of the end of the renewal is required for this License.';
                                result.failed.add(errorRecord);
                                continue;
                            }

                            if (app.Type__c == 'RSTR - Restore - No A/I Status' &&
                                    (lastClearanceDate > effectiveExpireDate.addMonths(2) ||
                                            lic.LastTaxClearanceStatus__c != 'Approved / Compliant')) {
                                RenewalScanningResults__c errorRecord = new RenewalScanningResults__c();
                                errorRecord.LicenseNumber__c = lic.Name;
                                errorRecord.License__c = validLicenseId;
                                errorRecord.Status__c = 'Error';
                                errorRecord.Comments__c =
                                        'A tax clearance by the end of the restoration period is required for this License.';
                                result.failed.add(errorRecord);
                                continue;
                            }
                        }

                        if (status.startsWith('HC')) {
                            app.Phase__c = 'H - License Generation';
                        } else if (status.startsWith('E1')) {
                            app.Phase__c = 'E - Executive Officer Review';
                        } else {
                            app.Phase__c = 'A - Application Received';
                        }

                        app.Status__c = status;

                        if (renewInactive) {
                            app.ActiveInactive__c = 'Inactive';
                        }

                        result.applicationsToUpdate.add(app);

                        RenewalScanningResults__c found = new RenewalScanningResults__c();
                        found.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                        found.License__c = validLicenseId;
                        found.Status__c = 'Success';
                        found.License__r = licensesMap.get(validLicenseId);

                        if (renewInactive) {
                            found.Comments__c =
                                    'Application ' + app.Name + ' was updated to ' + status.substring(0, 2) +
                                    ' and Set to Inactive';
                        } else {
                            found.Comments__c =
                                    'Application ' + app.Name + ' was updated to ' + status.substring(0, 2);
                        }

                        result.success.add(found);
                    }
                } else {
                    List<Application__c> apps = appsByLicensePeriod.get(timePeriodWithMultipleApplications);
                    for (Application__c app : apps) {
                        RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                        notFound.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                        notFound.Status__c = 'Error';
                        notFound.Comments__c = 'Existing renewal application Found: ' + app.Name;
                        result.failed.add(notFound);
                    }
                }
            }
            //license does not have matching application
            else {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                notFound.Status__c = 'Error';
                notFound.Comments__c = 'This application does not exist. Please use the "Scan Renewals in A1" button';
                notFound.License__r = licensesMap.get(validLicenseId);
                result.failed.add(notFound);
            }
        }

        return result;
    }

    @AuraEnabled
    public static ScanResult scanCreate(List<String> licenseNumbers,
                                        Date receivedDate,
                                        String type,
                                        String renewingPermitToPractice,
                                        String renewByPermitToPractice,
                                        Boolean renewInactive) {
        ScanResult result = new ScanResult();

        //find matching license records
        Map<Id, License__c> licensesMap = new Map<Id, License__c>([
                SELECT
                        Id,
                        Name,
                        Status__c,
                        LicenseType__c,
                        ActiveInactive__c,
                        LicenseType__r.AbleToInactivate__c,
                        LicenseType__r.StartofRenewalPeriod__c
                FROM License__c
                WHERE Name IN :licenseNumbers
                AND LicenseType__c != null
        ]);

        Map<String, License__c> licenseNumberLicenseMap = new Map<String, License__c>();
        List<Id> validLicenseIds = new List<Id>();
        Map<Id, String> licenseIdLicenseTypeIdMap = new Map<Id, String>();

        for (License__c lc : licensesMap.values()) {
            licenseNumberLicenseMap.put(lc.Name, lc);
        }

        //filter out invalid and valid license numbers
        for (String ln : licenseNumbers) {
            if (ln == '')continue;
            if (!licenseNumberLicenseMap.containsKey(ln)) {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = ln;
                notFound.Status__c = 'Error';
                notFound.Comments__c = 'License Not Found';
                result.failed.add(notFound);

                continue;
            }

            License__c lc = licenseNumberLicenseMap.get(ln);
            if (!VALID_LICENSE_STATUSES.contains(lc.Status__c)) {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = ln;
                notFound.Status__c = 'Error';
                notFound.Comments__c = 'Wrong Status: ' + lc.Status__c;
                notFound.License__r = lc;
                result.failed.add(notFound);

                continue;
            }

            if (lc.LicenseType__c != null && renewInactive && !lc.LicenseType__r.AbleToInactivate__c) {
                RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                notFound.LicenseNumber__c = ln;
                notFound.Status__c = 'Error';
                notFound.Comments__c = 'License is not eligible to renew inactive';
                result.failed.add(notFound);

                continue;
            }

            //store valid license  record Ids
            validLicenseIds.add(lc.Id);

            //store license type Ids
            licenseIdLicenseTypeIdMap.put(lc.Id, lc.LicenseType__c);
        }

        //find existing applications with Type='RNEW - Renewal'
        //Type__c = 'RSTR - Restore'
        Set<String> existingApplicationsStatusFilter = new Set<String>{
                'HC - Application Completed',
                'HX - Application Invalid, Delete',
                'H8 - Application Suspense Warning'
                };

        Map<Id, Application__c> existingApplicationsRnew = new Map<Id, Application__c>([
                SELECT
                        Id,
                        Name,
                        CurrentLicense__c,
                        LicenseType__c,
                        LicensePeriod__c,
                        ApplicationReceivedDate__c
                FROM Application__c
                WHERE CurrentLicense__c IN :validLicenseIds
                AND (Type__c = 'RNEW - Renewal' OR Type__c = 'RSTR - Restore - No A/I Status')
                AND Status__c NOT IN :existingApplicationsStatusFilter
                AND (NOT Status__c LIKE '%Withdrawn%')
                AND (NOT Status__c LIKE '%Terminated%')
                AND (NOT Status__c LIKE '%Withdrawal%')
                AND LicenseType__c IN :licenseIdLicenseTypeIdMap.values()
        ]);

        //store license Ids with  matching Rnew - Rnewal applications grouped by LicenseId, LicenseTypId
        Map<Id, Map<Id, List<Application__c>>> licenseIdApplicationRnewMap2 =
                new Map<Id, Map<Id, List<Application__c>>>();

        for (Application__c app : existingApplicationsRnew.values()) {
            if (!licenseIdApplicationRnewMap2.containsKey(app.CurrentLicense__c)) {
                licenseIdApplicationRnewMap2.put(app.CurrentLicense__c, new Map<Id, List<Application__c>>());
            }

            if (!licenseIdApplicationRnewMap2.get(app.CurrentLicense__c).containsKey(app.LicenseType__c)) {
                licenseIdApplicationRnewMap2.get(app.CurrentLicense__c).put(app.LicenseType__c,
                        new List<Application__c>());
            }

            licenseIdApplicationRnewMap2.get(app.CurrentLicense__c).get(app.LicenseType__c).add(app);

        }

        for (Id validLicenseId : validLicenseIds) {
            //if license has matching application
            Id licenseTypeId = licenseIdLicenseTypeIdMap.get(validLicenseId);
            Map<Id, List<Application__c>> licenseTypeIdMatchedApplicationsMap =
                    licenseIdApplicationRnewMap2.get(validLicenseId);
            Boolean hasExistingApp = false;
            if (licenseTypeIdMatchedApplicationsMap != null &&
                            licenseTypeIdMatchedApplicationsMap.get(licenseTypeId) != null &&
                    !licenseTypeIdMatchedApplicationsMap.get(licenseTypeId).isEmpty()) {
                List<Application__c> apps = licenseIdApplicationRnewMap2.get(validLicenseId).get(licenseTypeId);

                for (Application__c app : apps) {
                    if (app.ApplicationReceivedDate__c >=
                    licensesMap.get(validLicenseId).LicenseType__r.StartofRenewalPeriod__c) {
                        RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                        notFound.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                        notFound.License__c = validLicenseId;
                        notFound.Status__c = 'Error';
                        notFound.Comments__c = 'Existing Renewal application found: ' + app.Name;
                        notFound.License__r = licensesMap.get(validLicenseId);
                        result.failed.add(notFound);
                        hasExistingApp = true;
                        break;
                    }
                }
            }

            if (!hasExistingApp) {
                License__c lc = licensesMap.get(validLicenseId);
                
                if (!renewInactive && lc.ActiveInactive__c == 'Active') {
                    lc.GenerateRenewalApplicationA1Active__c = true;
                }

                if (lc.ActiveInactive__c == 'Inactive' || renewInactive) {
                    lc.GenerateRenewalApplicationA1Inactive__c = true;
                }

                lc.RenewalReceivedDate__c = receivedDate;
                lc.ScanRenewalA1Type__c = type;
                lc.RenewingPermittoPractice__c = renewingPermitToPractice;
                lc.RenewByPermitToPractice__c = renewByPermitToPractice;
                result.licensesToUpdate.add(lc);

                RenewalScanningResults__c successCreateApplication = new RenewalScanningResults__c();
                successCreateApplication.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                successCreateApplication.License__c = validLicenseId;
                successCreateApplication.Status__c = 'Success';
                successCreateApplication.Comments__c = 'Application will be created.';
                successCreateApplication.License__r = licensesMap.get(validLicenseId);
                result.success.add(successCreateApplication);
            }
        }

        return result;
    }

    @AuraEnabled
    public static void commitScanResult(String scanResult) {
        Map<String, Object> m = (Map<String, Object>)JSON.deserializeUntyped(scanResult);
        List<Application__c> applications = new List<Application__c>();
        List<License__c> licenses = new List<License__c>();
        if (m.get('applicationsToUpdate') != null && m.get('applicationsToUpdate') != '[]') {
            PVLProcess__e process = new PVLProcess__e();
            
            applications = (List<Application__c>) JSON.deserialize(JSON.serialize(m.get('applicationsToUpdate')), List<Application__c>.class);
            process.Payload__c = JSON.serialize(applications);
            process.Type__c = 'ScanResultApplication';
            EventBus.publish(process);

        }
        if (m.get('licensesToUpdate') != null && m.get('licensesToUpdate') != '[]') {
            licenses = (List<License__c>) JSON.deserialize(JSON.serialize(m.get('licensesToUpdate')), List<License__c>.class);
        }
        if(!licenses.isEmpty()) {
            commitRecord(JSON.serialize(licenses), 'license');
        }
    }
    @future
    public static void commitRecord(String scanResult, String type) {
        if(type == 'application') {
            Application__c app = (Application__c) JSON.deserialize(scanResult, Application__c.class);
            update app;
        } else if (type == 'license') {
            List<License__c> licenses = (List<License__c>) JSON.deserialize(scanResult, List<License__c>.class);
            update licenses;
        }
    } 

    private static List<Map<String, String>> getPickListEntries(String fieldApiName) {
        if (fieldsFieldMap == null) {
            fieldsFieldMap = PVLScanningComponent__mdt.getSObjectType()
                    .getDescribe()
                    .fields
                    .getMap();
        }

        List<PicklistEntry> entries = fieldsFieldMap.get(fieldApiName)
                .getDescribe()
                .getPicklistValues();

        List<Map<String, String>> result = new List<Map<String, String>>();

        for (PicklistEntry entry : entries) {
            result.add(new Map<String, String>{
            'label' => entry.getLabel(),
            'value' => entry.getValue()
            });
        }

        return result;
    }

    public class ScanResult{
        @AuraEnabled
        public List<RenewalScanningResults__c> failed {
            get;set;
        }

        @AuraEnabled
        public List<RenewalScanningResults__c> success{
            get;set;
        }

        @AuraEnabled
        public List<Application__c> applicationsToUpdate;

        @AuraEnabled
        public List<License__c> licensesToUpdate;

        public ScanResult() {
            failed = new List<RenewalScanningResults__c>();
            success = new List<RenewalScanningResults__c>();
            applicationsToUpdate = new List<Application__c>();
            licensesToUpdate = new List<License__c>();
        }
    }
}