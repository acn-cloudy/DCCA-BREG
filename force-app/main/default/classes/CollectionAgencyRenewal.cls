/*
 * ___________________________________________________________________________________
 * Create New Apex for Collection Agency Renewal called "CollectionAgencyRenewal"
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA04112024 - Created for Case 00034844
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 04/11/2024
 * __________________________________________________________________________________
 */
public class CollectionAgencyRenewal {
    public static Map<Id, License__c> licenseMap = new Map<Id, License__c>();

    @InvocableMethod(
        label='Collection Agency Renewal'
        description='Renew Collection Agency Licenses'
        category='License__c'
        )
    public static List <Results> execute (List<Input> inputs) {
        List<Results> results = new List<Results>();
        Set<String> licenseIds = new Set<String>();
        Set<String> applicationIds = new Set<String>();
        for(Input i: inputs) {            
            licenseIds.add(i.inputLicense.Id);
            applicationIds.add(i.inputApplication.Id);
            licenseMap.put(i.inputLicense.Id, i.inputLicense);

            Results res = new Results();
            res.operationOutcome = i.inputApplication.Name + ' processed.';
            results.add(res);
        }
        

        List<Application__c> records = ApplicationSelector.getApplicationsByIds(new List<String>(applicationIds));
        List<Application__c> COLARenewals = new List<Application__c>();
        List<Application__c> COLAXRenewals = new List<Application__c>();
        List<Application__c> COLXBRenewals = new List<Application__c>();
        List<Application__c> COLBRenewals = new List<Application__c>();
        for(Application__c app:records){
            if(app.LicenseTypeCode__c == 'COLA'){
                COLARenewals.add(app);
            } else if(app.LicenseTypeCode__c == 'COLAX'){
                COLAXRenewals.add(app);
            } else if(app.LicenseTypeCode__c == 'COLXB'){
                COLXBRenewals.add(app);
            } else if(app.LicenseTypeCode__c == 'COLB'){
                COLBRenewals.add(app);
            }
        }

        if(!COLARenewals.isEmpty()){
            doCOLARenewals(COLARenewals);
        }

        if(!COLAXRenewals.isEmpty()){
            doCOLAXRenewals(COLAXRenewals);
        }

        if(!COLXBRenewals.isEmpty()){
            doCOLXBRenewals(COLXBRenewals);
        }

        if(!COLBRenewals.isEmpty()){            
            doCOLBRenewals(COLBRenewals);
        }

        (new ApplicationDomain(records)).createLicenseHistory(licenseIds);

        return results;
    }

    public static void doCOLARenewals(List<Application__c> apps){        
        ApplicationService.renewApplicationLicenses(apps);
        Set<String> renewedLics = new Set<String>();
        Map<String, String> licAppPeriod = new Map<String, String>();
        for(Application__c app:apps){
            renewedLics.add(app.CurrentLicense__r.Id);
            licAppPeriod.put(app.CurrentLicense__r.Id, app.CurrentLicense__r.LicenseType__r.NextLicensePeriod__c);
        }

        List<String> subQuery = new List<String>();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :renewedLics
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND EntityLicenseType__c = 'COLB'
        ]) {
            subQuery.add('(CurrentLicense__c = \'' + a.EntityLicense__c + '\' AND LicensePeriodRNEW__c = \'' + licAppPeriod.get(a.EmployeeLicense__c) + '\')');
        }

        if(!subQuery.isEmpty()){                
            Set<String> depApplicationIds = new Set<String>();
            String q = 'SELECT Id FROM Application__c ';
            q += 'WHERE Type__c = \'RNEW - Renewal\' ';
            q += 'AND Status__c = \'D1 - Awaiting Dependency Review\' ';
            q += 'AND (';
            q += String.join(subQuery, ' OR ');
            q += ')';

            List<Application__c> depApplications = Database.query(q);
            for(Application__c app:depApplications){
                depApplicationIds.add(app.Id);
            }

            if(!depApplicationIds.isEmpty()){
                ApplicationService.renewApplicationLicenses(ApplicationSelector.getApplicationsByIds(new List<String>(depApplicationIds)));
            }
        }
    }

    public static void doCOLAXRenewals(List<Application__c> apps){        
        ApplicationService.renewApplicationLicenses(apps);
        Set<String> renewedLics = new Set<String>();
        Map<String, String> licAppPeriod = new Map<String, String>();
        for(Application__c app:apps){
            renewedLics.add(app.CurrentLicense__r.Id);
            licAppPeriod.put(app.CurrentLicense__r.Id, app.CurrentLicense__r.LicenseType__r.NextLicensePeriod__c);
        }

        List<String> subQuery = new List<String>();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :renewedLics
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND EntityLicenseType__c = 'COLXB'
        ]) {
            subQuery.add('(CurrentLicense__c = \'' + a.EntityLicense__c + '\' AND LicensePeriodRNEW__c = \'' + licAppPeriod.get(a.EmployeeLicense__c) + '\')');
        }

        if(!subQuery.isEmpty()){                
            Set<String> depApplicationIds = new Set<String>();
            String q = 'SELECT Id FROM Application__c ';
            q += 'WHERE Type__c = \'RNEW - Renewal\' ';
            q += 'AND Status__c = \'D1 - Awaiting Dependency Review\' ';
            q += 'AND (';
            q += String.join(subQuery, ' OR ');
            q += ')';

            List<Application__c> depApplications = Database.query(q);
            for(Application__c app:depApplications){
                depApplicationIds.add(app.Id);
            }

            if(!depApplicationIds.isEmpty()){
                ApplicationService.renewApplicationLicenses(ApplicationSelector.getApplicationsByIds(new List<String>(depApplicationIds)));
            }
        }
    }

    public static void doCOLXBRenewals(List<Application__c> apps){
        Map<String, Application__c> renewedLics = new Map<String, Application__c>();
        for(Application__c app:apps){
            renewedLics.put(app.CurrentLicense__r.Id, app);
        }

        List<Application__c> hasCOLAXs = new List<Application__c>();
        List<String> hasCOLAXIds = new List<String>();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :renewedLics.keySet()
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND EmployeeActiveInactive__c = 'Active'
            AND EmployeeLicenseType__c = 'COLAX'
            AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
        ]) {
            hasCOLAXs.add(renewedLics.get(a.EntityLicense__c));
            hasCOLAXIds.add(renewedLics.get(a.EntityLicense__c).Id);
        }

        if(!hasCOLAXs.isEmpty()){
            ApplicationService.renewApplicationLicenses(hasCOLAXs);
        }

        // Update no MAT
        List<Application__c> noCOLAXApps = new List<Application__c>();
        List<License__c> noCOLAXLics = new List<License__c>();
        Set<String> noCOLAXLicIds = new Set<String>();
        for(Application__c app:apps){
            if(!hasCOLAXIds.contains(app.Id)){
                app.Status__c = 'D1 - Awaiting Dependency Review';
                app.Phase__c = 'D - Dependency Review';
                noCOLAXApps.add(app);

                License__c curLic = licenseMap.get(app.CurrentLicense__r.Id);
                curLic.ThisLicenseRenewed__c = true;
                noCOLAXLics.add(curLic);
                noCOLAXLicIds.add(curLic.Id);
            }
        }

        if(!noCOLAXApps.isEmpty()){
            update noCOLAXApps;

            if(!noCOLAXLics.isEmpty()){
                update noCOLAXLics;
                (new ApplicationDomain(noCOLAXApps)).createLicenseHistory(noCOLAXLicIds);
            }        
        }
    }

    public static void doCOLBRenewals(List<Application__c> apps){
        Map<String, Application__c> renewedLics = new Map<String, Application__c>();
        for(Application__c app:apps){
            renewedLics.put(app.CurrentLicense__r.Id, app);
        }

        List<Application__c> hasCOLAs = new List<Application__c>();
        List<String> hasCOLAIds = new List<String>();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :renewedLics.keySet()
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND EmployeeActiveInactive__c = 'Active'
            AND EmployeeLicenseType__c = 'COLA'
            AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
        ]) {
            hasCOLAs.add(renewedLics.get(a.EntityLicense__c));
            hasCOLAIds.add(renewedLics.get(a.EntityLicense__c).Id);
        }

        if(!hasCOLAs.isEmpty()){
            ApplicationService.renewApplicationLicenses(hasCOLAs);
        }

        // Update no MAT
        List<Application__c> noCOLAApps = new List<Application__c>();
        List<License__c> noCOLALics = new List<License__c>();
        Set<String> noCOLALicIds = new Set<String>();
        for(Application__c app:apps){
            if(!hasCOLAIds.contains(app.Id)){
                app.Status__c = 'D1 - Awaiting Dependency Review';
                app.Phase__c = 'D - Dependency Review';
                noCOLAApps.add(app);

                License__c curLic = licenseMap.get(app.CurrentLicense__r.Id);
                curLic.ThisLicenseRenewed__c = true;
                noCOLALics.add(curLic);
                noCOLALicIds.add(curLic.Id);
            }
        }

        if(!noCOLAApps.isEmpty()){
            update noCOLAApps;

            if(!noCOLALics.isEmpty()){
                update noCOLALics;
                (new ApplicationDomain(noCOLAApps)).createLicenseHistory(noCOLALicIds);
            }        
        }
    }

    public class Input {
        @InvocableVariable(label='License Record for Input' description='Input License' required=true)
        public License__c inputLicense;
        @InvocableVariable(label='Application Record for Input' description='Input Application' required=true)
        public Application__c inputApplication ;
    }
    public class Results {
        @InvocableVariable(label='Records for Output' description='Output' required=true)
        public String operationOutcome;
    }
}