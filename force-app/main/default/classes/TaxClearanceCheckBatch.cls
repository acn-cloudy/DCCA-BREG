/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: TaxClearanceCheckBatchTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL08209022 - Created for case 00023037
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 08/09/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class TaxClearanceCheckBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts{

    private String licenseTypeId;

    private String query;

    private static Set<String> licenseStatusFilter = new Set<String>{
            'C - Current, Valid & In Good Standing',
            'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
            'R - Valid Thru Expiration Date, Subject To Renewal',
            'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
            'Z - Current & Valid, But Subject To Disciplinary Requirement',
            'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement',
            'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)'
            };

    public TaxClearanceCheckBatch(String parentLicenseTypeId) {
        licenseTypeId = parentLicenseTypeId;
        query = 'SELECT Id, ' +
                'LicenseeNameFormula__c, ' +
                'Licensee__r.BPID__c, ' +
                'Licensee__r.FEIN__c, ' +
                'Licensee__r.StateExciseTaxNumber__c ' +
                'FROM License__c ' +
                'WHERE LicenseType__c = :licenseTypeId ' +
                'AND Status__c IN :licenseStatusFilter ' +
                'AND LastTaxClearanceStatus__c != \'Approved / Compliant\' '+
                'AND ActiveInactive__c = \'Active\'';
    }

    public void execute(Database.BatchableContext bc, List<SObject> sObjects) {
        List<License__c> licenses = (List<License__c>) sObjects;

        TaxClearanceApiHelper.TaxClearanceResponse apiResponse = TaxClearanceApiHelper.runClearance(licenses);
        Map<String, TaxClearanceApiHelper.TaxClearanceResultResult> foundSsnsResultMap = new Map<String, TaxClearanceApiHelper.TaxClearanceResultResult>();
        Map<String, TaxClearanceApiHelper.TaxClearanceResultResult> foundFeinsResultMap = new Map<String, TaxClearanceApiHelper.TaxClearanceResultResult>();
        Map<String, TaxClearanceApiHelper.TaxClearanceResultResult> foundTaxIdsResultMap = new Map<String, TaxClearanceApiHelper.TaxClearanceResultResult>();

        if (apiResponse.ssns != null && !apiResponse.ssns.isEmpty()) {
            foundSsnsResultMap.putAll(mapResults(apiResponse.ssns));
        }

        if (apiResponse.feins != null && !apiResponse.feins.isEmpty()) {
            foundFeinsResultMap.putAll(mapResults(apiResponse.feins));
        }

        if (apiResponse.tax_ids != null && !apiResponse.tax_ids.isEmpty()) {
            foundTaxIdsResultMap.putAll(mapResults(apiResponse.tax_ids));
        }

        for (License__c l : licenses) {
            String bpId = l.Licensee__r.BPID__c;
            String fein = l.Licensee__r.FEIN__c;
            String taxId = l.Licensee__r.StateExciseTaxNumber__c;
            Boolean dFound = false;

            if (bpId != null && foundSsnsResultMap.containsKey(bpId)) {
                TaxClearanceApiHelper.TaxClearanceResultResult r = foundSsnsResultMap.get(bpId);
                if (r.status_code == 'Y') {
                    doYUpdate(l, r);
                    continue;
                } else if (r.status_code == 'D') {
                    dFound = true;
                }
            }

            if (fein != null && foundFeinsResultMap.containsKey(fein)) {
                TaxClearanceApiHelper.TaxClearanceResultResult r = foundFeinsResultMap.get(fein);
                if (r.status_code == 'Y') {
                    doYUpdate(l, r);
                    continue;
                } else if (r.status_code == 'D' && !dFound) {
                    dFound = true;
                }
            }

            if (taxId != null && foundTaxIdsResultMap.containsKey(taxId)) {
                TaxClearanceApiHelper.TaxClearanceResultResult r = foundTaxIdsResultMap.get(taxId);
                if (r.status_code == 'Y') {
                    doYUpdate(l, r);
                    continue;
                } else if (r.status_code == 'D' && !dFound) {
                    dFound = true;
                }
            }

            if (dFound) {
                l.LastTaxClearanceStatus__c = 'Denied / Not Compliant';
            } else {
                l.LastTaxClearanceStatus__c = 'Tax Id was not found on record with DOTAX';
            }
        }

        update licenses;
    }

    private void doYUpdate(License__c license, TaxClearanceApiHelper.TaxClearanceResultResult result) {
        String effectiveFrom = result.effective_from;
        List<String> splitDate = effectiveFrom.split('/');
        Date effectiveFromDate = Date.newInstance(Integer.valueOf(splitDate[2]),
                Integer.valueOf(splitDate[0]),
                Integer.valueOf(splitDate[1]));

        license.LastTaxClearanceDate__c = effectiveFromDate;
        license.TaxEntityName__c = result.name;

        String licenseNameFormula = TaxClearanceApiHelper.cleanClearanceResultName(license.LicenseeNameFormula__c);
        String clearanceResultName = TaxClearanceApiHelper.cleanClearanceResultName(result.name);

        if (licenseNameFormula == clearanceResultName) {
            license.LastTaxClearanceStatus__c = 'Approved / Compliant';
        } else {
            license.LastTaxClearanceStatus__c = 'Approved / Compliant. Entity name does not match DOTAX';
        }
    }

    private Map<String, TaxClearanceApiHelper.TaxClearanceResultResult> mapResults(List<TaxClearanceApiHelper.TaxClearanceResult> results) {
        Map<String, TaxClearanceApiHelper.TaxClearanceResultResult> ret = new Map<String, TaxClearanceApiHelper.TaxClearanceResultResult>();
        for (TaxClearanceApiHelper.TaxClearanceResult r : results) {
            if (r.id != null && r.results != null && !r.results.isEmpty()) {
                if (!ret.containsKey(r.id)) {
                    ret.put(r.id, r.results[0]);
                }
            }
        }

        return ret;
    }

    public void finish(Database.BatchableContext bc) {
        LicenseType__c lt = [SELECT Id, Name FROM LicenseType__c WHERE Id = :licenseTypeId];
        BatchJobFinishNotification notification = new BatchJobFinishNotification('TaxClearanceCheckBatch', lt.Name);
        notification.sendEmail();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
}