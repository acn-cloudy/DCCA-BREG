@isTest
global with sharing class CreateRecordContTest {
    public static testMethod void testGetPickListValuesIntoList() {
        
        Test.setMock(HttpCalloutMock.class, new MockService());

        CreateRecordCont.getPickListValuesIntoList('PersonAccount', 'Salutation ','Person Account');
        System.debug((new CreateRecordCont()).statesOptions);
    }
    global class MockService implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req) {
            String jsonStr = '{"values":[{"value":"C - Corporation","label":"C - Corporation"},{"value":"I - Individual","label":"I - Individual"},'
            +'{"value":"O - Organization (LLC)","label":"O - Organization (LLC)"},'
            +'{"value":"P - Limited Partnership/Partnership","label":"P - Limited Partnership/Partnership"},'
            +'{"value":"Q - Limited Liability Partnership","label":"Q - Limited Liability Partnership"}],"defaultValue":null}';
            HttpResponse res = new HttpResponse();
            res.setBody(jsonStr);
            res.setStatusCode(200);
            return res;

            // Create a fake response.
            // Set response values, and 
            // return response.
        }
    }
}