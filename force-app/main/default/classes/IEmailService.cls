public interface IEmailService {
    Messaging.SingleEmailMessage getEmail(EmailTemplate template, Map<String, String> bodyCustomMergeFieldMap, String[] toAddresses);
    Messaging.SingleEmailMessage getEmail(EmailTemplate template, Map<String, String> bodyCustomMergeFieldMap, String[] toAddresses, SObject whatIdRecord);
}