public without sharing class CertificateOfInsuranceController {
    public InsurancePortalSubmission__c record{set;get;}
    public DateTime createdDate = null;
    public CertificateOfInsuranceController(ApexPages.standardController std) {
        String recordId = std.getId();
        List<InsurancePortalSubmission__c> submissions = [Select Id, License__r.Name,
            CreatedDate, PVLLicenseNumber__c, LimitEachOccurrence__c, EntityId__c, LicenseNumber__c,
            TransactionType__c, InsuranceType__c, LicenseeName__c, LicenseTypePrefix__c,
            InsurerAffordingCoverage__c, PolicyNumber__c, BoardProgramName__c,
            PolicyEffectiveDate__c, PolicyExpirationDate__c, AuthorizedRepresentativeFormula__c,
            PolicyCancellationDate__c, AdditionalComments__c, AuthorizedRepresentative__c from InsurancePortalSubmission__c where Id =: recordId];
        if(submissions.isEmpty()) {
            record = new InsurancePortalSubmission__c();
        } else {
            record = submissions.get(0);

            // Convert to HST
            DateTime dttime = record.CreatedDate;
            TimeZone targetTZ = Timezone.getTimeZone('Pacific/Honolulu');
            integer offsetTotargetTZ = targetTZ.getOffset(dttime);

            createdDate = dttime.addMinutes(offsetTotargetTZ/(1000*60));
        }
    }
    public DateTime getCreatedDate() {
        return createdDate;
    }
    public String getBoardProgram() {
        if(record != null && record.BoardProgramName__c != null) return toTitleCase(record.BoardProgramName__c);
        return '';
    }
    public String toTitleCase(String phrase){
        String titlePhrase = '';
        //a set of words that should always (or at least, almost always) be in lower case when in Title Case
        //eg The Day of the Jackal.  First and last word of a phrase should always be Capped though.
        Set<String> forceLower = new Set<String>{'of', 'the', 'for', 'and', 'a', 'to', 'at' ,'an', 'but', 'if', 'or', 'nor'};
      
        if(phrase != null && phrase.length() > 0){
          String[] splitPhrase = phrase.trim().split(' ');
                  
          for(integer i = 0; i < splitPhrase.size(); i++){
            if(!forceLower.contains(splitPhrase[i].toLowerCase()) || i == 0 || i == (splitPhrase.size()-1) ){
              titlePhrase += (splitPhrase[i].substring(0,1).toUpperCase())+(splitPhrase[i].substring(1).toLowerCase())+' ';
            }else{
              titlePhrase += splitPhrase[i].toLowerCase()+' ';
            }
          }
        }
          return titlePhrase.trim();
        }
}