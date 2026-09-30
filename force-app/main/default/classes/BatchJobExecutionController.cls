/*
* ─────────────────────────────────────────────────────────
* Controller for the BatchJobExecution Lightning Component 
* ─────────────────────────────────────────────────────────
* PacPoint-SS05610 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Surbhi Sharma - PacificPointCorp 
* @created      2019-09-13
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/

public class BatchJobExecutionController{
	/*This Method is to load Custom metedataand return Active Custom metadata */
    @AuraEnabled
    public static List<BatchJob_Setting__mdt> loadBatchClassesAsButtons(){
        List<String> scheduledjobList = new List<String>();
        List<String> apexNameList = new List<String>();
        List<BatchJob_Setting__mdt> batchList = new List<BatchJob_Setting__mdt>();
        for(BatchJob_Setting__mdt batch: [SELECT Is_Active__c, MasterLabel, Is_scheduled__c, Batch_Size__c, Batch_Job_Class_Name__c  FROM BatchJob_Setting__mdt WHERE Is_Active__c=true]){
            batchList.add(batch);
            apexNameList.add(batch.Batch_Job_Class_Name__c);  
        }
        
    	List<String> statusList = new List<String>{'Queued','Processing','Holding','Preparing'};        
        for(AsyncApexJob jobInfo : [SELECT ApexClass.Name, Id, Status FROM AsyncApexJob WHERE Status  IN: statusList  LIMIT 1]){
        	scheduledjobList.add(jobInfo.ApexClass.Name);
        }
        for(BatchJob_Setting__mdt batch :batchList){
            if(scheduledjobList.contains(batch.Batch_Job_Class_Name__c)){
                batch.Is_scheduled__c = true;
            }
            
        }
        return batchList;
    }
    /*This method returns the logged in user profile Name for Accecss validation */
    @AuraEnabled    
    public static string fetchProfile(){       
	   String pName=[Select id,name FROM profile WHERE id=:userInfo.getProfileId() LIMIT 1].Name;
       return pName;
    }
    /*This method is to Run batch class on click of Button */
	@AuraEnabled
    public static void runBatchClass(BatchJob_Setting__mdt batchsetting){
        Type t = Type.forName(batchsetting.Batch_Job_Class_Name__c);
        if(t != null) {
            Database.Batchable<sObject> instance = (Database.Batchable<sObject>)t.newInstance();
       	    Id jobid= Database.executeBatch(instance,(Integer)batchsetting.Batch_Size__c);  
        }
        
        
    }

}