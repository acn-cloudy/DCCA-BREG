@RestResource(urlMapping='/api/getGoodStandingStatus')
global without sharing class BREGExternalAPIGetGoodStandingStatus {
    global class BusinessGoodStandingStatusRequest {
        public String fileNumber { get; set; }
        public String suffix { get; set; }
    }

    global class BusinessGoodStandingStatusResponse {
        public Boolean goodStandingStatus { get; set; }
        public String fileNumber { get; set; }
        public String suffix { get; set; }
        public String errorMessage { get; set; }
    }
    @HttpPost
    global static BusinessGoodStandingStatusResponse getGoodStandingStatus() {
        BusinessGoodStandingStatusResponse response = new BusinessGoodStandingStatusResponse();
        if (RestContext.request.requestBody == null) {
            response.errorMessage = 'Request body cannot be null';
            return response;
        }
        BusinessGoodStandingStatusRequest request = (BusinessGoodStandingStatusRequest) JSON.deserialize(
            RestContext.request.requestBody.toString(),
            BusinessGoodStandingStatusRequest.class
        );
        // Implement the logic to search businesses based on the parameters
        /*if (request == null) {
            response.errorMessage = 'Request cannot be null';
            return response;
        }*/
        if (String.isBlank(request.fileNumber)) {
            response.errorMessage = 'File number cannot be blank';
            return response;
        }
        if (String.isBlank(request.suffix)) {
            response.errorMessage = 'Suffix cannot be blank';
            return response;
        }
        // Here you would implement the logic to check the good standing status of the business
        String fileNumberWithSuffix = request.fileNumber + request.suffix;
        List<Account> accounts = [
            SELECT Id, Name, breg_File__c, breg_File_Suffix__c, breg_Good_Standing__c
            FROM Account
            WHERE breg_File__c = :fileNumberWithSuffix AND Account.RecordType.DeveloperName = 'BREG_Account'
            LIMIT 1
        ];
        // Populate response.businesses, response.totalCount, and response.errorMessage accordingly
        if (accounts.isEmpty()) {
            response.fileNumber = request.fileNumber;
            response.suffix = request.suffix;
            response.errorMessage = 'No business found with the provided file number and suffix';
            return response;
        }
        Account acc = accounts[0];
        response.goodStandingStatus = acc.breg_Good_Standing__c;
        response.fileNumber = acc.breg_File__c.replace(request.suffix, ''); //in SF data model file number contains suffix as well
        response.suffix = acc.breg_File_Suffix__c;
        // You can add more fields to the response if needed
        return response;
    }
}