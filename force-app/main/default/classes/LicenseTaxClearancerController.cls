/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: LicenseTaxClearancerControllerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL07212022 - Created for case 00022295
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 07/21/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class LicenseTaxClearancerController {
    @AuraEnabled
    public static String runClearanceCheck(String recordId) {
        TaxClearanceApiHelper.TaxClearanceResponse resp = TaxClearanceApiHelper.runClearance(recordId);

        TaxClearanceApiHelper.TaxClearanceResultResult clearanceResultResult;
        List<TaxClearanceApiHelper.TaxClearanceResult> clearanceResults =
                new List<TaxClearanceApiHelper.TaxClearanceResult>();

        if (resp.ssns != null && !resp.ssns.isEmpty()) {
            clearanceResults.add(resp.ssns[0]);
        }

        if (resp.feins != null && !resp.feins.isEmpty()) {
            clearanceResults.add(resp.feins[0]);
        }

        if (resp.tax_ids != null && !resp.tax_ids.isEmpty()) {
            clearanceResults.add(resp.tax_ids[0]);
        }

        Boolean desiredResultsFound = false;
        Boolean yCheckDone = false;
        Boolean dCheckDone = false;

        do {
            //First look for Y
            //If no Y, look for D
            //Otherwise no results found
            if (!yCheckDone && !desiredResultsFound) {
                TaxClearanceApiHelper.TaxClearanceResultResult y = checkForStatusCode('Y', clearanceResults);
                if (y != null) {
                    desiredResultsFound = true;
                    clearanceResultResult = y;
                }
                yCheckDone = true;
            } else if (!dCheckDone && !desiredResultsFound) {
                TaxClearanceApiHelper.TaxClearanceResultResult d = checkForStatusCode('D', clearanceResults);
                if (d != null) {
                    desiredResultsFound = true;
                    clearanceResultResult = d;
                }
                dCheckDone = true;
            } else {
                desiredResultsFound = true;
            }
        } while (!desiredResultsFound);

        String returnMessage = '';
        if (clearanceResultResult != null) {
            if (clearanceResultResult.status_code == 'D') {
                resp.license.LastTaxClearanceStatus__c = 'Denied / Not Compliant';
                returnMessage = 'The licensee is not currently tax compliant.';
            } else if (clearanceResultResult.status_code == 'Y') {
                String effectiveFrom = clearanceResultResult.effective_from;
                List<String> splitDate = effectiveFrom.split('/');
                Date effectiveFromDate = Date.newInstance(Integer.valueOf(splitDate[2]),
                        Integer.valueOf(splitDate[0]),
                        Integer.valueOf(splitDate[1]));

                resp.license.LastTaxClearanceDate__c = effectiveFromDate;
                resp.license.TaxEntityName__c = clearanceResultResult.name;

                String licenseNameFormula = TaxClearanceApiHelper.cleanClearanceResultName(resp.license.LicenseeNameFormula__c);
                String clearanceResultName = TaxClearanceApiHelper.cleanClearanceResultName(clearanceResultResult.name);

                if (licenseNameFormula == clearanceResultName) {
                    resp.license.LastTaxClearanceStatus__c = 'Approved / Compliant';
                    returnMessage =
                            'License ' + resp.license.Name + ' is tax compliant as of ' + Date.today().format() +
                            '. The Tax Clearance Date has been updated on the License to reflect that License is currently compliant.';
                } else {
                    resp.license.LastTaxClearanceStatus__c = 'Approved / Compliant. Entity name does not match DOTAX';
                    returnMessage = 'License ' + resp.license.Name +
                            ' is tax compliant but the Entity Name on file with department of tax is ' +
                            clearanceResultResult.name + ' and does not match the Licensee’s name in Ho’ala.';
                }
            }
        } else {
            resp.license.LastTaxClearanceStatus__c = 'Tax Id was not found on record with DOTAX';
            returnMessage = 'The licensee\'s tax Id(s) were not found on record with the Hawaii Department of Tax.';
        }

        //throw new TaxClearanceApiHelper.TaxClearanceApiException('Something went wrong.');
        update resp.license;
        return returnMessage;
    }

    private static TaxClearanceApiHelper.TaxClearanceResultResult checkForStatusCode(String statusCodeToCheck,
                                                                                     List<TaxClearanceApiHelper.TaxClearanceResult> clearanceResults) {
        for (TaxClearanceApiHelper.TaxClearanceResult r : clearanceResults) {
            //find status code
            if (r.results != null && !r.results.isEmpty()) {
                if (r.results[0].status_code == statusCodeToCheck) {
                    return r.results[0];
                }
            }
        }

        return null;
    }
}