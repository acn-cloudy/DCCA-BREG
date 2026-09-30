@IsTest
public class TaxClearanceApiHelperTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createLicense();
        TaxClearanceApi__c settings = new TaxClearanceApi__c();
        settings.EndpointUrl__c = 'https://test.api.test';
        settings.Username__c = 'test';
        settings.Password__c = 'test';
        settings.SetupOwnerId = UserInfo.getOrganizationId();
        insert settings;
    }

    @IsTest
    static void testRunClearance() {
        License__c l = [SELECT Id FROM License__c LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.StateExciseTaxNumber__c = '1';
        update acc;

        l.Licensee__c = acc.Id;
        update l;

        Test.setMock(HttpCalloutMock.class, new RunClearanceDResultMockImpl());
        Test.startTest();
        TaxClearanceApiHelper.runClearance(l.Id);
        Test.stopTest();
    }

    public class RunClearanceNoResultsMockImpl implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req) {
            TaxClearanceApiHelper.TaxClearanceResponse resp = new TaxClearanceApiHelper.TaxClearanceResponse();
            resp.feins = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            TaxClearanceApiHelper.TaxClearanceResult feinsResult = new TaxClearanceApiHelper.TaxClearanceResult();
            feinsResult.id = '123';
            feinsResult.message = 'No Results';
            resp.feins.add(feinsResult);

            HttpResponse ret = new HttpResponse();
            ret.setStatusCode(200);
            ret.setBody(JSON.serialize(resp));
            return ret;
        }
    }

    public class RunClearanceErr400MockImpl implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req) {
            HttpResponse ret = new HttpResponse();
            ret.setStatusCode(400);
            ret.setBody('');
            return ret;
        }
    }

    public class RunClearanceDResultMockImpl implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req) {
            TaxClearanceApiHelper.TaxClearanceResponse resp = new TaxClearanceApiHelper.TaxClearanceResponse();
            resp.feins = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            resp.ssns = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            resp.tax_ids = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            TaxClearanceApiHelper.TaxClearanceResult feinsResult = new TaxClearanceApiHelper.TaxClearanceResult();
            feinsResult.id = '1233435';
            feinsResult.results = new List<TaxClearanceApiHelper.TaxClearanceResultResult>();
            TaxClearanceApiHelper.TaxClearanceResultResult feinsResultResult =
                    new TaxClearanceApiHelper.TaxClearanceResultResult();
            feinsResultResult.status_code = 'D';
            feinsResultResult.effective_from = Datetime.now().format('M/d/y');
            feinsResultResult.name = 'test';
            feinsResultResult.new_tax_id = '1';
            feinsResultResult.tax_id = '1';
            feinsResult.results.add(feinsResultResult);
            resp.feins.add(feinsResult);
            resp.ssns.add(feinsResult);
            resp.tax_ids.add(feinsResult);

            HttpResponse ret = new HttpResponse();
            ret.setStatusCode(200);
            ret.setBody(JSON.serialize(resp));
            return ret;
        }
    }

    public class RunClearanceYResultMockImpl implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req) {
            TaxClearanceApiHelper.TaxClearanceResponse resp = new TaxClearanceApiHelper.TaxClearanceResponse();
            resp.feins = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            resp.ssns = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            resp.tax_ids = new List<TaxClearanceApiHelper.TaxClearanceResult>();
            TaxClearanceApiHelper.TaxClearanceResult feinsResult = new TaxClearanceApiHelper.TaxClearanceResult();
            feinsResult.id = '1233435';
            feinsResult.results = new List<TaxClearanceApiHelper.TaxClearanceResultResult>();
            TaxClearanceApiHelper.TaxClearanceResultResult feinsResultResult =
                    new TaxClearanceApiHelper.TaxClearanceResultResult();
            feinsResultResult.status_code = 'Y';
            feinsResultResult.effective_from = Datetime.now().format('M/d/y');
            feinsResultResult.name = 'test';
            feinsResultResult.new_tax_id = '1';
            feinsResultResult.tax_id = '1';
            feinsResult.results.add(feinsResultResult);
            resp.feins.add(feinsResult);
            resp.ssns.add(feinsResult);
            resp.tax_ids.add(feinsResult);

            HttpResponse ret = new HttpResponse();
            ret.setStatusCode(200);
            ret.setBody(JSON.serialize(resp));
            return ret;
        }
    }
}