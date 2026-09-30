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
*    1. updated by Andrew Naples on 10/04/2021
*       details: Guest User cannot access this page reference 
*                 as a callout in asynchronous mode
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class PVL_SendPVLEmails {
    @InvocableMethod(label = 'Send PVL Emails' category = 'Payment')
    public static void sendPVLEmails(List<Id> ids) {
        // Query the payment records with Id conditions
        List<pymt__PaymentX__c> payment_L = [
                SELECT
                        Id,
                        Transaction__c,
                        Transaction__r.Name,
                        Name,
                        EmailAsyncId__c,
                        pymt__Billing_First_Name__c,
                        pymt__Billing_Last_Name__c,
                        pymt__Card_Type__c,
                        pymt__Last_4_Digits__c,
                        pymt__Billing_Email__c,
                        pymt__Amount__c,
                        pymt__Transaction_Id__c,
                        pymt__Date__c,
                        Transaction__r.Description__c,
                        pymt__Billing_Street__c,
                        pymt__Billing_City__c,
                        pymt__Billing_Postal_Code__c,
                        pymt__Billing_Country__c
                FROM pymt__PaymentX__c
                WHERE Id in :ids
        ];
        // Make sure that the code is not executed from the Asynchronised job.
        if (!System.isFuture()) {
            for (pymt__PaymentX__c p : payment_L) {
                String asyncId = System.enqueueJob(new QueueClass(p.Id));
                // update payment emailasyncId
                p.EmailAsyncId__c = asyncId;
            }
            update payment_L;
        }
    }


    // Queueable class to make sure the code is excuted from Asynchronised. 
    public class QueueClass implements Queueable,Database.AllowsCallouts {
        public Id paymentId;
        public Integer counter = 1;
        //accepts a set of records to update and their new batch number
        public QueueClass(Id paymentId) {
            this.paymentId = paymentId;
        }
        public QueueClass(Id paymentId, Integer counter) {
            this.paymentId = paymentId;
            this.counter = counter;
        }


        public void execute(QueueableContext context) {
            System.attachFinalizer(new FinalizerClass(paymentId, counter));
            sendLicenseApplicationEmails(paymentId);
        }
    }

    public class FinalizerClass implements Finalizer {
        public Id paymentId;
        private Integer counter = 1;

        public FinalizerClass (Id paymentId, Integer counter) {
            this.paymentId = paymentId;
            this.counter = counter;
        } 
        public void execute(FinalizerContext ctx) {
            String parentJobId = '' + ctx.getAsyncApexJobId();
            if (ctx.getResult() != ParentJobResult.SUCCESS) {
                System.debug('#####counter####' +  counter);
                System.debug('#####getException####' +  ctx.getException());
                if(counter == 3) {
                    ApplicationLogService.logApplicationError('Send PVL Payment Receipt Issue', paymentId, '', ctx.getException() + '');
                } else {
                    this.counter ++;
                    ApplicationLogService.logApplicationError('Pending Error Captured by PVL Payment Issue', paymentId, '', ctx.getException() + '');
                    System.enqueueJob(new QueueClass(paymentId, this.counter));
                    
                }
            } else {
                // Query Payment
                List<pymt__PaymentX__c> payments = [Select Id, EmailAsyncId__c from pymt__PaymentX__c where Id =: paymentId and EmailAsyncId__c != null];
                for(pymt__PaymentX__c payment: payments) {
                    payment.EmailAsyncId__c = null;
                }
                if(!payments.isEmpty()) update payments;
            }
        }

    }

    public static void sendLicenseApplicationEmails(Id paymentId) {
            pymt__PaymentX__c p = [
                SELECT
                        Id,
                        Transaction__c,
                        Transaction__r.License__r.LicenseType__r.RenewalSurvey__c,
                        Transaction__r.Name,
                        Transaction__r.Application__c,
                        Name,
                        pymt__Billing_First_Name__c,
                        pymt__Billing_Last_Name__c,
                        pymt__Card_Type__c,
                        pymt__Last_4_Digits__c,
                        pymt__Billing_Email__c,
                        pymt__Amount__c,
                        pymt__Transaction_Id__c,
                        pymt__Date__c,
                        Transaction__r.Description__c,
                        pymt__Billing_Street__c,
                        pymt__Billing_City__c,
                        pymt__Billing_Postal_Code__c,
                        pymt__Billing_Country__c
                FROM pymt__PaymentX__c
                WHERE Id =: paymentId
        ];

        List<TransactionLine__c> tls = [
                SELECT
                        Id,
                        Name,
                        Transaction__c,
                        CashierCodeDescription__c,
                        Amount__c
                FROM TransactionLine__c
                WHERE Transaction__c =: p.Transaction__c
        ];
        //site guest users, for an unknown reason, likely a bug with salesforce, 
        //cannot access this page reference as a callout in asynchronous mode
        //guidance is to leverage a full url.
        //PageReference attachmentRef = PAGE.PVL_PaymentReceipt;
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        
        PageReference attachmentRef = UserInfo.getUserType() != 'Standard' 
            ? new PageReference(orgSetting.CommunityURL__c+'/apex/PVL_PaymentReceipt')
            : PAGE.PVL_PaymentReceipt;
        Blob attachmentReceipt;
        String s_paymentDate = '';

        if (p.pymt__Date__c != null) {
            Datetime dt_paymentDate =
                    datetime.newInstance(p.pymt__Date__c.year(), p.pymt__Date__c.month(), p.pymt__Date__c.day());
            s_paymentDate = dt_paymentDate.formatGMT('dd MMM yyyy');
        }

        attachmentRef.getParameters().put('id', p.Id);
        attachmentRef.getParameters().put('tranId', p.pymt__Transaction_Id__c);
        attachmentRef.getParameters().put('tranDate', s_paymentDate);
        if (Test.isRunningTest()) {
            attachmentReceipt = Blob.valueOf('test');
        } else {
            attachmentReceipt = attachmentRef.getContentAsPDF();
        }
        // Start writing the compose the emails.
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        if (orgSetting.Use_Organization_Wide_Email__c) {
            OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where address = 'noreply@dcca.hawaii.gov'];
            if (owea.size() > 0) {
                semail.setOrgWideEmailAddressId(owea[0].Id);
            }
        } else {
            semail.setReplyTo('noreply@dcca.hawaii.gov');
            semail.setSenderDisplayName('noreply@dcca.hawaii.gov');
        }
        semail.setSubject('DCCA PVL License Application Receipt');
        String[] sendTo = new String[]{p.pymt__Billing_Email__c};
        semail.setToAddresses(sendTo);
        String plainTextBody = '';
        plainTextBody += 'MyPVL Portal\n\n';
        plainTextBody +=
                'This payment is non-refundable.This is to acknowledge receipt of your application. This receipt does not constitute approval or acceptance of your application. \n\n';
        plainTextBody +=
                'All applications are subject to review and all applicants are subject to requirements in affect at the time of filing. \n\n';
        plainTextBody +=
                'TO VERIFY THE STATUS OF YOUR APPLICATION: Please return to your MyPVL account at https://mypvl.dcca.hawaii.gov/ \n\n';
        plainTextBody += 'Thank you for submitting your application online. \n\n';
        plainTextBody += 'Please keep a copy of this payment receipt for your records. \n\n';
        plainTextBody += 'Thank you! Payment amount $' + p.pymt__Amount__c + ' has been made. \n\n';
        plainTextBody += 'Mahalo for your payment! \n';
        plainTextBody += p.Transaction__r.License__r.LicenseType__r.RenewalSurvey__c + '\n\n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Transaction Information \n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Reference ID: ' + p.Transaction__r.Name + '\n';
        plainTextBody += 'Transaction ID: ' + p.pymt__Transaction_Id__c + '\n';
        plainTextBody += 'Transaction Date: ' + s_paymentDate + '\n';
        plainTextBody += 'Transaction Amount: $' + p.pymt__Amount__c + '\n';
        plainTextBody += 'Description: ' + p.Transaction__r.Description__c + '\n';
        if (tls != null) {
            plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
            plainTextBody += 'Item Description       Reference Number        Amount \n';
            plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
            for (TransactionLine__c tl : tls) {
                String tempS;
                if (tl.CashierCodeDescription__c != null && tl.CashierCodeDescription__c.lastIndexOf('-') != -1) {
                    tempS = tl.CashierCodeDescription__c.substring(0, tl.CashierCodeDescription__c.lastIndexOf('-'));
                } else {
                    tempS = tl.CashierCodeDescription__c;
                }
                plainTextBody += tempS + ':     ' + tl.Name + '     $' + tl.Amount__c + '\n';
            }
            plainTextBody += 'Total: $' + p.pymt__Amount__c + '\n';
        }
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Payment Information \n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Card Type: ' + p.pymt__Card_Type__c + '\n';
        plainTextBody += 'Account Number (last 4): ******' + p.pymt__Last_4_Digits__c + '\n';
        plainTextBody += 'Name on Card: ' + p.pymt__Billing_First_Name__c + ' ' + p.pymt__Billing_Last_Name__c + ' \n';
        plainTextBody += 'Billing Address: ' + p.pymt__Billing_Street__c + '\n';
        plainTextBody +=
                p.pymt__Billing_City__c + ', ' + p.pymt__Billing_Postal_Code__c + ', ' + p.pymt__Billing_Country__c +
                '\n\n';
        plainTextBody += 'If you have any questions, please contact us at pvl@dcca.hawaii.gov or (808)586-3000';
        // Set the plain text body for the email
        semail.setPlainTextBody(plainTextBody);

        String htmlMsg = '<p>MyPVL Portal</p>' +
                '<p>This payment is non-refundable.This is to acknowledge receipt of your application. This receipt does not constitute approval or acceptance of your application.</p>' +
                '<p>All applications are subject to review and all applicants are subject to requirements in affect at the time of filing.</p>' +
                '<p>TO VERIFY THE STATUS OF YOUR APPLICATION: Please return to your MyPVL account at https://mypvl.dcca.hawaii.gov/</p>' +
                '<p>Thank you for submitting your application online.</p>' +
                '<p>Please keep a copy of this payment receipt for your records.</p>' +
                '<p>Thank you! Payment amount $' + p.pymt__Amount__c + ' has been made.</p>' +
                '<p>Mahalo for your payment!</p>' +
                '<p>' + p.Transaction__r.License__r.LicenseType__r.RenewalSurvey__c + '</p>' +
                '<p>- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - <br/>' +
                'Transaction Information<br/>' +
                '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -<br/>' +
                'Reference ID: ' + p.Transaction__r.Name + '<br/>' +
                'Transaction ID: ' + p.pymt__Transaction_Id__c + '<br/>' +
                'Transaction Date: ' + s_paymentDate + '<br/>' +
                'Transaction Amount: $' + p.pymt__Amount__c + '<br/>' +
                'Description: ' + p.Transaction__r.Description__c + '<br/>';
        if (tls != null) {
            htmlMsg += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -<br/>' +
                    'Item Description       Reference Number        Amount <br/>' +
                    '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -<br/>';
            for (TransactionLine__c tl : tls) {
                String tempS;
                if (tl.CashierCodeDescription__c != null && tl.CashierCodeDescription__c.lastIndexOf('-') != -1) {
                    tempS = tl.CashierCodeDescription__c.substring(0, tl.CashierCodeDescription__c.lastIndexOf('-'));
                } else {
                    tempS = tl.CashierCodeDescription__c;
                }
                htmlMsg += tempS + ':     ' + tl.Name + '     $' + tl.Amount__c + '<br/>';
            }
            htmlMsg += 'Total: $' + p.pymt__Amount__c + '<br/>';
        }
        htmlMsg += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - <br/>' +
                'Payment Information <br/>' +
                '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - <br/>' +
                'Card Type: ' + p.pymt__Card_Type__c + '<br/>' +
                'Account Number (last 4): ******' + p.pymt__Last_4_Digits__c + '<br/>' +
                'Name on Card: ' + p.pymt__Billing_First_Name__c + ' ' + p.pymt__Billing_Last_Name__c + ' <br/>' +
                'Billing Address: ' + p.pymt__Billing_Street__c + '<br/>' +
                p.pymt__Billing_City__c + ', ' + p.pymt__Billing_Postal_Code__c + ', ' + p.pymt__Billing_Country__c +
                '<br/><br/>' +
                'If you have any questions, please contact us at pvl@dcca.hawaii.gov or (808)586-3000</p>';
        // Set the html text body for the email
        semail.setHtmlBody(htmlMsg);
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        // Attache the files
        efa.setFileName('payment_receipt.pdf');
        efa.setBody(attachmentReceipt);
        semail.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
        if(p.Transaction__r.Application__c != null && attachmentReceipt != null && attachmentReceipt.size() > 0){
            uploadPaymentReceiptToSpringCM(p.Transaction__r.Application__c, attachmentReceipt);
        }
    }


    @future(callout=true)
    public static void uploadPaymentReceiptToSpringCM(Id applicationId, Blob attachmentReceipt) {
        if(applicationId != null && attachmentReceipt != null && attachmentReceipt.size() > 0) {
            try {
                List<SpringCMDocument> result = (!Test.isRunningTest()) ? SpringCMConnector.createFile(applicationId, 'payment_receipt.pdf', attachmentReceipt): null;
            } catch(Exception ex) {
                System.debug('ERROR uploading payment receipt to SpringCM: ' + ex.getMessage());
                System.debug('Stack trace: ' + ex.getStackTraceString());
                ApplicationLogService.logApplicationError('PVL Payment Receipt SpringCM Upload Failed', null, applicationId, ex.getMessage());
            }
        } else {
            System.debug('Skipping SpringCM upload - Application ID or attachment is null/empty');
        }
    }
}