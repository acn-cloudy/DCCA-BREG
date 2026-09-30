@IsTest
public with sharing class BREGExternalAPIUpdateScannerStatusTest {
    @IsTest
    public static void testUpdateScannerStatus() {
        BREGExternalAPIUpdateScannerStatus.ScannerStatusRequest request = new BREGExternalAPIUpdateScannerStatus.ScannerStatusRequest();
        request.timestamp = DateTime.now().formatGmt('yyyy-MM-dd HH:mm:ss');
        request.status = 'New';
        request.processed = 1;
        request.error = 0;
        request.queue = 1;
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/updateScannerStatus';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = req;
        BREGExternalAPIUpdateScannerStatus.updateScannerStatus();
        BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse response = (BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse) JSON.deserialize(RestContext.response.responseBody.toString(), BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse.class);
        Assert.isNotNull(response.recordId);
    }

    @IsTest
    public static void testUpdateScannerStatus_EmptyRequest() {
        // Simulate an empty request body
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/updateScannerStatus';
        req.httpMethod = 'POST';
        req.requestBody = null;
        RestContext.request = req;
        BREGExternalAPIUpdateScannerStatus.updateScannerStatus();
        BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse response = (BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse) JSON.deserialize(RestContext.response.responseBody.toString(), BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse.class);
        System.assertEquals('Request body cannot be null', response.errorMessage);
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals(null, response.recordId);
    }

    @IsTest
    public static void testUpdateScannerStatus_Exception() {
        // Simulate an exception by removing the Heartbeat record type from the describe info
        // We'll use a mock for the Schema.SObjectType if possible, but since that's not possible in Apex,
        // we'll simulate by passing an invalid JSON that will fail deserialization
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/api/updateScannerStatus';
        req.httpMethod = 'POST';
        // Invalid JSON to cause deserialization exception
        req.requestBody = Blob.valueOf('{invalidJson}');
        RestContext.request = req;
        BREGExternalAPIUpdateScannerStatus.updateScannerStatus();
        BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse response = (BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse) JSON.deserialize(RestContext.response.responseBody.toString(), BREGExternalAPIUpdateScannerStatus.ScannerStatusResponse.class);
        System.assertNotEquals(null, response.errorMessage, 'Should return an error message');
        System.assertEquals(500, RestContext.response.statusCode);
        System.assertEquals(null, response.recordId);
    }
}