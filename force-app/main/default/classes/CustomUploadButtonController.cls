/*
* ─────────────────────────────────────────────────────────────────────────────────────────────────
* Controller for CustomUploadButton component
* Displays a button on the filing page based on criteria, to upload documents on a filing
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
public without sharing class CustomUploadButtonController 
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
            serverResponse.showUploadButton = (Boolean)filingList[0].get(checkboxApiName);
        }

        return serverResponse;
    }

	public class Response
    {
        @AuraEnabled
        public Boolean showUploadButton {get; set;}

        @AuraEnabled
        public String errorMessage {get; set;}

        public Response()
        {
            showUploadButton = false;
            errorMessage = '';
        }

    }
}