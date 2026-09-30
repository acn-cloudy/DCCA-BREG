/****
 * Description: Set the all Associated Licenses with an AssociatedLicense.Status__c = Employed TO Terminated 
 * and set the EndDate__c = License.EffectiveExpireDate__c. AZ20210412PA00014200
 * Date: 04/12/2021
 * Updated by: Alvin Zhou
 * 
 * ****** */
global class AssociatedLicensesStatusUpdate  implements Database.Batchable<SObject>, Database.Stateful {
    global String query;
    global AssociatedLicensesStatusUpdate(List<Id> entityIds) {
        query = 'Select Id, EmploymentStatus__c, EntityLicense__c, EndDate__c, EntityLicense__r.EffectiveExpireDate__c from AssociatedLicense__c where EmploymentStatus__c = \'Employed\' and Id IN '
         + GlobalUtilities.convertIdsToIdStr(entityIds) ;
       
    }
    /* batch start class */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

	global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<AssociatedLicense__c> associatedLicenses = (List<AssociatedLicense__c>) scope;
        for(AssociatedLicense__c record: associatedLicenses) {
            record.EndDate__c = record.EntityLicense__r.EffectiveExpireDate__c;
            record.EmploymentStatus__c = 'Terminated';
        }
        update associatedLicenses;
    }

    /* batch finish class */
    global void finish(Database.BatchableContext context) {}

}