/*
 * -----------------------------------------------------------------------------------
 * Description
 * Covered by: CTCheckoutFormControllerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL04082022 - Created for Case 00020872
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 04/08/2022
 * __________________________________________________________________________________
 * Changes
 */
public class CTCheckoutFormController {
    private final Application__c application;

    public CTCheckoutFormController(ApexPages.StandardController stdController) {
        this.application = (Application__c)stdController.getRecord();
    }

    public List<License__c> getApplicantLicenses() {
        return [
                SELECT
                        Id,
                        Name,
                        NotificationLicenseNumber__c,
                        LicenseCode__c,
                        EffectiveExpireDate__c,
                        CheckoutFormConditional__c,
                        ActiveInactive__c
                FROM
                License__c
                WHERE Licensee__c = :this.application.Applicant__c
                AND LicenseType__r.Name IN ('CT - Entity', 'CT - RME', 'CT - Sole Proprietor', 'EJ', 'EM', 'EJS', 'EJI', 'ESS', 'PJ', 'PM', 'EVM')
        ];
    }

    public List<ApplicationClassifications__c> getApplicationClassifications() {
        List<String> excludedStatus = new List<String>{'CW - Class Withdrawn by Applicant', 'HC - Application Completed', 'U - Class No Longer Needed Due To Upgrade To Higher Class', 'NA - No Application'};
        return [
                SELECT
                        Id,
                        ClassificationName1__c
                FROM ApplicationClassifications__c
                WHERE Application__c = :this.application.Id
                AND Status__c NOT IN :excludedStatus
        ];
    }

    public List<LicenseClassification__c> getClassificationsHeld() {
        List<License__c> licenses = getApplicantLicenses();
        Map<String, LicenseClassification__c> licClassificationMap = new Map<String, LicenseClassification__c>();

        if(licenses != null && !licenses.isEmpty()){    
            Map<Id, License__c> licMap = new Map<Id, License__c>(licenses);        
            for(LicenseClassification__c lc : [
                SELECT
                        Id,
                        ClassificationName__c,
                        Status__c
                FROM LicenseClassification__c
                WHERE License__c IN :licMap.keySet()
                AND License__r.LicenseType__r.Name IN ('CT - Entity', 'CT - RME', 'CT - Sole Proprietor')
                AND Status__c IN ('C - Current, Valid & In Good Standing', 'I - Class No Longer Active (No RME/Firm, No EMPR)', 'RI - RESTRICTED INACTIVE', 'T - CLASS NO LONGER ACTIVE (LICENSE TERMINATED)', 'F - Class No Longer Active (License Forfeited)')
                ORDER BY EndDate__c DESC
            ]) {
                LicenseClassification__c currentLC = licClassificationMap.get(lc.ClassificationName__c);
                if(currentLC == null || lc.Status__c == 'C - Current, Valid & In Good Standing'){
                    licClassificationMap.put(lc.ClassificationName__c, lc);
                }
            }
        }

        return licClassificationMap.values();
    }

    public List<ApplicationClassifications__c> getDependentApplicationClassifications() {
        List<String> excludedStatus = new List<String>{'CW - Class Withdrawn by Applicant', 'HC - Application Completed', 'U - Class No Longer Needed Due To Upgrade To Higher Class', 'NA - No Application'};
        return [
                SELECT
                        Id,
                        ClassificationName1__c
                FROM ApplicationClassifications__c
                WHERE Application__c = :this.application.DependentApplication__c
                AND Status__c NOT IN :excludedStatus
        ];
    }

    public List<License__c> getDependentLicenseLicenses() {
        String dependentApplicationLicenseId = this.application?.DependentApplication__r?.CurrentLicense__c;
        String dependentLicenseeId = this.application?.DependentLicense__r?.Licensee__c;
        if (dependentApplicationLicenseId == null && dependentLicenseeId == null) {
            return null;
        }

        String query = 'SELECT Id, ' +
                'Name, ' +
                'NotificationLicenseNumber__c, ' +
                'LicenseCode__c, ' +
                'EffectiveExpireDate__c, ' +
                'CheckoutFormConditional__c, ' +
                'ActiveInactive__c ' +
                'FROM License__c ';

        String whereClause = '';

        if (dependentApplicationLicenseId != null) {
            whereClause += 'WHERE Id = :dependentApplicationLicenseId';
        } else if (dependentLicenseeId != null) {
            whereClause += 'WHERE Licensee__c = :dependentLicenseeId';
        }

        whereClause += (whereClause == '') ? '' : ' AND ';
        whereClause += 'LicenseType__r.Name IN (\'CT - Entity\', \'CT - RME\', \'CT - Sole Proprietor\', \'EJ\', \'EM\', \'EJS\', \'EJI\', \'ESS\', \'PJ\', \'PM\', \'EVM\')';

        query += whereClause;

        return Database.query(query);
    }

    // public List<LicenseClassification__c> getDependentLicenseLicenseClassifications() {
    //     return [
    //             SELECT
    //                     Id,
    //                     ClassificationName1__c,
    //                     Status__c
    //             FROM LicenseClassification__c
    //             WHERE (License__c = :this.application.DependentLicense__c
    //             OR License__c = :this.application.DependentApplication__r.CurrentLicense__c)
    //             AND 
    //     ];
    // }

    public List<LicenseClassification__c> getDependentLicenseLicenseClassifications() {
        List<License__c> licenses = getDependentLicenseLicenses();        
        Map<String, LicenseClassification__c> licClassificationMap = new Map<String, LicenseClassification__c>();

        if(licenses != null && !licenses.isEmpty()){            
            Map<Id, License__c> licMap = new Map<Id, License__c>(licenses);
            for(LicenseClassification__c lc : [
                SELECT
                        Id,
                        ClassificationName__c,
                        ClassificationName1__c,
                        Status__c
                FROM LicenseClassification__c
                WHERE License__c IN :licMap.keySet()
                AND License__r.LicenseType__r.Name IN ('CT - Entity', 'CT - RME', 'CT - Sole Proprietor')
                AND Status__c IN ('C - Current, Valid & In Good Standing', 'I - Class No Longer Active (No RME/Firm, No EMPR)', 'RI - RESTRICTED INACTIVE', 'T - CLASS NO LONGER ACTIVE (LICENSE TERMINATED)', 'F - Class No Longer Active (License Forfeited)')
                ORDER BY EndDate__c DESC
            ]) {
                LicenseClassification__c currentLC = licClassificationMap.get(lc.ClassificationName__c);
                if(currentLC == null || lc.Status__c == 'C - Current, Valid & In Good Standing'){
                    licClassificationMap.put(lc.ClassificationName__c, lc);
                }
            }
        }

        return licClassificationMap.values();
    }
}