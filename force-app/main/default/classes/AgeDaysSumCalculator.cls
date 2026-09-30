/*
 * ___________________________________________________________________________________
 * Calculate the sum of Age Days of related Status History Records
 * Covered by: AgeDaysSumCalculatorTest
 * __________________________________________________________________________________
 * PacPoint-CL041019 - Created for BREG phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 4/10/2019
 * __________________________________________________________________________________
 */
public class AgeDaysSumCalculator {
    
    public AgeDaysSumCalculator(){}
    
    /*
     * @param parentObjectName the API name of the object of the look up field (possible values are SEBCase__c, Investigation__c, Filing__c, Exam__c)
     * @param parentFieldName the API name of the look up field in Status History object (possible values are SEBCase__c, Investigation__c, Filing__c, Exam__c)
     * @param parentIds The list of parentIds that needs the AgeDays sum to be calculated.
     */
    /*
    public static void calculate(String parentObjectName, String parentFieldName, List<Id> parentIds) {
        //Construct an aggregate query to get the sum of the AgeDays of all related status history of each
        //individual parentIds
        String sql = 'SELECT ' + parentFieldName;
        sql += ',SUM(AgeDays__c) sumAd FROM StatusHistory__c WHERE ' + parentFieldName + ' IN :parentIds';
        sql += ' GROUP BY ' + parentFieldName;

        //execute query
        List<AggregateResult> aggregateResults = Database.query(sql);

        List<sObject> sObjectsToUpdate = new List<sObject>();

        for (AggregateResult aggr : aggregateResults) {
            Id parentId = (Id) aggr.get(parentFieldName);
            Decimal ageDaysSum = (Decimal) aggr.get('sumAd');

            sObject parentObject = Schema.getGlobalDescribe().get(parentObjectName).newSObject();

            //set the parent's AgeDays__c to the SUM of its related Status History records' AgeDays field
            parentObject.put('Id', parentId);
            parentObject.put('AgeDays__c', ageDaysSum);

            sObjectsToUpdate.add(parentObject);
        }

        //commit update to database
        if (!sObjectsToUpdate.isEmpty()) {
            update sObjectsToUpdate;
        }
    }
*/
}