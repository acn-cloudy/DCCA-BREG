@isTest
public class ManagedContentControllerTest {
    @IsTest(SeeAllData=true)
    static void test_getContent(){
        List<ConnectApi.ManagedContentVersion> items = ManagedContentController.getContentList(0, 4, null, 'DCCA_News');
        Test.startTest();
        ManagedContentController.getContent(items.get(0).contentKey, 0, 10, null, 'DCCA_News');
        Test.stopTest();
    }
    
    @IsTest(SeeAllData=true)
    static void test_getContentList(){
        List<ConnectApi.ManagedContentVersion> items = ManagedContentController.getContentList(0, 4, null, 'DCCA_News');
    }

    @IsTest(SeeAllData=true)
    static void test_getContentCollection(){
        ConnectApi.ManagedContentVersionCollection c = ManagedContentController.getContentCollection(0, 4, null, null, 'DCCA_News');
    }

    @IsTest(SeeAllData=true)
    static void test_getContentCollectionWithTopic(){
        ConnectApi.ManagedContentVersionCollection c = ManagedContentController.getContentCollection(0, 4, null, 'test', 'DCCA_News');
    }
}