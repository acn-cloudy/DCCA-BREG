/*
 * ___________________________________________________________________________________
 * Controller for A1LicenseMassScanner lightning component
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL01312020 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 1/31/2020
 * __________________________________________________________________________________
 */
public class A1LicenseMassScannerController {
    public static final Set<String> VALID_LICENSE_STATUSES = new Set<String>{
            'C - Current, Valid & In Good Standing',
            'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
            'CR - Current/Next Renewal Paid',
            'D - Forfeited; Needs to Restore',
            'DM - Forfeited/Maintenance Requirement Due',
            'R - Valid Thru Expiration Date, Subject To Renewal',
            'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
            'Z - Current & Valid, But Subject to Disciplinary Requirement',
            'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance'
            };

    public static final String STATUS_A1 = 'A1';

    @AuraEnabled
    public static List<Map<String, String>> getStatusPickListEntries() {
        return getPickListEntries('Status__c');
    }

    @AuraEnabled
    public static List<Map<String, String>> getActiveInactivePickListEntries() {
        return getPickListEntries('ActiveInactive__c');
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
    public static ScanResult scan(List<String> licenseNumbers,
                                  Date receivedDate) {
        ScanResult result = new ScanResult();

        //find matching license records
        Map<Id, License__c> licensesMap = new Map<Id, License__c>([
                SELECT
                        Id,
                        Name,
                        Status__c,
                        LicenseType__c,
                        LicenseType__r.AbleToInactivate__c
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
        Map<Id, Application__c> existingApplicationsRnew = new Map<Id, Application__c>([
                SELECT
                        Id,
                        Name,
                        CurrentLicense__c,
                        LicenseType__c,
                        LicensePeriod__c
                FROM Application__c
                WHERE CurrentLicense__c IN :validLicenseIds
                AND (Type__c = 'RNEW - Renewal' OR Type__c = 'RSTR - Restore - No A/I Status')
                AND Status__c != 'HC - Application Completed'
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

            if (licenseTypeIdMatchedApplicationsMap != null &&
                            licenseTypeIdMatchedApplicationsMap.get(licenseTypeId) != null &&
                    !licenseTypeIdMatchedApplicationsMap.get(licenseTypeId).isEmpty()) {
                List<Application__c> apps = licenseIdApplicationRnewMap2.get(validLicenseId).get(licenseTypeId);

                for (Application__c app : apps) {
                    RenewalScanningResults__c notFound = new RenewalScanningResults__c();
                    notFound.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                    notFound.License__c = validLicenseId;
                    notFound.Status__c = 'Error';
                    notFound.Comments__c = 'Existing Renewal application found: ' + app.Name;
                    result.failed.add(notFound);
                }
            } else {
                License__c lc = licensesMap.get(validLicenseId);
                lc.GenerateRenewalApplicationA1Active__c = true;
                lc.RenewalReceivedDate__c = receivedDate;
                result.licensesToUpdate.add(lc);

                RenewalScanningResults__c successCreateApplication = new RenewalScanningResults__c();
                successCreateApplication.LicenseNumber__c = licensesMap.get(validLicenseId).Name;
                successCreateApplication.License__c = validLicenseId;
                successCreateApplication.Status__c = 'Success';
                successCreateApplication.Comments__c = 'Application will be created.';
                result.success.add(successCreateApplication);
            }
        }

        return result;
    }

    @AuraEnabled
    public static void commitScanResult(String scanResult) {
        ScanResult scanned = (ScanResult) JSON.deserialize(scanResult, ScanResult.class);

        if (!scanned.licensesToUpdate.isEmpty()) {
            update scanned.licensesToUpdate;
        }

        List<RenewalScanningResults__c> scanResultsToInsert = new List<RenewalScanningResults__c>();
        scanResultsToInsert.addAll(scanned.failed);
        scanResultsToInsert.addAll(scanned.success);

        if (!scanResultsToInsert.isEmpty()) {
            insert scanResultsToInsert;
        }
    }

    private static List<Map<String, String>> getPickListEntries(String fieldApiName) {
        List<PicklistEntry> entries = PVLScanningComponent__mdt.getSObjectType()
                .getDescribe()
                .fields
                .getMap()
                .get(fieldApiName)
                .getDescribe().getPicklistValues();

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