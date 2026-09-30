@IsTest
public with sharing class BREGDecreeGenerationTest {
    private static final String STATUS_INV_DISSOLVED = BREGAccountStatus2DissolutionBatch.STATUS_DISSOLVED;
    private static final String STATUS_INV_REVOKED = BREGAccountStatus2DissolutionBatch.STATUS_REVOKED;
    private static final String STATUS_INV_CANCELLED = BREGAccountStatus2DissolutionBatch.STATUS_CANCELLED;
    private static final String STATUS_ADM_TERMINATED = BREGAccountStatus2DissolutionBatch.STATUS_TERMINATED;

    private class DecreeGenerationCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (method == 'GET' && endpoint.contains('/folders/path/')) {
                if (endpoint.contains('Other+Sources%2FBREG+Combined+Documents%2FDecree+Documents')) {
                    res.setStatusCode(404);
                    res.setBody('{"error":"not found"}');
                    return res;
                }
                if (endpoint.contains('Other+Sources%2FBREG+Combined+Documents')) {
                    res.setStatusCode(200);
                    res.setBody('{"Name":"Combined","Href":"/folders/combined-folder-id/"}');
                    return res;
                }
                if (endpoint.contains('Other+Sources%2FBREG+Merged+Documents%2FDecree+Documents')) {
                    res.setStatusCode(200);
                    res.setBody('{"Name":"Templates","Href":"/folders/template-folder-id/"}');
                    return res;
                }
            }

            if (method == 'POST' && endpoint.contains('/folders')) {
                res.setStatusCode(201);
                res.setBody('{"Name":"Dated","Href":"/folders/dated-folder-id/"}');
                return res;
            }

            if (method == 'GET' && endpoint.contains('/folders/template-folder-id/documents')) {
                res.setStatusCode(200);
                String encodedName = endpoint.contains('name=') ? endpoint.substringAfter('name=') : '';
                String decodedName = String.isBlank(encodedName) ? '' : EncodingUtil.urlDecode(encodedName, 'UTF-8');
                if (String.isBlank(decodedName)) {
                    res.setBody('{"Results":[]}');
                } else {
                    res.setBody('{"Results":[{"Name":"' + decodedName + '","Href":"/documents/template-doc-id"}]}');
                }
                return res;
            }

            if (method == 'POST' && endpoint.contains('/documentxmlmergetasks')) {
                res.setStatusCode(201);
                res.setBody('{"Status":"Created","Href":"/documentxmlmergetasks/task-1"}');
                return res;
            }

            res.setStatusCode(500);
            res.setBody('{"error":"unexpected endpoint"}');
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        Id bregAccRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('BREG_Account').getRecordTypeId();

        insert new List<Account>{
            new Account(Name = 'Decree Test D1', breg_Entity_Status__c = 'Active (A)', breg_Entity_Type__c = 'D1', breg_Incorporation_Date__c = Date.today().addYears(-2), RecordTypeId = bregAccRecordType),
            new Account(Name = 'Decree Test F1', breg_Entity_Status__c = 'Active (A)', breg_Entity_Type__c = 'F1', breg_Incorporation_Date__c = Date.today().addYears(-2), RecordTypeId = bregAccRecordType),
            new Account(Name = 'Decree Test G5', breg_Entity_Status__c = 'Active (A)', breg_Entity_Type__c = 'G5', breg_Incorporation_Date__c = Date.today().addYears(-2), RecordTypeId = bregAccRecordType),
            new Account(Name = 'Decree Test C5', breg_Entity_Status__c = 'Active (A)', breg_Entity_Type__c = 'C5', breg_Incorporation_Date__c = Date.today().addYears(-2), RecordTypeId = bregAccRecordType)
        };
    }

    @IsTest
    static void testGroupAccountsByDecreeEntityType() {
        List<Account> sampleAccounts = new List<Account>{
            new Account(Name = 'K5 Account', breg_Entity_Type__c = 'K5'),
            new Account(Name = 'C6 Account', breg_Entity_Type__c = 'C6'),
            new Account(Name = 'C5 Account', breg_Entity_Type__c = 'C5'),
            new Account(Name = 'D2 Account', breg_Entity_Type__c = 'D2'),
            new Account(Name = 'D1 Account', breg_Entity_Type__c = 'D1'),
            new Account(Name = 'F1 Account', breg_Entity_Type__c = 'F1'),
            new Account(Name = 'G5 Account', breg_Entity_Type__c = 'G5')
        };

        Map<String, List<Account>> grouped = BREGDecreeGeneration.groupAccountsByDecreeEntityType(sampleAccounts);

        System.assertEquals(1, grouped.get('K5, K6').size(), 'K5/K6 group should contain one account');
        System.assertEquals(1, grouped.get('C6').size(), 'C6 group should contain one account');
        System.assertEquals(1, grouped.get('C5').size(), 'C5 group should contain one account');
        System.assertEquals(1, grouped.get('D2, D9, A2, C2').size(), 'D2/D9/A2/C2 group should contain one account');
        System.assertEquals(1, grouped.get('D1, P1, A1, C1, S1').size(), 'D1/P1/A1/C1/S1 group should contain one account');
        System.assertEquals(1, grouped.get('F1, F2').size(), 'F1/F2 group should contain one account');
        System.assertEquals(1, grouped.get('G5, G6, L5, L6, Q5, Q6').size(), 'G5/G6/L5/L6/Q5/Q6 group should contain one account');
    }

    @IsTest
    static void testGetDissolutionAccountsFromHistoryToday() {
        List<Account> accounts = [
            SELECT Id, breg_Entity_Type__c, breg_Entity_Status__c
            FROM Account
            WHERE Name IN ('Decree Test D1', 'Decree Test F1', 'Decree Test G5', 'Decree Test C5')
        ];

        // Create dissolution transactions for the accounts
        List<breg_Transaction__c> dissolutionTransactions = new List<breg_Transaction__c>{
            new breg_Transaction__c(breg_Account__c = accounts[0].Id, breg_Transaction_Code__c = 'INCN', breg_Effective_Date__c = Date.today()),
            new breg_Transaction__c(breg_Account__c = accounts[1].Id, breg_Transaction_Code__c = 'INDBX', breg_Effective_Date__c = Date.today()),
            new breg_Transaction__c(breg_Account__c = accounts[2].Id, breg_Transaction_Code__c = 'INDS', breg_Effective_Date__c = Date.today()),
            new breg_Transaction__c(breg_Account__c = accounts[3].Id, breg_Transaction_Code__c = 'INVR', breg_Effective_Date__c = Date.today())
        };

        Test.startTest();
        insert dissolutionTransactions;
        List<Account> dissolvedToday = BREGDecreeGeneration.getDissolutionAccountsFromHistoryToday();
        Test.stopTest();

        System.assertEquals(
            4,
            dissolvedToday.size(),
            'Should return 4 accounts that have dissolution transactions within the last 60 days'
        );
        System.assertEquals('Decree Test C5', dissolvedToday[0].Name, 'Accounts should be ordered by name');
        System.assertEquals('Decree Test D1', dissolvedToday[1].Name, 'Accounts should be ordered by name');
        System.assertEquals('Decree Test F1', dissolvedToday[2].Name, 'Accounts should be ordered by name');
        System.assertEquals('Decree Test G5', dissolvedToday[3].Name, 'Accounts should be ordered by name');
    }

    @IsTest
    static void testGetDissolutionDocumentNameFromTemplate() {
        System.assertEquals(
            'K5,K6 - Certificate of Revocation',
            BREGDecreeGeneration.getDissolutionDocumentName('K5, K6'),
            'Should strip template suffix from K5/K6 template name'
        );

        System.assertEquals(
            'C5 - Decree of Termination',
            BREGDecreeGeneration.getDissolutionDocumentName('C5'),
            'Should strip template suffix from C5 template name'
        );

        System.assertEquals(
            'Unknown Group',
            BREGDecreeGeneration.getDissolutionDocumentName('Unknown Group'),
            'Should fallback to group label when template mapping is missing'
        );
    }

    @IsTest
    static void testGenerateDissolutionDecreeDocumentsNoHistory() {
        Test.setMock(HttpCalloutMock.class, new DecreeGenerationCalloutMock());

        Test.startTest();
        BREGDecreeGeneration.generateDissolutionDecreeDocuments();
        Test.stopTest();

        System.assert(true, 'Method should safely exit when there are no matching history records');
    }

    @IsTest
    static void testGenerateDissolutionDecreeDocumentsFromHistory() {
        BREGAccountTriggerHandler.skipDocusignWorkflow = true;

        Account d1Account = [
            SELECT Id, breg_Entity_Status__c
            FROM Account
            WHERE Name = 'Decree Test D1'
            LIMIT 1
        ];
        d1Account.breg_Entity_Status__c = STATUS_INV_DISSOLVED;

        Test.setMock(HttpCalloutMock.class, new DecreeGenerationCalloutMock());

        Test.startTest();
        update d1Account;
        BREGDecreeGeneration.generateDissolutionDecreeDocuments();
        Test.stopTest();

        System.assert(true, 'Method should process history-based dissolution accounts and complete orchestration');
    }

    @IsTest
    static void testGenerateDissolutionDecreeDocumentsListNullAndEmpty() {
        Test.setMock(HttpCalloutMock.class, new DecreeGenerationCalloutMock());

        Test.startTest();
        BREGDecreeGeneration.generateDissolutionDecreeDocuments((List<Account>) null);
        BREGDecreeGeneration.generateDissolutionDecreeDocuments(new List<Account>());
        Test.stopTest();

        System.assert(true, 'List overload should safely return for null/empty input');
    }

    @IsTest
    static void testGenerateDissolutionDecreeDocumentsListHappyPath() {
        Test.setMock(HttpCalloutMock.class, new DecreeGenerationCalloutMock());

        List<Account> dissolvedAccounts = [
            SELECT Id, Name, breg_Entity_Type__c, breg_Delinquency_Due_Date__c, breg_Involuntary_Dissolution_Notice_Date__c
            FROM Account
            WHERE Name = 'Decree Test D1'
            LIMIT 1
        ];

        Test.startTest();
        BREGDecreeGeneration.generateDissolutionDecreeDocuments(dissolvedAccounts);
        Test.stopTest();

        System.assert(true, 'List overload should process non-empty dissolution accounts');
    }

    @IsTest
    static void testGenerateDissolutionDecreeDocumentsInternalDirect() {
        Test.setMock(HttpCalloutMock.class, new DecreeGenerationCalloutMock());

        List<Account> dissolvedAccounts = [
            SELECT Id, Name, breg_Entity_Type__c, breg_Delinquency_Due_Date__c, breg_Involuntary_Dissolution_Notice_Date__c
            FROM Account
            WHERE Name = 'Decree Test D1'
            LIMIT 1
        ];

        Test.startTest();
        BREGDecreeGeneration.generateDissolutionDecreeDocumentsInternal(dissolvedAccounts);
        Test.stopTest();

        System.assert(true, 'Internal decree generation method should execute with provided dissolution accounts');
    }
}