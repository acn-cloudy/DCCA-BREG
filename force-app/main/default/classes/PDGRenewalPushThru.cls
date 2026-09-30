global class PDGRenewalPushThru extends ApplicationRenewalPushThru {
    global PDGRenewalPushThru() {
        super(new List<String> {'GD', 'GD - Sole Proprietor', 'GDA', 'PD', 'PD - Sole Proprietor', 'PDA'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        List<PDGRenewal.Input> inputs = new List<PDGRenewal.Input>();
        for(Application__c record:records){
            PDGRenewal.Input input = new PDGRenewal.Input();
            input.record = record;
            inputs.add(input);
        }

        if(!inputs.isEmpty()){
            PDGRenewal.forPushThrough = true;
            PDGRenewal.execute(inputs);
            PDGRenewal.forPushThrough = false;
        }
    }
}