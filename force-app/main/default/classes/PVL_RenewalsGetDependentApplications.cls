public without sharing class PVL_RenewalsGetDependentApplications {
    @InvocableMethod(
    label = 'Get Dependent Application'
    description = 'Kick off the Renewal Dependency Flow for any possible license on the dependent side of the 1-way dependency'
    category = 'PVL Renewals')
    public static List<Output> getDependentApplication(List<Input> inputs) { 
        Integer appReceivedDateGracePeriod = (Integer) PVLRenewalSettings__c.getInstance(UserInfo.getUserId())?.ReceivedDateGracePeriod__c;
        appReceivedDateGracePeriod = appReceivedDateGracePeriod == null ? 21 : appReceivedDateGracePeriod;
        Map<Id, Output> licenses = new Map<Id, Output>();
        Map<Id, Id> associationMap = new Map<Id, Id>();
        Map<Id, Input> inputMap = new Map<Id, Input>();

        for (Input thisInput : inputs) {
            inputMap.put(thisInput.ivokingLicense.Id, thisInput);
            licenses.put(thisInput.ivokingLicense.Id, new Output());
        }

        //find all associated licenses where the invoking license is on either side of the relationship
        for (AssociatedLicense__c associatedLicense : [
            SELECT
                EntityLicense__c, EmployeeLicense__c, EntityPrincipal__c, Position__c
            FROM AssociatedLicense__c
            WHERE ( 
                (
                    EntityLicense__c IN :licenses.keySet()
                    AND (
                        (
                            EntityLicense__r.LicenseType__r.Name != 'RB - Entity'
                            AND (
                                (PositionStatus__c = 'P - PRINCIPAL' AND EntityLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'P - PRINCIPAL')
                                OR (PositionStatus__c = 'D - DESIGNATED' AND EntityLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'D - DESIGNATED')
                            )
                        ) OR (EntityLicense__r.LicenseType__r.Name = 'RB - Entity' AND PositionStatus__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)')
                    )
                ) OR (
                    EmployeeLicense__c IN: licenses.keySet()
                    AND (
                        (
                            EmployeeLicense__r.LicenseType__r.Name != 'RB - Entity'
                            AND (
                                (PositionStatus__c = 'P - PRINCIPAL' AND EmployeeLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'P - PRINCIPAL')
                                OR (PositionStatus__c = 'D - DESIGNATED' AND EmployeeLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'D - DESIGNATED')
                            )
                        ) OR (EmployeeLicense__r.LicenseType__r.Name = 'RB - Entity' AND PositionStatus__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)')
                    )
                )
            )
            AND EmploymentStatus__c = 'Employed'
        ]) {
            //find the specific input fot this associatedLicense
            Input targetInput = inputMap.containsKey(associatedLicense.EntityLicense__c) ? inputMap.get(associatedLicense.EntityLicense__c) : inputMap.get(associatedLicense.EmployeeLicense__c);
            Map<Id, Id> targetRelationship = targetInput.determineRelationshipTo(associatedLicense);
            if (!targetRelationship.isEmpty()) {
                associationMap.putAll(targetRelationship);
            }
        }

        List<Application__c> applications = [
            SELECT
                Id,
                CurrentLicense__c,
                CurrentLicense__r.Name,
                RNEWRSTRDate__c,
                ActiveInactive__c,
                RenewingPermittoPractice__c,
                CurrentLicense__r.AssociatedLicenseNonRenewalCount__c,
                Type__c,
                ApplicationReceivedDate__c,
                OnlineApplicationTypeDependencyFlow__c,
                LicenseTypeCode__c,
                Status__c,
                LicenseType__c,
                LicenseType__r.StartofRenewalPeriod__c,
                LicenseType__r.OneWayDependency__c,
                LicenseType__r.RequiresallEmployeestoRenew__c,
                Phase__c,
                CompleteApplicationBy__c
            FROM Application__c
            WHERE CurrentLicense__c IN :associationMap.keySet()
            AND Type__c IN ('RNEW - Renewal', 'RSTR - Restore - No A/I Status')
            AND Status__c IN ('D1 - Awaiting Dependency Review','HC - Application Completed')
        ];

        for (Application__c application : applications) {
            Date renewalGrace = application.LicenseType__r.StartofRenewalPeriod__c.addDays(-1 * appReceivedDateGracePeriod);
            if (application.ApplicationReceivedDate__c >= renewalGrace) {
                licenses.get(associationMap.get(application.CurrentLicense__c)).dependentApplication = application;
            }
        }
        return licenses.values();
    }

    public class Input {
        @InvocableVariable(
        label = 'License'
        description = 'The license being renewed'
        required = true)
        public License__c ivokingLicense;

        @InvocableVariable(label = 'Requires Entity Principal?')
        public Boolean requiresEntityPrincipal;

        @InvocableVariable(
        label = 'Associated License Relationship'
        description = 'Informs which side of the associated license relationship to look for dependencies'
        required = true)
        public String associatedLicenseRelationship;

        public Map<Id, Id> determineRelationshipTo(AssociatedLicense__c associatedLicense) {
            Map<Id, Id> returnValue = new Map<Id, Id>();
            //need to find the associated license where the invoking license is on the opposite side of the target relationship
            String sourceRelationshipField = this.associatedLicenseRelationship?.equalsIgnoreCase('EntityLicense') ? 'EmployeeLicense__c' : 'EntityLicense__c';
            if (
                    ((Id) associatedLicense.get(sourceRelationshipField)) == this.ivokingLicense.Id && //ensure this is not the targeted associated license from a different relationship
                (
                    ((associatedLicense.EntityPrincipal__c && this.requiresEntityPrincipal) || !this.requiresEntityPrincipal) || //if entity principal is checked, only look for entity principaled items, otherwise ignore this flag
                    this.isValidForRbEntity(associatedLicense)
                )
            ) {
                //matches the requirement of entity principal or not
                returnValue.put((Id) associatedLicense.get(this.associatedLicenseRelationship + '__c'), this.ivokingLicense.Id);
            }

            return returnValue;
        }

        private Boolean isValidForRbEntity(AssociatedLicense__c associatedLicense){
            return this.ivokingLicense.LicenseTypeName__c.equalsIgnoreCase('RB - Entity') &&
            String.IsNotBlank(associatedLicense.Position__c)&&
            associatedLicense.Position__c.equalsIgnoreCase('PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)');
        }
    }

    public class Output {
        @InvocableVariable(
        label = 'Application'
        description = 'The dependent application')
        public Application__c dependentApplication;

        Output() {
            this.dependentApplication = null;
        }
    }
}