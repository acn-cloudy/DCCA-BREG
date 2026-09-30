public inherited sharing class EmailTemplatesSelector extends fflib_SObjectSelector implements IEmailTemplatesSelector {

    public static final EmailTemplatesSelector INSTANCE = (EmailTemplatesSelector)fflibe_Applicationimpl.SELECTOR.newInstance(EmailTemplate.getSObjectType());
    
    public EmailTemplatesSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            EmailTemplate.Id,
            EmailTemplate.Body,
            EmailTemplate.DeveloperName,
            EmailTemplate.HtmlValue,
            EmailTemplate.Subject
        };
    }

    public Schema.SObjectType getSObjectType() {
        return EmailTemplate.getSObjectType();
    }

    public EmailTemplate[] selectByDeveloperNames(Set<String> developerNames) {
        return Database.query(
            newQueryFactory()
                .setCondition('DeveloperName IN :developerNames')
                .toSOQL()
        );
    }
}