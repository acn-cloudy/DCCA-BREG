@IsTest
private class BREGExternalAPIGetGoodStandingStatusTest {

    // Utility method to prepare REST request context
    private static void setRestRequest(Blob bodyJson) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/getGoodStandingStatus';
        req.httpMethod = 'POST';
        req.requestBody = bodyJson;
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testNullRequest() {
        setRestRequest(null);
        BREGExternalAPIGetGoodStandingStatus.BusinessGoodStandingStatusResponse res =
            BREGExternalAPIGetGoodStandingStatus.getGoodStandingStatus();
        Assert.areEqual('Request body cannot be null', res.errorMessage);
    }

    @IsTest
    static void testBlankFileNumber() {
        setRestRequest(Blob.valueOf('{"fileNumber":"","suffix":"ABC"}'));
        BREGExternalAPIGetGoodStandingStatus.BusinessGoodStandingStatusResponse res =
            BREGExternalAPIGetGoodStandingStatus.getGoodStandingStatus();
        Assert.areEqual('File number cannot be blank', res.errorMessage);
    }

    @IsTest
    static void testBlankSuffix() {
        setRestRequest(Blob.valueOf('{"fileNumber":"12345","suffix":""}'));
        BREGExternalAPIGetGoodStandingStatus.BusinessGoodStandingStatusResponse res =
            BREGExternalAPIGetGoodStandingStatus.getGoodStandingStatus();
        Assert.areEqual('Suffix cannot be blank', res.errorMessage);
    }

    @IsTest
    static void testNoBusinessFound() {
        setRestRequest(Blob.valueOf('{"fileNumber":"9999","suffix":"ZZ"}'));
        BREGExternalAPIGetGoodStandingStatus.BusinessGoodStandingStatusResponse res =
            BREGExternalAPIGetGoodStandingStatus.getGoodStandingStatus();
        Assert.areEqual('No business found with the provided file number and suffix', res.errorMessage);
        Assert.areEqual('9999', res.fileNumber);
        Assert.areEqual('ZZ', res.suffix);
    }

    @IsTest
    static void testBusinessFound() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();
        // Insert account with required fields
        Account acc = new Account(
            Name = 'Business',
            breg_File__c = '12345ABC',
            breg_File_Suffix__c = 'ABC',
            Suffix__c = 'ABC', // needed for the query condition
            breg_Good_Standing__c = true,
            RecordTypeId = bregAccRecordType
        );
        insert acc;

        setRestRequest(Blob.valueOf('{"fileNumber":"12345","suffix":"ABC"}'));
        BREGExternalAPIGetGoodStandingStatus.BusinessGoodStandingStatusResponse res =
            BREGExternalAPIGetGoodStandingStatus.getGoodStandingStatus();

        Assert.areEqual(true, res.goodStandingStatus, 'Should return good standing true');
        Assert.areEqual('12345', res.fileNumber);
        Assert.areEqual('ABC', res.suffix);
        Assert.areEqual(null, res.errorMessage, 'No error expected when record found');
    }
}