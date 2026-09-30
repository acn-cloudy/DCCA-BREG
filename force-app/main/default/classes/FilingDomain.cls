/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: FilingDomainTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL11122021 - Created for Phase #
 * -----------------------------------------------------------------------------------
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/12/2021
 * __________________________________________________________________________________
 * Changes
 * -----------------------------------------------------------------------------------
 */
public with sharing class FilingDomain extends SObjectDomain{
    public FilingDomain(List<Filing__c> filings) {
        super(filings);
    }

    public void validateEditPermission() {
        for (Filing__c filing : (List<Filing__c>) records) {
            if (!FilingService.validateEditPermission(filing)) {
                if (Trigger.isExecuting) {
                    Filing__c oldFiling = (Filing__c) Trigger.oldMap.get(filing.Id);
                    Filing__c newFiling = (Filing__c) Trigger.newMap.get(filing.Id);
                    if (oldFiling.SkipReviewerEditValidation__c && !newFiling.SkipReviewerEditValidation__c) {
                        //don't validate when only setting Skip flag to false
                        continue;
                    }

                    Trigger.newMap.get(filing.Id).addError('Only the reviewer can edit this Filing.');
                    continue;
                }
                filing.addError('Only the reviewer can edit this Filing.');
            }
        }
    }
}