global class MotorVehicleIndustryRenewalPushThrough extends ApplicationRenewalPushThru {
    global MotorVehicleIndustryRenewalPushThrough() {
        super(new List<String> {'MVD', 'MVB', 'CS'}, new List<String> {'R - Valid Thru Expiration Date, Subject To Renewal'});
    }

    global override void processRecords(List<Application__c> records) {
        List<MotorVehicleIndustryRenewal.Input> inputs = new List<MotorVehicleIndustryRenewal.Input>();
        for(Application__c record:records){
            MotorVehicleIndustryRenewal.Input input = new MotorVehicleIndustryRenewal.Input();
            input.record = record;
            inputs.add(input);
        }

        if(!inputs.isEmpty()){
            MotorVehicleIndustryRenewal.forPushThrough = true;
            MotorVehicleIndustryRenewal.execute(inputs);
            MotorVehicleIndustryRenewal.forPushThrough = false;
        }
    }
}