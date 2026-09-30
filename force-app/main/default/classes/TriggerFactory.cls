/*
* ─────────────────────────────────────────────────────────
* class for the Generic Trigger factory patternn
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp 
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/
public class TriggerFactory {
    
    public class TriggerException extends Exception {
 
    }

    /**
     * Public static method to create and execute a trigger handler
     *
     * Arguments:  Schema.sObjectType soType - Object type to process (SObject.sObjectType)
     *
     * Throws a TriggerException if no handler has been coded.
     */
    public static void createAndExecuteHandler(Schema.sObjectType soType) {
        // Get a handler appropriate to the object being processed
        ITrigger handler = getHandler(soType);
        // Make sure we have a handler registered, new handlers must be registered in the getHandler method.
        if (handler == null) {
            throw new TriggerException('No Trigger Handler registered for Object Type: ' + soType);
        }

        // Execute the handler to fulfil the trigger
        execute(handler);
    }

    /**
     * private static method to control the execution of the handler
     *
     * Arguments:  ITrigger handler - A Trigger Handler to execute
     */
    private static void execute(ITrigger handler) {
        // Before Trigger
        if (Trigger.isBefore) {
            // Call the bulk before to handle any caching of data and enable bulkification
            handler.bulkBefore();

            // Iterate through the records to be deleted passing them to the handler.
            if (Trigger.isDelete) {
                for (SObject so: Trigger.old) {
                    handler.beforeDelete(so);
                }
            }
            
            if (Trigger.isUnDelete) {
                for (SObject so: Trigger.new) {
                    handler.beforeUnDelete(so);
                }
            }
            
            // Iterate through the records to be inserted passing them to the handler.
            else if (Trigger.isInsert) {
                for (SObject so: Trigger.new) {
                    handler.beforeInsert(so);
                }
            }
            // Iterate through the records to be updated passing them to the handler.
            else if (Trigger.isUpdate) {
                for (SObject so: Trigger.old) {
                    handler.beforeUpdate(so, Trigger.newMap.get(so.Id));//Added for case 00005582 
                }
            }
        } else {
            // Call the bulk after to handle any caching of data and enable bulkification
            handler.bulkAfter();

            // Iterate through the records deleted passing them to the handler.
            if (Trigger.isDelete) {
                for (SObject so: Trigger.old) {
                    handler.afterDelete(so);
                }
            }
            
            if (Trigger.isUnDelete) {
                for (SObject so: Trigger.new) {
                    handler.afterUnDelete(so);
                }
            }
            
            // Iterate through the records inserted passing them to the handler.
            else if (Trigger.isInsert) {
                for (SObject so: Trigger.new) {
                    handler.afterInsert(so);
                }
            }
            // Iterate through the records updated passing them to the handler.
            else if (Trigger.isUpdate) {
                for (SObject so: Trigger.old) {
                    handler.afterUpdate(so, Trigger.newMap.get(so.Id));
                }
            }
        }

        // Perform any post processing
        handler.andFinally();
    }

    /**
     * private static method to get the appropriate handler for the object type.
     * Modify this method to add any additional handlers.
     *
     * Arguments:  Schema.sObjectType soType - Object type tolocate (SObject.sObjectType)
     *
     * Returns:    ITrigger - A trigger handler if one exists or null.
     */
    private static ITrigger getHandler(Schema.sObjectType soType) {
        if(soType === Application__c.sObjectType) {
            return new ApplicationHandler();
        } else if(soType === ApplicationClassifications__c.sObjectType) {
            return new ApplicationClassificationsHandler();
        } else if (soType === Transaction__c.sObjectType) {
            return new Transaction_Handler();
        } else if (soType === License__c.sObjectType) {
            return new LicenseHandler();
        } else if (soType === EligibleCandidateLoad__c.sObjectType) {
            return new EligibleCandidateLoadHandler();
        } else if (soType === ExamResultsLoad__c.sObjectType) {
            return new ExamResultLoadHandler();
        } else if (soType === LicenseClassification__c.sObjectType) {
            return new LicenseClassificationHandler();
        } else if (soType === ApplicationRequirement__c.sobjectType) {
            return new ApplicationRequirementHandler();
        } else if (soType === Account.sobjectType) {
            return new AccountHandler();
        } else if (soType === LicenseConditions__c.SobjectType) {
            return new LicenseConditionHandler();
        } else if (soType === LicenseType__c.SObjectType) {
            return new LicenseTypeHandler();
        } else if (soType === InsuranceBond__c.sObjectType) {
            return new InsuranceBondHandler();
        } else if (soType === Notification__c.sObjectType) {
            return new NotificationHandler();
        } else if (soType === LicenseRequirements__c.SobjectType) {
            return new LicenseRequirementHandler();
        } else if (soType === AssociatedLicense__c.SobjectType) {
            return new AssociatedLicenseHandler();
        } else if (soType === CertificateRequest__c.SobjectType) {
            return new CertificateRequestHandler();
        } else if (soType === ContentDocumentLink.SobjectType) {
            return new ContentDocumentLinkHandler();
        } else if(soType === Exam__c.sObjectType) {
            return new ExamHandler();
        } else if(soType == Filing__c.sObjectType){
            return new FilingHandler();
        } else if(soType == FileDetails__c.sObjectType){
            return new FileDetailHandler();
        } else if(soType == Application_Cache__c.sObjectType){
            return new DraftApplicationHandler();
        } else if(soType == Sanction__c.sobjectType) {
            return new SanctionHandler();
        } else if(soType == ExamResults__c.sobjectType) {
            return new ExamResultsHandler();
        }
        return null;
    }
}