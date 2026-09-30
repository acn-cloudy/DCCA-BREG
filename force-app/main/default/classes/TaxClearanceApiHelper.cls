/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: TaxClearanceApiHelperTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL07202022 - Created for case 00022295
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 07/20/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class TaxClearanceApiHelper {
    public static final Integer HTTP_STATUS_OK = 200;

    private static Map<String, License__c> ssnsLicenseMap = new Map<String, License__c>();
    private static Map<String, License__c> feinLicenseMap = new Map<String, License__c>();
    private static Map<String, License__c> taxIdLicenseMap = new Map<String, License__c>();

    public static TaxClearanceResponse runClearance(List<License__c> licenses) {
        Set<String> ssns = new Set<String>();
        Set<String> feins = new Set<String>();
        Set<String> taxIds = new Set<String>();

        for (License__c l : licenses) {
            if (l.Licensee__r.BPID__c != null) {
                ssns.add(l.Licensee__r.BPID__c);
            }

            if (l.Licensee__r.FEIN__c != null) {
                feins.add(stripNonNumeric(l.Licensee__r.FEIN__c));
            }

            if (l.Licensee__r.StateExciseTaxNumber__c != null) {
                taxIds.add(stripNonNumeric(l.Licensee__r.StateExciseTaxNumber__c));
            }
        }

        HttpResponse resp = sendRequest(ssns, feins, taxIds);
        if (resp.getStatusCode() == HTTP_STATUS_OK) {
            String responseBody = resp.getBody();
            TaxClearanceResponse result = (TaxClearanceResponse) JSON.deserialize(responseBody, TaxClearanceResponse.class);
            return result;
        } else {
            throw new TaxClearanceApiException(String.valueOf(resp.getStatusCode()) + ':' + resp.getStatus());
        }
    }

    public static TaxClearanceResponse runClearance(String licenseId) {
        Set<String> ssns = new Set<String>();
        Set<String> feins = new Set<String>();
        Set<String> taxIds = new Set<String>();

        License__c l = [
                SELECT
                        Id,
                        Name,
                        LicenseeNameFormula__c,
                        Licensee__r.BPID__c,
                        Licensee__r.FEIN__c,
                        Licensee__r.StateExciseTaxNumber__c
                FROM License__c
                WHERE Id = :licenseId
                AND Licensee__c != null
        ];

        if (l.Licensee__r.BPID__c != null) {
            ssns.add(l.Licensee__r.BPID__c);
        }

        if (l.Licensee__r.FEIN__c != null) {
            feins.add(stripNonNumeric(l.Licensee__r.FEIN__c));
        }

        if (l.Licensee__r.StateExciseTaxNumber__c != null) {
            taxIds.add(stripNonNumeric(l.Licensee__r.StateExciseTaxNumber__c));
        }

        HttpResponse resp = sendRequest(ssns, feins, taxIds);
        if (resp.getStatusCode() == HTTP_STATUS_OK) {
            String responseBody = resp.getBody();
            TaxClearanceResponse result = (TaxClearanceResponse) JSON.deserialize(responseBody, TaxClearanceResponse.class);
            result.license = l;
            return result;
        } else {
            throw new TaxClearanceApiException(String.valueOf(resp.getStatusCode()) + ':' + resp.getStatus());
        }
    }

    private static HttpResponse sendRequest(Set<String> ssns, Set<String> feins, Set<String> taxIds) {
        JSONGenerator generator = JSON.createGenerator(false);

        generator.writeStartObject();
        generator.writeObjectField('ssns', ssns);
        generator.writeObjectField('feins', feins);
        generator.writeObjectField('tax_ids', taxIds);
        generator.writeEndObject();

        String requestParam = generator.getAsString();

        TaxClearanceApi__c apiConfig = TaxClearanceApi__c.getOrgDefaults();
        Blob usernamePass = Blob.valueOf(apiConfig.Username__c + ':' + apiConfig.Password__c);
        String basicAuth = 'Basic ' + EncodingUtil.base64Encode(usernamePass);

        Http h = new Http();

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(apiConfig.EndpointUrl__c);
		req.setTimeout(120000);
        req.setHeader('Authorization', basicAuth);
        req.setBody(requestParam);

        return h.send(req);
    }

    public static String stripNonNumeric(String input) {
        return input.replaceAll('[^0-9]', '');
    }

    public static String cleanClearanceResultName(String name) {
        name = name.toLowerCase();
        name = name.remove(',');
        name = name.remove('.');
        name = name.remove('\'');
        name = name.remove('-');

        //decode 'and' char
        name = name.replaceAll('(?<![\\w\\d])&amp;(?![\\w\\d])', 'AND');

        //remove apostrophe
        name = name.replaceAll('(?<=[\\w\\d])&#39;(?=[\\w\\d])', '');

        //Treat "CONSTRUCTION" and "CONST" as the same.
        name = name.replaceAll('(?<![\\w\\d])const(?![\\w\\d])', 'construction');

        //Treat "SVC" and "SVCS" and "SERVICES" as the same.
        name = name.replaceAll('(?<![\\w\\d])svc(?![\\w\\d])', 'services');
        name = name.replaceAll('(?<![\\w\\d])svcs(?![\\w\\d])', 'services');

        //Treat "INTERNATIONAL" and "INTL" as the same.
        name = name.replaceAll('(?<![\\w\\d])intl(?![\\w\\d])', 'international');

        //Treat "MANAGEMENT" and "MGMT" as the same.
        name = name.replaceAll('(?<![\\w\\d])mgmt(?![\\w\\d])', 'management');

        //Treat “LIMITED LIABILITY COMPANY” and “LLC” as the same.
        name = name.replaceAll('(?<![\\w\\d])llc(?![\\w\\d])', 'limited liability company');

        //Treat “LIMITED LIABILITY PARTNERSHIP” and “LLP” as the same.
        name = name.replaceAll('(?<![\\w\\d])llp(?![\\w\\d])', 'limited liability partnership');

        //Treat "&" and "AND" as the same.
        name = name.replaceAll('&', 'AND');

        //Treat "CO" and "COMPANY" as the same.
        name = name.replaceAll('(?<![\\w\\d])co(?![\\w\\d])', 'company');

        //Treat "CORP" and "CORPORATION" as the same.
        name = name.replaceAll('(?<![\\w\\d])corp(?![\\w\\d])', 'corporation');

        //Treat "MAINTENANCE" and "MAINT." and "MAINT" as the same.
        name = name.replaceAll('(?<![\\w\\d])maint(?![\\w\\d])', 'maintenance');

        //Treat "INC" and "INCORPORATED" as the same
        name = name.replaceAll('(?<![\\w\\d])inc(?![\\w\\d])', 'incorporated');

        //Remove spaces
        name = name.replaceAll('\\s{1,}', '');

        name = name.trim();

        return name;
    }

    public class TaxClearanceResponse{
        public License__c license;

        @AuraEnabled
        public List<TaxClearanceResult> ssns;

        @AuraEnabled
        public List<TaxClearanceResult> feins;

        @AuraEnabled
        public List<TaxClearanceResult> tax_ids;
    }

    public class TaxClearanceResult{
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String message;

        @AuraEnabled
        public List<TaxClearanceResultResult> results;
    }

    public class TaxClearanceResultResult{
        @AuraEnabled
        public String status_code;

        @AuraEnabled
        public String effective_from;

        @AuraEnabled
        public String tax_id;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String new_tax_id;
    }

    public class TaxClearanceApiException extends Exception{
    }
}