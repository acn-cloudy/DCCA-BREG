@RestResource(urlMapping='/pvl/application-status/v1/health')
global with sharing class PVLApplicationStatusHealthResource {
    global class HealthResponse {
        public String result;
        public String version;
        public String service;
        public String checkedAt;
    }

    @HttpGet
    global static HealthResponse health() {
        if (RestContext.response == null) {
            RestContext.response = new RestResponse();
        }
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.statusCode = 200;

        HealthResponse response = new HealthResponse();
        response.result = 'OK';
        response.version = 'v1';
        response.service = 'PVL Application Status';
        response.checkedAt = PVLApplicationStatusService.formatIsoGmt(System.now());
        return response;
    }
}