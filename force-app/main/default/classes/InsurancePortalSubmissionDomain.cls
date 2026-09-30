public with sharing class InsurancePortalSubmissionDomain extends SobjectDomain {
    public static final String REINSTATEMENT = 'REIN';
    public static final String CONTINUATION = 'CONT';
    public static final String NEWINSURANCE = 'NEW';
    public static final String CANCELLATION = 'CANC';
    
    
    
    public InsurancePortalSubmissionDomain(List<InsurancePortalSubmission__c> insuranceportalSubmissions) {
        super(insuranceportalSubmissions);
    }

    public Map<String, List<InsurancePortalSubmission__c>> convertLicenseIdToInsurancePortalSubmission() {
        Map<String, List<InsurancePortalSubmission__c>> insurancePortalSubmissionMap = new Map<String, List<InsurancePortalSubmission__c>>();
        for(InsurancePortalSubmission__c record: (List<InsurancePortalSubmission__c>) records) {
            List<InsurancePortalSubmission__c> insuranceSubmissions = new List<InsurancePortalSubmission__c>();
            if(insurancePortalSubmissionMap.containsKey(record.License__c)) {
                insuranceSubmissions = insurancePortalSubmissionMap.get(record.License__c);
            }
            insuranceSubmissions.add(record);
            insurancePortalSubmissionMap.put(record.License__c, insuranceSubmissions);
        }
        return insurancePortalSubmissionMap;
    }

    public List<InsurancePortalSubmission__c> filterInsurancePortalSubmissionForCancellation() {
        List<InsurancePortalSubmission__c> filteredRecords = new List<InsurancePortalSubmission__c>();
        for(InsurancePortalSubmission__c record: (List<InsurancePortalSubmission__c>) records) {
            if(record.TransactionType__c == CANCELLATION) {
                filteredRecords.add(record);
            }

        }
        return filteredRecords;

    }
    public List<InsurancePortalSubmission__c> filterInsurancePortalSubmissionForBondCreate() {
        List<InsurancePortalSubmission__c> filteredRecords = new List<InsurancePortalSubmission__c>();
        for(InsurancePortalSubmission__c record: (List<InsurancePortalSubmission__c>) records) {
            if(record.TransactionType__c == NEWINSURANCE 
            || record.TransactionType__c == CONTINUATION
            || record.TransactionType__c == REINSTATEMENT) {
                filteredRecords.add(record);
            }

        }
        return filteredRecords;
    }
    /***** Set the InsurancePortalSubmission__c.Status__c = "Error"

Set the Error Reason = "Unable to find a matching Insurance Record" 
 */
    public List<InsurancePortalSubmission__c> failRemainingCancelledInsurancePortalSubmission(Set<String> idSet) {
        List<InsurancePortalSubmission__c> failedRecords = new List<InsurancePortalSubmission__c>();
        for(InsurancePortalSubmission__c record: (List<InsurancePortalSubmission__c> )records) {
            if(!idSet.contains(record.Id)) {
                record.Status__c = 'Error';
                record.ErrorReason__c = 'Unable to find a matching Insurance Record';
                failedRecords.add(record);
            }
        }
        return failedRecords;

    }

    public List<InsuranceBond__c> createInsuranceCoverage() {
        List<InsuranceBond__c> bonds = new List<InsuranceBond__c>();
        for(InsurancePortalSubmission__c record: (List<InsurancePortalSubmission__c>) records) {
            if(record.TransactionType__c == NEWINSURANCE) {
                InsuranceBond__c bond = new InsuranceBond__c();
                bond.Amount__c = record.LimitEachOccurrence__c;
                bond.CancelDate__c = record.PolicyCancellationDate__c;
                bond.DesignatedSignatory__c = record.AuthorizedRepresentative__c;
                bond.License__c = record.License__c;
                bond.PolicyNumber__c = record.PolicyNumber__c;
                bond.Remarks__c = record.AdditionalComments__c;
                if(record.PolicyEffectiveDate__c != null && record.PolicyEffectiveDate__c > Date.today()) {
                    bond.Status__c = 'Pending';
                } else {
                    bond.Status__c = 'Active';
                }
                bond.EffectiveDate__c = record.PolicyEffectiveDate__c;
                bond.Surety__c = record.InsurerAffordingCoverage__c;
                bond.TermDate__c = record.PolicyExpirationDate__c;
                bond.TransactionCode__c = 'New - New Bond/Insurance';
                if(record.InsuranceType__c == 'General Liability') {
                    bond.Type__c = 'LP - Liability / Property Damage';

                } else if(record.InsuranceType__c == 'Liability') {
                    bond.Type__c = 'LI - Liability';
                    
                } else if(record.InsuranceType__c == 'Workers Comp') {
                    bond.Type__c = 'WC - Workers Compensation';
                    
                }else if(record.InsuranceType__c == 'Leasing Company WC only') {
                    bond.Type__c = 'SW - Workers Comp Thru Leasing Co.';
                    
                }
                bonds.add(bond);
            }
            if(record.TransactionType__c == CONTINUATION) {
                InsuranceBond__c bond = new InsuranceBond__c();
                bond.Amount__c = record.LimitEachOccurrence__c;
                bond.CancelDate__c = record.PolicyCancellationDate__c;
                bond.DesignatedSignatory__c = record.AuthorizedRepresentative__c;
                bond.License__c = record.License__c;
                bond.PolicyNumber__c = record.PolicyNumber__c;
                bond.Remarks__c = record.AdditionalComments__c;
                if(record.PolicyEffectiveDate__c != null && record.PolicyEffectiveDate__c > Date.today()) {
                    bond.Status__c = 'Pending';
                } else {
                    bond.Status__c = 'Active';
                }
                bond.EffectiveDate__c = record.PolicyEffectiveDate__c;
                bond.Surety__c = record.InsurerAffordingCoverage__c;
                bond.TermDate__c = record.PolicyExpirationDate__c;
                bond.TransactionCode__c = 'CONT - Continuation Certificate';
                if(record.InsuranceType__c == 'General Liability') {
                    bond.Type__c = 'LP - Liability / Property Damage';

                } else if(record.InsuranceType__c == 'Liability') {
                    bond.Type__c = 'LI - Liability';
                    
                } else if(record.InsuranceType__c == 'Workers Comp') {
                    bond.Type__c = 'WC - Workers Compensation';
                    
                }else if(record.InsuranceType__c == 'Leasing Company WC only') {
                    bond.Type__c = 'SW - Workers Comp Thru Leasing Co.';
                    
                }
                bonds.add(bond);
            }
            if(record.TransactionType__c == REINSTATEMENT) {
                InsuranceBond__c bond = new InsuranceBond__c();
                bond.Amount__c = record.LimitEachOccurrence__c;
                bond.CancelDate__c = record.PolicyCancellationDate__c;
                bond.DesignatedSignatory__c = record.AuthorizedRepresentative__c;
                bond.License__c = record.License__c;
                bond.PolicyNumber__c = record.PolicyNumber__c;
                bond.Remarks__c = record.AdditionalComments__c;
                if(record.PolicyEffectiveDate__c != null && record.PolicyEffectiveDate__c > Date.today()) {
                    bond.Status__c = 'Pending';
                } else {
                    bond.Status__c = 'Active';
                }
                bond.EffectiveDate__c = record.PolicyEffectiveDate__c;
                bond.Surety__c = record.InsurerAffordingCoverage__c;
                bond.TermDate__c = record.PolicyExpirationDate__c;
                bond.TransactionCode__c = 'CANC - Cancellation';
                if(record.InsuranceType__c == 'General Liability') {
                    bond.Type__c = 'LP - Liability / Property Damage';

                } else if(record.InsuranceType__c == 'Liability') {
                    bond.Type__c = 'LI - Liability';
                    
                } else if(record.InsuranceType__c == 'Workers Comp') {
                    bond.Type__c = 'WC - Workers Compensation';
                    
                }else if(record.InsuranceType__c == 'Leasing Company WC only') {
                    bond.Type__c = 'SW - Workers Comp Thru Leasing Co.';
                    
                }
                bonds.add(bond);
            }
        }
        return bonds;
    }


}