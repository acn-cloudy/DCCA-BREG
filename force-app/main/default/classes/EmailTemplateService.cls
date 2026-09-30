public class EmailTemplateService {
    // Create method to query Email templates and return map of Name to email template with paramaters list of names
    public static Map<String, String> getEmailTemplatesIds(Set<String> names) {
        Map<String, String> emailTemplates = new Map<String, String>();
        for (EmailTemplate template : [SELECT Id, Name, Subject, HtmlValue, Body FROM EmailTemplate WHERE Name IN :names]) {
            emailTemplates.put(template.Name, template.Id);
        }
        return emailTemplates;
    }    
}