@IsTest
private class BREGBigObjectRelatedListControllerTest {

    // Hold reference to the related transaction record
    private static Id transactionId;
    private static Id accountId;

    /**
     * Shared setup: create one parent transaction record
     * and insert 10 related Big Object records
     */
    @testSetup
    static void setupData() {   
         // --- 1. Create parent record ---
        BREGTestDataFactory.createEntityAccounts(1);
        accountId = [SELECT Id FROM Account LIMIT 1].Id;
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 50; i++) {
            Contact c = new Contact();
            c.FirstName = 'Test';
            c.LastName = 'User' + i;
            c.AccountId = accountId;
            c.Email = 'testuser' + i + '@example.com';
            contacts.add(c);
    }
    insert contacts;
    }
            

    // ─────────────────────────────────────────────
    // TESTS
    // ─────────────────────────────────────────────

    @IsTest
    static void testGetFieldLabels() {
        Test.startTest();
        Map<String, String> labels = BREGBigObjectRelatedListController.getFieldLabels(
            'breg_BRIM_Transaction_Event__b',
            new List<String>{
                'breg_BRIM_CREATED_BY__c',
                'breg_BRIM_EVENT_TYPE__c',
                'breg_BRIM_TRANS_ID__c'
            }
        );
        Test.stopTest();

        System.assertNotEquals(0, labels.size(), 'Expected some field labels returned');
        System.assert(labels.containsKey('breg_BRIM_EVENT_TYPE__c'), 'Expected EVENT_TYPE__c label');
    }

    @IsTest
    static void testGetFieldLabelsIncludesUnknownFieldHint() {
        Test.startTest();
        Map<String, String> labels = BREGBigObjectRelatedListController.getFieldLabels(
            'Contact',
            new List<String>{ 'FirstName', 'Definitely_Not_A_Field__c' }
        );
        Test.stopTest();

        System.assertEquals('Definitely_Not_A_Field__c (Unknown field)', labels.get('Definitely_Not_A_Field__c'));
        System.assert(labels.containsKey('FirstName'), 'Known fields should still be returned');
    }

    @IsTest
    static void testQueryPageBasic() {
        accountId = [SELECT Id FROM Account LIMIT 1].Id;
        Test.startTest();
        System.debug(accountId);
        BREGBigObjectRelatedListController.PageResult result = BREGBigObjectRelatedListController.queryPageUnwrapped(
            'Contact',
            'AccountId',
            String.valueOf(accountid),
            new List<String>{ 'FirstName', 'LastName', 'Email' },
            10,
            'AccountId',
            'ASC',
            null,
            true
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected PageResult not null');
        System.assert(result.rows.size() > 0, 'Expected rows returned');
        System.assertNotEquals(null, result.nextCursor, 'Expected nextCursor for pagination');
        System.assertEquals(10, result.rows.size(), 'Expected 10 records (page size)');
    }

    @IsTest
    static void testQueryPagePrevPage() {
        // First page
        accountId = [SELECT Id FROM Account LIMIT 1].Id;
        BREGBigObjectRelatedListController.PageResult firstPage = BREGBigObjectRelatedListController.queryPageUnwrapped(
            'Contact',
            'AccountId',
            String.valueOf(accountid),
            new List<String>{ 'FirstName', 'LastName', 'Email' },
            5,
            'AccountId',
            'ASC',
            null,
            true
        );

        // Previous page (reverse)
        Test.startTest();
        BREGBigObjectRelatedListController.PageResult prevPage = BREGBigObjectRelatedListController.queryPageUnwrapped(
           'Contact',
            'AccountId',
            String.valueOf(accountid),
            new List<String>{ 'FirstName', 'LastName', 'Email' },
            3,
            'AccountId',
            'ASC',
            null,
            true
        );
        Test.stopTest();

        System.assertNotEquals(null, prevPage, 'Expected non-null previous page');
        System.assert(prevPage.rows.size() == 10, 'Expected 10 rows on previous page');
    }

    @IsTest
    static void testQueryPageUsesSortFieldWhenRequestedFieldsUnknown() {
        accountId = [SELECT Id FROM Account LIMIT 1].Id;

        Test.startTest();
        BREGBigObjectRelatedListController.PageResult result = BREGBigObjectRelatedListController.queryPageUnwrapped(
            'Contact',
            'AccountId',
            String.valueOf(accountId),
            new List<String>{ 'Nope__c' },
            10,
            'Email',
            'ASC',
            null,
            true
        );
        Test.stopTest();

        System.assert(result.rows.size() > 0, 'Expected fallback query to still return rows');
        System.assertNotEquals(null, result.rows[0].values.get('Email'), 'Sort field should be selected when requested fields are unknown');
    }

    @IsTest
    static void testQueryPageWithCursorCoversComparatorAndCoercion() {
        accountId = [SELECT Id FROM Account LIMIT 1].Id;

        BREGBigObjectRelatedListController.PageResult firstPage = BREGBigObjectRelatedListController.queryPageUnwrapped(
            'Contact',
            'AccountId',
            String.valueOf(accountId),
            new List<String>{ 'FirstName', 'LastName', 'Email' },
            10,
            'Email',
            'ASC',
            null,
            true
        );

        Test.startTest();
        BREGBigObjectRelatedListController.PageResult nextPage = BREGBigObjectRelatedListController.queryPageUnwrapped(
            'Contact',
            'AccountId',
            String.valueOf(accountId),
            new List<String>{ 'FirstName', 'LastName', 'Email' },
            10,
            'Email',
            'ASC',
            firstPage.nextCursor,
            true
        );
        Test.stopTest();

        System.assertNotEquals(null, nextPage, 'Expected next page result');
        System.assert(nextPage.rows.size() > 0, 'Expected cursor-based page to return rows');
    }

    @IsTest
    static void testQueryPageInvalidInputs() {
        
        Boolean threw = false;
        try {
            Test.startTest();
            BREGBigObjectRelatedListController.queryPageUnwrapped(
                null, null, null, null, null, null, null, null, null
            );
            Test.stopTest();
        } catch (Exception e) {
            threw = true;
        }
        System.assert(threw, 'Expected validation exception when missing parameters');
    }
}