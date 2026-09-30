trigger EarnedCETrigger on Earned_Continuing_Education__c (after insert, after update, after delete, after undelete) {    
    Map<Id, List<Earned_Continuing_Education__c>> LicIdCEListMap = new Map<Id, List<Earned_Continuing_Education__c>>();
    Map<Id, List<Earned_Continuing_Education__c>> LicIdCEListMap2 = new Map<Id, List<Earned_Continuing_Education__c>>();
    Set<Id> licIds = new Set<Id>();

    List<Earned_Continuing_Education__c> CEList = new List<Earned_Continuing_Education__c>();
    List<Earned_Continuing_Education__c> CEList2 = new List<Earned_Continuing_Education__c>();       

    Boolean isUpdateLicenseOnce = false;

    if(trigger.isUpdate || trigger.isInsert) {
        for(Earned_Continuing_Education__c CE : trigger.New){
            if(CE.License__c != null) {
                licIds.add(CE.License__c);   
            }
        }
    }
    if(trigger.isDelete) {
        for(Earned_Continuing_Education__c CE : trigger.old){
            if(CE.License__c != null){
                licIds.add(CE.License__c);
            }
        }
    }
    if(licIds.size() > 0) {
        CEList = [SELECT Credits__c, License__c, BienniumCompare__c FROM Earned_Continuing_Education__c WHERE License__c IN : licIds AND CourseType__c = 'Core' AND BienniumCompare__c = true ];
        for(Earned_Continuing_Education__c CE : CEList){
            if(!LicIdCEListMap.containsKey(CE.License__c)){
            LicIdCEListMap.put(CE.License__c, new List<Earned_Continuing_Education__c>());
            }
            LicIdCEListMap.get(CE.License__c).add(CE);
        }
        List<License__c> licList = new List<License__c>();
        licList = [SELECT TotalCoreHoursinthisBien__c FROM License__c WHERE Id IN: licIds];
        licIds.clear();
        for(License__c lic : licList) {
            List<Earned_Continuing_Education__c> tempCEList = new List<Earned_Continuing_Education__c>();
            tempCEList = LicIdCEListMap.get(lic.Id);
            if(tempCEList == null) {
                continue;
            }
            Double CECoreHours = 0;                
            if(CEList.size() > 0) {                    
                for(Earned_Continuing_Education__c CE : tempCEList) {
                    if(CE.Credits__c != null){
                    CECoreHours += CE.Credits__c;
                    }
                }
                lic.TotalCoreHoursinthisBien__c = CECoreHours;
            }
        }
        update licList;
    }
    if(Trigger.isAfter) {
        if(isUpdateLicenseOnce) return;
        Set<String> licenseIds = new Set<String>();
        // 00014076
        List<Earned_Continuing_Education__c> educations = Trigger.new;
        if(educations == null ) educations = Trigger.old;
        for(Earned_Continuing_Education__c record: educations) {
            licenseIds.add(record.License__c);
        }
        
        // Query License records 
        List<License__c> records = [Select Id, CurrentBiennium__c, PreviousBiennium__c,
            ElectiveCreditsPreviousLicPeriod__c, CoreCreditsPreviousLicensePeriod__c,
            ElectiveCreditsThisLicensePeriod__c, CoreCreditsThisLicensePeriod__c, 
            (select Id, Credits__c, Biennium__c, Type__c from Earned_Continuing_Education__r where BienniumMatch__c = true)
            from License__c where Id =: licenseIds ];

        Map<Id, License__c> licenseMap = new Map<Id, License__c>();
        for(License__c record: records) {
            List<Earned_Continuing_Education__c> earnedContinuingEducations = record.Earned_Continuing_Education__r;
            
            if(earnedContinuingEducations != null) {
                Decimal electiveCreditsPreviousLicPeriod = 0 ;
                Decimal electiveCreditsThisLicensePeriod = 0 ;
                Decimal coreCreditsPreviousLicensePeriod = 0 ;
                Decimal coreCreditsThisLicensePeriod = 0 ;
                for(Earned_Continuing_Education__c education: earnedContinuingEducations ) {
                    if(education.Type__c == 'Elective') {
                        if(education.Biennium__c == record.CurrentBiennium__c) {
                            electiveCreditsThisLicensePeriod += (education.Credits__c != null ? education.Credits__c: 0);
                        }
                        if(education.Biennium__c == record.PreviousBiennium__c) {
                            electiveCreditsPreviousLicPeriod += (education.Credits__c != null ? education.Credits__c: 0);
                        }

                    } else if(education.Type__c == 'Core') {
                        if(education.Biennium__c == record.CurrentBiennium__c) {
                            coreCreditsThisLicensePeriod += (education.Credits__c != null ? education.Credits__c: 0);
                        }
                        if(education.Biennium__c == record.PreviousBiennium__c) {
                            coreCreditsPreviousLicensePeriod += (education.Credits__c != null ? education.Credits__c: 0);
                        }
                    }
                }
                // Compare the difference of the credits sum to check if there is any difference.
                if(record.ElectiveCreditsThisLicensePeriod__c != electiveCreditsThisLicensePeriod ) {
                    record.ElectiveCreditsThisLicensePeriod__c = electiveCreditsThisLicensePeriod;
                    licenseMap.put(record.Id, record);
                }
                if(record.ElectiveCreditsPreviousLicPeriod__c != electiveCreditsPreviousLicPeriod) {
                    record.ElectiveCreditsPreviousLicPeriod__c = electiveCreditsPreviousLicPeriod;
                    licenseMap.put(record.Id, record);
                }
                if(record.CoreCreditsThisLicensePeriod__c != coreCreditsThisLicensePeriod) {
                    record.CoreCreditsThisLicensePeriod__c = coreCreditsThisLicensePeriod;
                    licenseMap.put(record.Id, record);
                }
                if(record.CoreCreditsPreviousLicensePeriod__c != coreCreditsPreviousLicensePeriod) {
                    record.CoreCreditsPreviousLicensePeriod__c = coreCreditsPreviousLicensePeriod;
                    licenseMap.put(record.Id, record);
                }
            }
        }
        if(!licenseMap.isEmpty()) {
            update licenseMap.values();
        }
        isUpdateLicenseOnce = true;
            
        
    }
}