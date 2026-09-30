@RestResource(urlMapping='/pvl/application-status/v1/individual/status-check')
global with sharing class PVLApplicationStatusCheckResource {
    @HttpPost
    global static PVLApplicationStatusService.ResponseEnvelope statusCheck() {
        ensureResponse();

        try {
            if (RestContext.request == null || RestContext.request.requestBody == null) {
                RestContext.response.statusCode = 400;
                return PVLApplicationStatusService.invalidInput(null, 'REQUEST_BODY_MISSING');
            }

            PVLApplicationStatusService.RequestEnvelope request =
                (PVLApplicationStatusService.RequestEnvelope) JSON.deserialize(
                    RestContext.request.requestBody.toString(),
                    PVLApplicationStatusService.RequestEnvelope.class
                );

            PVLApplicationStatusService.ResponseEnvelope response = PVLApplicationStatusService.checkStatus(request);
            if (response.result == PVLApplicationStatusService.RESULT_INVALID_INPUT) {
                RestContext.response.statusCode = 400;
            } else if (response.result == PVLApplicationStatusService.RESULT_ERROR) {
                RestContext.response.statusCode = 500;
            } else {
                RestContext.response.statusCode = 200;
            }
            return response;
        } catch (System.JSONException ex) {
            RestContext.response.statusCode = 400;
            return PVLApplicationStatusService.invalidInput(null, 'MALFORMED_JSON');
        } catch (Exception ex) {
            RestContext.response.statusCode = 500;
            return PVLApplicationStatusService.error(null, 'SALESFORCE_UNAVAILABLE');
        }
    }

    private static void ensureResponse() {
        if (RestContext.response == null) {
            RestContext.response = new RestResponse();
        }
        RestContext.response.addHeader('Content-Type', 'application/json');
    }
}