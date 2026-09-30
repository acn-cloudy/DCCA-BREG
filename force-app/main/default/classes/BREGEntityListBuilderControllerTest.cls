@isTest
private class BREGEntityListBuilderControllerTest {
    @TestSetup static void testSetup() {
        BREGTestDataFactory.createFormConfigurations();
        BREGTestDataFactory.createFeeSettings();
        BREGTestDataFactory.createEntityAccounts(5); // Create 5 test accounts
    }

    @isTest
    static void testSearch() {
        // Prepare input
        BREGEntityListBuilderController.SearchInput input = new BREGEntityListBuilderController.SearchInput();
        input.recordTypes = new List<String>{'D1'};
        input.name = 'Acme';
        input.zipCodes = '12345';
        input.startDate = '2020-01-01';
        input.endDate = '2025-12-31';

        Test.startTest();
        BREGEntityListBuilderController.SearchResult result = BREGEntityListBuilderController.search(input);
        Test.stopTest();

        System.assert(result != null, 'Search result should not be null');
        System.assertEquals(1, result.RecordsFound, 'Should find 1 matching records');
        System.assertEquals(0.05, result.PricePerRecord, 'Should return default price');
        System.assertEquals(0.05, result.Total, 'Total should equal price * count');
    }

    @isTest
    static void testUpsertList() {
        // Prepare input
        BREGEntityListBuilderController.SearchInput input = new BREGEntityListBuilderController.SearchInput();
        input.recordTypes = new List<String>{'D1', 'Q5'};
        input.name = 'Acme';
        input.zipCodes = '12345';
        input.startDate = '2020-01-01';
        input.endDate = '2025-12-31';

        Test.startTest();
        Id entityListId = BREGEntityListBuilderController.upsertList(input);
        Test.stopTest();

        Assert.isTrue(entityListId != null, 'Entity list id should not be null');
    }
}