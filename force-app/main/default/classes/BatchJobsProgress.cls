/********************************************************************************************************
*    Name:  BatchJobsProgress.cls
*    Author: PacificPoint 
*    Date:  10/16/2018
*    
*    Test Class: DepositRollupsBatchProgressTest.cls
*    VF Component: BatchJobsProgressComponent.component
********************************************************************************************************/

global class BatchJobsProgress {
 
    private List<BatchJob> batchJobs;
    
    /*******************************************************************************************************
    * @description number of batch jobs the control will monitor
    */  
    global Integer numberOfJobs {get; set;}

    /*******************************************************************************************************
    /*******************************************************************************************************
    * @description number of batch jobs the control will monitor
    */  
    global String apexClassName {get; set;}

    /*******************************************************************************************************
    * @description label to display at the top of the progress meter
    */  
    global String batchComponentLabel {get; set;}
 
    /*******************************************************************************************************
    * @description query for the current batch job progress
    */  
    global List<BatchJob> getBatchJobs() {
        //Create new list of BatchJobs, a wrapper class that includes the job and percent complete.
        batchJobs = new List<BatchJob>();
 
        //If number of jobs was not defined, default to 20
        if(numberOfJobs== null || numberofJobs <= 0) {
            numberofJobs = 20;
        }
        
        if(batchComponentLabel== null) {
            batchComponentLabel = 'Batch Apex Jobs';
        }
        
        List<String> apexClassNameList = apexClassName.split('\\|');
        List<AsyncApexJob> ajobs = [select TotalJobItems, Status, NumberOfErrors, MethodName, JobType, JobItemsProcessed, Id, 
                                    CreatedDate, CreatedById, CompletedDate, ApexClassId, ApexClass.Name 
                                    From AsyncApexJob WHERE ApexClass.Name IN: apexClassNameList order by CreatedDate desc limit :numberOfJobs];
        //Query the Batch apex jobs
        for(AsyncApexJob a : ajobs) {
            Double itemsProcessed = a.JobItemsProcessed;
            Double totalItems = a.TotalJobItems;
 
            BatchJob j = new BatchJob();
            j.job = a;
 
            //Determine the pecent complete based on the number of batches complete
            if(a.status == 'Completed') {
                j.percentComplete = 100;
                
            //Determine the pecent complete based on the number of batches complete
            } else if (totalItems == 0) {
                //A little check here as we don't want to divide by 0.
                j.percentComplete = 0;
                
            } else {
                j.percentComplete = ((itemsProcessed  / totalItems) * 100.0).intValue();
            }
            batchJobs.add(j);
            
        }
        return batchJobs;
    }
 
    
    /*******************************************************************************************************
    * @description wrapper class includes the job itself and a value for the percent complete
    */  
    global Class BatchJob{
        global AsyncApexJob job {get; set;}
        global Integer percentComplete {get; set;}
    }
    
    
    
}