/*
* ─────────────────────────────────────────────────────────
* Send email functions to be invoked by the process builder.
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ300820 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2020-08-30
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class PVL_SendListBuilderEmails {
    @InvocableMethod(label='Send List Builder Emails' category='Payment')
    public static void sendListBuilderEmails(List<Id> ids) {
        //  query for payment records
        List<pymt__PaymentX__c> payment_L = [SELECT Id, Transaction__c, Transaction__r.Name, Name, pymt__Billing_Email__c, pymt__Amount__c, pymt__Transaction_Id__c, pymt__Date__c, Transaction__r.Description__c, pymt__Billing_Street__c, pymt__Billing_City__c, pymt__Billing_Postal_Code__c, pymt__Billing_Country__c
                                             FROM pymt__PaymentX__c 
                                             WHERE Id in :ids];
        // It will call the send email function one by one with the limit of 200 
        for (pymt__PaymentX__c p : payment_L) {
            sendListBuilderEmails(p);
        }
    }

    public static void sendListBuilderEmails(pymt__PaymentX__c p) {
        List<Messaging.EmailFileAttachment> emailAttachList = new List<Messaging.EmailFileAttachment>();
        // Start writing the emails.
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
        if(orgSetting.Use_Organization_Wide_Email__c) {
        	OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where address = 'noreply@dcca.hawaii.gov'];
        	if (owea.size() > 0) {
        		semail.setOrgWideEmailAddressId(owea[0].Id);
        	}
        } else {
            semail.setReplyTo('noreply@dcca.hawaii.gov');
            semail.setSenderDisplayName('noreply@dcca.hawaii.gov');
        }
        // Adding subject
        semail.setSubject('PVL List Builder Receipt');
        // Set the receiver to be the billing email under the payment records.
        String[] sendTo = new String[]{p.pymt__Billing_Email__c};
        semail.setToAddresses(sendTo);
        String plainTextBody = '';
        plainTextBody += 'MyPVL Portal \n\n';
        plainTextBody += 'This payment is non-refundable. \n\n';
        plainTextBody += 'Please keep a copy of this payment receipt for your records. \n\n';
        plainTextBody += 'Thank you! Payment amount $' + p.pymt__Amount__c + ' has been made. \n\n';
        plainTextBody += 'Mahalo for your payment! \n\n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Transaction Information \n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Reference ID: ' + p.Transaction__r.Name + '\n';
        plainTextBody += 'Transaction ID: ' + p.pymt__Transaction_Id__c + '\n';
        String s_paymentDate = ''; 
        // format the date
        if (p.pymt__Date__c != null) {
            Datetime dt_paymentDate = datetime.newInstance(p.pymt__Date__c.year(), p.pymt__Date__c.month(), p.pymt__Date__c.day());
            s_paymentDate = dt_paymentDate.formatGMT('dd MMM yyyy');
        } 
        plainTextBody += 'Transaction Date: ' + s_paymentDate + '\n';
        plainTextBody += 'Transaction Amount: $' + p.pymt__Amount__c + '\n';
        plainTextBody += 'Description: ' + p.Transaction__r.Description__c + '\n\n';
        plainTextBody += 'If you have any questions, please contact us at pvl@dcca.hawaii.gov or (808) 586-3000';
        semail.setPlainTextBody(plainTextBody);
        // Complete the body of the emails.

        PageReference ref = PAGE.PVL_ListBuilderReceipt;
        ref.getParameters().put('Id', p.Id);
        ref.getParameters().put('tranId', p.pymt__Transaction_Id__c);
        ref.getParameters().put('tranDate', s_paymentDate);
        Blob b;
        if(Test.isRunningTest()) b= Blob.valueOf('test');
        else b = ref.getContentAsPDF() ;
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('list_builder_receipt.pdf');
        efa.setBody(b);
        emailAttachList.add(efa);
        // Make sure the test code was not thrown error when query the document. 
        if(!Test.isRunningTest()) {
            //Get your document from document Object
            Document doc = [Select Id, Name, Body, ContentType, DeveloperName, Type From Document Where DeveloperName = 'List_Builder_PDF_Guide'];
     
            //Create Email file attachment from document
            Messaging.EmailFileAttachment pdfGuide = new Messaging.EmailFileAttachment();
            pdfGuide.setContentType(doc.ContentType);
            pdfGuide.setFileName('list_builder_pdf_guide.pdf');
            pdfGuide.Body = doc.Body;
            emailAttachList.add(pdfGuide);
        }
        // send emails.
        semail.setFileAttachments(emailAttachList);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
    }
}