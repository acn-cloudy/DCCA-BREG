/*
 * ___________________________________________________________________________________
 * Used to maintain the Real Estate  Renewal
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA09042024 - Created for Case 00037665
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 09/04/2024
 * __________________________________________________________________________________
 */
public class RealEstateRenewal {
    private static Set<String> appIdsForRenew = new Set<String>();
    public static Map<String, Application__c> renewApps = new Map<String, Application__c>();
    @InvocableMethod(
        label='Real Estate Renewal'
        description='Renew application with license types RB - Broker, RS, RBO, RB - Entity and RB - Sole Proprietor'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<String> appIds = new List<String>();
        Set<String> ceConfirmedLics = new Set<String>();
        for(Input inp: inputs) {
            appIds.add(inp.record.Id);

            // Check if CE Confirmed; might be updated from Process Builder and not yet in DB
            if(inp.record.CEisConfirmed__c == true) ceConfirmedLics.add(inp.record.CurrentLicense__c);
        }
        List<Application__c> applications = ApplicationSelector.getApplicationsByIds(appIds);
        List<Application__c> appsForCustom = (new ApplicationDomain(applications)).filterApplicationsNotForInactiveRenew();
        appIdsForRenew.addAll((new ApplicationDomain(appsForCustom)).getIds());
        
        Set<String> d2CERequiredLics = getD2CERequiredLics(appsForCustom);
        List<String> d2Apps = new List<String>();
        List<Application__c> appsForCustom2 = new List<Application__c>();
        for(Application__c appForCustom : appsForCustom){
            if(!ceConfirmedLics.contains(appForCustom.CurrentLicense__c) && d2CERequiredLics.contains(appForCustom.CurrentLicense__c)) d2Apps.add(appForCustom.Id);
            else appsForCustom2.add(appForCustom);
        }

        List<Application__c> rBBApps = (new ApplicationDomain(appsForCustom2)).filterAppByLicenseTypes(new Set<String> {'RB - Broker'});
        List<String> rBBAppsLicIds = (List<String>) (new ApplicationDomain(rBBApps)).getFieldValues('CurrentLicense__c');
        if(!rBBApps.isEmpty()) captureRenewApp(processRBB(rBBApps));

        List<Application__c> rSApps = (new ApplicationDomain(appsForCustom2)).filterAppByLicenseTypes(new Set<String> {'RS'});
        if(!rSApps.isEmpty()) captureRenewApp(processRS(rSApps));

        List<Application__c> rBOApps = (new ApplicationDomain(appsForCustom2)).filterAppByLicenseTypes(new Set<String> {'RBO'});
        if(!rBOApps.isEmpty()) captureRenewApp(processRBO(rBOApps));

        List<Application__c> rBEApps = (new ApplicationDomain(appsForCustom2)).filterAppByLicenseTypes(new Set<String> {'RB - Entity'});
        if(!rBEApps.isEmpty()) captureRenewApp(processRBE(rBEApps));

        List<Application__c> rBSPApps = (new ApplicationDomain(appsForCustom2)).filterAppByLicenseTypes(new Set<String> {'RB - Sole Proprietor'});
        if(!rBSPApps.isEmpty()) captureRenewApp(processRBSP(rBSPApps));

        (new ApplicationDomain(renewApps.values())).renewApplication();

        List<Application__c> d1Update = (new ApplicationDomain(appsForCustom)).filterRecordsByIds(renewApps.keySet());
        Map<String, Application__c> appsForUpdate = new Map<String, Application__c>();
        appsForUpdate.putAll(renewApps);

        List<String> dependencyCheckItems = new List<String>();   
        for(Application__c record: d1Update) {
            if(!appsForUpdate.containsKey(record.Id)) {
                record.Status__c = d2Apps.contains(record.Id) ? 'D2 - Continuing Education Missing' : 'D1 - Awaiting Dependency Review';
                record.Phase__c = 'D - Dependency Review';
                appsForUpdate.put(record.Id, record);
            } else if(appIds.contains(record.Id) && rBBAppsLicIds.contains(record.CurrentLicense__c)){                
                dependencyCheckItems.add(record.Id);
            }
        }

        List<License__c> renewLicenses = (new ApplicationDomain(appsForUpdate.values())).renewLicenses();
        
        
        // update applications
        List<Application__c> currentApps = new List<Application__c>();
        Map<String, Application__c> extraApps = new Map<String, Application__c>();
        for(Application__c appForUpdate : appsForUpdate.values()){
            if(appIds.contains(appForUpdate.Id)) currentApps.add(appForUpdate);
            else extraApps.put(appForUpdate.Id, appForUpdate);
        }

        // Disable Insurace Validation
        ApplicationHandler.bypassInsuranceValidation = true;
        if(!currentApps.isEmpty()) update currentApps;
        ApplicationHandler.bypassInsuranceValidation = false;

        // // Disable Flow for derived HC Applications
        // if(!extraApps.isEmpty()) turnOffAppRenewFlow();
        // if(!extraApps.isEmpty()) update extraApps;
        // if(!extraApps.isEmpty()) turnOnAppRenewFlow();

        

        // Dedup Licenses
        Set<License__c> licenseSet = new Set<License__c>(renewLicenses);

        // Set CEisConfirmed__c = false for Renewed Licenses
        List<String> renewLicsStatuses = new List<String>{'CM - Current, Valid & In Good Standing/Maint. Requirement Due', 'C - Current, Valid & In Good Standing'};
        for(License__c licenseEntry : licenseSet){
            if(renewLicsStatuses.contains(licenseEntry.Status__c)) licenseEntry.CEisConfirmed__c = false;
            if(renewLicsStatuses.contains(licenseEntry.Status__c)) LicenseService.licenseIdsForCERequiredReset.add(licenseEntry.Id);
        }
        
        List<String> currentLicenseIds = (List<String>) (new ApplicationDomain(currentApps)).getFieldValues('CurrentLicense__c');
        List<License__c> currentLics = new List<License__c>();
        Map<String, License__c> extraLics = new Map<String, License__c>();
        for(License__c license : licenseSet) {
            if(currentLicenseIds.contains(license.Id)) currentLics.add(license);
            else extraLics.put(license.Id, license);
        }

        update currentLics;

        if(!extraApps.isEmpty() && !extraLics.isEmpty()) DataBase.executeBatch(new RealEstateRenewalBatch(extraLics, extraApps), 50);
        
        BarberingCosmetologyRenewal.checkToCreateLicenseHistory(appsForUpdate.values());

        List<Application__c> appsForInactive = (new ApplicationDomain(applications)).filterApplicationsForInactiveRenew();

        for(Application__c record: appsForInactive) {
            BarberingCosmetologyRenewal.lanchRenewingInactiveFlow(record);
        }

        if(!dependencyCheckItems.isEmpty()){
            for(Application__c depenencyCheckItem: ApplicationSelector.getApplicationsForDependencyCheck(dependencyCheckItems)){
                Map<String, Object> Params = new Map<String, Object>();       
                Params.put('InputApplication', depenencyCheckItem); 
                Flow.Interview.ApplicationRenewalDependencyCheck renewalFlow = new Flow.Interview.ApplicationRenewalDependencyCheck(Params);
                renewalFlow.start();
            }
        }

        List<Results> responseWrapper= new List<Results>();
        for(Input inp: inputs) {
            Results re = new Results();
            re.operationOutcome = 'Success';
            responseWrapper.add(re);
        }
        return responseWrapper;
    }
    
    private static void turnOffAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = true;
        upsert orgSetting;
    }
    private static void turnOnAppRenewFlow() {
        OrgConfiguration__c orgSetting = OrgConfiguration__c.getOrgDefaults();
        orgSetting.SkipAppRenewFlow__c = false;
        upsert orgSetting;
    }

    private static Set<String> getD2CERequiredLics(List<Application__c> apps){
        Set<String> appLicenseTypes = new Set<String>();
        Map<String, List<String>> licTypeLicsMap = new Map<String, List<String>>();
        for(Application__c app : apps){
            appLicenseTypes.add(app.LicenseType__c);
            List<String> licTypeLicIds = licTypeLicsMap.get(app.LicenseType__c);
            if(licTypeLicIds == null) licTypeLicIds = new List<String>();
            licTypeLicIds.add(app.CurrentLicense__c);
            licTypeLicsMap.put(app.LicenseType__c, licTypeLicIds);
        }

        // Check License Types for D2CERequired__c        
        Set<String> d2CERequiredLics = new Set<String>();
        for(LicenseType__c lt : LicenseTypeSelector.getLicenseTypesByIds(new List<String>(appLicenseTypes))){
            if(lt.D2CERequired__c == true) d2CERequiredLics.addAll(licTypeLicsMap.get(lt.Id));
        }

        // Check License if Excempted or CE Confirmed
        for(License__c lic : LicenseSelector.getLicensesCEStatus(d2CERequiredLics)){
            d2CERequiredLics.remove(lic.Id);
        }

        return d2CERequiredLics;
    }

    public static List<Application__c> processRBB(List<Application__c> records) { 
        List<Application__c> appForRenew = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'RB - Entity', 'RB - Sole Proprietor'}, ' AND EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<String> cEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EntityLicense__c');
        appForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEmployeeLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'RB - Entity', 'RB - Sole Proprietor'}, ' AND EntityLicenseStatus__c != \'C - Current, Valid & In Good Standing\' AND Position__c = \'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\'');
        List<String> entityLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EntityLicense__c');
        List<Application__c> assocLicApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(entityLicenseIds);
        
        if(!cEntityLicenseIds.isEmpty() || !assocLicApps.isEmpty()){
            List<String> assocLicAppslicenseIds = new List<String>();
            if(!assocLicApps.isEmpty()) appForRenew.addAll(assocLicApps);
            if(!assocLicApps.isEmpty()) assocLicAppslicenseIds.addAll((List<String>) (new ApplicationDomain(assocLicApps)).getFieldValues('CurrentLicense__c'));
            for(AssociatedLicense__c associatedLicense : associatedLicenses){
                if(assocLicAppslicenseIds.contains(associatedLicense.EntityLicense__c)) appForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>{associatedLicense.EmployeeLicense__c}));
            }

            if(!cEntityLicenseIds.isEmpty()) assocLicAppslicenseIds.addAll(cEntityLicenseIds);
            // Process Non-Principal Apps for Entity
            List<AssociatedLicense__c> tAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(assocLicAppslicenseIds, null, ' AND Position__c != \'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\'');
            List<String> tEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(tAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
            List<Application__c> tAssocLicApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(tEmployeeLicenseIds);
            if(!tAssocLicApps.isEmpty()) appForRenew.addAll(tAssocLicApps);

            List<AssociatedLicense__c> cBICAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(assocLicAppslicenseIds, null, ' AND Position__c = \'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\'');
            List<String> cBICEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(cBICAssociatedLicenses)).getFieldValues('EntityLicense__c');

            List<AssociatedLicense__c> bicAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(assocLicAppslicenseIds, null, ' AND Position__c = \'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)\' AND EmployeeLicenseStatus__c != \'C - Current, Valid & In Good Standing\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\'');
            List<String> bicEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(bicAssociatedLicenses)).getFieldValues('EmployeeLicense__c');

            List<String> forRenewalBIC = new List<String>();
            for(Application__c appRNEW:appForRenew){
                if(bicEmployeeLicenseIds.contains(appRNEW.CurrentLicense__c)) forRenewalBIC.add(appRNEW.CurrentLicense__c);
            }

            for(AssociatedLicense__c bicAssociatedLicense : bicAssociatedLicenses){
                if(forRenewalBIC.contains(bicAssociatedLicense.EmployeeLicense__c)) cBICEntityLicenseIds.add(bicAssociatedLicense.EntityLicense__c);
            }

            List<AssociatedLicense__c> rboAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(cBICEntityLicenseIds, new List<String>{'RBO'}, '');
            List<String> rboEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(rboAssociatedLicenses)).getFieldValues('EntityLicense__c');
            List<Application__c> rboAssocLicApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(rboEntityLicenseIds);
            if(!rboAssocLicApps.isEmpty()) appForRenew.addAll(rboAssocLicApps);
        }
        
        return appForRenew;
    }

    public static List<Application__c> processRS(List<Application__c> records) { 
        List<Application__c> appForRenew = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(licenseIds, new List<String>{'RB - Entity', 'RB - Sole Proprietor'}, ' AND EntityLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        appForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(employeeLicenseIds)));
        
        return appForRenew;
    }

    public static List<Application__c> processRBO(List<Application__c> records) { 
        List<Application__c> appForRenew = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'RB - Entity'}, ' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        
        List<AssociatedLicense__c> bicAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(employeeLicenseIds, null, ' AND Position__c = \'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\'');
        List<String> bicEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(bicAssociatedLicenses)).getFieldValues('EntityLicense__c');

        for(AssociatedLicense__c associatedLicense : associatedLicenses){
            if(bicEntityLicenseIds.contains(associatedLicense.EmployeeLicense__c)) appForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>{associatedLicense.EntityLicense__c}));
        }
        
        return appForRenew;
    }

    public static List<Application__c> processRBE(List<Application__c> records) { 
        List<Application__c> appForRenew = new List<Application__c>();
        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        
        List<AssociatedLicense__c> cAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'RB - Broker'}, ' AND Position__c = \'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\'');
        List<String> cEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(cAssociatedLicenses)).getFieldValues('EntityLicense__c');
        appForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>(cEntityLicenseIds)));

        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, new List<String>{'RB - Broker'}, ' AND Position__c = \'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\' AND EmployeeLicenseStatus__c != \'C - Current, Valid & In Good Standing\'');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> assocLicApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(employeeLicenseIds);
        Set<String> accocLicAppsD2Required = getD2CERequiredLics(assocLicApps);
        
        if(!cEntityLicenseIds.isEmpty() || accocLicAppsD2Required.isEmpty()){      
            List<String> assocLicAppslicenseIds = new List<String>();
            if(!assocLicApps.isEmpty()){
                appForRenew.addAll(assocLicApps);
                assocLicAppslicenseIds.addAll((List<String>) (new ApplicationDomain(assocLicApps)).getFieldValues('CurrentLicense__c'));
                for(AssociatedLicense__c associatedLicense : associatedLicenses){
                    if(assocLicAppslicenseIds.contains(associatedLicense.EmployeeLicense__c)) appForRenew.addAll((new ApplicationDomain(records)).filterApplicationByLicenseIds(new Set<String>{associatedLicense.EntityLicense__c}));
                }
            }

            List<String> renewAppslicenseIds = (List<String>) (new ApplicationDomain(appForRenew)).getFieldValues('CurrentLicense__c');
            List<AssociatedLicense__c> tAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(renewAppslicenseIds, null, ' AND Position__c != \'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\'');
            List<String> tEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(tAssociatedLicenses)).getFieldValues('EmployeeLicense__c');
            List<Application__c> tAssocLicApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(tEmployeeLicenseIds);
            if(!tAssocLicApps.isEmpty()) appForRenew.addAll(tAssocLicApps);

            List<AssociatedLicense__c> cBICAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(renewAppslicenseIds, null, ' AND Position__c = \'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)\' AND EmployeeLicenseStatus__c = \'C - Current, Valid & In Good Standing\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\' AND PositionStatus__c != \'X - EXTEND TEMPORARY (REAL ESTATE)\'');
            List<String> cBICEntityLicenseIds = (List<String>)(new AssociatedLicenseDomain(cBICAssociatedLicenses)).getFieldValues('EntityLicense__c');

            List<AssociatedLicense__c> bicAssociatedLicenses = AssociatedLicenseSelector.getPDGByEntity(renewAppslicenseIds, null, ' AND Position__c = \'BIC - BROKER-IN-CHARGE (REAL ESTATE COMMISSION)\' AND EmployeeLicenseStatus__c != \'C - Current, Valid & In Good Standing\' AND PositionStatus__c != \'T - TEMPORARY (REAL ESTATE)\' AND PositionStatus__c != \'X - EXTEND TEMPORARY (REAL ESTATE)\'');
            List<String> bicEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(bicAssociatedLicenses)).getFieldValues('EmployeeLicense__c');

            List<String> forRenewalBIC = new List<String>();
            for(Application__c tAssocLicApp:tAssocLicApps){
                if(bicEmployeeLicenseIds.contains(tAssocLicApp.CurrentLicense__c)) forRenewalBIC.add(tAssocLicApp.CurrentLicense__c);
            }

            for(AssociatedLicense__c bicAssociatedLicense : bicAssociatedLicenses){
                if(forRenewalBIC.contains(bicAssociatedLicense.EmployeeLicense__c)) cBICEntityLicenseIds.add(bicAssociatedLicense.EntityLicense__c);
            }

            //RBO
            List<AssociatedLicense__c> rboAssociatedLicenses = AssociatedLicenseSelector.getPDGByEmployee(cBICEntityLicenseIds, new List<String>{'RBO'}, '');
            List<String> rboEmployeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(rboAssociatedLicenses)).getFieldValues('EntityLicense__c');
            List<Application__c> rboAssocLicApps = ApplicationSelector.getD1RNApplicationsByLicenseIds(rboEmployeeLicenseIds);
            if(!rboAssocLicApps.isEmpty()) appForRenew.addAll(rboAssocLicApps);

            
            System.debug('EMEL');
            System.debug(cBICEntityLicenseIds);
            System.debug(rboEmployeeLicenseIds);
        } else {
            List<Application__c> d2Apps = new List<Application__c>();
            for(Application__c assocLicApp : assocLicApps){
                if(accocLicAppsD2Required.contains(assocLicApp.CurrentLicense__c)) assocLicApp.Phase__c = 'D - Dependency Review';
                if(accocLicAppsD2Required.contains(assocLicApp.CurrentLicense__c)) assocLicApp.Status__c = 'D2 - Continuing Education Missing';
                if(accocLicAppsD2Required.contains(assocLicApp.CurrentLicense__c)) d2Apps.add(assocLicApp);
            }
            if(!d2Apps.isEmpty()) update d2Apps;
        }

        return appForRenew;
    }

    public static List<Application__c> processRBSP(List<Application__c> records) { 
        List<Application__c> appForRenew = new List<Application__c>();
        appForRenew.addAll(records);

        List<String> licenseIds = (List<String>) (new ApplicationDomain(records)).getFieldValues('CurrentLicense__c');
        List<AssociatedLicense__c> associatedLicenses = AssociatedLicenseSelector.getPDGByEntity(licenseIds, null, '');
        List<String> employeeLicenseIds = (List<String>)(new AssociatedLicenseDomain(associatedLicenses)).getFieldValues('EmployeeLicense__c');
        List<Application__c> assocLicApps = ApplicationSelector.getRNApplicationsByLicenseIds(employeeLicenseIds);
        if(!assocLicApps.isEmpty()) appForRenew.addAll(assocLicApps);

        return appForRenew;
    }

    public static void captureRenewApp(List<Application__c> records) {
        for(Application__c app: records) {
            if(app.Status__c != 'HC - Application Completed'
                 || (appIdsForRenew.contains(app.Id) && app.Status__c == 'HC - Application Completed')) {
                renewApps.put(app.Id, app);
            }
        }
    }

    public class Input {
        @InvocableVariable(label='Application Record for Input' description='Input Application' required=true)
        public Application__c record;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output Renewals' required=true)
        public String operationOutcome;
    }
}