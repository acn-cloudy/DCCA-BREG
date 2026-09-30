public inherited sharing class EmailAlertTriggersSelector extends fflib_SObjectSelector {

    public static final EmailAlertTriggersSelector INSTANCE = (EmailAlertTriggersSelector)fflibe_Applicationimpl.SELECTOR.newInstance(EmailAlertTrigger__c.getSObjectType());

    public EmailAlertTriggersSelector() {
        super(false, false, false, false);
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new Schema.SObjectField[] {
            EmailAlertTrigger__c.Email__c,
            EmailAlertTrigger__c.Contact__c,
            EmailAlertTrigger__c.User__c,
            EmailAlertTrigger__c.Filing__c,
            EmailAlertTrigger__c.Id,
            EmailAlertTrigger__c.Case__c,
            EmailAlertTrigger__c.RelatedRecordId__c
        };
    }

    public Schema.SObjectType getSObjectType() {
        return EmailAlertTrigger__c.getSObjectType();
    }

    public EmailAlertTrigger__c[] selectByIds(Set<Id> emailAlertTriggerIds) {
        return Database.query(
            newQueryFactory()
                .selectField('Filing__r.RecordTypeName__c')
                .selectField('Filing__r.Status__c')
                .selectField('Filing__r.ConfidentialityLevel__c')
                .selectField('Filing__r.DocumentCategory__c')
                .selectField('Filing__r.DocumentType__c')
                .selectField('Filing__r.FilingDescription__c')
                .selectField('Filing__r.PUCCaseNumber__c')
                .selectField('Filing__r.PUC_Case__r.DocketTitle__c')
                .selectField('Filing__r.Originating_Account__c')
                .selectField('Filing__r.Name')
                .setCondition('Id in: emailAlertTriggerIds')   
                .toSOQL()
        );
    }

    

}