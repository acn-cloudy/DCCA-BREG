/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for CustomPaymentButton component
* Displays a button on the filing page based on criteria, to send the user to the payment page
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* PacPoint-LC012519 - Created for BREG Phase 1
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Initial implementation
* @author       Lucian Ciobanu - PacificPointCorp 
* @created      2019-01-25
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Changes
*
*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
*/
public without sharing class CustomPaymentButtonController 
{
	@AuraEnabled
    public static Response getNecessaryInfoFromServer(String filingId, String checkboxApiName)
    {
        Response serverResponse = new Response();

        String query = 'SELECT Id, ' + checkboxApiName + ' FROM Filing__c WHERE Id = :filingId LIMIT 1';

        List<Filing__c> filingList = Database.query(query);

        if(filingList.size() == 0)
        {
            serverResponse.errorMessage = 'No Filing records were found for the given record Id!'; 
            return serverResponse;           
        }
        else
        {
            serverResponse.showPaymentButton = (Boolean)filingList[0].get(checkboxApiName);

            List<pymt__PaymentX__c> payments = [SELECT Id FROM pymt__PaymentX__c WHERE Transaction__r.Filing__c = :filingId ORDER BY CreatedDate];
            // if this filing has a payment linked to it
            if(payments.size() > 0)
            {
                serverResponse.paymentId = payments[0].Id;
            }
        }

        return serverResponse;
    }

    public class Response
    {
        @AuraEnabled
        public Boolean showPaymentButton {get; set;}

        @AuraEnabled
        public String errorMessage {get; set;}

        @AuraEnabled
        public String paymentId {get; set;}

        public Response()
        {
            paymentId = '';
            showPaymentButton = false;
            errorMessage = '';
        }

    }
}