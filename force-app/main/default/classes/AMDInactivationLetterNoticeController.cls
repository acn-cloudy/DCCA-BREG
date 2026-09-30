/*
 * ___________________________________________________________________________________
 * AMD Inactivation Letter Notice Controller
 * For AMDInactivationLetterNotice Email Templates
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA02022024 - Created for Case 00033728
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 02/02/2024
 * __________________________________________________________________________________
 */
public class AMDInactivationLetterNoticeController {
    public License__c lic{get;set;}
    public String currentRecordId{get;set;}
    public String boardProgramName {set;get;}
    public String licenseeName {set;get;}
    public String renewalMailToStreet {set;get;}
    public String renewalMailToCity {set;get;}
    public String renewalMailToState {set;get;}
    public String renewalMailToZipCode {set;get;}
    
    public AMDInactivationLetterNoticeController(){
        currentRecordId  = ApexPages.CurrentPage().getparameters().get('id');
        if(currentRecordId != null && String.isNotBlank(currentRecordId)){
            lic = [SELECT 
                Id, Name, LicenseeNameFormula__c, BoardProgramName__c, RenewalMailToStreet__c, 
                RenewalMailToCity__c, RenewalMailToState__c, RenewalMailToZipCode__c
                FROM License__c WHERE Id =:currentRecordId];
            this.boardProgramName = lic.BoardProgramName__c;
            this.renewalMailToCity = lic.RenewalMailToCity__c;
            this.licenseeName = lic.LicenseeNameFormula__c;
            this.renewalMailToStreet = lic.RenewalMailToStreet__c;
            this.renewalMailToState = lic.RenewalMailToState__c;
            this.renewalMailToZipCode = lic.RenewalMailToZipCode__c;
        }
    }

    //00033731
    @InvocableMethod(label='Process AMD Inactivation' description='Create Notifications, generate files and send emails for AMD Inactivation Letter Notice.' category='License')
    public static List <Results> processAMDInactivation(recordInfo[] licenseRecords){
        List<String> forUpdateLicenseIds = new List<String>();
        List<Results> results = new List<Results>();
        
        for(recordInfo record: licenseRecords) {
            Results res = new Results();
            res.operationOutcome = record.Id;
            results.add(res);
            forUpdateLicenseIds.add(record.Id);
        }
        List<License__c> forUpdateLicenses=[Select Id, NotificationEmail__c, SendAMDInactivationEmail__c from License__c where Id in:  forUpdateLicenseIds];
        List<Notification__c> notifications = (new LicenseDomain(forUpdateLicenses)).generateAMDInactivationNotifications(true);

        if(!notifications.isEmpty()){
            insert notifications;            
            Database.executeBatch(new AMDInactivationBatch(), 10);
        }

        return results;
    }

    public class recordInfo {
        @InvocableVariable
        public String Id;        
    }

    public class Results {
        @InvocableVariable(label='Records for Output' description='Output' required=true)
        public String operationOutcome;
    }
}