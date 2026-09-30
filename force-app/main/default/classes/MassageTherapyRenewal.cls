/*
 * ___________________________________________________________________________________
 * Create New Apex Class for Massage Therapy Renewal called "MassageTherapyRenewal"
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-EA04112024 - Created for Case 00034843
 * __________________________________________________________________________________
 * Initial implementation
 *
 * @author emel.l.agarao@pacificpointcorp.com
 *
 * @created 04/11/2024
 * __________________________________________________________________________________
 */
public class MassageTherapyRenewal {
    public static Map<Id, License__c> licenseMap = new Map<Id, License__c>();
    public static Boolean forPushThrough = false;

    @InvocableMethod(
        label='Massage Therapy Renewal'
        description='Renew Massage Therapy Licenses'
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
        List<Application__c> inactiveRenewals = new List<Application__c>();
        List<Application__c> MATRenewals = new List<Application__c>();
        List<Application__c> MAERenewals = new List<Application__c>();
        List<Application__c> MAESPRenewals = new List<Application__c>();
        for(Application__c app:records){
            if(app.ApplicationRenewingInactive__c == true || app.ActiveInactive__c == 'Inactive'){
                inactiveRenewals.add(app);
            } else if(app.LicenseTypeCode__c == 'MAT'){
                MATRenewals.add(app);
            } else if(app.LicenseTypeCode__c == 'MAE'){
                MAERenewals.add(app);
            } else if(app.LicenseTypeCode__c == 'MAE - Sole Proprietor'){
                MAESPRenewals.add(app);
            }
        }

        if(!inactiveRenewals.isEmpty()){
            ApplicationService.renewApplicationLicenses(inactiveRenewals);
        }


        if(!MATRenewals.isEmpty()){
            doMATRenewals(MATRenewals);
        }

        if(!MAERenewals.isEmpty()){            
            doMAERenewals(MAERenewals);
        }

        if(!MAESPRenewals.isEmpty()){            
            doMAESPRenewals(MAESPRenewals);
        }
        
        BarberingCosmetologyRenewal.checkToCreateLicenseHistory(records);

        return results;
    }

    public static void doMATRenewals(List<Application__c> apps){        
        ApplicationService.renewApplicationLicenses(apps);
        Set<String> renewedLics = new Set<String>();
        
        for(Application__c app:apps){
            renewedLics.add(app.CurrentLicense__r.Id);
        }

        List<String> subQueries = new List<String>();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EmployeeLicense__c IN :renewedLics
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND (EntityLicenseType__c = 'MAE' OR EntityLicenseType__c = 'MAE - Sole Proprietor')
            AND (PositionStatus__c = 'P - PRINCIPAL' OR Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)')
        ]) {
            String subQuery = '(CurrentLicense__c = \'' + a.EntityLicense__c + '\' ';
            subQuery += !forPushThrough ? 'AND SameAsLicenseTypeNextRenewPeriod__c = true)' : 'AND SameAsLicenseTypeNextRenewPeriod__c = true)';
            subQueries.add(subQuery);
        }

        if(!subQueries.isEmpty()){                
            Set<String> depApplicationIds = new Set<String>();
            String q = 'SELECT Id FROM Application__c ';
            q += 'WHERE Type__c = \'RNEW - Renewal\' ';
            q += 'AND Status__c = \'D1 - Awaiting Dependency Review\' ';
            q += 'AND (';
            q += String.join(subQueries, ' OR ');
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

    public static void doMAERenewals(List<Application__c> apps){
        Map<String, Application__c> renewedLics = new Map<String, Application__c>();
        for(Application__c app:apps){
            renewedLics.put(app.CurrentLicense__r.Id, app);
        }

        List<Application__c> hasMATs = new List<Application__c>();
        List<String> hasMATIds = new List<String>();
        Set<String> renewedLicIds = renewedLics.keySet();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :renewedLicIds
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND EmployeeActiveInactive__c = 'Active'
            AND EmployeeLicenseType__c = 'MAT'
            AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            AND PositionStatus__c = 'P - PRINCIPAL'
        ]) {
            hasMATs.add(renewedLics.get(a.EntityLicense__c));
            hasMATIds.add(renewedLics.get(a.EntityLicense__c).Id);
        }

        if(!hasMATs.isEmpty()){
            ApplicationService.renewApplicationLicenses(hasMATs);
        }

        // Update no MAT
        List<Application__c> noMATApps = new List<Application__c>();
        List<License__c> noMATLics = new List<License__c>();
        Set<String> noMATLicIds = new Set<String>();
        for(Application__c app:apps){
            if(!hasMATIds.contains(app.Id)){
                app.Status__c = 'D1 - Awaiting Dependency Review';
                app.Phase__c = 'D - Dependency Review';
                noMATApps.add(app);

                License__c curLic = licenseMap.get(app.CurrentLicense__r.Id);
                curLic.ThisLicenseRenewed__c = true;
                noMATLics.add(curLic);
                noMATLicIds.add(curLic.Id);
            }
        }

        if(!noMATApps.isEmpty()){
            update noMATApps;

            if(!noMATLics.isEmpty()){
                update noMATLics;
                BarberingCosmetologyRenewal.checkToCreateLicenseHistory(noMATApps);
            }        
        }
    }

    public static void doMAESPRenewals(List<Application__c> apps){
        Map<String, Application__c> renewedLics = new Map<String, Application__c>();
        for(Application__c app:apps){
            renewedLics.put(app.CurrentLicense__r.Id, app);
        }

        List<Application__c> hasMATs = new List<Application__c>();
        List<String> hasMATIds = new List<String>();
        for (AssociatedLicense__c a : [
            SELECT Id, EntityLicense__c, EmployeeLicense__c
            FROM AssociatedLicense__c
            WHERE EntityLicense__c IN :renewedLics.keySet()
            AND EmploymentStatus__c = 'Employed'
            AND (EndDate__c >= TODAY OR EndDate__c = null)
            AND EmployeeActiveInactive__c = 'Active'
            AND EmployeeLicenseType__c = 'MAT'
            AND EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            AND (PositionStatus__c = 'P - PRINCIPAL' OR Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)')
        ]) {
            hasMATs.add(renewedLics.get(a.EntityLicense__c));
            hasMATIds.add(renewedLics.get(a.EntityLicense__c).Id);
        }

        if(!hasMATs.isEmpty()){
            ApplicationService.renewApplicationLicenses(hasMATs);
        }

        // Update no MAT
        List<Application__c> noMATApps = new List<Application__c>();
        List<License__c> noMATLics = new List<License__c>();
        Set<String> noMATLicIds = new Set<String>();
        for(Application__c app:apps){
            if(!hasMATIds.contains(app.Id)){
                app.Status__c = 'D1 - Awaiting Dependency Review';
                app.Phase__c = 'D - Dependency Review';
                noMATApps.add(app);

                License__c curLic = licenseMap.get(app.CurrentLicense__r.Id);
                curLic.ThisLicenseRenewed__c = true;
                noMATLics.add(curLic);
                noMATLicIds.add(curLic.Id);
            }
        }

        if(!noMATApps.isEmpty()){
            update noMATApps;

            if(!noMATLics.isEmpty()){
                update noMATLics;
                BarberingCosmetologyRenewal.checkToCreateLicenseHistory(noMATApps);
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