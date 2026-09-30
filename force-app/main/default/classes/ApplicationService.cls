/*
* ─────────────────────────────────────────────────────────
* Used for the Business logic around
* Application records
* ─────────────────────────────────────────────────────────
* PacPoint-AZ130619 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Alvin Zhou - PacificPointCorp
* @created      2019-06-13
* ───────────────────────────────────────────────────────────
* Changes
*
* 05-20-2020 PacPoint:RdG - Case# 8363 - Validation Check: License to have Insurances w/ valid term dates before an Application can be updated to HC
*
* ───────────────────────────────────────────────────────────
*/
public without sharing class ApplicationService {
    public static Boolean skipApplicationPhaseUpdate = false;
    public static Boolean skipApplicationCacheUpdate = false;
    public static Boolean skipExamCreation = false;
    private static Map<String, License__c> licensesForRenew = new Map<String, License__c>();
    private static Set<String> applicationIdSetForSendApprovedForExamLetterEmail = new Set<String>();
    private static Set<String> applicationIdSetForADDPApprovedLetterEmail = new Set<String>();
    private static Set<String> applicationIdsTobeChecked = new Set<String>();
    private static Set<String> applicationIdsTobeDeleted = new Set<String>();
    private static Map<String, String> appIdMapForDependentLicenseCheck = new Map<String, String>();
    private static Set<String> applicationClassificationToCheck = new Set<String>();
    private static Set<String> applicationIds_L_LicenseReview = new Set<String>();
    private static Set<String> applicationIds_L_LicenseRequirement = new Set<String>();
    private static Set<String> applicationIds_L_Classification = new Set<String>();
    private static Set<String> applicationIds_L_PDFGeneration = new Set<String>();
    private static List<String> depedentAppIds_L_LicenseReview = new List<String>();
    private static List<String> dependentLicenseIds = new List<String>();
    private static List<String> onlineRenewalCopyAppIds = new List<String>();
    private static Set<String> hcRenewalCheckIds = new Set<String>();
    public static Map<String, Boolean> hcRenewalValidationFail = new Map<String, Boolean>();

    // 00005902 Dymatic Create PDF
    public static void PDFGeneration(SObject oldSo, SObject so) {
        Application__c app = (Application__c) so;
        Application__c oldApp = (Application__c) oldSo;
        if(app.GenerateFile__c && app.GenerateFile__c  != oldApp.GenerateFile__c) {
            applicationIds_L_PDFGeneration.add(app.Id);
            app.GenerateFile__c = false;
        }
    }

    /*
     * Case 00023552 related to 00023182 00023183
     */
    public static List<Application__c> takeRenewalSnapshot(List<Application__c> apps) {
        Map<Id, Application__c> applicationMap = new Map<Id, Application__c>(apps);
        Set<String> licenseIds = new Set<String>();

        for (Application__c a : apps) {
            if(a.CurrentLicense__c != null) {
                licenseIds.add(a.CurrentLicense__c);
            }
        }

        Map<String, List<AssociatedLicense__c>> licenseIdassocEmployersMap = new Map<String, List<AssociatedLicense__c>>();
        for (AssociatedLicense__c a : [
                SELECT
                        Id,
                        EntityName__c,
                        EntityLicenseNumber__c,
                        EmployeeLicense__c,
                        Position__c,
                        EntityActiveInactive__c
                FROM AssociatedLicense__c
                WHERE EmployeeLicense__c IN :licenseIds
                AND EmploymentStatus__c = 'Employed'
                AND (EndDate__c >= TODAY OR EndDate__c = null)
        ]) {
            if (!licenseIdassocEmployersMap.containsKey(a.EmployeeLicense__c)) {
                licenseIdassocEmployersMap.put(a.EmployeeLicense__c, new List<AssociatedLicense__c>());
            }

            licenseIdassocEmployersMap.get(a.EmployeeLicense__c).add(a);
        }

        Map<String, List<AssociatedLicense__c>> licenseIdassocEmployeesMap = new Map<String, List<AssociatedLicense__c>>();
        for (AssociatedLicense__c a : [
                SELECT
                        Id,
                        EmployeeName__c,
                        EmployeeLicense__r.Name,
                        PositionStatus__c,
                        EntityLicense__c,
                        Position__c,
                        EntityActiveInactive__c
                FROM AssociatedLicense__c
                WHERE EntityLicense__c IN :licenseIds
                AND EmploymentStatus__c = 'Employed'
                AND (EndDate__c >= TODAY OR EndDate__c = null)
        ]) {
            if (!licenseIdassocEmployeesMap.containsKey(a.EmployeeLicense__c)) {
                licenseIdassocEmployeesMap.put(a.EntityLicense__c, new List<AssociatedLicense__c>());
            }

            licenseIdassocEmployeesMap.get(a.EntityLicense__c).add(a);
        }

        Map<String, List<InsuranceBond__c>> licenseIdInsuranceBondMap = new Map<String, List<InsuranceBond__c>>();
        for (InsuranceBond__c ib : [
                SELECT
                        Id,
                        Type__c,
                        PolicyNumber__c,
                        Surety__c,
                        TermDate__c,
                        License__c
                FROM InsuranceBond__c
                WHERE License__c IN :licenseIds
                AND Status__c = 'Active'
                AND (TermDate__c >= TODAY OR TermDate__c = null)
                AND (CancelDate__c >= TODAY OR CancelDate__c = null)
        ]) {
            if (!licenseIdInsuranceBondMap.containsKey(ib.License__c)) {
                licenseIdInsuranceBondMap.put(ib.License__c, new List<InsuranceBond__c>());
            }

            licenseIdInsuranceBondMap.get(ib.License__c).add(ib);
        }

        Map<String, List<LicenseClassification__c>> licenseIdLicenseClassificationMap = new Map<String, List<LicenseClassification__c>>();
        for (LicenseClassification__c lc :  [
                SELECT
                        Id,
                        ClassificationName__c,
                        ClassificationDescription__c,
                        EffectiveStartDate__c,
                        RestrictedClassRenewalForm__c,
                        License__c
                FROM LicenseClassification__c
                WHERE License__c IN :licenseIds
                AND Status__c = 'C - Current, Valid & In Good Standing'
                AND (EndDate__c >= TODAY OR EndDate__c = null)
        ]) {
            if (!licenseIdLicenseClassificationMap.containsKey(lc.License__c)) {
                licenseIdLicenseClassificationMap.put(lc.License__c, new List<LicenseClassification__c>());
            }

            licenseIdLicenseClassificationMap.get(lc.License__c).add(lc);
        }

        for (Application__c app : apps) {
            String licenseId = app.CurrentLicense__c;
            if (licenseId == null) {
                continue;
            }
            Boolean hasEmployers = licenseIdassocEmployersMap.containsKey(licenseId);
            Boolean hasEmployees = licenseIdassocEmployeesMap.containsKey(licenseId);

            JSONGenerator employmentDataGenerator = JSON.createGenerator(false);
            //Employers
            if (hasEmployers) {
                employmentDataGenerator.writeStartObject();
                employmentDataGenerator.writeObjectField('employers', licenseIdassocEmployersMap.get(licenseId));
                employmentDataGenerator.writeEndObject();
            }

            //employees
            if (hasEmployees) {
                employmentDataGenerator.writeStartObject();
                employmentDataGenerator.writeObjectField('employees', licenseIdassocEmployeesMap.get(licenseId));
                employmentDataGenerator.writeEndObject();
            }

            if (hasEmployees || hasEmployers) {
                app.OnlineRenewalEmployment__c = employmentDataGenerator.getAsString();
            }

            if (licenseIdInsuranceBondMap.containsKey(licenseId)) {
                app.OnlineRenewalInsurance__c = JSON.serialize(licenseIdInsuranceBondMap.get(licenseId));
            }

            if (licenseIdLicenseClassificationMap.containsKey(licenseId)) {
                app.OnlineRenewalClasses__c = JSON.serialize(licenseIdLicenseClassificationMap.get(licenseId));
            }
        }

        return apps;
    }

    public static void generateOnlineRenewalCopy(SObject oldSo, SObject so) {
        Application__c app = (Application__c) so;
        Application__c oldApp = (Application__c) oldSo;
        if(app.GenerateOnlineRenewal__c) {
            app.GenerateOnlineRenewal__c = false;
            onlineRenewalCopyAppIds.add(app.Id);
        }
    }

    //PacPoint:RdG - Case# 8363 - Validation Check: License to have Insurances w/ valid term dates before an Application can be updated to HC
    public static void validationLicenseRenew(SObject oldSo, SObject so) {
        Application__c app = (Application__c) so;
        Application__c oldApp = (Application__c) oldSo;
        License__c license;
        if(!licensesForRenew.isEmpty()) {
            license = licensesForRenew.get(app.CurrentLicense__c);
        }
        if((app.Type__c == 'RNEW - Renewal' || app.Type__c == 'RSTR - Restore - No A/I Status') && ((app.Phase__c == 'H - License Generation' && app.Phase__c != oldApp.Phase__c && app.Status__c == null) || (app.Status__c == 'HC - Application Completed' && app.Status__c != oldApp.Status__c))
        && (app.ActiveInactive__c == 'Active' || app.ActiveInactive__c == null)){
            if(app.LicenseType__c != null && app.CurrentLicense__c != null){
                
                if(license != null) {
                    Boolean isValid = hcRenewalValidationFail.containsKey(app.Id) ? hcRenewalValidationFail.get(app.Id) : isHcRenewalValidationFail(new List<Application__c>{app}, new List<License__c>{license}).get(app.Id);
                    if(isValid) app.addError('This License can not renew because it does not have valid insurance/bond one day after the end of the license period');
                }

                //dont validate dependent app
                if (oldApp.Phase__c == 'D - Dependency Review') {
                    return;
                }

                List<License__c> currentLicense = LicenseSelector.getLicenses(new String[]{app.CurrentLicense__c});
                if (!currentLicense.isEmpty() &&
                        currentLicense[0].LicenseType__r.DependencyRequired__c &&
                        !currentLicense[0].LicenseType__r.RequiresallEmployeestoRenew__c) {
                    List<PVL_RenewalsGetDependentApplications.Input> inputs = new List<PVL_RenewalsGetDependentApplications.Input>();
                    PVL_RenewalsGetDependentApplications.Input param = new PVL_RenewalsGetDependentApplications.Input();
                    param.associatedLicenseRelationship = currentLicense[0].LicenseType__r.AssociatedLicenseRelationship__c;
                    param.ivokingLicense = currentLicense[0];
                    param.requiresEntityPrincipal = currentLicense[0].LicenseType__r.EntityPrincipalFlagUsed__c;
                    inputs.add(param);
                    System.debug('##inuput##' + JSON.serialize(inputs));
                    List<PVL_RenewalsGetDependentApplications.Output> outs =
                            PVL_RenewalsGetDependentApplications.getDependentApplication(inputs);
                    Application__c depApp = outs[0].dependentApplication;
                    System.debug('####depApp####' + depApp);
                    if (depApp != null) {
                        Boolean depIsValid = hcRenewalValidationFail.containsKey(depApp.Id) ? hcRenewalValidationFail.get(depApp.Id) : isHcRenewalValidationFail(new List<Application__c>{depApp}).get(depApp.Id);
                        if(depIsValid) app.addError('This License can not renew because the dependent license ' +
                                depApp.CurrentLicense__r.Name +
                                ' does not have valid insurance/bond one day after the end of the license period.');
                    }
                }
            }
        }
    }

    public static void ensureRenewByPermitToPracticeValue(SObject so) {
        Application__c application = (Application__c) so;
        if (application.RenewingPermitToPractice__c == 'No' || String.isBlank(application.RenewingPermitToPractice__c)) {
            application.RenewByPermitToPractice__c = null;
        }
    }

    public static Map<String, Boolean> isHcRenewalValidationFail(List<Application__c> apps, List<License__c> records) {
        Map<String, Boolean> isHcRenewalValidationFailResults = new Map<String, Boolean>();
        Map<String, Application__c> licToAppMap = new Map<String, Application__c>();
        for(Application__c app:apps){
            if(app == null) continue;

            isHcRenewalValidationFailResults.put(app.Id, false);
            if(app.CurrentLicense__c != null){
                licToAppMap.put(app.CurrentLicense__c, app);
            }
        }

        List<InsuranceBond__c> bonds = InsuranceBondSelector.getInsuranceBonds(new List<String>(licToAppMap.keySet()));
        Map<String, List<InsuranceBond__c>> bondsByLicense =
            (new InsuranceBondDomain(bonds)).getLicenseId2InsuranceBonds();
        for(License__c record:records){
            if(
                record.LicenseType__r.RequiresInsurance__c 
                && !String.isBlank(record.LicenseType__r.InsuranceBondTypesRequired__c)
            ) {
                Application__c app = licToAppMap.get(record.Id);
                Date coverageThroughDate = getCoverageThroughDate(app, record);

                List<InsuranceBond__c> licenseBonds = bondsByLicense.containsKey(record.Id)
                    ? bondsByLicense.get(record.Id)
                    : new List<InsuranceBond__c>();
                List<InsuranceBond__c> activeBonds =
                    (new InsuranceBondDomain(licenseBonds)).getActiveInsurancebonds(coverageThroughDate);
                Set<String> missingRequiredTypes =
                    (new InsuranceBondDomain(activeBonds)).getMissingRequiredTypes(record);

                if (record.BondWaiver__c) {
                    missingRequiredTypes.remove('BD - Bond');
                }

                if (app != null) {
                    isHcRenewalValidationFailResults.put(app.Id, !missingRequiredTypes.isEmpty());
                }
            }
        }
        
        hcRenewalValidationFail.putAll(isHcRenewalValidationFailResults);
        return isHcRenewalValidationFailResults;
    }

    // Coverage is measured against the period being renewed from, which the application
    // records at creation. License EffectiveExpireDate__c cannot be used: the RME dependent
    // branch re-queries the Entity license after ApplicationRNEW_RSTRHandler has rolled it
    // to the next biennium (e.g. 9/30/2028).
    //
    // Do not restore the empty-list fallback that used to re-run this filter against the
    // application date only when no bonds survived. Open-ended records (SI / SW exclusions
    // and continuous BD Bonds) survive a 9/30/2028 comparison, so that fallback never ran
    // for the licensees who needed it. With the cutoff date correct, the fallback is gone.
    @TestVisible
    private static Date getCoverageThroughDate(Application__c app, License__c license) {
        if (app == null) {
            return license.EffectiveExpireDate__c;
        }

        Map<String, Object> populatedFields = app.getPopulatedFieldsAsMap();

        // A restoration is filed after the period has lapsed, so coverage only has to be
        // current today. CompleteApplicationBy__c holds the restoration deadline here, which
        // is a future date and would demand more coverage than any annual policy provides.
        if (populatedFields.containsKey('Type__c')
            && app.Type__c == 'RSTR - Restore - No A/I Status') {
            return Date.today().addDays(-1);
        }

        if (populatedFields.containsKey('CompleteApplicationBy__c')
            && app.CompleteApplicationBy__c != null) {
            return app.CompleteApplicationBy__c;
        }

        return license.EffectiveExpireDate__c;
    }

    public static void checkForHCRenewalValidationFail(Sobject oldSo, SObject so) {    
        Application__c app = (Application__c) so;
        Application__c oldApp = (Application__c) oldSo;
        if(
            (app.Type__c == 'RNEW - Renewal' || app.Type__c == 'RSTR - Restore - No A/I Status') 
            && ((app.Phase__c == 'H - License Generation' && app.Phase__c != oldApp.Phase__c && app.Status__c == null) || (app.Status__c == 'HC - Application Completed' && app.Status__c != oldApp.Status__c))
            && (app.ActiveInactive__c == 'Active' || app.ActiveInactive__c == null)
            && app.LicenseType__c != null 
            && app.CurrentLicense__c != null
        ){
            hcRenewalCheckIds.add(app.Id);
        }
    }

    public static Map<String, Boolean> isHcRenewalValidationFail(List<Application__c> apps) {
        List<String> licIds = new List<String>();
        for(Application__c app:apps){
            if(app != null && app.CurrentLicense__c != null){
                licIds.add(String.valueOf(app.CurrentLicense__c));
            }
        }

        List<License__c> lics = LicenseSelector.getLicenses(licIds);        
        return isHcRenewalValidationFail(apps, lics);
    }

    private static Boolean disabledUpdateStatus = false;
    // 00008048
    private static Set<String> applicationIdSetForLicensePeriodChange = new Set<String>();


    // 00008048
    public static void captureLicensePeriodChange(SObject oldSo, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = (Application__c) oldSo;
        if((application.LicensePeriod__c != oldApplication.LicensePeriod__c ||
        application.LicenseType__c != oldApplication.LicenseType__c ||
        // (oldApplication.Status__c != application.Status__c) ||
        (oldApplication.ActiveInactive__c != application.ActiveInactive__c) ||
        (oldApplication.MethodofLicensure__c != application.MethodofLicensure__c) || 
            (oldApplication.Island__c != application.Island__c) ||
            (oldApplication.Type__c != application.Type__c) ||
            (oldApplication.ActiveInactive__c != application.ActiveInactive__c)) &&
        (application.Type__c == 'LICN - New License' ||
            application.Type__c == 'LICF - New License after Forfeiture' ||
            application.Type__c == 'LICC - New License after Cancelation/Close Business' ||
            application.Type__c == 'RNEW - Renewal') &&
            !((application.LicenseTypeCode__c == 'MVB' || application.LicenseTypeCode__c == 'MVD' || application.LicenseTypeCode__c == 'MVD - Sole Proprietor') 
            && application.Type__c == 'RNEW - Renewal')) {
            applicationIdSetForLicensePeriodChange.add(application.Id); 
        }
    }
    // 00008048
    public static void reCreateTransactionLines(List<Application__c> records) {
        if(applicationIdSetForLicensePeriodChange.isEmpty()) return;
        List<Application__c> applications = (List<Application__c>)(new ApplicationDomain(
            records)).filterRecords(applicationIdSetForLicensePeriodChange);
        applicationIdSetForLicensePeriodChange.clear();
        //query transactions by applications
        List<String> applicationIds = (new ApplicationDomain(applications)).getIds();
        //reCreateTransactionLines(applicationIds);

        Map<String, List<String>> payLoadMap = new Map<String, List<String>>();
        payLoadMap.put('applicationIds', applicationIds);
        if(!onlineRenewalCopyAppIds.isEmpty()) {
            payLoadMap.put('onlineRenewalCopyAppIds',new List<String>(onlineRenewalCopyAppIds));
            onlineRenewalCopyAppIds.clear();
        }
        PVLProcess__e process = new PVLProcess__e();
        process.Type__c = 'App - Recreate Transaction Lines';
        process.Payload__c = JSON.serialize(payLoadMap);
        EventBus.publish(process);

    }
    public static void reCreateTransactionLines(List<String> applicationIds) {
        List<Transaction__c> transactions = TransactionSelector.getNewTransactionsByAppIds(applicationIds);

        // Changes request from case 8249
        List<Transaction__c> transaction4LinesRebuild = (new TransactionDomain(transactions)).getTransactionForLicenseFees();

        //case 00032255
        List<Transaction__c> transactionsForDelete = (new TransactionDomain(transactions)).getTransactionsForDelete();
        delete transactionsForDelete;

        List<Id> applicationIdsForRenewalTransactionCreate = new List<Id>();
        Set<Id> applicationIdsForLinesRebuild = new Set<Id>();

        for(Transaction__c t : transaction4LinesRebuild) {
            applicationIdsForLinesRebuild.add(t.Application__c); 
        }

        for(Id appId : applicationIds) {
            if(!applicationIdsForLinesRebuild.contains(appId)) {
                applicationIdsForRenewalTransactionCreate.add(appId);
            }
        }

        if(!transaction4LinesRebuild.isEmpty()) {
            // Delete and create the transactionLines;
            System.debug('##############transaction4LinesRebuild##########'+ transaction4LinesRebuild);
            TransactionService.reGenerateTransactionLines(transaction4LinesRebuild);
        }

        if(!applicationIdsForRenewalTransactionCreate.isEmpty()) {
            // Create the transactionLines;
            // case 00032255
            List<Application__c> applicationRecords = ApplicationSelector.getApplications(applicationIdsForRenewalTransactionCreate);
            TransactionService.generateRenewalFeeTransactions(applicationRecords);
        }
    }

    // create a new method that can be used by the ApplicationHandler - before update. 
    // To capture the changes of SendApprovedForExamLetterEmail__c and reset the checkbox to be false
    // To capture when the SendApprovedForExamLetterEmail__c is set to true
    // define the variable used in the class level
    // 00029513
    public static void captureSendApprovedForExamLetterEmail(SObject oldSo, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = (Application__c) oldSo;
        if(application.SendApprovedForExamLetterEmail__c 
            && application.SendApprovedForExamLetterEmail__c != oldApplication.SendApprovedForExamLetterEmail__c) {
            applicationIdSetForSendApprovedForExamLetterEmail.add(application.Id);
        }
    }
    // 00029513 - create a new method that are sending email 
    public static void sendApprovedForExamLetterEmail() {
        if(applicationIdSetForSendApprovedForExamLetterEmail.isEmpty()) return;
        List<Application__c> records = ApplicationSelector.getApplicationExamApprovalNotification(applicationIdSetForSendApprovedForExamLetterEmail);
        applicationIdSetForSendApprovedForExamLetterEmail.clear();

        if(records.isEmpty()) return;

        // call the method of applicationdomain to get List of Email template Names from Application.LicenseType__r.ExamApprovalEmailTemplate__r.Name
        Set<String> emailTemplateNames = (new ApplicationDomain(records)).getEmailTemplateNames();
        // Call EmailTemplateService.getEmailTemplates to get the map of EmailTemplate Name to Id
        Map<String, String> templateName2Id = EmailTemplateService.getEmailTemplatesIds(emailTemplateNames);
        // Call Application Domain Send ApprovedForExamLetterEmail
        List<Messaging.SingleEmailMessage> emails = (new ApplicationDomain(records)).sendApprovedForExamLetterEmail(templateName2Id);
        // Send the email
        Messaging.sendEmail(emails);

    }

    // create a new method that can be used by the ApplicationHandler - before update. 
    // To capture the changes of Send_ADDP_Approved_Letter_Email__c and reset the checkbox to be false
    // To capture when the Send_ADDP_Approved_Letter_Email__c is set to true
    // define the variable used in the class level
    // 00030984
    public static void captureSendADDPApprovedLetterEmail(SObject oldSo, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = (Application__c) oldSo;
        if(
            application.Send_ADDP_Approved_Letter_Email__c 
            && application.Send_ADDP_Approved_Letter_Email__c != oldApplication.Send_ADDP_Approved_Letter_Email__c
        ) {
            applicationIdSetForADDPApprovedLetterEmail.add(application.Id);
        }
    }
    // 00030984
    public static void sendADDPApprovedLetterEmail() {
        if(applicationIdSetForADDPApprovedLetterEmail.isEmpty()) return;
        List<Application__c> records = [
            SELECT Id, NotificationEmail__c 
            FROM Application__c 
            WHERE Id in: applicationIdSetForADDPApprovedLetterEmail and NotificationEmail__c != null 
        ];

        applicationIdSetForADDPApprovedLetterEmail.clear();

        if(records.isEmpty()) return;
        Set<String> emailTemplateNames = new Set<String>{'ADDP Approved Letter Email'};
        // Call EmailTemplateService.getEmailTemplates to get the map of EmailTemplate Name to Id
        Map<String, String> templateName2Id = EmailTemplateService.getEmailTemplatesIds(emailTemplateNames);
        String emailTemplateId = templateName2Id.get((new List<String>(emailTemplateNames))[0]);

        if(emailTemplateId != null){            
            // Call Application Domain Send ADDPApprovedLetterEmail
            List<Messaging.SingleEmailMessage> emails = (new ApplicationDomain(records)).sendADDPApprovedLetterEmail(emailTemplateId);
            // Send the email
            Messaging.sendEmail(emails);
        }
    }

    // Calculate outstanding amount with child transactions
    public static void calcualteOutStanding(Set<String> applicationIds) {
        List<String> recordIds = new List<String>(applicationIds);
        //Query Applications
        List<Application__c> applications = ApplicationSelector.getApplications(applicationIds);
        // Query Transactions
        Map<String, Decimal> sumAmtPerApp
            = TransactionService.getTransactionsWithTotalAmount(recordIds);
        // Turn off the update of tApplication status 
        List<Application_Cache__c> caches = new List<Application_Cache__c>();
        if(!skipApplicationCacheUpdate) {
            caches = (new ApplicationDomain(applications)).updateAppOutStandingAmt(sumAmtPerApp);
        }
        
        
        // commit the update of the applications;
        update applications;
        if(!caches.isEmpty()) {
            update caches;
        }
    }

    // Used by the ApplicaitonHandler-after insert
    public static void captureLicenseTypeCheck(SObject so) {
        captureLicenseTypeCheck(null, so);
    }

    // Used to capture the Phase Changes
    public static void captureLLicenseReview(SObject so) {
        Application__c application = (Application__c) so;
        if(application.Phase__c == 'L - License Review'
            && (application.Type__c == 'LICN - New License'
            || application.Type__c == 'LICF - New License after Forfeiture'
            || application.Type__c == 'REAC - Reactivation')) {
            applicationIds_L_LicenseReview.add(application.Id);
        }
    }

    // Used to capture the Phase Changes
    public static void captureLLicenseReview(SObject oldSO, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = (Application__c) oldSo;
        if(application.Phase__c != oldApplication.Phase__c
            || application.Type__c != oldApplication.Type__c) {
            captureLLicenseReview(so);
        }
    }

    // Used to capture the licenseType Changes
    public static void captureLicenseTypeCheck(SObject oldSo, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = null;
        if(oldSO != null ) {
            oldApplication = (Application__c) oldSo;
        }
        if(oldApplication == null ||
            (oldApplication.Phase__c != application.Phase__c) ||
            (oldApplication.Type__c != application.Type__c) ||
            (oldApplication.MethodofLicensure__c != application.MethodofLicensure__c) ||
            (oldApplication.TypeofEntity__c != application.TypeofEntity__c) ||
            (oldApplication.ActiveInactive__c != application.ActiveInactive__c)) {

            applicationIdsTobeChecked.add(application.Id);
        }

        if(oldApplication == null ||
            (oldApplication.LicenseType__c != application.LicenseType__c) ||
            (oldApplication.Type__c != application.Type__c) ||
            (oldApplication.MethodofLicensure__c != application.MethodofLicensure__c) ||
            (oldApplication.TypeofEntity__c != application.TypeofEntity__c) ||
            (oldApplication.ActiveInactive__c != application.ActiveInactive__c)) {

            applicationIdsTobeDeleted.add(application.Id);
            applicationIdsTobeChecked.add(application.Id);
        }
    }

    // Add Application Classifications
    public static void insertApplicationClassifications(List<Application__c> applications, Set<String> filteredIds){
        List<Application__c> records = (new ApplicationDomain(applications)).filterRecords(filteredIds);
        insertApplicationClassifications(records);
    }

    // 00005272 
    // Used to create application Classifications 
    public static void insertApplicationClassifications(List<Application__c> records) {
        List<String> licenseTypeIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('LicenseType__c');
        List<String> recordIds = (new ApplicationDomain(records)).getIds();
        Map<String, List<Classification__c>> classificationsMap = ApplicationClassificationsService.getLicenseTypeClassificationsMap(licenseTypeIds);

        // Get Application Classifications Records
        List<ApplicationClassifications__c> appClassifications
            = (new ApplicationDomain(records)).getApplicationClassifications(classificationsMap);
        insert appClassifications;
    }

    // 00005439: Trigger to Populate License Requirements
    public static void populateLicenseRequirements(SObject so) {
        populateLicenseRequirements(null, so);
    }

    // Used to capture the licenseType Changes
    public static void populateLicenseRequirements(SObject oldSo, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = null;
        if(oldSO != null ) {
            oldApplication = (Application__c) oldSo;
        }
        if(oldApplication == null && application.Type__c == 'REAC - Reactivation' && application.CurrentLicense__c != null) {
            applicationIds_L_LicenseRequirement.add(application.Id);
        }
    }

    // Add Application Requirements
    public static void populateLicenseRequirements(List<Application__c> applications, Set<String> filteredIds){
        List<Application__c> records = (new ApplicationDomain(applications)).filterRecords(filteredIds);
        insertLicenseRequirements(records);
    }

    // 00005439 
    // Used to create application requirements 
    public static void insertLicenseRequirements(List<Application__c> records) {
        List<String> currentLicenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<String> recordIds = (new ApplicationDomain(records)).getIds();
        Map<String, List<LicenseRequirements__c>> licenseRequirements = licenseService.getLicenseRequirements(currentLicenseIds);

        // Get application requirement records
        List<ApplicationRequirement__c> appRequirements
            = (new ApplicationDomain(records)).getApplicationRequirements(licenseRequirements);
        insert appRequirements;
    }
    public static void deleteAppRequirements(List<String> recordIds) {
        List<ApplicationRequirement__c> appRequirements 
            = ApplicationRequirementSelector.getApplicationRequirementByAppIds(recordIds);
        List<ApplicationRequirement__c> recordsForDelete 
            = (new ApplicationRequirementDomain(appRequirements)).filterAppRequirementForDelete();
        delete recordsForDelete;
        
    }
    public static void deleteAppRequirements(List<Application__c> applications, Set<String> filteredIds){
        List<Application__c> records = (new ApplicationDomain(applications)).filterRecords(filteredIds); 
        List<String> recordIds = (new ApplicationDomain(records)).getIds();
        // Check and delete application requirements
        deleteAppRequirements(recordIds);
    }
    // 00003563 
    // Used to create application requirements 
    public static void updateAppRequirements(List<Application__c> records) {
        
        List<String> licenseTypeIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('LicenseType__c');
        List<String> recordIds = (new ApplicationDomain(records)).getIds();
        // Check and delete application requirements
        
        Map<String, List<LicenseTypeRequirements__c>> licenseTypeRequirements
            = LicenseTypeRequirementsService.getLicenseTypeRequirements(licenseTypeIds);
        System.debug('######licenseTypeRequirements####' + licenseTypeRequirements);
        // prepare the applicationId => classification ID Set
        Map<String, Set<String>> appClassificationIds = ApplicationClassificationsService.getClassificationMap(recordIds);
        System.debug('######appClassificationIds####' + appClassificationIds);
        // Get application requirement records
        List<ApplicationRequirement__c> appRequirements
            = (new ApplicationDomain(records)).getApplicationRequirements(licenseTypeRequirements,
                    appClassificationIds);
        System.debug('######appRequirements####' + appRequirements);
        // Get Application Id => requirement Id Set
        Map<String, Set<String>> appIdToRequirementIdSet
            = ApplicationRequirementService.getAppRequirementIdSet(recordIds);
        System.debug('######appIdToRequirementIdSet####' + appIdToRequirementIdSet);
        List<ApplicationRequirement__c> filterredAppRequirements
            = (new ApplicationRequirementDomain(appRequirements)).filterRecordsFromSet(appIdToRequirementIdSet);
        insert filterredAppRequirements;
    }

    // Call PDF Generation Engine
    public static void generatePDF(List<Application__c> applications, Set<String> filteredIds){
        List<Application__c> records = (new ApplicationDomain(applications)).filterRecords(filteredIds);
        // Call application file generator
        (new ApplicationDomain(records)).generatePDF();
        // PVL_PDFGenerator.producePDFToFile(records[0].Id);
    }

    @future (callout=true)
    public static void generateCheckoutForm(List<String> applicationIds) {
        List<Application__c> applications = [SELECT Id, Name, CheckoutFormVersion__c FROM Application__c WHERE Id IN :applicationIds];
        for (Application__c app : applications) {
            if (app.CheckoutFormVersion__c == null) {
                continue;
            }

            PageReference ref = new PageReference('/apex/' + app.CheckoutFormVersion__c + '?id=' + app.Id);
            String fileName = app.Name+'-CTCheckoutForm.pdf';
            Blob content = Test.isRunningTest() ? Blob.valueOf('test') : ref.getContent();
            SpringCMConnector.createFile(app.Id,fileName, content);
        }
    }

    /**
     * IMLCC: Runs in a separate transaction after Application insert.
     * Updates applications (Phase/Status/GenerateLicense), creates payments, enqueues send-email job.
     * Called from IMLCCQueueable.createApplications() to avoid "Too many queueable jobs" and reduce volume per transaction.
     */
    @future
    public static void runIMLCCAfterApplicationCreate(List<Id> appIds, List<Id> matchedAccountIds) {
        if (appIds == null) appIds = new List<Id>();
        if (matchedAccountIds == null) matchedAccountIds = new List<Id>();

        if (!appIds.isEmpty()) {
            List<Application__c> toUpdate = [SELECT Id FROM Application__c WHERE Id IN :appIds];
            for (Application__c a : toUpdate) {
                a.GenerateLicense__c = true;
                a.Phase__c = 'H - License Generation';
                a.Status__c = 'HC - Application Completed';
            }
            update toUpdate;
            IMLCCQueueable.createPaymentsForApps(appIds);
        }
        if (!Test.isRunningTest() && !matchedAccountIds.isEmpty()) {
            IMLCCSendEmailQueueable.sendNotifications(new Set<Id>(matchedAccountIds));
        }
    }

    // Add Application Requirements
    public static void createApplicationRequirements(List<Application__c> applications, Set<String> filteredIds){
        List<Application__c> records = (new ApplicationDomain(applications)).filterRecords(filteredIds);
        updateAppRequirements(records);
    }

    // 00003450: Trigger on Application to mark Application Classification Records that are not on Dependent License or Dependent Applicaiton
    public static void checkClassifications(List<Application__c> applications, Set<String> filteredIds) {
        List<Application__c> records = (new ApplicationDomain(applications)).filterRecords(filteredIds);
        updateClassifications(records);
    }

    public static void updateClassifications(List<Application__c> records) {
        // Get Application Ids
        List<String> recordIds = (new ApplicationDomain(records)).getIds();
        // Check the Dependent Application Ids.
        List<String> dependentApplicationIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('DependentApplication__c');
        List<String> licenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('DependentLicense__c');
        // Query license Classifications Get Map <licenseId, List<Classification>> ()
        Map<String, List<Classification__c>> licenseToClassifications = new Map<String, List<Classification__c>>();
        if(!licenseIds.isEmpty()) {
            List<LicenseClassification__c> licenseClassifications = [Select Id, Classification__r.Id, Classification__r.Name, EffectiveStartDate__c, License__c from LicenseClassification__c where License__c in: licenseIds ];
            for(LicenseClassification__c licenseClassification: licenseClassifications) {
                List<Classification__c> classifications = licenseToClassifications.get(licenseClassification.License__c);
                if(classifications == null ) {
                    classifications = new List<Classification__c>();
                }
                Classification__c classification = licenseClassification.Classification__r;
                if( classification == null ) {
                    continue;
                }
                classifications.add(classification);
                licenseToClassifications.put(licenseClassification.License__c, classifications);
            }
        }
        // Query license Classifications  Get Map <DependentapplicationId, List<Classification>> ()
        Map<String, List<Classification__c>> dependentAppClassifications = new Map<String, List<Classification__c>>();
        if(!dependentApplicationIds.isEmpty()) {
            dependentAppClassifications = ApplicationClassificationsService.getClassifications(dependentApplicationIds);
        }
        // Conver Map <licenseId, List<Classification>>  to Map<applicationId, List<Classification>>
        // Conver Map <DependentapplicationId, List<Classification>>  to Map<applicationId, List<Classification>>
        Map<String, Set<String>>  appToSupposedClassifications = (new ApplicationDomain(records)
                ).getDependentClassifications(dependentAppClassifications, licenseToClassifications);
        // Query the Classifications and convert to => updated <currentApplicationId, List<AppClassification>>
        Map<String, List<ApplicationClassifications__c>> appClassifications = new Map<String, List<ApplicationClassifications__c>>();
        // Map<applicationId, List<Classification>>
        appClassifications = ApplicationClassificationsService.getAppClassifications(recordIds);
        // Compare the  <currentApplicationId, List<AppClassification>> with Map<applicationId, List<Classification>> to find out all the list<AppClassification>
        List<ApplicationClassifications__c> appClassificationsToBeUpdated = (new ApplicationDomain(records)
                ).addCommentToApplicationClassifications(appToSupposedClassifications, appClassifications);
        // Update List<Application Classification>
        update appClassificationsToBeUpdated;
    }

    public static void updateApplicationClassification( SObject so) {
        updateApplicationClassification(null, so);
    }

    public static void updateApplicationClassification(SObject oldSo, SObject so) {
        Application__c application = (Application__c) so;
        Application__c oldApplication = null;
        if(oldSO != null ) {
            oldApplication = (Application__c) oldSo;
        }
        //10/03/2019 change request from Miros
        //From: Application__c.LicenseType__c.Name = "CT - RME" OR "CT - Entity"
        //To: Application__c.LicenseType__c.DependeyRequired__c=true. Thnxs!
        //if(application.LicenseTypeCode__c !='CT - RME' &&
        //    application.LicenseTypeCode__c != 'CT - ENTITY') {
        //    return;
        //}
        if (application.DependencyRequired__c != true) {
            return;
        }
        if(oldApplication == null ||
          (oldApplication.DependentLicense__c != application.DependentLicense__c)){
            applicationClassificationToCheck.add(application.Id);
        }
        if(oldApplication == null ||
          (oldApplication.DependentApplication__c != application.DependentApplication__c)){
            applicationClassificationToCheck.add(application.Id);
        }
    }

    // 00005043: Trigger on Application phase and status.
    public static List<String> updateApplicationPhaseAndStatus(List<Application__c> applications, Set<String> filteredIds) {
        List<Application__c> rawRecords = new List<Application__c>();
        if(filteredIds == null) {
            //00005043 capture applicaiton if phase is L - License Review
            rawRecords = (new ApplicationDomain(applications)).filterForDependentApplicationCheck();
        } else {
            rawRecords = (new ApplicationDomain(applications)).filterRecords(filteredIds);
        }
        List<Application__c> records = (new ApplicationDomain(rawRecords)).checkActive();
        if(records.isEmpty() ) {
            return new List<String>();
        }
        // LicenseTypeCode__c ! = (CT Entity, CT RME, CT Sole Prop) 
        // (new ApplicationDomain(records)).updateAppWithOtherLicenseTypes();
        // LicenseTypeCode__c = (CT Entity, CT RME, CT Sole Prop) 
        // Change requirement in 00005043, 
        // "that the function is triggereed by Dependency Required on the license."
        // Set<String> licenseTypeSet = new Set<String>();
        // licenseTypeSet.add('CT - Entity');
        // licenseTypeSet.add('CT - RME');
        // licenseTypeSet.add('CT - Sole Prop');
        // List<Application__c> filteredAppsForFurtherCheck 
        //     = (new ApplicationDomain(records)).filterAppByLicenseTypes(licenseTypeSet);
        List<Application__c> filteredAppsForFurtherCheck  = records;
        System.debug('#######filteredAppsForFurtherCheck######' + filteredAppsForFurtherCheck);
        // Check if there is any DependentLicenseType__c
        // Get Dependent License records
        List<String> dependentLicenseIds = (new ApplicationDomain(filteredAppsForFurtherCheck)).getDependentLicenseIds();
        // Query Dependent License records
        List<License__c> dependentLicenses = LicenseSelector.getLicenses(dependentLicenseIds);
        Map<String, License__c> dependentLicenseMap = (new LicenseDomain(dependentLicenses)).getIdToLicense();
        // Check if there is any 
        List<String> dependentAppIds = (new ApplicationDomain(filteredAppsForFurtherCheck)).getDependentAppIds();
        // Query Dependent Application records
        List<Application__c> dependentApps = ApplicationSelector.getApplications(dependentAppIds);

        Map<String, Application__c> dependentApplications =(new ApplicationDomain(dependentApps)).getIdToApplication();
        List<String> dependentAppIdsTobeUpdated = (new ApplicationDomain(filteredAppsForFurtherCheck)).updateStatusByDependencies(dependentLicenseMap, dependentApplications);
        return dependentAppIdsTobeUpdated;
    }

    // 00005043: Trigger on Dependent Application phase and status.
    public static void updateDependentApplications() {
        // Update for the case defect 00008825
        List<Application__c> dependentApps = ApplicationSelector.getApplications(depedentAppIds_L_LicenseReview);
        depedentAppIds_L_LicenseReview.clear();
        (new ApplicationDomain(dependentApps)).updateApplicationsWithL1Values();
        update dependentApps;
    }

    // 00005003: Creation of a batch job that will Set Application to AW when Complete By Date is reached during A Phase
    // public static void updateApplicationsStatus(List<Application__c> applicationsToUpdate, Map<Id,List<SObject>> examType_M) {
    //     (new ApplicationDomain(applicationsToUpdate)).updateApplicationsStatus(examType_M);
    //     update applicationsToUpdate;
    // }

    /****
    // 00005748 Create Dependent Licenses
    // Comment out due to the change of the customer req
    public static void updateDependentLicenses(Map<String, String> appIdToLicenseId) {
        Set<String> applicationIdsForDependentLicenseCheck = appIdToLicenseId.keySet();
        List<Application__c> dependentApplications = ApplicationSelector.getDependentApps(applicationIdsForDependentLicenseCheck);
        List<License__c> dependentLicenses = (new ApplicationDomain(dependentApplications)).getDependentLicenses(appIdToLicenseId);
        update dependentLicenses;
    }
    ****/

    public static void runFinally(List<Application__c> applications) {
        if(Trigger.isAfter != null && Trigger.isAfter) {
            if(!applicationIdsTobeDeleted.isEmpty()) {
                if(!applicationIdsTobeDeleted.isEmpty()) {
                    deleteAppRequirements(applications, applicationIdsTobeDeleted);
                    applicationIdsTobeDeleted.clear();
                }   
            }
            
            if(!applicationIdsTobeChecked.isEmpty()) {
                createApplicationRequirements(applications, applicationIdsTobeChecked);
                applicationIdsTobeChecked.clear();
            }
            
            if(!applicationClassificationToCheck.isEmpty()) {
                checkClassifications(applications, applicationClassificationToCheck);
                applicationClassificationToCheck.clear();
            }
            if(!applicationIds_L_LicenseRequirement.isEmpty()) {
                populateLicenseRequirements(applications, applicationIds_L_LicenseRequirement);
                applicationIds_L_LicenseRequirement.clear();
            }

            if(!applicationIds_L_PDFGeneration.isEmpty()) {
                generatePDF(applications, applicationIds_L_PDFGeneration);
                applicationIds_L_PDFGeneration.clear();
            }
            if(!depedentAppIds_L_LicenseReview.isEmpty()) {
                // update Dependent Applications
                // TriggerHelper.disableApplicationTrigger = true;
                updateDependentApplications();
                // Update for the case defect 00008825
                // TriggerHelper.disableApplicationTrigger = false;
            }
            if(Trigger.isInsert != null && Trigger.isInsert && skipExamCreation != true) {
                // 00004707 : Trigger to populate the Exam Results object
                applicationCreateExamRequiredRecords(applications);
            }
            // 00008048
            reCreateTransactionLines(applications);
            // 00014255
            batchSaveOnlineRenewalCopy(); 
            // 00029513
            sendApprovedForExamLetterEmail();
            // 00030984
            sendADDPApprovedLetterEmail();

        } else if(Trigger.isBefore != null && Trigger.isBefore) {
            if(Trigger.isInsert) {
                depedentAppIds_L_LicenseReview = updateApplicationPhaseAndStatus(applications, null);
                applicationIds_L_LicenseReview.clear();
            } else {
                if(!applicationIds_L_LicenseReview.isEmpty()) {
                    // to check if need to update the application status/ application phase
                    // to skip the update application 
                    if(!skipApplicationPhaseUpdate) {
                        depedentAppIds_L_LicenseReview = updateApplicationPhaseAndStatus(applications, applicationIds_L_LicenseReview);
                    }
                    applicationIds_L_LicenseReview.clear();
                }
                if(!hcRenewalCheckIds.isEmpty()) {
                    List<Application__c> filteredRecords = (new ApplicationDomain(applications)).filterRecords(hcRenewalCheckIds);
                    hcRenewalCheckIds.clear();
                    isHcRenewalValidationFail(filteredRecords);
                }
                
            }   
        }
    }

    public static void batchSaveOnlineRenewalCopy() {
        if(!onlineRenewalCopyAppIds.isEmpty()) {
            Database.executeBatch(new GenerateRenewalApplicationBatch(onlineRenewalCopyAppIds, 'OnlineRenewalCopy'), 1);
            onlineRenewalCopyAppIds.clear();
        }
    }

    public static void applicationCreateExamRequiredRecords(List<Application__c> applicationList){
        List<ExamsRequired__c> examRequiredToCreate = new List<ExamsRequired__c>();
        Set<Id> licenseTypeIds = new Set<Id>();
        for(Application__c a : applicationList){
            if(String.isNotBlank(a.LicenseType__c)){
                licenseTypeIds.add(a.LicenseType__c);
            }
        }

        List<ExamTypes__c> examTypesResult = [SELECT Id, LicenseType__c FROM ExamTypes__c WHERE Status__c = 'Active' AND LicenseType__c =: licenseTypeIds];

        //Maps the Exam Type records to their corresponding License Type
        Map<Id, List<ExamTypes__c>> licenseTypeIdExamTypesMap = new Map<Id, List<ExamTypes__c>>();

        for (ExamTypes__c examType : examTypesResult){

            if(!licenseTypeIdExamTypesMap.containsKey(examType.LicenseType__c)){
                List<ExamTypes__c> newExamTypes = new List<ExamTypes__c>();
                licenseTypeIdExamTypesMap.put(examType.LicenseType__c, newExamTypes);
            }

            licenseTypeIdExamTypesMap.get(examType.LicenseType__c).add(examType); 
        }

        for(Application__c applicationRecord : applicationList){
            if(applicationRecord.Applicant__c != null && applicationRecord.LicenseType__c != null
                && licenseTypeIdExamTypesMap.containsKey(applicationRecord.LicenseType__c)) {

                //checks if the license type exists on the Map
                //Retrieves the Exam Type Records of the License Type from the Map
                List<ExamTypes__c> examTypesList = licenseTypeIdExamTypesMap.get(applicationRecord.LicenseType__c);
                //For each Exam Type, create an Exam Results Record
                for(ExamTypes__c examTypeRecord : examTypesList){
                    ExamsRequired__c examRequiredRecord = new ExamsRequired__c();
                    examRequiredRecord.Applicant__c = applicationRecord.Applicant__c;
                    examRequiredRecord.Application__c = applicationRecord.Id;
                    examRequiredRecord.ExamType__c = examTypeRecord.Id;
                    examRequiredToCreate.add(examRequiredRecord);
                }
            }
        }
        if(!examRequiredToCreate.isEmpty()){
            insert examRequiredToCreate;
        }
    }

    public static void captureLicenseRecord(List<Application__c> records) {
        List<String> currentLicenseIds = (List<String>)(new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<License__c> licenses = LicenseSelector.getLicenses(currentLicenseIds);
        licensesForRenew = new Map<String, License__c> (licenses);
    }


    public static void renewApplicationLicenses(List<Application__c> records) {
        //Dedup
        Set<Application__c> deduped = new Set<Application__c>(records);
        records = new List<Application__c>(deduped);

        // Renew Applications
        (new ApplicationDomain(records)).renewApplication();
        List<License__c> renewLicenses = (new ApplicationDomain(records)).renewLicenses();
        // update applications
        update records;
        // update licenses
        update renewLicenses;
        checkToCreateLicenseHistory(records); 
        

    }
    public static void checkToCreateLicenseHistory(List<Application__c> applications) {
        List<String> renewLicenseIds = (List<String>) (new ApplicationDomain(applications)).getFieldValues('CurrentLicense__c');
        List<LicenseHistory__c> histories 
                = LicenseHistorySelector.getHistories(new List<String>{'RNEW - RENEWED', 'RSTR - Restoration'}, renewLicenseIds);
            
        Map<String, String> licenseId2LicensePeriodRNEW 
            = (new ApplicationDomain(applications)).getLicenseId2LicensePeriodRNEW();
        
        Set<String> licenseIdsWithHistory = (new LicenseHistoryDomain(histories)
            ).checkExistingLicenses(licenseId2LicensePeriodRNEW);
        
        Set<String> renewLicenseIdSet = new Set<String>();
        renewLicenseIdSet.addAll(renewLicenseIds);
        renewLicenseIdSet.removeAll(licenseIdsWithHistory);
        
        (new ApplicationDomain(applications)).createLicenseHistory(renewLicenseIdSet);
    }
}