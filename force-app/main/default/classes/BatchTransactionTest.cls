/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Test class for BatchTransaction
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* PacPoint-LC040819 - Created for DCCA phase 1
* @author       Lucian Ciobanu - PacificPointCorp
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
@isTest 
public class BatchTransactionTest {

    @isTest
    public static void Test1(){
        
		// Data setup
        String orgId = UserInfo.getOrganizationId();
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
        String uniqueName = orgId + dateString + randomInt;
        String unserializedFields = '{"data": [{"Transaction__c":"TotalAmount__c"},{"Account__r":"Name"}]}';

        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User dummyUser = new User(
                Alias = 'standu',
                Email = uniqueName + '@test' + orgId + '.org',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                Division__c = 'BREG',
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueName + '@test' + orgId + '.org');
        insert dummyUser;

        User dummyUserPVL = new User(
                Alias = 'stapvl',
                Email = uniqueName + '@test' + orgId + '.org',
                EmailEncodingKey = 'UTF-8',
                LastName = 'TestPVL',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                Division__c = 'PVL',
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueName +'pvl'+ '@test' + orgId + '.org');
        insert dummyUserPVL;

        User dummyUserOAH = new User(
                Alias = 'staoah',
                Email = uniqueName + '@test' + orgId + '.org',
                EmailEncodingKey = 'UTF-8',
                LastName = 'TestOAH',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                Division__c = 'OAH',
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = uniqueName +'oah'+ '@test' + orgId + '.org');
        insert dummyUserOAH;

        Account acc = new Account();
        acc.Name = 'Test936844';
        acc.OAH_Case_Number__c = 'x';
        acc.ProjectNumber__c = 'y';
        insert acc;

        List<NewBatchTransactionComponentConfig__mdt> batchTransConfigList = BatchTransaction.getBatchTransactionConfig('Search Criteria');


        CashierCode__c cc = new CashierCode__c();
        cc.Name = '000 - Test';
        cc.Amount__c = 10.00;
        insert cc;

        BatchTransaction.SearchFields searchFields = new BatchTransaction.SearchFields();
        searchFields.label = 'Name';
        searchFields.name = 'name';
        searchFields.value = 'Test936844 Inc';

        List<BatchTransaction.SearchFields> searchFieldsList = new List<BatchTransaction.SearchFields>();
        searchFieldsList.add(searchFields);

		// Run the code
        Test.startTest();
            System.runAs(dummyUser) {
                BatchTransaction.getInitialValues('TransactionListView');
                List<Account> accs = BatchTransaction.searchLines(searchFieldsList, searchFieldsList, 5, 1);
                BatchTransaction.saveTransactions('[{ "id" : "' + acc.Id + '", "workitem" : "", "description" : "" }]', '[{ "code" : "' + cc.Id + '", "description" : "", "amount" : 100 }]',searchFieldsList, unserializedFields);

                // Verify Results
                System.assertEquals(1, accs.size());
                System.assertEquals(1, [SELECT COUNT() FROM Transaction__c]);
                System.assertEquals(1, [SELECT COUNT() FROM TransactionLine__c]);

                BatchTransaction.saveTransactions('[{ "id" : "' + acc.Id + '", "workitem" : "", "description" : "" }]', '[{ "code" : "", "description" : "", "amount" : 100 }]',searchFieldsList, unserializedFields);
            }
            System.runAs(dummyUserPVL) {
                BatchTransaction.getInitialValues('TransactionListView');
            }
            System.runAs(dummyUserOAH) {
                BatchTransaction.getInitialValues('TransactionListView');
            }
        Test.stopTest();
        

    }
}