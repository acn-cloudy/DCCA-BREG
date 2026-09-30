global class SEBCasePenaltyBatch implements schedulable, Database.Batchable<SObject>, Database.Stateful {
    private String query = 'Select Id, RestitutionCollected__c, RestitutionAssessed__c, PenaltiesSuspended__c, ' 
    + ' PenaltiesAssessed__c, PenaltiesCollected__c from SEBCase__c ';

    /*
     * batch start class
     */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        List<SEBCase__c> records = (List<SEBCase__c>) scope;
        List<SEBCase__c> casesForUpdate = new List<SEBCase__c>();
        List<String> recordIds = new List<String>();
        for(SEBCase__c record: records) {
            recordIds.add(record.Id);
        }
        List<Sanction__c> sanctions = [Select Id, (Select Id, Status__c from Sanction_Payments__r ) from Sanction__c where SEBCaseID__c in: recordIds];
        List<String> sanctionIds = new List<String>();
        for(Sanction__c sanction: sanctions) {
            sanctionIds.add(sanction.Id);
        }
        List<SEBCase__c> penaltiesForUpdate = calculateSummalizedAmount(records, sanctionIds, 'Penalty');
        Set<Id> caseIdSet = (new Map<Id, SEBCase__c>(penaltiesForUpdate)).keySet();
        
        List<SEBCase__c> restitutionForUpdate = calculateSummalizedAmount(records, sanctionIds, 'Restitution/Rescission');
        Set<Id> restitutionIdSet = (new Map<Id, SEBCase__c>(restitutionForUpdate)).keySet();
        
        for(SEBCase__c record: records) {
            if(caseIdSet.contains(record.Id) || restitutionIdSet.contains(record.Id)) {
                casesForUpdate.add(record);
            }
        }
        
        if(!casesForUpdate.isEmpty()) {
            update casesForUpdate;
        }
        
    }

    // public Map<String, Decimal> getDecimalCalFromPayment(List<AggregateResult> results, List<AggregateResult> cancelledResults) {
    //     Map<String, Decimal> summarizedAmount = new Map<String, Decimal>();
    //     for(AggregateResult result: results) {
    //         String sebCaseId = (String) result.get('SEBCaseID__c');
    //         Decimal amountDue = (Decimal) result.get('amount');
    //         summarizedAmount.put(sebCaseId, amountDue);
    //     }
    //     for(AggregateResult result: cancelledResults) {
    //         String sebCaseId = (String) result.get('caseId');
    //         if(summarizedAmount.containsKey(sebCaseId)) {
    //             Decimal amountDue = summarizedAmount.get(sebCaseId);
    //             Decimal amountCancelled = (Decimal) result.get('amount');
    //             if(amountDue == null) amountDue = 0;
    //             if(amountCancelled == null) amountCancelled = 0;
    //             amountDue = amountDue - amountCancelled;
    //             summarizedAmount.put(sebCaseId, amountDue);
    //         } 
    //     }
    //     return summarizedAmount;

    // }
    public Map<String, Decimal> getDecimalCal(List<AggregateResult> results) {
        Map<String, Decimal> summarizedAmount = new Map<String, Decimal>();
        for(AggregateResult result: results) {
            String sebCaseId = (String) result.get('SEBCaseID__c');
            Decimal amountDue = (Decimal) result.get('amount');
            summarizedAmount.put(sebCaseId, amountDue);
        }
        return summarizedAmount;

    }


    public List<SEBCase__c> calculateSummalizedAmount(List<SEBCase__c> records, List<String> sanctionIds, String type) {
        List<SEBCase__c> casesForUpdate = new List<SEBCase__c>();    
        List<String> recordIds = new List<String>();
        for(SEBCase__c record: records) {
            recordIds.add(record.Id);
        }


        List<AggregateResult> resultsAssessed = [Select SEBCaseID__c, Sum(Total_Sanction_Amount__c) amount 
            from Sanction__c where Sanction__c =: type and SEBCaseID__c in: recordIds group by SEBCaseID__c];
        // List<AggregateResult> cancelledResultsAssessed = [Select Sanction__r.SEBCaseID__c caseId, Sum(AmountDue__c) amount 
        //     from Sanction_Payment__c where Status__c = 'Cancelled' and Sanction__r.Sanction__c =: type 
        //     and Sanction__c in: sanctionIds group by Sanction__r.SEBCaseID__c];
        Map<String, Decimal> assessedAmount = getDecimalCal(resultsAssessed);

        List<AggregateResult> resultsCollected = [Select SEBCaseID__c, Sum(Total_Amount_Paid__c) amount 
            from Sanction__c where Sanction__c =: type and SEBCaseID__c in: recordIds group by SEBCaseID__c];

        Map<String, Decimal> collectedAmount = getDecimalCal(resultsCollected);
        
        List<AggregateResult> resultsSuspended = new List<AggregateResult>();
        if(type == 'Penalty') {
            resultsSuspended = [Select SEBCaseID__c, Sum(Suspended_Amount__c) amount 
                from Sanction__c where Sanction__c =: type and Id in: sanctionIds group by SEBCaseID__c];
        }
        Map<String, Decimal> suspendedAmount = getDecimalCal(resultsSuspended);

        if(type == 'Penalty') {
            casesForUpdate = toUpdateForPenality(records, assessedAmount, collectedAmount, suspendedAmount);
        }
        else if(type == 'Restitution/Rescission') {
            casesForUpdate = toUpdateForRestitution(records, assessedAmount, collectedAmount);
        }
        return casesForUpdate;
    }
           
    public List<SEBCase__c> toUpdateForPenality(List<SEBCase__c> records, Map<String, Decimal> assessedAmount, 
        Map<String, Decimal> collectedAmount, Map<String, Decimal> suspendedAmount) {
        List<SEBCase__c> casesForUpdate = new List<SEBCase__c>();    
        for(SEBCase__c record: records) {
            Boolean toBeUpdated = false;  
            if(collectedAmount.containsKey(record.Id)  
                && record.PenaltiesCollected__c != collectedAmount.get(record.Id)) {
                record.PenaltiesCollected__c = collectedAmount.get(record.Id);
                toBeUpdated = true;
            }

            if(assessedAmount.containsKey(record.Id)  
                && record.PenaltiesAssessed__c != assessedAmount.get(record.Id)) {
                record.PenaltiesAssessed__c = assessedAmount.get(record.Id);
                toBeUpdated = true;
            }

            if(suspendedAmount.containsKey(record.Id)  
                && record.PenaltiesSuspended__c != suspendedAmount.get(record.Id)) {
                record.PenaltiesSuspended__c = suspendedAmount.get(record.Id);
                toBeUpdated = true;
            }
            if(toBeUpdated) {
                casesForUpdate.add(record);
            }
        }
        return casesForUpdate;
    }
    public List<SEBCase__c> toUpdateForRestitution(List<SEBCase__c> records, Map<String, Decimal> assessedAmount, 
        Map<String, Decimal> collectedAmount) {
        List<SEBCase__c> casesForUpdate = new List<SEBCase__c>();    
        for(SEBCase__c record: records) {
            Boolean toBeUpdated = false;
            if(collectedAmount.containsKey(record.Id) 
                && record.RestitutionCollected__c != collectedAmount.get(record.Id)) {
                record.RestitutionCollected__c = collectedAmount.get(record.Id);
                toBeUpdated = true;
            }

            if(assessedAmount.containsKey(record.Id) 
                && record.RestitutionAssessed__c != assessedAmount.get(record.Id)) {
                record.RestitutionAssessed__c = assessedAmount.get(record.Id);
                toBeUpdated = true;
            }
            if(toBeUpdated) {
                casesForUpdate.add(record);
            }
        }
        return casesForUpdate;
    }

    /*
     * batch finish class
     */
    global void finish(Database.BatchableContext context) {}

    public void execute(System.SchedulableContext context) {
        Database.executeBatch(new SEBCasePenaltyBatch(), 100);
    }
}