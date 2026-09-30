global class MassageTherapyRenewalPushThrough  extends ApplicationRenewalPushThru {
    global MassageTherapyRenewalPushThrough() {
        super(new List<String> {'MAE', 'MAE - Sole Proprietor'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        List<MassageTherapyRenewal.Input> inputs = new List<MassageTherapyRenewal.Input>();
        for(Application__c record:records){
            MassageTherapyRenewal.Input input = new MassageTherapyRenewal.Input();
            input.inputApplication = record;
            input.inputLicense = new License__c(Id = record.CurrentLicense__c);
            inputs.add(input);
        }

        if(!inputs.isEmpty()){
            MassageTherapyRenewal.forPushThrough = true;
            MassageTherapyRenewal.execute(inputs);
            MassageTherapyRenewal.forPushThrough = false;
        }
    }
}