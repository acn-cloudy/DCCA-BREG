@isTest
private class BREGEntityListWeeklyJobTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Entity Job Acc');
        insert acc;

        breg_Entity_List__c entityList = new breg_Entity_List__c(breg_Status__c = 'All');
        insert entityList;

        String csvText = '"' + acc.Id + '","' + acc.Name + '",SomeOtherColumn\n';

        breg_Entity_List_Result__c elr = new breg_Entity_List_Result__c(breg_Entity_List__c = entityList.Id, breg_Docusign_Document_Id__c = 'FAKE_DOC_ID');
        insert elr;

        breg_Transaction__c tx = new breg_Transaction__c(
            breg_Account__c = acc.Id,
            breg_Transaction_Code__c = 'ADD',
            breg_Description__c = 'Address change'
        );
        insert tx;

        // Fake Blob in static variable for DocuSignAPI stub
        //Test.setMock(HttpCalloutMock.class, new BREGEntityListWeeklyJobTest.DocuSignApiMock(csvText));
    }

    @IsTest
    static void testCheckDifferences() {
        List<breg_Entity_List_Result__c> elrs = [
            SELECT Id, breg_Entity_List__c, breg_Docusign_Document_Id__c
            FROM breg_Entity_List_Result__c
        ];

        Map<Id, SObject> result = BREGEntityListWeeklyJob.checkDifferences(elrs);

        System.assertEquals(1, result.size(), 'One Entity List should be updated');
        breg_Entity_List__c updated = (breg_Entity_List__c) result.values()[0];
        System.assertNotEquals(null, updated.breg_Difference_for_a_week__c, 'Difference text must be populated');
        System.assert(updated.breg_Difference_for_a_week__c.contains('Address change'), 'Difference text should contain description');
    }

    // --- Stub for DocuSignAPI ---
    private class DocuSignApiMock implements HttpCalloutMock {
        private String csvText;
        DocuSignApiMock(String csvText) {
            this.csvText = csvText;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Return CSV text as blob
            res.setBody(csvText);
            return res;
        }
    }
}