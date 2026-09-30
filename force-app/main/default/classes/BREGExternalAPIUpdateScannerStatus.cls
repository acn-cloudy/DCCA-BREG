@RestResource(urlMapping='/api/updateScannerStatus')
global with sharing class BREGExternalAPIUpdateScannerStatus {
    global class ScannerStatusRequest {
        public String timestamp { get; set; }
        public String status { get; set; }
        public Integer processed { get; set; }
        public Integer error { get; set; }
        public Integer queue { get; set; }
    }

    global class ScannerStatusResponse {
        public Id recordId { get; set; }
        public String errorMessage { get; set; }
    }

    @HttpPost
    global static void updateScannerStatus() {
        ScannerStatusResponse response = new ScannerStatusResponse();
        RestContext.response = new RestResponse();

        try {
            if (RestContext.request.requestBody == null) {
                response.errorMessage = 'Request body cannot be null';
                RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
                RestContext.response.statusCode = 400;
                return;
            }

            ScannerStatusRequest req = (ScannerStatusRequest) JSON.deserialize(RestContext.request.requestBody.toString(), ScannerStatusRequest.class);

            // Get the Heartbeat record type Id for breg_Case_Staging__c
            Id heartbeatRecordTypeId = Schema.SObjectType.breg_Case_Staging__c.getRecordTypeInfosByName().get('Heartbeat').getRecordTypeId();

            breg_Case_Staging__c caseStaging = new breg_Case_Staging__c(
                RecordTypeId = heartbeatRecordTypeId,
                breg_Status__c = req.status,
                breg_Processed__c = req.processed,
                breg_Error__c = req.error,
                breg_Queue__c = req.queue,
                breg_Timestamp__c = Datetime.valueOfGmt(req.timestamp)
            );

            insert caseStaging;

            response.recordId = caseStaging.Id;
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
            RestContext.response.statusCode = 201;
        } catch (Exception ex) {
            response.recordId = null;
            response.errorMessage = ex.getMessage();
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response));
            RestContext.response.statusCode = 500;
        }
    }
}