@IsTest
private class PVLApplicationStatusHealthResourceTest {
    @IsTest
    static void healthReturnsOk() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/pvl/application-status/v1/health';
        request.httpMethod = 'GET';
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        PVLApplicationStatusHealthResource.HealthResponse response = PVLApplicationStatusHealthResource.health();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('application/json', RestContext.response.headers.get('Content-Type'));
        System.assertEquals('OK', response.result);
        System.assertEquals('v1', response.version);
        System.assertEquals('PVL Application Status', response.service);
        System.assertNotEquals(null, response.checkedAt);
    }
}