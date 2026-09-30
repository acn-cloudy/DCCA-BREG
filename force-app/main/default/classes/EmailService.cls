public inherited sharing class EmailService implements IEmailService {

    public static EmailService INSTANCE = (EmailService)fflibe_Applicationimpl.SERVICE.newInstance(IEmailService.class);

    public static OrgWideEmailAddress defaultOrgWideEmail {
        get {
            if (defaultOrgWideEmail == null) {
                defaultOrgWideEmail = ((IOrgWideEmailAddressSelector)fflibe_Applicationimpl.SELECTOR.newInstance(OrgWideEmailAddress.sObjectType)).getDefaultOrgWideEmailAddress();
            }
            return defaultOrgWideEmail;
        }
        private set;
    }


    public Messaging.SingleEmailMessage getEmail(EmailTemplate template, Map<String, String> bodyCustomMergeFieldMap, String[] toAddresses) {
        return this.getEmail(template, bodyCustomMergeFieldMap, toAddresses, null);
    }

    public Messaging.SingleEmailMessage getEmail(EmailTemplate template, Map<String, String> bodyCustomMergeFieldMap, String[] toAddresses, SObject whatIdRecord) {
        String htmlBody = template.HtmlValue;
        String plainBody = template.Body;
        String subject = template.Subject;

        // replace custom merge fields in the body
        for (String field : bodyCustomMergeFieldMap.keySet()) {    
            if (htmlBody != null) {
                htmlBody = htmlBody.replace(field, bodyCustomMergeFieldMap.get(field));
            }
            if (plainBody != null) {
                plainBody = plainBody.replace(field, bodyCustomMergeFieldMap.get(field));
            }
        }

        // if there is a related record that is supposed to replace merge fields, do that here
        if (whatIdRecord != null) { 
            Pattern p = getMergeFieldPattern(whatIdRecord);
            subject = replaceMergeFields(subject, whatIdRecord, p);  
            plainBody = plainBody != null ? replaceMergeFields(plainBody, whatIdRecord, p) : null;
            htmlBody = htmlBody != null ? replaceMergeFields(htmlBody, whatIdRecord, p) : null;
        }

        Messaging.Singleemailmessage email = new Messaging.Singleemailmessage();
        email.setOrgWideEmailAddressId(EmailService.defaultOrgWideEmail.Id);
        email.setToAddresses(toAddresses);
        email.setSubject(subject);
        email.setHtmlBody(htmlBody);
        email.setPlainTextBody(plainBody);

        return email;
    }

    public Pattern getMergeFieldPattern(SObject sobj) {
        return Pattern.compile('\\{!' + sobj.getSObjectType() + '\\.(\\w+)\\}'); // i.e. group(0) = {!Filing__c.DocketNo__c}, group(1) = DocketNo__c
    }

    public String replaceMergeFields(String emailText, SObject whatIdRecord, Pattern p) {
        Matcher m = p.matcher(emailText);
        while (m.find()) {
            Object fieldValue = whatIdRecord.get(m.group(1));
            emailText = emailText.replace(m.group(0), String.valueOf(fieldValue != null ? fieldValue : ''));
        }
        return emailText;
    }

}