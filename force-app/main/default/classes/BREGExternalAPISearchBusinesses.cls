@RestResource(urlMapping='/api/searchBusinesses')
global with sharing class BREGExternalAPISearchBusinesses {
    private static final Integer MAX_SIZE = 2000;
    private static final Integer DEFAULT_SIZE = 100;
    private static final Integer DEFAULT_PAGE = 1;
    private static final Integer MAX_PAGE_SIZE = 1000;
    private static final Integer DEFAULT_PAGE_SIZE = 50;

    global class Address {
        public String addressLine1 { get; set; }
        public String addressLine2 { get; set; }
        public String addressLine3 { get; set; }
        public String city { get; set; }
        public String locality { get; set; }
        public String localityCode { get; set; }
        public String postalCode { get; set; }
        public String country { get; set; }
        public String countryCode { get; set; }
    }
    global class Business {
        public String businessId { get; set; }
        public String masterName { get; set; }
        public String alphasortName { get; set; }
        public String crossReferenceName { get; set; }
        public String fileNumber { get; set; }
        public String fileSuffix { get; set; }
        public String name { get; set; }
        public String organizedInLocality { get; set; }
        public String organizedInCountry { get; set; }
        public Address mailingAddress { get; set; }
    }
    global class SearchBusinessesResponse {
        public List<Business> businesses { get; set; }
        public Integer totalCount { get; set; }
        public String errorMessage { get; set; }
        public Integer pageSize { get; set; }
        public Integer pageNumber { get; set; }
    }
    global class SearchBusinessesRequest {
        public String query { get; set; }
        public Integer size { get; set; }
        public Integer page { get; set; }
        public List<String> nameStatus { get; set; }
        public List<String> nameType { get; set; }
        public List<String> excludedFileSuffixes { get; set; }
        public Boolean excludeUnregisteredOwners { get; set; }
    }

    @HttpPost
    global static SearchBusinessesResponse searchBusinesses() {
        SearchBusinessesResponse response = new SearchBusinessesResponse();
        if (RestContext.request.requestBody == null) {
            response.errorMessage = 'Request body cannot be null';
            return response;
        }
        SearchBusinessesRequest request = (SearchBusinessesRequest) JSON.deserialize(
            RestContext.request.requestBody.toString(),
            SearchBusinessesRequest.class
        );
        // Implement the logic to search businesses based on the parameters
        Integer size = request.size;
        if (request.size == null || request.size <= 0) {
            size = DEFAULT_SIZE;
        } else if (request.size > MAX_SIZE) {
            size = MAX_SIZE;
        }
        Integer page = request.page;
        if (request.page == null || request.page <= 0) {
            page = DEFAULT_PAGE;
        } else if (request.page > MAX_PAGE_SIZE) {
            page = MAX_PAGE_SIZE;
        }
        if (request.query == null || String.isBlank(request.query)) {
            response.errorMessage = 'Query cannot be empty';
            return response;
        }
        // Here you would implement the logic to search for businesses based on the request parameters
        response.businesses = new List<Business>();
        response.totalCount = 0;
        response.errorMessage = null;
        response.pageSize = size;
        response.pageNumber = page;
        Integer offset = (page - 1) * size;
        if (offset < 0) {
            offset = 0;
        } else if (offset > MAX_SIZE) {
            offset = MAX_SIZE;
        }

        List<String> nameStatus = request.nameStatus;
        List<String> nameType = request.nameType;
        List<String> excludedFileSuffixes = request.excludedFileSuffixes;
        Boolean excludeUnregisteredOwners = request.excludeUnregisteredOwners != null ? request.excludeUnregisteredOwners : false;
        String query = request.query;
        if (!query.contains('%')) {
            //add wildcards to the start and end for partial matching
            query = '%' + query + '%';
        }
        String whereClause =
            'WHERE   RecordType.Name = \'BREG Account\' AND Name LIKE :query ' +
            (nameStatus != null && !nameStatus.isEmpty() ? ' AND breg_Entity_Status__c IN :nameStatus ' : '') +
            (nameType != null && !nameType.isEmpty() ? ' AND breg_Entity_Type__c IN :nameType ' : '') +
            (excludedFileSuffixes != null && !excludedFileSuffixes.isEmpty() ? ' AND breg_File_Suffix__c NOT IN :excludedFileSuffixes ' : '') +
            (excludeUnregisteredOwners ? ' AND breg_File_Suffix__c != \'ZZ\' AND breg_Entity_Type__c != \'MSTR\' ' : '');

        String soqlQuery =
            'SELECT  Id, ' +
            'breg_File__c, ' +
            'breg_File_Suffix__c, ' +
            'Name,BillingStreet, ' +
            'breg_Mailing_Address_Street_2__c,' +
            'BillingCity, ' +
            'BillingState, ' +
            'BillingStateCode, ' +
            'BillingPostalCode, ' +
            'BillingCountry, ' +
            'BillingCountryCode, ' +
            'breg_Formation_State__c, ' +
            'breg_Formation_Country__c ' +
            'FROM    Account ' +
            whereClause +
            'LIMIT   :size ' +
            'OFFSET  :offset';
        List<Account> accounts = Database.query(soqlQuery);

        // Get total count using the same where clause conditions
        String countQuery = 'SELECT COUNT() ' + 'FROM Account ' + whereClause;

        Integer totalCount = Database.countQuery(countQuery);
        response.totalCount = totalCount > MAX_SIZE ? MAX_SIZE : totalCount;
        response.pageSize = size > response.totalCount ? response.totalCount : size;
        response.businesses = new List<Business>();
        // Populate the response with the found businesses
        if (accounts.isEmpty()) {
            response.errorMessage = 'No businesses found for the given query';

            return response;
        }
        for (Account acc : accounts) {
            Business business = new Business();
            business.fileNumber = acc.breg_File__c?.replace(acc.breg_File_Suffix__c, ''); //in SF data model file number contains suffix as well
            business.fileSuffix = acc.breg_File_Suffix__c;
            business.businessId = acc.Id; // Assuming businessId is the Account Id
            business.mailingAddress = new Address();
            business.mailingAddress.addressLine1 = acc.BillingStreet;
            business.mailingAddress.city = acc.BillingCity;
            business.mailingAddress.locality = acc.BillingState;
            business.mailingAddress.localityCode = acc.BillingStateCode;
            business.mailingAddress.postalCode = acc.BillingPostalCode;
            business.mailingAddress.country = acc.BillingCountry;
            business.mailingAddress.countryCode = acc.BillingCountryCode;
            business.mailingAddress.addressLine2 = acc.breg_Mailing_Address_Street_2__c;
            business.masterName = acc.Name; // Assuming masterName is the same as the account name
            business.alphasortName = acc.Name; // Assuming alphasortName is the same as the account name
            business.crossReferenceName = acc.Name; // Assuming crossReferenceName is the same as the account name
            //business.fileNumber = acc.Id; // TODO: populate fileNumber if applicable
            //business.fileSuffix = ''; // TODO // Populate fileSuffix if applicable
            business.organizedInLocality = acc.breg_Formation_State__c; // Assuming organizedInLocality is the billing city
            business.organizedInCountry = acc.breg_Formation_Country__c; // Assuming organizedInCountry is the billing country
            business.name = acc.Name;
            // Populate other fields as necessary
            response.businesses.add(business);
        }
        // Populate response.businesses, response.totalCount, and response.errorMessage accordingly
        return response;
    }
}