trigger PVLProcessTrigger on PVLProcess__e(after insert) {
    Set<Application__c> dependencyApplicationsToProcess = new Set<Application__c>();
    List<PVLProcess__e> processes = Trigger.new;
    System.debug('###processes size##' + processes.size());
    System.debug('###processes##' + processes);
    for (PVLProcess__e process : processes) {
        if(process.Type__c == 'Generate VF Page') {
            String payload = process.Payload__c;
            Map<String, String> payLoadMap = (Map<String, String>) JSON.deserialize(
                payload,
                Map<String, String>.class
            );
            String recordId = payLoadMap.get('Id');
            String notificationId = payLoadMap.get('notificationId');
            String fileEngines = payLoadMap.get('fileEngines');
            String fileName = payLoadMap.get('fileName');
            PVL_VFPDFGenerator.producePDFToFile(recordId, fileEngines, notificationId, fileName);

        } else if (process.Type__c == 'Generate PDF') {
            String payload = process.Payload__c;
            Map<String, String> payLoadMap = (Map<String, String>) JSON.deserialize(
                payload,
                Map<String, String>.class
            );
            String recordId = payLoadMap.get('Id');
            String notificationId = payLoadMap.get('notificationId');
            String fileEngines = payLoadMap.get('fileEngines');
            List<String> fileEngineList = new List<String>();
            for (String fileEngine : fileEngines.split(',')) {
                fileEngineList.add(fileEngine.trim());
            }
            for (String fileEngine : fileEngineList) {
                if (notificationId != null) {
                    PVL_PDFGenerator.producePDFToFile(recordId, fileEngine, notificationId);
                } else {
                    PVL_PDFGenerator.producePDFToFile(recordId, fileEngine);
                }
            }
        } else if (process.Type__c == 'Create collection allocation') {
            String payload = process.Payload__c;
            Set<Id> pIds = (Set<Id>) JSON.deserialize(payload, Set<Id>.class);
            PaymentAllHandler.PaymentXStart(pIds);
        } else if (process.Type__c == 'Terminate Associated License') {
            String payload = process.Payload__c;
            List<AssociatedLicense__c> associateLicenses = new List<AssociatedLicense__c>();
            Map<Id, Date> associateLicense2ExpireDate = (Map<Id, Date>) JSON.deserialize(
                payload,
                Map<Id, Date>.class
            );
            for (Id recordId : associateLicense2ExpireDate.keySet()) {
                AssociatedLicense__c associateLicense = new AssociatedLicense__c();
                associateLicense.Id = recordId;
                associateLicense.EmploymentStatus__c = 'Terminated';
                associateLicense.EndDate__c = associateLicense2ExpireDate.get(recordId);
                associateLicenses.add(associateLicense);
            }
            update associateLicenses;
        } else if(process.Type__c == 'Terminate Insurance Bonds') {
            String payload = process.Payload__c;
            Set<String> insuranceStatusFilter = new Set<String>{
                'Active',
                'Pending',
                'Waived'
                };
            List<String> licenseIds = (List<String>) JSON.deserialize(payload, List<String>.class);
            List<InsuranceBond__c> bonds = [Select Id, Status__c, 
                License__c, License__r.NonRenewalDate__c from InsuranceBond__c where License__c in: licenseIds
                and Status__c IN :insuranceStatusFilter];
            for(InsuranceBond__c bond: bonds) {
                bond.Status__c = 'Inactive';
                //bond.TermDate__c = bond.License__r.NonRenewalDate__c;
            }
            if(!bonds.isEmpty())
                update bonds;
        } else if (process.Type__c == 'Terminate License') {
            String payload = process.Payload__c;
            Map<Id, String> employeeLicenseIdStatusMap = (Map<Id, String>) JSON.deserialize(
                payload,
                Map<Id, String>.class
            );
            List<License__c> licenses = new List<License__c>();
            for (Id recordId : employeeLicenseIdStatusMap.keySet()) {
                License__c license = new License__c();
                license.Id = recordId;
                license.Status__c = employeeLicenseIdStatusMap.get(recordId);
                licenses.add(license);
            }
            update licenses;
        } else if (process.Type__c == 'DependencyFlow') {
            Set<Id> licenseIds = (Set<Id>) JSON.deserializeStrict(
                process.Payload__c,
                Set<Id>.class
            );
            Set<Id> associatedLicenseIds = new Set<Id>();
            for (AssociatedLicense__c associatedLicense : [
                SELECT EntityLicense__c
                FROM AssociatedLicense__c
                WHERE
                    EmployeeLicense__c IN :licenseIds
                    AND EmploymentStatus__c = 'Employed'
                    AND (EndDate__c = null OR EndDate__c > TODAY)
            ]) {
                associatedLicenseIds.add(associatedLicense.EntityLicense__c);
            }
            for (Application__c dependentApplication : [
                SELECT
                    Id,
                    CurrentLicense__c,
                    DependentLicense__c,
                    RNEWRSTRDate__c,
                    ActiveInactive__c,
                    D2CEisRequired__c,
                    RenewingPermittoPractice__c,
                    Type__c,
                    ApplicationReceivedDate__c,
                    LicenseType__r.DependencyRequired__c,
                    Status__c,
                    LicenseType__r.OneWayDependency__c,
                    LicenseType__r.RequiresAllEmployeesToRenew__c,
                    LicenseType__r.StartofRenewalPeriod__c,
                    LicenseType__r.X2ndDependencyRequired__c,
                    LicenseType__r.Name,
                    LicenseType__c,
                    Phase__c,
                    OnlineApplicationType__c
                FROM Application__c
                WHERE
                    (CurrentLicense__r.DependentLicense__c IN :licenseIds
                    OR CurrentLicense__c IN :associatedLicenseIds)
                    AND Status__c = 'D1 - Awaiting Dependency Review'
                FOR UPDATE
            ]) {
                Map<String, Object> flowInput = new Map<String, Object>{
                    'InputApplication' => dependentApplication,
                    'reprocessing' => true
                };
                Flow.Interview thisFlow = Flow.Interview.createInterview(
                    'ApplicationRenewalDependencyCheck',
                    flowInput
                );
                if(!Test.isRunningTest()) {
                    thisFlow.start();
                }
                
            }
        } else if (process.Type__c == 'MultiDependencyFlow') {
            Map<Id, License__c> licenses = new Map<Id, License__c>(
                (List<License__c>) JSON.deserializeStrict(
                    process.Payload__c,
                    List<License__c>.class
                )
            );
            Set<Application__c> uniqueApplicationsToReturn = new Set<Application__c>();
            Set<Id> licenseTypeIds = new Set<Id>();
            for (License__c thisLicense : licenses.values()) {
                licenseTypeIds.add(thisLicense.LicenseType__c);
            }
            Map<Id, LicenseType__c> licenseTypes = new Map<Id, LicenseType__c>(
                [
                    SELECT Id, DependentLicenseType__c, X2ndDependentLicenseType__c
                    FROM LicenseType__c
                    WHERE
                        X2ndDependencyRequired__c = TRUE
                        AND (DependentLicenseType__c IN :licenseTypeIds
                        OR X2ndDependentLicenseType__c IN :licenseTypeIds)
                ]
            );
            if (licenseTypes.isEmpty()) {
                continue;
            }
            List<License__c> dependentLicenses = [SELECT
                    (
                        SELECT
                            Id,
                            CurrentLicense__c,
                            RNEWRSTRDate__c,
                            ActiveInactive__c,
                            RenewingPermittoPractice__c,
                            Type__c,
                            ApplicationReceivedDate__c,
                            Status__c,
                            LicenseType__c,
                            Phase__c
                        FROM Applications1__r
                        WHERE Status__c = 'D1 - Awaiting Dependency Review'
                    ),
                    (
                        SELECT EmployeeLicense__c
                        FROM AssociatedEmployee__r
                        WHERE EmployeeLicense__c IN :licenses.keySet()
                    )
                FROM License__c
                WHERE
                    LicenseType__c IN :licenseTypes.keySet()
                    AND Id IN (
                        SELECT EntityLicense__c
                        FROM AssociatedLicense__c
                        WHERE EmployeeLicense__c IN :licenses.keySet()
                    )
                FOR UPDATE];
            for (License__c dependentLicense : dependentLicenses) {
                for (
                    AssociatedLicense__c associatedLicense : dependentLicense.AssociatedEmployee__r
                ) {
                    uniqueApplicationsToReturn.addAll(dependentLicense.Applications1__r);
                }
            }
            for (Application__c multiDependentApplication : uniqueApplicationsToReturn) {
                Map<String, Object> flowInput = new Map<String, Object>{
                    'ApplicationsToFurtherProcess' => multiDependentApplication
                };
                Flow.Interview thisFlow = Flow.Interview.createInterview(
                    'Application_Renewal_Dependency_Multiple_Dependencies',
                    flowInput
                );
                thisFlow.start();
            }
        } else if(process.Type__c == 'CallLicenseHistoryFlow') {
            String idStr = process.Payload__c;
            List<String> idList = (List<String>) JSON.deserialize(idStr, List<String>.class);
            List<License__c> records = [Select Id from License__c where Id in: idList];
            for(License__c record: records) {
                Map<String, Object> flowParam = new Map<String, Object>();
                flowParam.put('InputLicense', record);
                Flow.Interview i = Flow.Interview.createInterview('License_Create_License_History', flowParam);
                i.start();
            }
        } else if(process.Type__c == 'MoveSpringCMFiles') {
            PVLFolderFeed feed = (PVLFolderFeed) JSON.deserialize(
                    process.Payload__c, PVLFolderFeed.class);
            SpringCMConnector.updateFilesAndFolderAsync(feed.fileUrls, feed.recordId);
        } else if(process.Type__c == 'ScanResultApplication') {
            List<Application__c> apps = (List<Application__c>) JSON.deserialize(process.Payload__c, List<Application__c>.class);
            List<Application__c> appRemaining = new List<Application__c>();
            for(Integer i = 0;i<apps.size(); i++ ) {
                if(i == 0) {
                    update apps.get(i);
                } else {
                    appRemaining.add(apps.get(i));
                }
            }
            if(!appRemaining.isEmpty()) {
                PVLProcess__e processSingle = new PVLProcess__e();
            
                processSingle.Payload__c = JSON.serialize(appRemaining);
                processSingle.Type__c = 'ScanResultApplication';
                EventBus.publish(processSingle);

            }
            
        }
        else if(process.Type__c == 'App - Recreate Transaction Lines'){
            String idStr = process.Payload__c;
            Map<String, List<String>> payLoadMap = (Map<String, List<String>>) JSON.deserialize(idStr, Map<String, List<String>>.class);
            if(payLoadMap.containsKey('applicationIds') && payLoadMap.get('applicationIds').size() > 0){
                ApplicationService.reCreateTransactionLines(payLoadMap.get('applicationIds'));
            }

            if(payLoadMap.containsKey('onlineRenewalCopyAppIds') && payLoadMap.get('onlineRenewalCopyAppIds').size() > 0){
                Database.executeBatch(new GenerateRenewalApplicationBatch(payLoadMap.get('onlineRenewalCopyAppIds'), 'OnlineRenewalCopy'), 1);
            }
        }
    }

}