@IsTest
private class PVLApplicationStatusCheckResourceTest {
    @IsTest
    static void statusCheckReturnsDeliverStatus() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount(
            'RestHappy',
            '808-555-0001',
            '123456789'
        );
        Application__c applicationRecord = PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'RestHappy');
        PVLApplicationStatusTestFactory.createSnapshot(
            applicationRecord.Id,
            'A1 - Awaiting Review',
            'deliver_status',
            System.now()
        );

        RestContext.request = requestWithBody(
            JSON.serialize(PVLApplicationStatusTestFactory.request('8085550001', '6789'))
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        assertJsonContentType();
        System.assertEquals(PVLApplicationStatusService.RESULT_DELIVER_STATUS, response.result);
        String responseJson = JSON.serialize(response);
        System.assertEquals(false, responseJson.contains((String) accountRecord.Id));
        System.assertEquals(false, responseJson.contains('8085550001'));
    }

    @IsTest
    static void statusCheckReturnsInvalidInputForBadLast4() {
        PVLApplicationStatusService.RequestEnvelope envelope =
            PVLApplicationStatusTestFactory.request('8085550002', '12A4');
        RestContext.request = requestWithBody(JSON.serialize(envelope));
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        assertJsonContentType();
        System.assertEquals(PVLApplicationStatusService.RESULT_INVALID_INPUT, response.result);
        System.assertEquals('SSN_LAST4_INVALID', response.handoffReason);
    }

    @IsTest
    static void statusCheckReturnsInvalidInputForMalformedJson() {
        RestContext.request = requestWithBody('{bad json');
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        assertJsonContentType();
        System.assertEquals(PVLApplicationStatusService.RESULT_INVALID_INPUT, response.result);
        System.assertEquals('MALFORMED_JSON', response.handoffReason);
    }

    @IsTest
    static void statusCheckReturnsInvalidInputForMissingBody() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/pvl/application-status/v1/individual/status-check';
        request.httpMethod = 'POST';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        assertJsonContentType();
        System.assertEquals(PVLApplicationStatusService.RESULT_INVALID_INPUT, response.result);
        System.assertEquals('REQUEST_BODY_MISSING', response.handoffReason);
    }

    @IsTest
    static void statusCheckReturnsOfferTransferAsHttp200() {
        RestContext.request = requestWithBody(
            JSON.serialize(PVLApplicationStatusTestFactory.request('8085550003', '6789'))
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        assertJsonContentType();
        System.assertEquals(PVLApplicationStatusService.RESULT_OFFER_TRANSFER, response.result);
        System.assertEquals('NO_ACCOUNT_MATCH', response.handoffReason);
    }

    @IsTest
    static void statusCheckReturnsTemporarilyUnavailableAsHttp200() {
        Account accountRecord = PVLApplicationStatusTestFactory.createPersonAccount(
            'RestNoSnapshot',
            '808-555-0004',
            '123456789'
        );
        PVLApplicationStatusTestFactory.createApplication(accountRecord.Id, 'RestNoSnapshot');
        RestContext.request = requestWithBody(
            JSON.serialize(PVLApplicationStatusTestFactory.request('8085550004', '6789'))
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        assertJsonContentType();
        System.assertEquals(PVLApplicationStatusService.RESULT_TEMPORARILY_UNAVAILABLE, response.result);
        System.assertEquals('SNAPSHOT_NOT_FOUND', response.handoffReason);
    }

    @IsTest
    static void statusCheckReturnsErrorAsHttp500() {
        RestContext.request = requestWithBody(
            JSON.serialize(PVLApplicationStatusTestFactory.request('8085550005', '6789'))
        );
        RestContext.response = new RestResponse();

        PVLApplicationStatusService.forceExceptionForTest = true;
        try {
            Test.startTest();
            PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusCheckResource.statusCheck();
            Test.stopTest();

            System.assertEquals(500, RestContext.response.statusCode);
            assertJsonContentType();
            System.assertEquals(PVLApplicationStatusService.RESULT_ERROR, response.result);
            System.assertEquals('SALESFORCE_UNAVAILABLE', response.errorCode);
        } finally {
            PVLApplicationStatusService.forceExceptionForTest = false;
        }
    }

    private static RestRequest requestWithBody(String body) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/pvl/application-status/v1/individual/status-check';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(body);
        return request;
    }

    private static void assertJsonContentType() {
        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
    }
}