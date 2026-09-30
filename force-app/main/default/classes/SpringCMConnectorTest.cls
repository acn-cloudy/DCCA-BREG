@isTest
private class SpringCMConnectorTest {
    @TestSetup
    static void setupTestData() {
        // 2b) Insert a session record (or we can create it fresh in code).
        SpringCLM_Session__c session = new SpringCLM_Session__c(
            AccessToken__c = 'InitialAccess',
            RefreshToken__c = 'InitialRefresh'
        );
        insert session;
    }

    @isTest
    static void testinitiateConnection() {
        String recordTypeId 
            = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(FirstName = 'Test Account', LastName='aaa', RecordTypeId = recordTypeId);        
        insert acc;

        SpringCMEos__EOS_Type__c eos = new SpringCMEos__EOS_Type__c(
            Name = 'Account', 
            SpringCMEos__Folder_Name_Format__c = '{0} - {1}',
            SpringCMEos__Variables__c = 'Account.Name,Account.Id',
            SpringCMEos__Path__c = '/All Divisions/Account',
            SpringCMEos__Folder_Name__c = '{!Account.Name} - {!Account.Id}'
        );
        insert eos;

        Test.startTest();
        SpringCMConnector.deletListBuilderFiles(acc.Id);
        SpringCMConnector.getFolderURL(acc.Id);
        SpringCMConnector.createFile(acc.Id, 'asdfsa.pdf', Blob.valueOf('sdfasf'));
        SpringCMConnector.updateFileDescription('https://test.salesforce.com','sdfsaaffsf');
        Test.stopTest();
    }

    @isTest
    static void testAsync() {
        String recordTypeId 
            = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(FirstName = 'Test Account', LastName='aaa', RecordTypeId = recordTypeId);
        insert acc;
        Test.startTest();
        SpringCMConnector.updateFileDesAndFolder('test', 'test', acc.Id);
        SpringCMConnector.updateFilesAndFolder(new List<String> {'https://test.salesforce.com'}, acc.Id);
        Test.stopTest();
    }
    @isTest
    static void testGetFolderUploadLink() {
        Test.startTest();
        SpringCMConnector.getFolderUploadLink('testFolder');
        Test.stopTest();
    }
    @isTest
    static void testDeleteDocument() {
        Test.startTest();
        SpringCMConnector.deleteDocument('testFolder');
        Test.stopTest();
    }
    @isTest
    static void testUpdateDescription() {
        Test.startTest();
        SpringCMConnector.updateDescription('testFiles', 'test');
        Test.stopTest();
    }
    @isTest
    static void testUpdateFilesAndFolderAsync(){
        String recordTypeId 
            = Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(FirstName = 'Test Account', LastName='aaa', RecordTypeId = recordTypeId);
        insert acc;

        Test.startTest();
        SpringCMConnector.updateFilesAndFolderAsync(new List<String>{'testFiles'}, acc.Id);
        Test.stopTest();
    }
    @isTest
    static void testUploadDocuments(){
        Test.startTest();
        Map<String, Blob> params = new Map<String, Blob>();
        params.put('Test', Blob.valueOf(''));
        
        Map<String, Blob> params2 = new Map<String, Blob>();
        params2.put('', Blob.valueOf('TEST 2'));
        
        Map<String, Blob> params3 = new Map<String, Blob>();
        params3.put('Test 3', Blob.valueOf('TEST 3'));

        SpringCMFolder folder = new SpringCMFolder();
        folder.CreateDocumentHref = 'Test';

        try{ 
            SpringCMConnector.uploadDocuments(folder, params);
        } catch(Exception ex){
            // Exceptions are thrown on class for checking
        }

        try{ 
            SpringCMConnector.uploadDocuments(folder, params2);
        } catch(Exception ex){
            // Exceptions are thrown on class for checking
        }

        try{ 
            SpringCMConnector.uploadDocuments(folder, params3);
        } catch(Exception ex){
            // Exceptions are thrown on class for checking
        }
    }
    @isTest
    static void testGeToken() {
        Test.startTest();
        SpringCMConnector.getToken();
        Test.stopTest();
    }
}