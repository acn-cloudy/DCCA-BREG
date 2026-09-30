@isTest
public class BREGHelpCenterControllerTest {

    @testSetup
    static void setupTestData() {
        Knowledge__kav article = new Knowledge__kav(
            Title = 'Test Article',
            breg_Answer__c = 'This is a test answer',
            breg_Topic__c = 'Start',
            UrlName = 'test-article',
            Language = 'en_US'
        );
        insert article;
    }

    @isTest
    static void testgetArticles_success() {
        Test.startTest();
        List<BREGHelpCenterController.ArticleWrapper> result = BREGHelpCenterController.getArticles('Start', false);
        Test.stopTest();

       Assert.areEqual(1, result.size());
       Assert.areEqual('Test Article', result[0].Title);
       Assert.areEqual('This is a test answer', result[0].Answer);
    }

    @isTest
    static void testgetArticles_noArticles() {
        Test.startTest();
        List<BREGHelpCenterController.ArticleWrapper> result = BREGHelpCenterController.getArticles('NonExistentTopic', false);
        Test.stopTest();

       Assert.areEqual(0, result.size());
    }


}