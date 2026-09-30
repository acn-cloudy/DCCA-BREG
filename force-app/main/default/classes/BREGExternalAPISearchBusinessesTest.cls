@IsTest
private class BREGExternalAPISearchBusinessesTest {
    // Utility method to prepare REST request context
    private static void setRestRequest(Blob bodyJson) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/searchBusinesses';
        req.httpMethod = 'POST';
        req.requestBody = bodyJson;
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testNullRequest() {
        setRestRequest(null);
        BREGExternalAPISearchBusinesses.SearchBusinessesResponse res = BREGExternalAPISearchBusinesses.searchBusinesses();

        Assert.areEqual('Request body cannot be null', res.errorMessage);
    }

    @IsTest
    static void testEmptyQuery() {
        setRestRequest(Blob.valueOf('{"query":""}'));
        BREGExternalAPISearchBusinesses.SearchBusinessesResponse res = BREGExternalAPISearchBusinesses.searchBusinesses();

        Assert.areEqual('Query cannot be empty', res.errorMessage);
    }

    @IsTest
    static void testNoBusinessesFound() {
        setRestRequest(Blob.valueOf('{"query":"NoMatch","size":10,"page":1}'));
        BREGExternalAPISearchBusinesses.SearchBusinessesResponse res = BREGExternalAPISearchBusinesses.searchBusinesses();

        Assert.areEqual('No businesses found for the given query', res.errorMessage);
        Assert.areEqual(0, res.totalCount);
    }

    @IsTest
    static void testBusinessFound() {
        // Insert a matching account
        String recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('BREG Account').getRecordTypeId();

        Account acc = new Account(
            Name = 'Business',
            //breg_File__c = 'F123',
            //breg_File_Suffix__c = 'S1',
            BillingStreet = '123 Main St',
            BillingCity = 'Metropolis',
            BillingPostalCode = '10001',
            BillingCountry = 'United States',
            breg_Entity_Status__c = 'Active (A)',
            breg_Entity_Type__c = 'D2',
            RecordTypeId = recordTypeId
        );
        insert acc;

        setRestRequest(Blob.valueOf('{"query":"Business","size":5,"page":1, "nameStatus":["Active (A)"]}'));
        BREGExternalAPISearchBusinesses.SearchBusinessesResponse res = BREGExternalAPISearchBusinesses.searchBusinesses();

        Assert.areEqual(null, res.errorMessage, 'Error should be null if found');
        Assert.isTrue(res.totalCount > 0, 'Should return at least one business');
        Assert.areEqual(acc.Id, res.businesses[0].businessId, 'BusinessId should match Account Id');
        Assert.areEqual('Business', res.businesses[0].name);
        Assert.areEqual('123 Main St', res.businesses[0].mailingAddress.addressLine1);
    }

    @IsTest
    static void testPageAndSizeLimits() {
        // Insert accounts to simulate results
        List<Account> accounts = new List<Account>();
        String recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('BREG Account').getRecordTypeId();
        for (Integer i = 0; i < 3; i++) {
            accounts.add(
                new Account(
                    Name = 'Business ' + i,
                    breg_File__c = '' + i,
                    breg_File_Suffix__c = '' + i,
                    BillingStreet = '123 Main St',
                    BillingCity = 'Metropolis',
                    BillingPostalCode = '10001',
                    BillingCountry = 'United States',
                    breg_Entity_Status__c = 'Active (A)',
                    breg_Entity_Type__c = 'D2',
                    RecordTypeId = recordTypeId
                )
            );
        }
        insert accounts;

        // Test with negative page/size
        setRestRequest(Blob.valueOf('{"query":"Business","size":-5,"page":-1}'));
        BREGExternalAPISearchBusinesses.SearchBusinessesResponse res = BREGExternalAPISearchBusinesses.searchBusinesses();

        Assert.areEqual(null, res.errorMessage);
        Assert.isTrue(res.totalCount > 0);

        // Test with very large page/size (should be capped at MAX_SIZE / MAX_PAGE_SIZE)
        setRestRequest(Blob.valueOf('{"query":"Business","size":99999,"page":99999}'));
        res = BREGExternalAPISearchBusinesses.searchBusinesses();
        Assert.areEqual('No businesses found for the given query', res.errorMessage);
        Assert.isTrue(res.businesses.size() == 0);
    }
}