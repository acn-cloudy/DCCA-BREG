public with sharing class BREGBatchInterfaceExtTest extends BREGBatchInterface {
    
    public override BatchProcessingResult processRecords(Map<Id, SObject> recordsMap, String sObjectType) {
        BatchProcessingResult result = new BatchProcessingResult();
        
        for (Integer i = 0; i < recordsMap.size(); i++) {
            Account acc = (Account) recordsMap.values()[i];
            acc.Name = 'Test Batch_' + i;
            result.recordsToUpsert.put(acc.Id, acc);
            
            // Create a test task
            Task testTask = new Task(
                Subject = 'Test Task for ' + acc.Name,
                WhatId = acc.Id,
                Status = 'Completed'
            );
            result.tasksToUpsert.add(testTask);
        }
        
        logs.add('Processed records by Test Batch');
        return result;
    }            
        
}