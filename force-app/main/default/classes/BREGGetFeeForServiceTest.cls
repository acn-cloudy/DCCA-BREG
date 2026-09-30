@isTest
public class BREGGetFeeForServiceTest {
    @testSetup
    static void setupData() {
        // Insert test data for breg_Fee__c
        insert new List<breg_Fee__c>{
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity List',
                breg_Is_Purchaseable_Document__c = true,
                breg_Fee_Amount__c = 0.05,
                breg_Purchase_Type_Fee_type__c = 'Form Fees',
                breg_Document_Description__c = 'Document description'
            ),
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity',
                breg_Is_Purchaseable_Document__c = true,
                breg_Fee_Amount__c = 0.05,
                breg_Purchase_Type_Fee_type__c = 'Form Fees',
                breg_Document_Description__c = 'Document description'
            ),
            new breg_Fee__c(
                breg_Record_Type__c = 'Annual Reminder',
                breg_Is_Purchaseable_Document__c = true,
                breg_Fee_Amount__c = 0.05,
                breg_Purchase_Type_Fee_type__c = 'Form Fees'
            ),
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity List',
                breg_Is_Purchaseable_Document__c = false,
                breg_Fee_Amount__c = 0.05,
                breg_Purchase_Type_Fee_type__c = 'Form Fees'
            ),
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity',
                breg_Is_Purchaseable_Document__c = true,
                breg_Fee_Amount__c = 0.10,
                breg_Purchase_Type_Fee_type__c = 'Form Fees'
            ),
            new breg_Fee__c(
                breg_Record_Type__c = 'Entity',
                breg_Is_Purchaseable_Document__c = true,
                breg_Fee_Amount__c = 0.05,
                breg_Purchase_Type_Fee_type__c = 'Certificate'
            )
        };
    }

    @isTest
    static void testGetFeeWithValidFilters() {
        List<String> fieldsToSelect = new List<String>{
            'Id',
            'Name',
            'breg_Record_Type__c',
            'breg_Fee_Amount__c',
            'breg_Is_Purchaseable_Document__c',
            'breg_Purchase_Type_Fee_type__c'
        };

        Map<String, Object> filters = new Map<String, Object>{
            'breg_Record_Type__c' => 'Entity List,Entity',
            'breg_Is_Purchaseable_Document__c' => true,
            'breg_Fee_Amount__c' => 0.05,
            'breg_Purchase_Type_Fee_type__c' => 'Form Fees',
            'breg_Document_Description__c' => 'Document description'
        };

        Test.startTest();
        List<breg_Fee__c> results = BREGGetFeeForService.getFees(fieldsToSelect, filters, null, null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return exactly 2 matching fees');
        for (breg_Fee__c fee : results) {
            System.assertEquals(0.05, fee.breg_Fee_Amount__c);
            System.assertEquals(true, fee.breg_Is_Purchaseable_Document__c);
            System.assertEquals('Form Fees', fee.breg_Purchase_Type_Fee_type__c);
            System.assert(fieldsToSelect.contains('breg_Purchase_Type_Fee_type__c'));
        }
    }

    @isTest
    static void testGetFeeWithNoMatch() {
        List<String> fieldsToSelect = new List<String>{ 'Id', 'Name', 'breg_Record_Type__c', 'breg_Fee_Amount__c' };

        Map<String, Object> filters = new Map<String, Object>{
            'breg_Record_Type__c' => 'Agent List',
            'breg_Is_Purchaseable_Document__c' => false,
            'breg_Fee_Amount__c' => 999.99,
            'breg_Purchase_Type_Fee_type__c' => 'Invalid'
        };

        List<breg_Fee__c> results = BREGGetFeeForService.getFees(fieldsToSelect, filters, 'breg_Record_Type__c', null);

        System.assertEquals(0, results.size(), 'Should return no fees with unmatched filters');
    }

    @isTest
    static void testGetFeeWithFilterLogicAndListValues() {
        List<String> fieldsToSelect = new List<String>{
            'Id',
            'Name',
            'breg_Record_Type__c',
            'breg_Fee_Amount__c',
            'breg_Is_Purchaseable_Document__c',
            'breg_Purchase_Type_Fee_type__c'
        };

        Map<String, Object> filters = new Map<String, Object>{
            'breg_Record_Type__c' => 'Entity,Entity List',
            'breg_Purchase_Type_Fee_type__c' => 'Certificate'
        };

        String filterLogic = '1 AND NOT 2';

        Test.startTest();
        List<breg_Fee__c> results = BREGGetFeeForService.getFees(fieldsToSelect, filters, null, filterLogic);
        Test.stopTest();

        System.assertEquals(4, results.size(), 'Should return only records with matching record type but NOT Certificate');

        for (breg_Fee__c fee : results) {
            System.assertEquals(false, fee.breg_Purchase_Type_Fee_type__c == 'Certificate', 'Filtered out Certificate type');
            System.assert(new List<String>{ 'Entity', 'Entity List' }.contains(fee.breg_Record_Type__c));
        }
    }

    @isTest
    static void testGetFeeWithNotInFilterLogic() {
        List<String> fieldsToSelect = new List<String>{ 'Id', 'breg_Purchase_Type_Fee_type__c' };

        Map<String, Object> filters = new Map<String, Object>{ 'breg_Purchase_Type_Fee_type__c' => 'Form Fees,Certificate' };

        String filterLogic = 'NOT 1';

        Test.startTest();
        List<breg_Fee__c> results = BREGGetFeeForService.getFees(fieldsToSelect, filters, null, filterLogic);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should exclude all known types via NOT IN');
    }

    @isTest
    static void testGetFeeWithNotNullLogic() {
        List<String> fieldsToSelect = new List<String>{ 'Id', 'breg_Fee_Amount__c' };

        Map<String, Object> filters = new Map<String, Object>{ 'breg_Fee_Amount__c' => null };

        String filterLogic = 'NOT 1';

        Test.startTest();
        List<breg_Fee__c> results = BREGGetFeeForService.getFees(fieldsToSelect, filters, null, filterLogic);
        Test.stopTest();

        System.assertEquals(6, results.size(), 'Should return all records where Fee_Amount__c is not null');

        for (breg_Fee__c fee : results) {
            System.assertNotEquals(null, fee.breg_Fee_Amount__c, 'Fee amount must not be null');
        }
    }

    @isTest
    static void testGetFeeWithStringNotInList() {
        List<String> fieldsToSelect = new List<String>{ 'Id', 'breg_Document_Description__c' };

        Map<String, Object> filters = new Map<String, Object>{
            'breg_Document_Description__c' => new List<String>{ 'Document description', 'Certificate description' }
        };
        String filterLogic = 'NOT 1';

        Test.startTest();
        List<breg_Fee__c> results = BREGGetFeeForService.getFees(fieldsToSelect, filters, null, filterLogic);
        Test.stopTest();

        System.assertEquals(4, results.size(), 'Should return only records where description is not in provided list');

        for (breg_Fee__c fee : results) {
            System.assert(
                !new List<String>{ 'Document description', 'Certificate description' }.contains(fee.breg_Document_Description__c),
                'Description should not match excluded values'
            );
        }
    }

    @isTest
    static void testFieldTypeResolver() {
        Assert.areEqual(
            Schema.DisplayType.String,
            new BREGGetFeeForService.FieldTypeResolver().getFieldType('breg_Form_Configuration__r.breg_Suffix_Code__c', 'breg_Fee__c')
        );
    }
}

//BREGGetFeeForService.getFee(new Set<String>{'Id', 'Name', 'breg_Record_Type__c', 'breg_Fee_Amount__c'}, new Map<String, Object>{ 'breg_Record_Type__c' => 'Entity List,Entity', 'breg_Is_Purchaseable_Document__c' => true, 'breg_Fee_Amount__c' => 0.05, 'breg_Purchase_Type_Fee_type__c' => 'Form Fees'})