public class TravelApprovalValidator {
    @AuraEnabled
    public static List<TravelApproval__c> validatedTravelApprovals(String recordId){
        try {
            List<TravelApproval__c> approvals = [Select Id, Name, NameOfTraveler__c, TravelerEmail__c, Final_Report_Uploaded__c from TravelApproval__c where Id =: recordId ];
            if(!approvals.isEmpty()) {
                TravelApproval__c record = approvals.get(0);
                String travelerName = record.NameOfTraveler__c;
                String travelerEmail = record.TravelerEmail__c;
                List<TravelApproval__c> pendingApprovalRecords = [
                    Select Id, BusinessOnlyReturnDate__c, Name from TravelApproval__c 
                        where TravelType__c IN ('Out-of-State', 'OCONUS (Foreign or Alaska)', 'CONUS (Contiguous 48 States)') and NameOfTraveler__c =: travelerName and TravelerEmail__c =: travelerEmail and Final_Report_Uploaded__c = false and BusinessOnlyReturnDate__c < LAST_N_DAYS:30 AND TravelApprovalStatus__c != 'Cancelled'];
                return pendingApprovalRecords;
            }
            return new List<TravelApproval__c>();   
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static string redirectURL(String recordId, String dst){
        try {
            PageReference pr = Page.dsfs__DocuSign_CreateEnvelope;
            pr.getParameters().put('SourceID', recordId);
            pr.getParameters().put('DST', dst);
            return pr.getUrl();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}