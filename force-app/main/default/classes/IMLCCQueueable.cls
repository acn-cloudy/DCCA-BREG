global without sharing class IMLCCQueueable implements Queueable, Database.AllowsCallouts{
    global List<IMLCCQueueableItem> batchItems = new List<IMLCCQueueableItem>();
    global List<IMLCCQueueablePushItem> pushItems = new List<IMLCCQueueablePushItem>();
    global List<IMLCCQueueableBulkPushItem> bulkPushItems = new List<IMLCCQueueableBulkPushItem>();
    global Integer processStep = 1;

    global IMLCCQueueable(){
        batchItems.clear();
        pushItems.clear();
        bulkPushItems.clear();
    }

    global IMLCCQueueable(Integer step){     
        this();
        processStep = step;
    }

    global IMLCCQueueable(Integer step, List<IMLCCQueueable.IMLCCQueueableItem> forProcessItems){     
        this();
        processStep = step;
        batchItems = forProcessItems;
    }

    global IMLCCQueueable(Integer step, List<IMLCCQueueable.IMLCCQueueablePushItem> forProcessItems){     
        this();
        processStep = step;
        pushItems = forProcessItems;
    }

    global IMLCCQueueable(Integer step, List<IMLCCQueueable.IMLCCQueueableBulkPushItem> forProcessItems){     
        this();
        processStep = step;
        bulkPushItems = forProcessItems;
    }

    global void execute(QueueableContext context) {
        try{
            if(processStep == 1) getLicenses();
            else if(processStep == 2) createApplications();
            else if(processStep == 3) pushLicenses();
            else if(processStep == 4) bulkPushLicenses();      
        } catch(IMLCCConnector.IMLCCException ex){
            String type = 'getLicenses';
            if(processStep == 2) type = 'createApplications';
            if(processStep == 3) type = 'pushLicenses';
            if(processStep == 4) type = 'bulkPushLicenses';

            logError('IMLCC Integration', 'IMLCCQueueable', type, ex.getStackTraceString(), ex.getMessage(), '');
        }
    }

    global void pushLicenses(){
        for(IMLCCQueueablePushItem batchItem:pushItems){
            if(batchItem.physicianId != null){
                Map<String, String> params = new Map<String, String>();
                params.put('licenseNumber', batchItem.licenseNumber);
                params.put('dateOfIssue', batchItem.dateOfIssue);
                params.put('dateOfExpiration', batchItem.dateOfExpiration);
                params.put('signer', batchItem.signer);

                try{
                    System.debug(IMLCCConnector.pushSingleLicenseToCompact(batchItem.physicianId, JSON.serialize(params)));
                } catch(IMLCCConnector.IMLCCException ex){
                    System.debug('IMLCCQueueable:pushSingleLicenseToCompact');
                    logError('IMLCC Integration', 'IMLCCQueueable', 'pushLicenses', ex.getStackTraceString(), ex.getMessage(), JSON.serialize(params));
                }
            }
        }
    }

    global void bulkPushLicenses(){
        for(IMLCCQueueableBulkPushItem batchItem:bulkPushItems){
            try{
                System.debug(IMLCCConnector.pushBulkLicensesToCompact(JSON.serialize(batchItem)));
            } catch(IMLCCConnector.IMLCCException ex){
                System.debug('IMLCCQueueable:pushBulkLicensesToCompact');
                logError('IMLCC Integration', 'IMLCCQueueable', 'bulkPushLicenses', ex.getStackTraceString(), ex.getMessage(), JSON.serialize(batchItem));
            }
        }
    }

    global void createApplications(){
        List<Account> physicians = new List<Account>();
        Map<String, Account> nipAccountMap = new Map<String, Account>();
        Map<String, Account> existingAccountsMap = new Map<String, Account>();
        List<String> existingAccountIds = new List<String>();

        Set<String> ssnSet = new Set<String>();
        Map<String, String> physicianIdToSSNMap = new Map<String, String>();
        Set<Id> matchedAccountIds = new Set<Id>();
        Map<String, PhysicianDetails> physicianIdToDetails = new Map<String, PhysicianDetails>();
        Map<String, Account> ssnToAccountSecondMap = new Map<String, Account>();
        Map<String, String> stateNameToCodeMap = new Map<String, String>();
        // Fetch the permitted State picklist values once (upper-cased name -> ISO code)
        // and reuse it inside the loop instead of describing on every iteration.
        Map<String, String> permittedStateNameToCode = getPermittedStateNameToCodeMap();
        //

        Id personAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        for(IMLCCQueueableItem batchItem:batchItems){
            if(batchItem.physicianId != null){
                PhysicianDetails physician = null;
                try{
                    physician = (PhysicianDetails) JSON.deserialize(IMLCCConnector.getRecordDetails('physician', batchItem.physicianId), PhysicianDetails.class);
                    physicianIdToDetails.put(batchItem.physicianId, physician);
                } catch(IMLCCConnector.IMLCCException ex){
                    System.debug('IMLCCQueueable:createApplications');
                    logError('IMLCC Integration', 'IMLCCQueueable', 'createApplications', ex.getStackTraceString(), ex.getMessage(), '');
                }
                
                if(physician != null && physician.new_cdssn != null && String.isNotBlank(physician.new_cdssn)){
                    ssnSet.add(formatSSN(physician.new_cdssn));
                    physicianIdToSSNMap.put(batchItem.physicianId, formatSSN(physician.new_cdssn));
                }
            }
        }
        Map<String, Account> ssnToAccountMap = new Map<String, Account>();
        if(!ssnSet.isEmpty()){
            for(Account acc : [
                SELECT Id, PersonMailingStreet, PersonMailingCity, PersonMailingPostalCode, 
                    PersonMailingState, PersonMailingStateCode, PersonBirthdate, BPID__c
                FROM Account 
                WHERE BPID__c IN :ssnSet 
                AND IsPersonAccount = true
            ]){
                ssnToAccountMap.put(acc.BPID__c, acc);
            }
        }
        

        for(IMLCCQueueableItem batchItem:batchItems){
            if(batchItem.physicianId != null){
                PhysicianDetails physician = null;
                try{
                    physician = physicianIdToDetails.containsKey(batchItem.physicianId) ? physicianIdToDetails.get(batchItem.physicianId) : null;
                } catch(IMLCCConnector.IMLCCException ex){
                    System.debug('IMLCCQueueable:createApplications');
                    logError('IMLCC Integration', 'IMLCCQueueable', 'createApplications', ex.getStackTraceString(), ex.getMessage(), '');
                }

                if(Test.isRunningTest()){
                    physician = new PhysicianDetails();
                    physician.new_cdfirstname = 'Test';
                    physician.new_cdlastname = 'Last Name';
                    physician.new_gender = 'Male';
                    physician.new_email = 'test@test.com';
                    physician.new_cdmailingaddress = 'TEST';
                    physician.new_cdmailingaddress = 'TEST';
                    physician.new_cdcity = 'TEST';
                    physician.new_cdzip = '30135';
                    physician.imlcc_physicianspersonalphone = '123456789';
                    physician.imlcc_practicepublicphone = '123456789';
                }
                
                if(physician != null){
                    String ssn = formatSSN(physician.new_cdssn);
                    Account existingAccount = ssn != null ? ssnToAccountMap.get(ssn) : null;

                    if(existingAccount == null){
                        if(!ssnToAccountSecondMap.containsKey(ssn)){ 
                            Account acc = new Account(
                                FirstName = physician.new_cdfirstname != null ? physician.new_cdfirstname : '',
                                LastName = physician.new_cdlastname != null ? physician.new_cdlastname : '',
                                MiddleName = physician.new_cdmiddlename != null ? physician.new_cdmiddlename : '',
                                NPI__c = batchItem.nipId != null ? batchItem.nipId : '',
                                PersonGenderIdentity = physician.new_gender != null ? physician.new_gender : '',
                                PersonEmail = physician.new_email != null ? physician.new_email : '',
                                PersonMailingStreet = physician.new_cdmailingaddress != null ? physician.new_cdmailingaddress : '',
                                PersonMailingCity = physician.new_cdcity != null ? physician.new_cdcity : '',
                                PersonMailingPostalCode = physician.new_cdzip != null ? physician.new_cdzip : '',
                                MobilePhone__c = physician.imlcc_physicianspersonalphone != null ? physician.imlcc_physicianspersonalphone : '',
                                BusinessPhone__c = physician.imlcc_practicepublicphone != null ? physician.imlcc_practicepublicphone : '',
                                BPID__c = formatSSN(ssn),
                                PersonBirthdate = parseDate(physician.new_cddob)
                            );
                            // Only populate the State picklist when the incoming value maps to a
                            // permitted picklist value. This prevents the daily batch from failing when the
                            // physician's office state is invalid (e.g. name '--').
                            String officeStateName = physician.imlcc_physicianofficestate != null && physician.imlcc_physicianofficestate.imlcc_name != null ? physician.imlcc_physicianofficestate.imlcc_name : '';
                            if(officeStateName.toUpperCase().contains('WASHINGTON')) officeStateName = 'WASHINGTON';
                            if(permittedStateNameToCode.containsKey(officeStateName.toUpperCase())){
                                acc.PersonMailingState = officeStateName;
                                stateNameToCodeMap.put(officeStateName, permittedStateNameToCode.get(officeStateName.toUpperCase()));
                            }
                            physicians.add(acc);
                            nipAccountMap.put(batchItem.nipId, acc);
                            ssnToAccountSecondMap.put(ssn, acc);
                        }
                        else if(ssnToAccountSecondMap.containsKey(ssn)){ 
                            nipAccountMap.put(batchItem.nipId, ssnToAccountSecondMap.get(ssn));
                        }
                    }
                    else{
                        nipAccountMap.put(batchItem.nipId, existingAccount);
                        matchedAccountIds.add(existingAccount.Id);
                    }

                    
                }
            } else if(batchItem.accountId != null){
                existingAccountIds.add(batchItem.accountId);
                matchedAccountIds.add(batchItem.accountId);
            }
        }

        if(!physicians.isEmpty()) insert physicians;

        // Get Existing Accounts Details
        for(Account acc:[SELECT Id, PersonMailingStreet, PersonMailingCity, PersonMailingPostalCode, PersonMailingState, PersonMailingStateCode FROM Account WHERE Id IN :existingAccountIds]){
            existingAccountsMap.put(acc.Id, acc);
        }

        // Create Application
        LicenseType__c MDLicType = [SELECT Id FROM LicenseType__c WHERE Name = 'MD'];
        LicenseType__c DOSLicType = [SELECT Id FROM LicenseType__c WHERE Name = 'DOS'];

        List<Application__c> appsForCreation = new List<Application__c>();
        for(IMLCCQueueableItem batchItem:batchItems){
            StandardLicenseValue licVal = batchItem.licVal;
            Application__c app = new Application__c();
            if(batchItem.accountId != null && existingAccountsMap.get(batchItem.accountId) != null){
                Account curAcc = existingAccountsMap.get(batchItem.accountId);
                app.Applicant__c = curAcc.Id;
                app.MailingStreet__c = curAcc.PersonMailingStreet;
                app.MailingCity__c = curAcc.PersonMailingCity; 
                app.MailingZipCode__c = curAcc.PersonMailingPostalCode;  
                app.MailingState__c = curAcc.PersonMailingStateCode != null ? curAcc.PersonMailingStateCode : stateNameToCodeMap.containsKey(curAcc.PersonMailingState) ? stateNameToCodeMap.get(curAcc.PersonMailingState) : '';
                app.MailingCountry__c = 'United States';

            } else if(batchItem.physicianId != null && nipAccountMap.get(batchItem.nipId) != null){
                Account curAcc = nipAccountMap.get(batchItem.nipId);
                app.Applicant__c = curAcc.Id;
                app.MailingStreet__c = curAcc.PersonMailingStreet;
                app.MailingCity__c = curAcc.PersonMailingCity; 
                app.MailingZipCode__c = curAcc.PersonMailingPostalCode;
                app.MailingState__c = curAcc.PersonMailingStateCode != null ? curAcc.PersonMailingStateCode : stateNameToCodeMap.containsKey(curAcc.PersonMailingState) ? stateNameToCodeMap.get(curAcc.PersonMailingState) : '';
                app.MailingCountry__c = 'United States';
            } else continue;
            
            app.IMLCCLicenseId__c = licVal.new_physicianlicenseid;
            app.Type__c = 'LICN - New License';
            app.Phase__c = 'A - Application Received';
            app.Status__c = 'A1 - Application Submitted, Awaiting Review';
            //app.GenerateLicense__c = true;
            app.DateofLicensure__c = Date.today();
            app.ApplicationReceivedDate__c = licVal.createdon != null ? Date.valueOf(DateTime.valueOfGMT((licVal.createdon).replace('T', ' ').replace('Z',''))) : null;
            app.TypeofEntity__c = 'I - Individual';
            app.MethodofLicensure__c = 'LC - Licensure Compact';

            if(licVal.new_name.contains('HAWAII MEDICAL BOARD - MD')) app.LicenseType__c = MDLicType.Id;
            else if(licVal.new_name.contains('HAWAII MEDICAL BOARD - DO')) app.LicenseType__c = DOSLicType.Id;

            app.ApprovedforLicensureDate__c = Date.today(); 
            app.LicensePeriod__c = 'This License Period';
            app.DateofLicensure__c = Date.today();

            app.IMLCC_Member__c = true;

            appsForCreation.add(app);
        }

        ApplicationService.skipExamCreation = true;
        if(!Test.isRunningTest() && !appsForCreation.isEmpty()) insert appsForCreation;

        // Trigger License Generation; only works on update
        // Trigger Transaction Lines only available for A1 Applications
        // Set Status to HC
        List<Id> appIds = new List<Id>();
        for(Application__c app:appsForCreation){
            if(app.MailingStreet__c != null){
                app.GenerateLicense__c = true;     
                app.Phase__c = 'H - License Generation';
                app.Status__c = 'HC - Application Completed';
                if(!Test.isRunningTest()) appIds.add(app.Id);
            }
            else{
                System.debug('Address missing '+app.Applicant__c);
            }
        }
        // Defer update apps, create payments, and send email via future (separate transaction; avoids "Too many queueable jobs")
        if (!Test.isRunningTest() && !appsForCreation.isEmpty()) {
            ApplicationService.runIMLCCAfterApplicationCreate(appIds, new List<Id>(matchedAccountIds));
        }

        ApplicationService.skipExamCreation = false;
        appsForCreation.clear();
        batchItems.clear();  
    }



    global void createPayments(List<Id> appIds){
        createPaymentsForApps(appIds);
    }

    /** Static payment creation for use from PVLProcessTrigger (IMLCCAfterApplicationCreate). */
    global static void createPaymentsForApps(List<Id> appIds){
        if (appIds == null || appIds.isEmpty()) return;
        List<pymt__PaymentX__c> payments = new List<pymt__PaymentX__c>();
        for (Transaction__c t : [SELECT Id, Name, TotalAmount__c, PersonAccountContact__c, Account__c, Application__c FROM Transaction__c WHERE Application__c IN :appIds]) {
            pymt__PaymentX__c payment = new pymt__PaymentX__c();            
            payment.Transaction__c = t.Id;
            payment.Name = t.Name;
            payment.pymt__Amount__c = t.TotalAmount__c;
            payment.pymt__Account__c = t.Account__c;
            payment.pymt__Contact__c = t.PersonAccountContact__c;
            payment.pymt__Status__c = 'Completed';
            payment.pymt__Payment_Type__c = 'Deposit Slip';
            payment.pymt__Date__c = Date.today();
            payments.add(payment);
        }
        if (!payments.isEmpty()) insert payments;
    }

    global void getLicenses(){
        // Get Pending List
        try{
            StandardLicenseListResponse resp = new StandardLicenseListResponse();            
            // Add Test Data
            if(Test.isRunningTest()){
                PhysiciantoLicenseIdDetails new_PhysiciantoLicenseId = new PhysiciantoLicenseIdDetails();
                new_PhysiciantoLicenseId.fullname = 'TEST';
                new_PhysiciantoLicenseId.new_cdnpi = 'test123';
                new_PhysiciantoLicenseId.contactid = 'contact123';

                StandardLicenseValue licVal = new StandardLicenseValue();
                licVal.new_physicianlicenseid = 'test123';
                licVal.createdon = null;
                licVal.new_name = 'TEST - HAWAII MEDICAL BOARD - MD';
                licVal.new_PhysiciantoLicenseId = new_PhysiciantoLicenseId;
                resp.value = new List<StandardLicenseValue>{licVal};
            } else{
                resp = (StandardLicenseListResponse) JSON.deserialize(IMLCCConnector.getList('license', 'status=pending&licType=sos'), StandardLicenseListResponse.class);
            }

            if(resp != null && resp.value != null){
                Map<String, StandardLicenseValue> physicianLicMap = new Map<String, StandardLicenseValue>();
                Map<String, List<StandardLicenseValue>> nipToLicMap = new Map<String, List<StandardLicenseValue>>();
                for(StandardLicenseValue slv : resp.value){
                    List<StandardLicenseValue> nipLics = nipToLicMap.get(slv.new_PhysiciantoLicenseId.new_cdnpi);
                        if(nipLics == null) nipLics = new List<StandardLicenseValue>();
                        nipLics.add(slv);
                        nipToLicMap.put(slv.new_PhysiciantoLicenseId.new_cdnpi, nipLics);                    
                        physicianLicMap.put(slv.new_physicianlicenseid, slv);
                }

                //Check existing Licenses  
                List<String> existingLICs = new List<String>();             
                for(License__c lic:[SELECT IMLCCLicenseId__c FROM License__c WHERE IMLCCLicenseId__c IN :physicianLicMap.keySet()]){
                    existingLICs.add(lic.IMLCCLicenseId__c);
                }
                
                
                Map<String, String> nipAccountMap = new Map<String, String>();
                // Check Existing Accounts
                for(Account acc:[SELECT Id, NPI__c FROM Account WHERE NPI__c IN :nipToLicMap.keySet()]){
                    nipAccountMap.put(acc.NPI__c, acc.Id);
                }

                List<IMLCCQueueableItem> forProcessing = new List<IMLCCQueueableItem>();
                for(String nip : nipToLicMap.keySet()){
                    List<StandardLicenseValue> licVals = nipToLicMap.get(nip);
                    for(StandardLicenseValue licVal : licVals){
                        if(existingLICs.contains(licVal.new_physicianlicenseid)) continue;

                        String contactId = licVal.new_PhysiciantoLicenseId.contactid;
                        IMLCCQueueableItem batchItem = new IMLCCQueueableItem();
                        batchItem.nipId = nip;
                        if(nipAccountMap.containsKey(nip)){
                            batchItem.accountId = nipAccountMap.get(nip);
                        } else if(contactId != null){
                            batchItem.physicianId = contactId;
                        } else {
                            continue;
                        }
                        batchItem.licVal = licVal;
                        forProcessing.add(batchItem);

                        // Limit is 100 callouts per transaction; Setting 90 for allowance
                        // Setting 90 for allowance
                        if(forProcessing.size() == 90){
                            if(!Test.isRunningTest()) System.enqueueJob(new IMLCCQueueable(2, forProcessing));
                            forProcessing.clear();
                        }
                    }
                }

                if(!forProcessing.isEmpty()){
                    if(!Test.isRunningTest()) System.enqueueJob(new IMLCCQueueable(2, forProcessing));
                    forProcessing.clear();
                }
            }
        } catch(IMLCCConnector.IMLCCException ex){
            System.debug('IMLCCQueueable:getLicenses');
            logError('IMLCC Integration', 'IMLCCQueueable', 'getLicenses', ex.getStackTraceString(), ex.getMessage(), '');
        }
    }

    global void logError(String type, String source, String sourceFunction, String stackTrace, String message, String payload){
        Application_Log__c appLog = new Application_Log__c();
        appLog.Type__c =type;
        appLog.Source__c = source;
        appLog.Source_Function__c = sourceFunction;
        appLog.Stack_Trace__c = stackTrace;
        appLog.Message__c = message;
        appLog.Integration_Payload__c = payload;
        Database.insert(appLog, false); // Do not rollback since were logging errors
    }

    private static Date parseDate(String dateString) {
        if(String.isBlank(dateString)) return null;
        try {
            return Date.valueOf(dateString);
        } catch(Exception e) {
            return null;
        }
    }

    /**
     * Processes the SSN/BPID string by removing all hyphens 
     * to comply with the Account validation rule.
     */
    public static String formatSSN(String rawSSN) {
        if (String.isBlank(rawSSN)) {
            return rawSSN;
        }
        // Removes every occurrence of the hyphen character
        return rawSSN.replace('-', '');
    }

    
    // Builds the permitted State picklist values (upper-cased name -> ISO code) so the
    // batch only writes values accepted by the PersonMailingState picklist. Called once
    // per run and reused across the loop instead of describing on every iteration.
    private static Map<String, String> getPermittedStateNameToCodeMap(){
        Map<String, String> stateNameToCode = new Map<String, String>();
        for(FieldUtils.PicklistOption option : FieldUtils.getPicklistOptions('Account', 'PersonMailingStateCode')){
            if(String.isNotBlank(option.label)) stateNameToCode.put(option.label.toUpperCase(), option.value);
        }
        return stateNameToCode;
    }

    global class StandardLicenseListResponse {
    public List<StandardLicenseValue> value;
  }

  global class StandardLicenseValue {
    public String new_physicianlicenseid;      
    public String createdon;
        public String new_name;
    public PhysiciantoLicenseIdDetails new_PhysiciantoLicenseId;   
  }

  global class PhysiciantoLicenseIdDetails{
    public String fullname;
    public String new_cdnpi;
    public String contactid;   
  }

  global class PhysicianDetails{
    public String new_cdfirstname;
    public String new_cdmiddlename;
    public String new_cdlastname;
    public String new_cdnpi;
    public String new_gender;
    public String new_email;
    public String new_cdmailingaddress;
    public String new_cdcity;
    public String new_cdzip;
    public String imlcc_physicianspersonalphone;
    public String imlcc_practicepublicphone;
    public String new_cddob; 
    public String new_cdssn;
    public IMLCC_State imlcc_physicianofficestate;
  }

  global class IMLCC_State{
    public string imlcc_name;
    public string imlcc_stateid;
    public string imlcc_code;
  }

    global class IMLCCQueueableItem{
        public String accountId;
        public String nipId;
        public String physicianId;
        public StandardLicenseValue licVal;
    }

    global class IMLCCQueueablePushItem{
        public String licenseNumber;
        public String dateOfIssue;
        public String dateOfExpiration;
        public String signer;
        public String physicianId;
    }

    global class IMLCCQueueableBulkPushItem{
        public String new_issueddate;
        public String new_expires;
        public String imlcc_signaturembtypedname;
        public Map<String, String> licenseNumbers;
    }
}