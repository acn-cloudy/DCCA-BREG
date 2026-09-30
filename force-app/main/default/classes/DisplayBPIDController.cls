public without sharing class DisplayBPIDController {
    private static Set<String> statuses = new Set<String>{
        'A4 - Rejected, Awaiting Notice',
        'A5 - Rejected, Notice Sent',
        'AW - Application Withdrawal',
        'B6 - Denied, Awaiting Notice',
        'B7 - Denial Letter Sent',
        'BW - Board Phase Withdrawal',
        'C6 - Denied, Awaiting Notice',
        'C7 - Denial Letter Sent',
        'DW - Dependency Review Phase Withdrawal',
        'E6 - Denied, Awaiting Notice',
        'E7 - Denial Letter Sent',
        'EW - Application Withdrawn After',
        'F6 - Denied, Awaiting Notice',
        'F7 - Denial Letter Sent',
        'F9 - Denial Letter Sent',
        'HC - Application Completed',
        'HD - Application Terminated',
        'HW - Application Withdrawn',
        'HX - Application Invalid, Delete',
        'L4 - Rejected Awaiting Notice',
        'L5 - Rejected, Notice Sent',
        'LW - Licensing Phase Withdrawal',
        'OW - (Second) Board Phase Withdrawal',
        'R6 - Denied, Awaiting Notice',
        'R7 - Denial Letter Sent',
        'S6 - Denied, Awaiting Notice',
        'S7 - Denial Letter Sent',
        'T6 - Denied, Awaiting Notice',
        'T7 - Denial Letter Sent',
        'XW - Withdrew From Exam'
    };
    @AuraEnabled
    public static String getAccountInfo(String bpId){
        try {
            
            List<Account> accList = [Select Id, Name from Account where BPID__c =: bpId];
            if(!accList.isEmpty()) {


                return accList.get(0).Name;
            } else {
                return '';
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String validateBPIDs(String bpId, String licenseType){
        Map<String, String> errors = new Map<String, String>();
        try {
            List<Account> accList = [Select Id, Name from Account where BPID__c =: bpId];
            if(!accList.isEmpty()) {
                List<Application__c> applications = [Select Id, CC_Applicant_Signature__c, DraftApplication__r.Status__c from Application__c 
                    where Applicant__r.BPID__c =: bpId and licenseType__r.LicenseType__c =: licenseType 
                    and Status__c not in: statuses ];
                if(!applications.isEmpty() && applications[0].CC_Applicant_Signature__c != null && applications[0].DraftApplication__r.Status__c == 'Submitted') {
                    errors.put('DuplicateError', Label.Application_DupError);
                    String errorStr = JSON.serialize(errors);
                    System.debug(errorStr);
                    AuraHandledException excp = new AuraHandledException(errorStr);
                    excp.setMessage(errorStr);
                    throw excp;
                } else if(!applications.isEmpty() && (applications[0].CC_Applicant_Signature__c == null || applications[0].DraftApplication__r.Status__c != 'Submitted')) {
                    return '';
                }
                return accList.get(0).Name;
            } else {
                return '';
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}