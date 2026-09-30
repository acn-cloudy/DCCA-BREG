/*
* ─────────────────────────────────────────────────────────
* Send email functions to be invoked by the Flow. Flow API Name: Payment_Send_BREG_Email.
* 
* ─────────────────────────────────────────────────────────
* PacPoint-JK210323 - Created for Case 27853
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Jonathan Kwok - PacificPointCorp 
* @created      2023-03-21
* ───────────────────────────────────────────────────────────
*/
public without sharing class BREG_SendBREGEmails {
    @InvocableMethod(label = 'Send BREG Emails' category = 'Payment')
    public static void sendBREGEmails(List<Id> ids) {
        // Query the payment records with Id conditions
        List<pymt__PaymentX__c> payment_L = [
                SELECT
                        Id,
                        Transaction__c,
                        Transaction__r.Name,
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
                WHERE Id in :ids and pymt__Billing_Email__c != null
        ];

        // Make sure that the code is not executed from the Asynchronised job.
        if (!System.isFuture()) {
            for (pymt__PaymentX__c p : payment_L) {
                System.enqueueJob(new QueueClass(p.Id));
            }
        }
    }

    // Queueable class to make sure the code is excuted from Asynchronised. 
    public class QueueClass implements Queueable,Database.AllowsCallouts {
        public Id paymentId;
        //accepts a set of records to update and their new batch number
        public QueueClass(Id paymentId) {
            this.paymentId = paymentId;
        }

        public void execute(QueueableContext context) {
            sendEmails(paymentId);
        }
    }

    public static void sendEmails(Id paymentId) {
        pymt__PaymentX__c p = [
                SELECT
                        Id,
                        Transaction__c,
                        Transaction__r.Name,
            			Transaction__r.Filing__c,
            			Transaction__r.Filing__r.Name,
            			Transaction__r.TransactionType__c,
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
                        pymt__Billing_Country__c,
                        pymt__Payment_Type__c,
                        pymt__Transaction_Type__c
                FROM pymt__PaymentX__c
                WHERE Id =: paymentId
        ];
		
        List<pymt__PaymentX__c> groupPayment = [
            	SELECT
            			Id,
            			Name,
            			Transaction__c,
            			Transaction__r.Filing__r.Name,
            			Transaction__r.TransactionGroup__c,
            			pymt__Amount__c
            			FROM pymt__PaymentX__c
            			WHERE Transaction__r.TransactionGroup__c =: p.Transaction__c
        ];

        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        Boolean isRefund = p.pymt__Transaction_Type__c == 'Refund';

        List<TransactionLine__c> refundTransactionLines = new List<TransactionLine__c>();
        Decimal totalRefundAmount;

        if (isRefund) {
            refundTransactionLines = [
                SELECT
                    Id,
                    Description__c,
                    breg_Quantity__c,
                    RefundAmount__c,
                    breg_Case__c,
                    breg_Case__r.breg_Workitem_Number__c,
                    breg_Refund_Case__c,
                    breg_Refund_Case__r.breg_Total_Refund_Amount__c
                FROM TransactionLine__c
                WHERE Transaction__c = :p.Transaction__c
                    AND RefundAmount__c != null
                    AND RefundAmount__c != 0
            ];

            if (refundTransactionLines.isEmpty()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Refund email was not sent because no Transaction Lines with RefundAmount__c were found. Payment Id: ' +
                    p.Id
                );
                return;
            }

            if (refundTransactionLines[0].breg_Refund_Case__c == null) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Refund email was not sent because breg_Refund_Case__c is empty. Payment Id: ' +
                    p.Id
                );
                return;
            }

            totalRefundAmount =
                refundTransactionLines[0]
                    .breg_Refund_Case__r
                    .breg_Total_Refund_Amount__c;

            if (totalRefundAmount == null) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Refund email was not sent because breg_Total_Refund_Amount__c is empty. Payment Id: ' +
                    p.Id
                );
                return;
            }
        }

        Decimal displayedTransactionAmount = isRefund ? totalRefundAmount : p.pymt__Amount__c;

        String s_paymentDate = '';
        if (p.pymt__Date__c != null) {
            Datetime dt_paymentDate =
                    datetime.newInstance(p.pymt__Date__c.year(), p.pymt__Date__c.month(), p.pymt__Date__c.day());
            s_paymentDate = dt_paymentDate.formatGMT('dd MMM yyyy');
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
            semail.setSenderDisplayName('DCCA No Reply');
        }
        semail.setSubject(
            isRefund
                ? 'DCCA BREG Filing Refund Receipt'
                : 'DCCA BREG Filing Payment Receipt'
        );
        String[] sendTo = new String[]{p.pymt__Billing_Email__c};
        semail.setToAddresses(sendTo);
        Boolean isPaymentTypeCash = p.pymt__Payment_Type__c == 'Cash';

        String plainTextBody = '';

        if (isRefund) {
            plainTextBody += 'Mahalo! \n';
            plainTextBody +=
                'A refund amount of $' +
                totalRefundAmount.setScale(2) +
                ' has been issued. \n';
            plainTextBody +=
                'Please keep a copy of this refund receipt for your records. \n\n';

            plainTextBody +=
                'This refund receipt confirms the amount refunded to your original payment method. ';
            plainTextBody +=
                'If you have any questions, please contact the Business Registration Division at 1-844-808-3222. \n\n';
        } else {
            plainTextBody += 'Mahalo for your payment! \n';
            plainTextBody +=
                'Payment amount of $' +
                p.pymt__Amount__c +
                ' has been made. \n';
            plainTextBody +=
                'Please keep a copy of this payment receipt for your records. \n\n';

        plainTextBody +=
            'This Payment is non-refundable. This is to acknowledge receipt of your application and does not constitute approval or acceptance of your application. \n';
        plainTextBody +=
            'All applications are subject to review. \n';
        plainTextBody +=
            'To verify the status of your application, please return to your BREG account at ' +
            setting.Link_to_Portal__c +
            ' \n\n';
        }
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Transaction Information \n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Reference ID: ' + p.Transaction__r.Name + '\n';
        if(p.pymt__Transaction_Id__c != null) {
            plainTextBody += 'Transaction ID: ' + p.pymt__Transaction_Id__c + '\n';
        }
        plainTextBody += 'Transaction Date: ' + s_paymentDate + '\n';
        plainTextBody +='Transaction Amount: $' + displayedTransactionAmount.setScale(2) + '\n';
        if (isRefund) {
            plainTextBody += getRefundTransactionLineItemsTextBody(refundTransactionLines);
        }else if(p.Transaction__r.TransactionType__c == 'Payment'){
            if(p.Transaction__r.Filing__c != null) {
        	    plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
                plainTextBody += 'Filling Name                       Amount \n';
                plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
                plainTextBody +=  p.Transaction__r.Filing__r.Name + '     $' + p.pymt__Amount__c + '\n';
            } else {
                // If the amount is 0 don't send the email
                if (p.pymt__Amount__c == 0) {
                    return;
                }
                plainTextBody += getTransactionLineItemsTextBody(p);
                
                semail = new Messaging.SingleEmailMessage();
                String orgWideEmailAddress = BREG_Setting__c.getOrgDefaults().Send_Emails_Org_Wide_Address__c;
                orgWideEmailAddress = orgWideEmailAddress != null ? orgWideEmailAddress : 'noreply@dcca.hawaii.gov';
                OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where address = :orgWideEmailAddress];
                if (owea.size() > 0) {
                    semail.setOrgWideEmailAddressId(owea[0].Id);
                }
                semail.setSubject(
                    isRefund
                        ? 'DCCA BREG Filing Refund Receipt'
                        : 'DCCA BREG Filing Payment Receipt'
                );
                semail.setToAddresses(sendTo);
            }
        }
        else{
            plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
            plainTextBody += 'Filling Name                       Amount \n';
            plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
            for (pymt__PaymentX__c gp : groupPayment ) {
                plainTextBody +=  gp.Transaction__r.Filing__r.Name + '     $' + gp.pymt__Amount__c + '\n';
                system.debug('Debug Filing Name: '+ gp.Transaction__r.Filing__r.Name );
            }
            plainTextBody += 'Total: $' + p.pymt__Amount__c + '\n';
        }
        
        
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Payment Information \n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        if(!isPaymentTypeCash) {
            plainTextBody += 'Card Type: ' + p.pymt__Card_Type__c + '\n';
            plainTextBody += 'Account Number (last 4): ******' + p.pymt__Last_4_Digits__c + '\n';
            plainTextBody += 'Name on Card: ' + p.pymt__Billing_First_Name__c + ' ' + p.pymt__Billing_Last_Name__c + ' \n';
        }
        plainTextBody += 'Billing Address: ' + p.pymt__Billing_Street__c + '\n';
        plainTextBody +=
                p.pymt__Billing_City__c + ', ' + p.pymt__Billing_Postal_Code__c + ', ' + p.pymt__Billing_Country__c +
                '\n\n';
                
        // Set the plain text body for the email
        semail.setPlainTextBody(plainTextBody);
        if (Test.isRunningTest()) {
            return;
        }
        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { semail });

        for (Messaging.SendEmailResult res : results) {
            if (res.isSuccess()) {
                System.debug('Email sent successfully');
            } else {
                // This will give you the actual error message
                System.debug('The following errors occurred: ' + res.getErrors()[0].getMessage());
            }
        }
    }

    private static String getRefundTransactionLineItemsTextBody(
        List<TransactionLine__c> refundTransactionLines
    ) {
        String plainTextBody = '';

        plainTextBody +=
            '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';

        plainTextBody +=
            'Work Item ID | Item | Quantity | Amount \n';

        plainTextBody +=
            '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';

        for (TransactionLine__c line : refundTransactionLines) {
            String workItemNumber =
                line.breg_Case__r != null &&
                line.breg_Case__r.breg_Workitem_Number__c != null
                    ? line.breg_Case__r.breg_Workitem_Number__c
                    : 'N/A';

            String item =
                line.Description__c != null
                    ? line.Description__c
                    : '';

            String quantity =
                line.breg_Quantity__c != null
                    ? String.valueOf(line.breg_Quantity__c)
                    : 'N/A';

            String amount =
                line.breg_Refund_Case__r != null &&
                line.breg_Refund_Case__r.breg_Total_Refund_Amount__c != null
                    ? '$' + String.valueOf(
                        line.breg_Refund_Case__r
                            .breg_Total_Refund_Amount__c
                            .setScale(2)
                    )
                    : 'N/A';

            plainTextBody +=
                workItemNumber +
                ' | ' +
                item +
                ' | ' +
                quantity +
                ' | ' +
                amount +
                '\n';
        }
        return plainTextBody;
    }

    private static String getTransactionLineItemsTextBody(pymt__PaymentX__c p) {
        String plainTextBody = '';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        plainTextBody += 'Work Item ID | Item | Quantity | Amount \n';
        plainTextBody += '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \n';
        List<TransactionLine__c> transactionLineItems = BREGPaymentController.getTransactionLines(new Set<Id>{ p.Id });
        List<BREGPaymentController.TransactionLineWrapper> wrappers = BREGPaymentController.getTransactionLineWrappers(transactionLineItems);
        for (BREGPaymentController.TransactionLineWrapper wrapper : wrappers) {
            String workItemNumber = wrapper.workItemNumber != null ? wrapper.workItemNumber : 'N/A';
            
            String item = wrapper.description != null ? wrapper.description : '';
            if (wrapper.description != null && (wrapper.isCertified == true || wrapper.isExpedited == true)) {
                List<String> tags = new List<String>();

                if (wrapper.isCertified == true) {
                    tags.add('Certified');
                }
                if (wrapper.isExpedited == true) {
                    tags.add('Expedited');
                }

                if (!tags.isEmpty()) {
                    item += ' (' + String.join(tags, ', ') + ')';
                }
            }
            String quantity = wrapper.quantity != null ? String.valueOf(wrapper.quantity) : 'N/A';
            String amount = wrapper.price != null ? '$' + String.valueOf(wrapper.price.setScale(2)) : 'N/A';

            plainTextBody += workItemNumber + ' | ' + item + ' | ' + quantity + ' | ' + amount + '\n';
        }
        return plainTextBody;
    }
}