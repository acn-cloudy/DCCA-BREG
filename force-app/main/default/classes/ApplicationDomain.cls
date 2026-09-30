/*
* ─────────────────────────────────────────────────────────
* Used for the single unit of  logic around
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
*
* ───────────────────────────────────────────────────────────
*/
public class ApplicationDomain extends SObjectDomain{
    public ApplicationDomain(List<Application__c> applications) {
        super(applications);
    }

    public List<Application__c> checkActive() {
        List<Application__c> applications = new list<Application__c>();
        for(Application__c application: (List<Application__c>) records) {
            if(application.ActiveInactive__c == 'Active'
                || application.ActiveInactive__c == null) {
                applications.add(application);
            }
        }
        return applications;
    }
    public List<Application__c> filterApplicationsByRenewalDate() {
        List<Application__c> applicationsForFilter = new List<Application__c>();
        for(Application__c record: (List<Application__c> )records) {
            Date effectiveExpireDate = record.CurrentLicense__r.EffectiveExpireDate__c;
            Integer days = Integer.valueOf(record.CurrentLicense__r.LicenseType__r.RenewalWindowInDays__c);

            if (record.LicensePeriodRNEW__c != record.LicenseType__r.PreviousLicensePeriod__c) {
                continue;
            }

            if(days != null && effectiveExpireDate != null) {
                if(effectiveExpireDate.addDays(days) > Date.today()) {
                    applicationsForFilter.add(record);
                }
            }
        }
        return applicationsForFilter;
    }

    public List<Application__c>  filterForDependentApplicationCheck() {
        List<Application__c> applications = new list<Application__c>();
        for(Application__c application: (List<Application__c>) records) {
            if(application.Phase__c == 'L - License Review'
                && (application.Type__c == 'LICN - New License'
                || application.Type__c == 'LICF - New License after Forfeiture'
                || application.Type__c == 'REAC - Reactivation')) {
                applications.add(application);
            }
        }
        return applications;
    }

    // Used to update the sum of the children transactions amount outstanding.
    public List<Application_Cache__c> updateAppOutStandingAmt(Map<String, Decimal> sumAmtPerApp) {
        List<Application_Cache__c> caches = new List<Application_Cache__c>();
        for(SObject record: records) {
            Application__c app = (Application__c) record;
            if(sumAmtPerApp.containsKey(app.Id)) {
                app.OutstandingAmount__c = sumAmtPerApp.get(app.Id);
                if(app.OutstandingAmount__c == 0 && app.DraftApplication__c != null) {
                    Application_Cache__c cache = app.DraftApplication__r;
                    if(cache.Status__c != 'Submitted') {
                        cache.Status__c = 'Submitted';
                        caches.add(cache);
                    }
                }
            }
        }
        return caches;
    }
    // 00041666
    public List<TransactionLine__c> getTransactionsWithCashierCodes(Map<String, Transaction__c> appIdToTransaction, List<LicenseTypeCashierCode__c> codes) {
        
        List<TransactionLine__c> lines = new List<TransactionLine__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(record.ApplyforTemporaryPermit__c) {
                Transaction__c tran = appIdToTransaction.get(record.Id);
                if(tran != null) lines.addAll((new LicenseTypeCashierCodeDomain(codes)).getTranLines(record, tran));
            }
        }
        return lines;
    }

    // 00012212 If Application__c.Type__c = "LICF - New License after Forfeiture",
    // then find the Cashier Codes where LicenceTypeCashierCode__c.Type__c = "LICN - New License"
    // in other words, treat LICF - New License after Forfeiture as the same as LICN - New License for fees.
    public void massageApplications() {
        for (Application__c app : (List<Application__c>) records) {
            if (app.Type__c == 'LICF - New License after Forfeiture') {
                app.Type__c = 'LICN - New License';
            }
            if(app.Status__c == 'AP - Application Pending Submittal by Applicant/Licensee') {
                app.Status__c = 'A1 - Application Submitted, Awaiting Review';
            }
        }
    }

    public Map<String, Set<String>> convertToKey2ClassIds(Map<String, Set<String>> appId2ClassificationIds, Boolean isCurrentLicenseYear) {
        Map<String, Set<String>> key2ClassificationIds = new Map<String, Set<String>>();

        for (Application__c app : (List<Application__c>) records) {
            String island = app.Island__c;
            String methodofLicensure = app.MethodofLicensure__c;
            String activeInactive = app.ActiveInactive__c;
            if (island == null) island = '';
            if (methodofLicensure == null) methodofLicensure = '';
            if (activeInactive != 'Inactive') activeInactive = '';

            String rawKey = app.Type__c + app.Status__c + app.LicenseType__c;
            if(isCurrentLicenseYear) rawKey += app.CurrentLicenseYear__c;

            String key = methodofLicensure + rawKey + island + '-' + activeInactive;
            String key1 = rawKey + '-' + activeInactive;
            String key2 = rawKey + island + '-' + activeInactive;
            if (app.Type__c != null && app.Status__c != null 
                && app.LicenseType__c != null && appId2ClassificationIds.containsKey(app.Id)) {
                    
                key2ClassificationIds.put(key, appId2ClassificationIds.get(app.Id));
                key2ClassificationIds.put(key1, appId2ClassificationIds.get(app.Id));
                key2ClassificationIds.put(key2, appId2ClassificationIds.get(app.Id));
            }
        }
        return key2ClassificationIds;
    }

    public Map<String, List<LicenseTypeCashierCode__c>> initiateKeys_M(Boolean isCurrentLicenseYear) {
        Map<String, List<LicenseTypeCashierCode__c>> keyToLTCC_M = new Map<String, List<LicenseTypeCashierCode__c>>();
        for (Application__c app : (List<Application__c>) records) {
            String island = app.Island__c;
            String methodofLicensure = app.MethodofLicensure__c;
            String activeInactive = app.ActiveInactive__c;
            if (island == null) island = '';
            if (methodofLicensure == null) methodofLicensure = '';
            if (activeInactive != 'Inactive') activeInactive = '';

            String rawKey = app.Type__c + app.Status__c + app.LicenseType__c;
            if(isCurrentLicenseYear) rawKey += app.CurrentLicenseYear__c;

            String key = methodofLicensure + rawKey + island + '-' + activeInactive;
            String key1 = rawKey + '-' + activeInactive;
            String key2 = rawKey + island + '-' + activeInactive;

            if (app.Type__c != null && app.Status__c != null && app.LicenseType__c != null) {
                if (!keyToLTCC_M.containsKey(key)) {
                    keyToLTCC_M.put(key, new List<LicenseTypeCashierCode__c>());
                    keyToLTCC_M.put(key1, new List<LicenseTypeCashierCode__c>());
                    keyToLTCC_M.put(key2, new List<LicenseTypeCashierCode__c>());
                }
            }
        }
        return keyToLTCC_M;
    }

    public Map<String, List<Transaction__c>> getApp2Transactions(Map<String, Transaction__c> accountIdToTransaction, Boolean isCurrentLicenseYear) {
        Map<String, List<Transaction__c>> keyToTransaction = new Map<String, List<Transaction__c>>();
        for (Application__c app : (List<Application__c>) records) {
            String island = app.Island__c;
            String methodofLicensure = app.MethodofLicensure__c;
            String activeInactive = app.ActiveInactive__c;
            if (island == null) island = '';
            if (methodofLicensure == null) methodofLicensure = '';
            if (activeInactive != 'Inactive') activeInactive = '';

            String rawKey = app.Type__c + app.Status__c + app.LicenseType__c;
            if(isCurrentLicenseYear) rawKey += app.CurrentLicenseYear__c;

            String key = methodofLicensure + rawKey + island + '-' + activeInactive;
            String key1 = rawKey + '-' + activeInactive;
            String key2 = rawKey + island + '-' + activeInactive;
            if (app.Type__c != null && app.Status__c != null && app.LicenseType__c != null) {
                if (accountIdToTransaction.containsKey(app.Id)) {
                    List<Transaction__c> transactions = new List<Transaction__c>();
                    if (keyToTransaction.containsKey(key)) {
                        transactions = keyToTransaction.get(key);
                    }
                    transactions.add(accountIdToTransaction.get(app.Id));
                    keyToTransaction.put(key, transactions);
                    keyToTransaction.put(key1, transactions);
                    keyToTransaction.put(key2, transactions);
                }
            }
            
        }
        return keyToTransaction;
    }

    // Change due to the case 000012287
    public List<Application__c> terminateApplication() {
        List<Application__c> recordsForUpdate = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(record.Status__c == 'A1 - Application Submitted, Awaiting Review' 
                ||  record.Status__c == 'A2 - Deficient, Awaiting Notice' 
                || record.Status__c == 'A3 - Deficiency Notice Sent' ) {
                record.Phase__c = 'H - License Generation';
                record.Status__c = 'HD - Application Terminated';
                recordsForUpdate.add(record);
            }
        }
        return recordsForUpdate;
    }

    // Change due to the case 000012287
    public List<Application__c> terminateHDApplicationForRealstateCommission() {
        List<Application__c> recordsForUpdate = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(record.Phase__c == 'D - Dependency Review') {
                if(record.Status__c == 'D2 - Continuing Education Missing' 
                        && record.BoardProgramName__c == 'REAL ESTATE COMMISSION') {
                    record.ActiveInactive__c = 'Inactive';
                    recordsForUpdate.add(record);
                }
            }
        }
        return recordsForUpdate;
    }
    // Change due to the case 000012287
    public void updateToHCApplicationCompleted() {
        for(Application__c record: (List<Application__c>) records) {
            record.Phase__c = 'H - License Generation';
            record.Status__c = 'HC - Application Completed';
        }
    }
    public List<License__c> updateCurrentLicenseToTerminatedAndRefunded() {
        List<License__c> currentLicenses = new List<License__c>();
        Set<String> licenseIds = new Set<String>();
        for(Application__c record: (List<Application__c>) records) {
            
            License__c license = record.CurrentLicense__r;
            if(license == null || licenseIds.contains(license.Id)) continue;
            license.Status__c = 'TX - Terminated and Refunded';
            currentLicenses.add(license);
            licenseIds.add(license.Id);
        }
        return currentLicenses;
    }
    // Change due to the case 000012287
    public List<Application__c> terminateHDApplicationForDReview() {
        List<Application__c> recordsForUpdate = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(record.Phase__c == 'D - Dependency Review') {
                if(record.Status__c == 'D1 - Awaiting Dependency Review' || 
                    (record.Status__c == 'D2 - Continuing Education Missing' 
                        && record.BoardProgramName__c == 'ELECTRICIAN AND PLUMBERS')) {
                    record.Phase__c = 'H - License Generation';
                    record.Status__c = 'HD - Application Terminated';
                    recordsForUpdate.add(record);
                }
            }
        }
        return recordsForUpdate;
    }

    // update status to "HD - Application Terminated" 
    public void updateApplicationsStatus(Map<Id,List<SObject>> examType_M) {
        //00005654 : Update Batch Job of case 5003
        Map<Id, Boolean> checkExamType_M = new Map<Id, Boolean>();
        if (examType_M.size() > 0) {
            for (Id appId : examType_M.keySet()) {
                LIst<SObject> examSobject_L = new List<SObject>();
                examSobject_L = examType_M.get(appId);
                for(SObject obj : examSobject_L){
                    Boolean autoTerminateifnotPassed = (Boolean)obj.getSObject('ExamType__r').get('AutoTerminateifnotPassed__c');
                    if (autoTerminateifnotPassed == true) {
                        checkExamType_M.put(appId, true);
                        break;
                    }
                }

                if (!checkExamType_M.containsKey(appId)) {
                    checkExamType_M.put(appId, false);
                }
            }
        }

        for(SObject record : records) {
            Boolean isTerminated = false;
            Application__c app = (Application__c)record;
            //case 00005654
            if (checkExamType_M.containsKey(app.Id)) {
                if (app.CompleteExamBy__c == System.today().addDays(-1) && checkExamType_M.get(app.Id)) {
                    isTerminated = true;
                }
            }

            //case 00005003
            if (app.Status__c != 'HC - Application Completed' && app.CompleteApplicationBy__c == System.today().addDays(-1)) {
                isTerminated = true;
            }

            //case 00005344
            if (app.Status__c != 'HC - Application Completed' && app.NoticeofFeesSentDate__c <= System.today().addDays(-120)) {
                isTerminated = true;
            }

            if (isTerminated) {
                app.Phase__c = 'H - License Generation';
                app.Status__c = 'HD - Application Terminated';
                app.IsApplicationTerminated__c = true;
            }
        }
    }
    // Call future actions
    public void generatePDF() {
        List<PVLProcess__e> processes = new List<PVLProcess__e>();
        for(SObject record: records) {
            Application__c app = (Application__c) record;
            String fileEngines = app.FileEngines__c;
            Map<String, String> payload = new Map<String, String>();
            PVLProcess__e process = new PVLProcess__e();
            if(fileEngines != null ) {
                System.debug('########fileEngines########' + fileEngines);
                List<String> fileEngineList = new List<String>();
                payload.put('Id', record.Id);
                payload.put('fileEngines', fileEngines);
                process.Type__c = 'Generate PDF';
                process.Payload__c = JSON.serialize(payload);
                processes.add(process);
                // for(String fileEngine: fileEngines.split(',')) {
                //     fileEngineList.add(fileEngine.trim());
                // }
                // for(String fileEngine: fileEngineList) {
                //     PVL_PDFGenerator.producePDFToFile(license.Id, fileEngine);
                //     System.debug('########app.Id########' + license.Id + '########fileEngines########' + fileEngines);
                // }
            }
        }
        EventBus.publish(processes);
    }


    public List<String> updateStatusByDependencies(Map<String, License__c> dependentLicenses, 
                        Map<String, Application__c> dependentApplications) {
        List<String> dependentApplicationIdsToBeUpdated = new List<String>();
        for(SObject record: records) {
            
            Application__c application = (Application__c) record;
            String licenseTypeId = application.DependentLicense__c;
            String applicationId = application.DependentApplication__c;
            // Only fired if dependency license is not empty.
            
            // If the LicneseType.DependencyRequired is not required, 
            // will skip for the dependent applicaiton status update.
            // 00005043 30/09/2019 changes based on the changes request
            if(!application.DependencyRequired__c) {
                application.Phase__c = 'L - License Review';
                application.Status__c = 'L1 - Applications Submitted, Awaiting Notice';
                continue;
            }

            if(dependentLicenses.get(licenseTypeId) != null) {
                License__c dependentLicense = dependentLicenses.get(licenseTypeId);
                /*********
                Dependent License Status = ("C - Current, Valid & In Good Standing", "CM - CUrrent, Valid & In Good Standing/Maint. Requirement Due", "CR - Current/Next Renewal Paid", 
                                            "Z - Current & Valid, But Subject To Disciplinary Requirement", "ZM - Current & Valid, But Subject To Disciplinary/Maintenance"): 
                                        Update Application Status-> L1 - Applications Submitted, Awaiting Notice
                Dependent License Status != ("C - Current, Valid & In Good Standing", "CM - CUrrent, Valid & In Good Standing/Maint. Requirement Due", "CR - Current/Next Renewal Paid", 
                                            "Z - Current & Valid, But Subject To Disciplinary Requirement", "ZM - Current & Valid, But Subject To Disciplinary/Maintenance"): 
                                        Update Application Status-> D1 - Awaiting Dependency Review
                                        Update Application Phase-> D - Dependency Review
                */
                if(dependentLicense.Status__c == 'CP - Current Pending' || 
                    dependentLicense.Status__c == 'C - Current, Valid & In Good Standing' || 
                    dependentLicense.Status__c == 'CM - Current, Valid & In Good Standing/Maint. Requirement Due' || 
                    dependentLicense.Status__c == 'CR - Current/Next Renewal Paid' || 
                    dependentLicense.Status__c == 'Z - Current & Valid, But Subject To Disciplinary Requirement' || 
                    dependentLicense.Status__c == 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance' ) {
                    application.Phase__c = 'L - License Review';
                    application.Status__c = 'L1 - Applications Submitted, Awaiting Notice';
                    
                } else {
                    application.Status__c = 'D1 - Awaiting Dependency Review';
                    application.Phase__c = 'D - Dependency Review';
                }
            }
            // Only fired if dependency application is not empty.
            if(dependentApplications.get(applicationId) != null) {
                Application__c dependentApplication = dependentApplications.get(applicationId);
                if(dependentApplication.Phase__c == 'D - Dependency Review') {
                    application.Phase__c = 'L - License Review';
                    application.Status__c = 'L1 - Applications Submitted, Awaiting Notice';
                    dependentApplicationIdsToBeUpdated.add(applicationId);
                } else if(dependentApplication.Phase__c == 'H - License Generation' || dependentApplication.Phase__c == 'L - License Review') {
                    application.Phase__c = 'L - License Review';
                    application.Status__c = 'L1 - Applications Submitted, Awaiting Notice';
                } else {
                    application.Status__c = 'D1 - Awaiting Dependency Review';
                    application.Phase__c = 'D - Dependency Review';
                }
            }

            if(dependentLicenses.get(licenseTypeId) == null && dependentApplications.get(applicationId) == null) {
                application.Status__c = 'D1 - Awaiting Dependency Review';
                application.Phase__c = 'D - Dependency Review';
            }
        }
        System.debug('####dependentApplicationIdsToBeUpdated#####' + dependentApplicationIdsToBeUpdated);
        return dependentApplicationIdsToBeUpdated;
    }

    public void updateApplicationsWithL1Values() {
        for(SObject record: records) {
            Application__c app = (Application__c) record;
            app.Status__c = 'L1 - Applications Submitted, Awaiting Notice';
            app.Phase__c = 'L - License Review';
        }
    }

    // Get License Id => Application record
    public Map<String, Application__c> getIdToApplication() {
        Map<String, Application__c> applications = new Map<String, Application__c>();
        for(SObject record : records) {
            Application__c application = (Application__c) record;
            applications.put(application.Id, application);
        }
        return applications;
    }

    // Used to generate application Requirements 
    public List<ApplicationRequirement__c> getApplicationRequirements(Map<String, List<LicenseTypeRequirements__c>> licenseTypeRequirement,
                        Map<String, Set<String>> appClassificationIds) {
        List<ApplicationRequirement__c> appRequirementsList = new List<ApplicationRequirement__c>();
        for(Sobject record: records){
            Application__c app = (Application__c) record;
            String licenseTypeId = app.LicenseType__c;
            List<LicenseTypeRequirements__c> requirements = licenseTypeRequirement.get(licenseTypeId);
            Set<String> classificationIds = appClassificationIds.get(app.Id);
            if(requirements == null ) {
                continue;
            }
            if(classificationIds == null ) classificationIds = new Set<String>();
            // Add all application requirement records
            appRequirementsList.addAll((new LicenseTypeRequirementsDomain(requirements)
                ).getAppRequirements(app, classificationIds));
        }
        return appRequirementsList;
    }
    // Used to generate the dpendent licenses when by dependent applications 
     public List<License__c> getDependentLicenses(Map<String, String> appIdToLicenseId) {
         List<License__c> dependentLicenses = new List<License__c>();
         for(Sobject record: records) {
             Application__c app = (Application__c) record;
             License__c license = app.CurrentLicense__r;
             String dependentApplicationId = app.DependentApplication__c;
             if(license != null && appIdToLicenseId.containsKey(dependentApplicationId)) {
                 // license.DependentLicense__c = appIdToLicenseId.get(dependentApplicationId);
                 dependentLicenses.add(license);
             }
         }
         return dependentLicenses;
     }

    // Used to generate application Requirements 
    public List<ApplicationRequirement__c> getApplicationRequirements(Map<String, List<LicenseRequirements__c>> licenseRequirements) {
        List<ApplicationRequirement__c> appRequirementsList = new List<ApplicationRequirement__c>();
        for(Sobject record: records){
            Application__c app = (Application__c) record;
            String licenseId = app.CurrentLicense__c;
            List<LicenseRequirements__c> requirements = licenseRequirements.get(licenseId);
            if(requirements == null) {
                continue;
            }
            // Add all application requirement records
            for (LicenseRequirements__c lr : requirements) {
                ApplicationRequirement__c applicationRequirement = new ApplicationRequirement__c();
                applicationRequirement.Application__c = app.Id;
                applicationRequirement.Requirement__c = lr.Requirement__c;
                applicationRequirement.RequirementLongDescription__c 
                    = lr.RequirementLongDescription__c;
                applicationRequirement.RequirementShortDescription__c 
                    = lr.RequirementShortDescription__c;
                appRequirementsList.add(applicationRequirement);
            }
        }
        return appRequirementsList;
    }

    // Used to generate ApplicationClassifications 
    public List<ApplicationClassifications__c> getApplicationClassifications(Map<String, List<Classification__c>> classificationsMap) {
        List<ApplicationClassifications__c> appClassificationsList = new List<ApplicationClassifications__c>();
        for(Sobject record: records){
            Application__c app = (Application__c) record;
            String licenseTypeId = app.LicenseType__c;
            List<Classification__c> classifications = classificationsMap.get(licenseTypeId);
            if(classifications == null) {
                continue;
            }
            // Add all ApplicationClassifications records
            for (Classification__c classification : classifications) {
                ApplicationClassifications__c appClassification = new ApplicationClassifications__c();
                appClassification.Application__c = app.Id;
                appClassification.Classification__c = classification.Id;
                //add any more fields?
                appClassificationsList.add(appClassification);
            }
        }
        return appClassificationsList;
    }

    public Map<String, Set<String>> getDependentClassifications(
        Map<String, List<Classification__c>> dependentAppClassifications, Map<String, List<Classification__c>> licenseToClassifications) {
        Map<String, Set<String>> appIdToClassifications = new Map<String, Set<String>>();
        for(SObject record: records) {
            Application__c application = (Application__c) record;
            List<Classification__c> classifications = new List<Classification__c>();
            if(application.DependentApplication__c != null ) {
                List<Classification__c> appClass1 = dependentAppClassifications.get(application.DependentApplication__c);
                if(appClass1 != null) {
                    classifications.addAll(appClass1);
                }
            }
            if(application.DependentLicense__c != null ) {
                List<Classification__c> appClass2 = licenseToClassifications.get(application.DependentLicense__c);
                if(appClass2 != null) {
                    classifications.addAll(appClass2);
                }
            }
            Set<String> classiNames = new Set<String>();
            for(Classification__c classi: classifications) {
                classiNames.add(classi.Name);
            }
            appIdToClassifications.put(application.Id, classiNames);
        }
        return appIdToClassifications;
    }
    // Case 0005047
    // Update Application to L1 - Applications Submitted, Awaiting Notice
    // if the License Type to be CT Entity, CT RME, CT Sole Prop 
    public void updateAppWithOtherLicenseTypes() {
        for(SObject record: records) {
            Application__c application = (Application__c) record;
            if( application.LicenseTypeCode__c !='CT - Entity'
                && application.LicenseTypeCode__c !='CT - RME'
                && application.LicenseTypeCode__c !='CT - Sole Prop') {
                application.Status__c = 'L1 - Applications Submitted, Awaiting Notice';
            }
        }
    }
    // Get Dependent License List
    public List<License__c> getDependentLicenses() {
        List<License__c> dependentLicenses = new List<License__c>();
        for(SObject record: records) {
            Application__c application = (Application__c) record;
            if( application.DependentLicense__r != null) {
                dependentLicenses.add(application.DependentLicense__r);
            }
        }
        return dependentLicenses;
    }
    // Case 0005047
    // Get Dependent License Ids
    public List<String> getDependentLicenseIds() {
        List<String> dependentLicenseIds = new List<String>();
        for(SObject record: records) {
            Application__c application = (Application__c) record;
            if( application.DependentLicense__c != null) {
                dependentLicenseIds.add(application.DependentLicense__c);
            }
        }
        return dependentLicenseIds;
    }

    // Case 0005047
    // Get Dependent Applicaiton Ids
    public List<String> getDependentAppIds() {
        List<String> dependentAppIds = new List<String>();
        for(SObject record: records) {
            Application__c application = (Application__c) record;
            if( application.DependentApplication__c != null) {
                dependentAppIds.add(application.DependentApplication__c);
            }
        }
        return dependentAppIds;
    }

    // Case 0005047
    // Filter L1 - Applications Submitted, Awaiting Notice
    // if the License Type are not certain types.
    public List<Application__c> filterAppByLicenseTypes(Set<String> licenseTypeSet) {
        List<Application__c> filteredApps = new List<Application__c>();
        for(SObject record: records) {
            Application__c application = (Application__c) record;
            System.debug('#######application.LicenseTypeCode__c######' + application.LicenseTypeCode__c);
            System.debug('#######licenseTypeSet######' + licenseTypeSet);
            if( licenseTypeSet.contains(application.LicenseTypeCode__c)) {
                filteredApps.add(application);
            }
        }
        return filteredApps;
    }

    public List<ApplicationClassifications__c> addCommentToApplicationClassifications(
        Map<String, Set<String>>  appToSupposedClassifications, Map<String, List<ApplicationClassifications__c>> appClassificationsMap){
        List<ApplicationClassifications__c> allAppClassification = new List<ApplicationClassifications__c>();
        for(SObject record: records) {
            Application__c app = (Application__c) record;
            if(app.DependentApplication__c == null && app.DependentLicense__c == null ) {
                continue;
            }
            List<ApplicationClassifications__c> appClassifications = appClassificationsMap.get(app.Id);
            Set<String> classificationNames = appToSupposedClassifications.get(app.Id);
            if(appClassifications == null ) {
                continue;
            }
            if(classificationNames == null ) {
                classificationNames = new Set<String>();
            }
            for(ApplicationClassifications__c appClassification: appClassifications) {
                if(!classificationNames.contains(appClassification.classification__r.Name )) {
                    appClassification.Comments__c = 'CLASSIFICATION IS NOT ON THE DEPENDENT APPLICATION OR LICENSE';

                } else {
                    appClassification.Comments__c = '';
                }
                allAppClassification.add(appClassification);
            }
        }
        return allAppClassification;
    }

    public void renewApplication() {
        for(Application__c record: (List<Application__c>) records) {
            record.Status__c = 'HC - Application Completed';
            record.Phase__c = 'H - License Generation';
        }
    }

    
    public List<License__c> getRenewLicenses() {
        Set<License__c> licenseSet = new Set<License__c>();
        for(Application__c record: (List<Application__c>) records) {
            licenseSet.add(record.CurrentLicense__r);
        }
        List<License__c> licenses = new List<License__c>();
        licenses.addAll(licenseSet);

        return licenses;
    }
    
    public Map<String, String> getLicenseId2LicensePeriodRNEW() {
        Map<String, String> licenseId2LicensePeriodRNEW = new Map<String, String>();
        for(Application__c record: (List<Application__c>) records) {
            if(record.CurrentLicense__r.Id != null)
                licenseId2LicensePeriodRNEW.put(record.CurrentLicense__r.Id, record.LicensePeriodRNEW__c);
        }
        return licenseId2LicensePeriodRNEW;
    }

    public void createLicenseHistory(Set<String> licenseIds) {
        for(Application__c record: (List<Application__c>) records) {
            if(licenseIds.contains(record.CurrentLicense__r.Id)) {
                Map<String, Object> params = new Map<String, Object>();
                params.put('InputApplication', record);
                params.put('InputLicense', record.CurrentLIcense__r);
                Flow.Interview.Create_License_History f = new Flow.Interview.Create_License_History(params);
                f.start();
            }
        }
        
    }
    // getEmailTemplateNames to get email template names(field - Application.LicenseType__r.ExamApprovalEmailTemplate__r.Name) for application list (records)
    public Set<String> getEmailTemplateNames() {
        Set<String> emailTemplateNames = new Set<String>();
        for(Application__c record: (List<Application__c>) records) {
            emailTemplateNames.add(record.LicenseType__r.ExamApprovalNotification__r.Name);
        }
        return emailTemplateNames;
    }

    // method sendApprovedForExamLetterEmail to send emails for application list (records)
    public List<Messaging.SingleEmailMessage> sendApprovedForExamLetterEmail(Map<String, String> emailTemplateIdMap) {
        String userId = UserInfo.getUserId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        OrgWideEmailAddress[] orgWideEmails = [select Id from OrgWideEmailAddress where DisplayName = 'DCCA No Reply'];
        
        for(Application__c record: (List<Application__c>) records) {
            // send email for each application
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(emailTemplateIdMap.get(record.LicenseType__r.ExamApprovalNotification__r.Name));
            email.setWhatId(record.Id);
            email.setTargetObjectId(userId);
            email.setTreatTargetObjectAsRecipient(false);
            email.setSaveAsActivity(false);
            if (!orgWideEmails.isEmpty()) {
                email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
            }
            // send email to record.NotificationEmail__c
            email.setToAddresses(new List<String>{record.NotificationEmail__c});
            emails.add(email);
        }
        return emails;
    }
    
    // method sendADDPApprovedLetterEmail to send emails for application list (records)
    public List<Messaging.SingleEmailMessage> sendADDPApprovedLetterEmail(String emailTemplateId) {
        String userId = UserInfo.getUserId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        OrgWideEmailAddress[] orgWideEmails = [select Id from OrgWideEmailAddress where DisplayName = 'DCCA No Reply'];
        
        for(Application__c record: (List<Application__c>) records) {
            // send email for each application
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(emailTemplateId);
            email.setWhatId(record.Id);
            email.setTargetObjectId(userId);
            email.setTreatTargetObjectAsRecipient(false);
            email.setSaveAsActivity(false);
            if (!orgWideEmails.isEmpty()) {
                email.setOrgWideEmailAddressId(orgWideEmails[0].Id);
            }
            // send email to record.NotificationEmail__c
            email.setToAddresses(new List<String>{record.NotificationEmail__c});
            emails.add(email);
        }
        return emails;
    }

    public List<Application__c> filterApplicationsForInactiveRenew() {
        List<Application__c> appsForInactiveRenew = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            
            if(record.ApplicationRenewingInactive__c || record.ActiveInactive__c == 'Inactive') {
                appsForInactiveRenew.add(record);
            }
            
        }
        return appsForInactiveRenew;
    }

    
    public List<Application__c> filterApplicationsNotForInactiveRenew() {
        List<Application__c> filteredRecords = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(!record.ApplicationRenewingInactive__c && record.ActiveInactive__c != 'Inactive') {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    public List<Application__c> filterApplicationByLicenseIds(Set<String> licenseIds) {
        List<Application__c> filteredRecords = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(licenseIds.contains(record.CurrentLicense__c) ) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    public List<Application__c> filterApplicationOnAssociatedLicenseSize(Map<String, List<AssociatedLicense__c>> associatedLicensesMap) {
        List<Application__c> apps = new List<Application__c>();
        for(Application__c record: (List<Application__c> ) records) {
            if(associatedLicensesMap.containsKey(record.CurrentLicense__c) && associatedLicensesMap.get(record.CurrentLicense__c).size() >= 2) {
                apps.add(record);
            }
        }
        return apps;
    }

    public List<AssociatedLicense__c> getAllAssociatedLicenses(Map<String, List<AssociatedLicense__c>> associatedLicenses) {
        List<AssociatedLicense__c> filteredRecords = new List<AssociatedLicense__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(associatedLicenses.containsKey(record.CurrentLicense__c)) {
                filteredRecords.addAll(associatedLicenses.get(record.CurrentLicense__c));
            }
        }
        return filteredRecords;
    }

    public List<Application__c> checkBSCClassifications(Map<String, List<LicenseClassification__c>> classMap, Map<String, List<AssociatedLicense__c>> entity2Employees) {
        List<Application__c> recordsForUpdate = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            String entityLicenseId = record.CurrentLicense__c;
            List<LicenseClassification__c> entityClassifications = classMap.get(entityLicenseId);
            Set<String> checklist = (new LicenseClassificationDomain(entityClassifications)).getClassifcationNames();
            List<AssociatedLicense__c> employeeLicenses = entity2Employees.get(entityLicenseId);
            Boolean isValid = (new AssociatedLicenseDomain(employeeLicenses)).checkBSCAssociatedLicenses(checklist, classMap);
            if(isValid) {
                record.Status__c = 'HC - Application Completed';
                record.Phase__c = 'H - License Generation';
                recordsForUpdate.add(record);
            }
        }
        return recordsForUpdate;
    }

    public List<Application__c> checkBEOClassifications(Map<String, List<LicenseClassification__c>> classMap, Map<String, Set<String>> licenseeId2LicenseId) {
        List<Application__c> recordsForUpdate = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            String entityLicenseId = record.CurrentLicense__c;
            List<LicenseClassification__c> entityClassifications = classMap.get(entityLicenseId);
            Set<String> checklist = (new LicenseClassificationDomain(entityClassifications)).getClassifcationNames();
            Set<String> beoLicenseeIds = licenseeId2LicenseId.get(record.Applicant__c);
            List<AssociatedLicense__c> employeeLicenses = new List<AssociatedLicense__c>();
            if(beoLicenseeIds == null) beoLicenseeIds = new Set<String>();
            for(String licenseId: beoLicenseeIds) {
                AssociatedLicense__c newRec = new AssociatedLicense__c();
                newRec.EmployeeLicense__c = licenseId;
                newRec.EntityLicense__c = entityLicenseId;
                employeeLicenses.add(newRec);
            }
            Boolean isValid = (new AssociatedLicenseDomain(employeeLicenses)).checkAssociatedLicenses(checklist, classMap);
            if(isValid) {
                record.Status__c = 'HC - Application Completed';
                record.Phase__c = 'H - License Generation';
                recordsForUpdate.add(record);
            }
        }
        return recordsForUpdate;
    }

    public List<Application__c> filterRecordsByIds(Set<String> recordIds) {
        List<Application__c> recordsNotInIdSet = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(!recordIds.contains(record.Id)) {
                recordsNotInIdSet.add(record);
            }
        }
        return recordsNotInIdSet;
    }
    public List<Application__c> filterRecordByStatus(String status) {
        List<Application__c> filteredRecords = new List<Application__c>();
        for(Application__c record: (List<Application__c>) records) {
            if(record.Status__c == status) {
                filteredRecords.add(record);
            }
        }
        return filteredRecords;
    }

    public List<License__c> renewLicenses() {
        List<License__c> licenses = new List<License__c>();
        for(Application__c record: (List<Application__c>) records) {
            License__c renewLicense = record.CurrentLicense__r;
            if(record.Status__c == 'HC - Application Completed') {
                renewLicense.ThisLicenseRenewed__c = true;
                renewLicense.PreviousEffectiveExpiryDate__c = renewLicense.EffectiveExpireDate__c;
                renewLicense.EffectiveExpireDate__c = record.RNEWRSTRDate__c;
                renewLicense.RenewingInactive__c = record.ApplicationRenewingInactive__c;
                renewLicense.CancelDate__c = null;
                if(renewLicense.Status__c == 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due' ) {
                    renewLicense.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
                } else if(renewLicense.Status__c == 'R - Valid Thru Expiration Date, Subject To Renewal') {
                    renewLicense.Status__c = 'C - Current, Valid & In Good Standing';
                } else if(renewLicense.Status__c == 'D - Forfeited; Needs to Restore') {
                    renewLicense.Status__c = 'C - Current, Valid & In Good Standing';
                } else if(renewLicense.Status__c == 'DM - Forfeited/Maintenance Requirement Due') {
                    renewLicense.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due';
                }
                licenses.add(renewLicense);

            } else if (record.Status__c == 'D1 - Awaiting Dependency Review' || record.Status__c == 'D2 - Continuing Education Missing') {
                renewLicense.ThisLicenseRenewed__c = true;
                licenses.add(renewLicense);
            }

        }
        return licenses;

    }
}