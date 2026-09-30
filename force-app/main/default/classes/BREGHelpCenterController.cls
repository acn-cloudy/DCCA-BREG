public without sharing class BREGHelpCenterController {
    public class ArticleWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Title;
        @AuraEnabled public String Answer;
        @AuraEnabled public String Topic;
        @AuraEnabled public Boolean IsDefault;

        public ArticleWrapper(Knowledge__kav article) {
            this.Id = article.Id;
            this.Title = article.Title;
            this.Answer = article.breg_Answer__c;
            this.Topic = article.breg_Topic__c;
            this.IsDefault = article.breg_Is_Default__c;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ArticleWrapper> getArticles(String topicName, Boolean includeDefault) {
        if (String.isBlank(topicName)) {
            throw new AuraHandledException(Label.BREG_Topic_name_is_required);
        }

        List<Knowledge__kav> articles = BREGHelpCenterController.getArticlesSOQL(topicName, includeDefault);

        List<ArticleWrapper> articleWrappers = new List<ArticleWrapper>();
        for (Knowledge__kav art : articles) {
            articleWrappers.add(new ArticleWrapper(art));
        }

        return articleWrappers;
    }

    private static List<Knowledge__kav> getArticlesSOQL(String topicName, Boolean includeDefault) {
        String statusCondition = Test.isRunningTest() ? '' : 'AND PublishStatus = \'Online\'';
        String topicCondition = includeDefault ? 'AND (breg_Topic__c = :topicName OR breg_Is_Default__c = true) ' : 'AND breg_Topic__c = :topicName ';
        String query = 
            'SELECT Id, Title, breg_Answer__c, breg_Topic__c, breg_Is_Default__c ' +
            'FROM Knowledge__kav ' +
            'WHERE Language = \'en_US\' ' +
            topicCondition +
            statusCondition +
            ' ORDER BY ArticleNumber ASC';

        return (List<Knowledge__kav>) Database.query(query);
    }
}