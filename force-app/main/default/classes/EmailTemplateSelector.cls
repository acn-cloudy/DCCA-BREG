public class EmailTemplateSelector {
    // get Email Template by name list use Soql Query
    public static List<EmailTemplate> getEmailTemplates(List<String> templateNames) {
        return [SELECT Id, Name FROM EmailTemplate WHERE Name IN :templateNames];
    }
    
}