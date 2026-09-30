public without sharing class BatchSummaryPDF {

    public string batch { get; set; }
    public List<String> transactionSummaryList { get; set; }
    public String printFields { get; set; }
    public List<Transaction__c> transactions { get; set; }
    public Map<String, List<String>> accountsFieldMap { get; set; }
    public List<String> codes { get; set; }

    public BatchSummaryPDF() {
        batch = ApexPages.currentPage().getParameters().get('batch');
        printFields = ApexPages.currentPage().getParameters().get('printFields'); //Account Fields to be shown on the pdf
        transactionSummaryList = new List<String>();

        Map<String, Object> objectFieldsMap = (Map<String, Object>)JSON.deserializeUntyped(printFields);
        List<Map<String, Object>> objectFieldsList = new List<Map<String, Object>>();
        for (Object instance : (List<Object>)objectFieldsMap.get('data')) {
            objectFieldsList.add((Map<String, Object>)instance);
        }

        String queryFields = '';
        Integer currentObject = 1;
        for(Map<String, Object> obj : objectFieldsList){
            for(String relationshipName : obj.keySet()){
                String currentFields = (String) obj.get(relationshipName);

                if(relationshipName == 'Transaction__c'){
                    if(currentFields != 'BatchNumber__c'){
                        queryFields += currentFields;
                    }
                }else{
                    //fields are separated by comma on the metadata. Split them into a list
                    List<String> fieldsList = currentFields.split(',');

                    Integer startNum = 1;
                    for(String fieldName : fieldsList){
                        queryFields += relationshipName + '.'+fieldName;
                        if(startNum != fieldsList.size()){
                            queryFields += ', ';
                        }
                        startNum += 1;
                    }

                }
                if(currentObject < objectFieldsList.size()){
                    queryFields += ', ';
                }

                currentObject += 1;
            }
        }



        //Retrieve Account's Field Properties
        Schema.SObjectType accountsObjType = Schema.getGlobalDescribe().get('Account');
        Map<String, Schema.SobjectField> fieldMap = accountsObjType.getDescribe().fields.getMap();

        String query = 'SELECT Id, BatchNumber__c, ' + queryFields + ' FROM Transaction__c WHERE BatchNumber__c = :batch';
        transactions = Database.query(query); //Retrieve the Transactions and related Account data

        //Format <Transaction Id, List <Label: Value>
        accountsFieldMap = new Map<String, List<String>>();

         //Retrieve Object Fields and field data
        Schema.SObjectType transactionObjType = Schema.getGlobalDescribe().get('Transaction__c');
        Map<String, Schema.SobjectField> transFieldMap = transactionObjType.getDescribe().fields.getMap();

        for(Transaction__c trans :transactions){
            for(Map<String, Object> obj : objectFieldsList) {
                String transactionSummary = '';
                for (String relationshipName : obj.keySet()) {
                    String currentFields = (String) obj.get(relationshipName);
                    List<String> fieldsList = currentFields.split(',');
                    if(relationshipName == 'Transaction__c'){
                        for(String fieldName : fieldsList){
                            Object fieldValue = trans.get(fieldName);
                            fieldValue = (fieldValue == null) ? '' : fieldValue;
                            String fieldLabel = transFieldMap.get(fieldName).getDescribe().getLabel();
                            transactionSummary += fieldLabel + ': ' + fieldValue + '<br />';
                        }
                    }else{
                        String getRelFieldname = relationshipName.replace('__r', '__c');
                        Schema.DescribeFieldResult f = Schema.getGlobalDescribe()
                                .get('Transaction__c')
                                .getDescribe()
                                .fields
                                .getMap()
                                .get(getRelFieldname)
                                .getDescribe();
                        String currentObjectFromRel = '';
                        for(Schema.SObjectType reference : f.getReferenceTo()) {
                            currentObjectFromRel = reference.getDescribe().getName();
                        }

                        //Retrieve Object Fields and field data
                        Schema.SObjectType currentObjType = Schema.getGlobalDescribe().get(currentObjectFromRel);
                        Map<String, Schema.SobjectField> currentObjFieldMap = currentObjType.getDescribe().fields.getMap();

                        for(String fieldName : fieldsList){
                            String fieldValue = (String) trans.getSobject(relationshipName).get(fieldName);
                            String fieldRelName = fieldName.replace(relationshipName + '.', '');
                            String fieldLabel = currentObjFieldMap.get(fieldRelName).getDescribe().getLabel();
                            fieldValue = (fieldValue == null) ? '' : fieldValue;
                            transactionSummary += fieldLabel + ': ' + fieldValue + '<br />';
                        }

                    }
                    transactionSummaryList.add(transactionSummary);
                }
            }
            String breakAfterRecord = '<br />';
            transactionSummaryList.add(breakAfterRecord);

        }
        codes = new List<String>();
        if (transactions.size() > 0) {
            for (TransactionLine__c tl : [SELECT CashierCode__r.CashierCode__c FROM TransactionLine__c WHERE Transaction__c = :transactions[0].Id])
            {
                codes.add(tl.CashierCode__r.CashierCode__c);
            }
        }
    }

}