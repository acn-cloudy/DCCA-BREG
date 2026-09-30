/*
 * ___________________________________________________________________________________
 * Covered by
 * __________________________________________________________________________________
 * PacPoint-CL11222019 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.loyola@pacificpointcorp.com
 * 
 * @created 11/22/2019
 * __________________________________________________________________________________
 *
 * @See https://www.lucidchart.com/documents/edit/b919cacf-1793-4f22-9385-b22e77693246/dp4_fxhXgjYW
 * @See Case 00006378
 */
public class LicenseClassificationDeactivator {
    // @InvocableMethod(label = 'LicenseClassificationDeactivator')
    // public static void process(List<Id> licenseId) {
    //     Id lcId = licenseId[0];
    //     License__c lc = [
    //             SELECT
    //                     Id,
    //                     LicenseType__r.Entity__c,
    //                     LicenseType__r.Individual__c
    //             From License__c
    //             WHERE Id = :lcId
    //             AND LicenseType__c != null
    //     ];

    //     if (lc.LicenseType__r.Entity__c) {
    //         processEntityTypeLicense(new List<Id>{lcId});
    //     } else if (lc.LicenseType__r.Individual__c) {
    //         processNonEntityTypeLicense(lcId);
    //     }
    // }

    // /*
    //  * Refer to process map
    //  * https://www.lucidchart.com/documents/edit/b919cacf-1793-4f22-9385-b22e77693246/dp4_fxhXgjYW
    //  */
    // private static void processNonEntityTypeLicense(Id licenseId) {
    //     //get RME Associated Licenses
    //     License__c lc = [
    //             SELECT
    //                     Id,
    //                     LicenseType__r.StatusDuetoLossofDependent__c,
    //                     LicenseType__r.StatusDuetoNonRenewal__c,
    //                     LicenseType__r.ClassStatusDuetoLossof_Dependent__c,
    //                     LicenseType__r.NumberofDaysUntilAutoForfeiture__c,
    //                     (SELECT
    //                              Id,
    //                              EntityLicense__c,
    //                              EmployeeLicense__c,
    //                              EntityPrincipal__c
    //                     FROM Associated_Licenses__r)
    //             FROM License__c
    //             WHERE Id = :licenseId
    //     ];

    //     List<AssociatedLicense__c> rmeAssociatedLicenseIds = lc.Associated_Licenses__r;
    //     List<License__c> associatedLcEntityLicEntityPrincipal = new List<License__c>();

    //     if (rmeAssociatedLicenseIds.isEmpty()) {
    //         return;
    //     }

    //     if (rmeAssociatedLicenseIds.size() > 1) {
    //         for (AssociatedLicense__c al : rmeAssociatedLicenseIds) {
    //             al.DualIndicator__c = null;
    //         }

    //         update rmeAssociatedLicenseIds;
    //     }

    //     lc.Status__c = lc.LicenseType__r.StatusDuetoLossofDependent__c;
    //     Integer autoForfeitureDays = 0;

    //     if (lc.LicenseType__r.NumberofDaysUntilAutoForfeiture__c != null) {
    //         autoForfeitureDays = (Integer) lc.LicenseType__r.NumberofDaysUntilAutoForfeiture__c;
    //     }

    //     lc.ForfeitureDate__c = Date.today().addDays(autoForfeitureDays);
    //     update lc;

    //     Set<Id> rmeEntityLicenseIds = new Set<Id>();
    //     Set<Id> entityAssociatedLicenseIds = new Set<Id>();

    //     for (AssociatedLicense__c al : rmeAssociatedLicenseIds) {
    //         if (al.EntityPrincipal__c) {
    //             License__c entityLicense = new License__c();
    //             entityLicense.Id = al.EntityLicense__c;
    //             entityLicense.Status__c = lc.LicenseType__r.StatusDuetoNonRenewal__c;
    //             entityLicense.ForfeitureDate__c = Date.today()
    //                     .addDays((Integer) lc.LicenseType__r.NumberofDaysUntilAutoForfeiture__c);
    //             associatedLcEntityLicEntityPrincipal.add(entityLicense);

    //             rmeEntityLicenseIds.add(al.EntityLicense__c);
    //         } else {
    //             entityAssociatedLicenseIds.add(al.EntityLicense__c);
    //         }
    //     }

    //     if (!associatedLcEntityLicEntityPrincipal.isEmpty()) {
    //         update associatedLcEntityLicEntityPrincipal;
    //     }

    //     Set<String> entityAssociatedLicEmployeeLicStatusFilter = new Set<String>{
    //             'C - Current, Valid & In Good Standing',
    //             'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
    //             'CR - Current/Next Renewal Paid',
    //             'DM - Forfeited/Maintenance Requirement Due',
    //             'R - Valid Thru Expiration Date, Subject To Renewal',
    //             'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
    //             'Z - Current & Valid, But Subject To Disciplinary Requirement',
    //             'ZI - Automatically Forfeited Due To Insurance Loss',
    //             'ZM - Current & Valid, But Subject To Disciplinary/Maintenance'
    //             };

    //     List<AssociatedLicense__c> entityAssociatedLics = [
    //             SELECT
    //                     Id,
    //                     EntityLicense__c
    //             FROM AssociatedLicense__c
    //             WHERE EntityLicense__c IN :rmeEntityLicenseIds
    //             AND EmployeeLicense__r.Status__c IN :entityAssociatedLicEmployeeLicStatusFilter
    //             AND EmploymentStatus__c = 'Employed'
    //     ];

    //     Set<Id> entityLicIds = new Set<Id>();

    //     for (AssociatedLicense__c al : entityAssociatedLics) {
    //         entityLicIds.add(al.EntityLicense__c);
    //     }

    //     Set<Id> licenseClassificationIdFilter = new Set<Id>();
    //     licenseClassificationIdFilter.add(licenseId); //for RMELicenseClassifications
    //     licenseClassificationIdFilter.addAll(entityLicIds); //for EntityLicenseClassifications
    //     licenseClassificationIdFilter.addAll(entityAssociatedLicenseIds); //for EntityAssociatedLicenseClassifications

    //     Map<Id, LicenseClassification__c> licenseClassificationMap = new Map<Id, LicenseClassification__c>([
    //             SELECT
    //                     Id,
    //                     Classification__c,
    //                     License__c,
    //                     License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c
    //             FROM LicenseClassification__c
    //             WHERE License__c IN :licenseClassificationIdFilter
    //             AND (Status__c = 'C - Current, Valid & In Good Standing' OR Status__c = null)
    //     ]);

    //     Set<Id> entityClassificationIds = new Set<Id>();
    //     Set<Id> entityAssociatedClassificationIds = new Set<Id>();
    //     Set<Id> rmeClassificationIds = new Set<Id>();

    //     Set<Id> entityLicenseClassificationIds = new Set<Id>();
    //     Map<Id, Set<Id>> rmeClassificationIdLicenseClassificationIdsMap = new Map<Id, Set<Id>>();

    //     for (LicenseClassification__c lcl : licenseClassificationMap.values()) {
    //         if (entityLicIds.contains(lcl.License__c)) {
    //             entityClassificationIds.add(lcl.Classification__c);
    //             entityLicenseClassificationIds.add(lcl.Id);
    //         }

    //         if (entityAssociatedLicenseIds.contains(lcl.License__c)) {
    //             entityAssociatedClassificationIds.add(lcl.Classification__c);
    //         }

    //         if (lcl.License__c == licenseId) {
    //             rmeClassificationIds.add(lcl.Classification__c);

    //             if (!rmeClassificationIdLicenseClassificationIdsMap.containsKey(lcl.Classification__c)) {
    //                 rmeClassificationIdLicenseClassificationIdsMap.put(lcl.Classification__c, new Set<Id>());
    //             }

    //             rmeClassificationIdLicenseClassificationIdsMap.get(lcl.Classification__c).add(lcl.Id);
    //         }
    //     }

    //     List<LicenseClassification__c> rmeLicClassToUpdate = new List<LicenseClassification__c>();

    //     for (Id rmeClassificationId : rmeClassificationIds) {
    //         if (entityAssociatedClassificationIds.contains(rmeClassificationId)) {
    //             continue;
    //         }

    //         if (entityClassificationIds.contains(rmeClassificationId)) {
    //             continue;
    //         }

    //         //Not Entity Associated Classifications and Entity Classifications Found
    //         Set<Id> lcToUpdate = rmeClassificationIdLicenseClassificationIdsMap.get(rmeClassificationId);
    //         for (Id lcId : lcToUpdate) {
    //             LicenseClassification__c rmeLicClass = new LicenseClassification__c();
    //             rmeLicClass.Id = lcId;
    //             rmeLicClass.Status__c = lc.LicenseType__r.ClassStatusDuetoLossof_Dependent__c;
    //             rmeLicClassToUpdate.add(rmeLicClass);
    //         }
    //     }

    //     if (!rmeLicClassToUpdate.isEmpty()) {
    //         //update Entity LicenseClassifications
    //         for (Id entityLicClassId : entityLicenseClassificationIds) {
    //             LicenseClassification__c entityLicClass = new LicenseClassification__c();
    //             entityLicClass.Id = entityLicClassId;
    //             entityLicClass.Status__c = lc.LicenseType__r.ClassStatusDuetoLossof_Dependent__c;
    //             rmeLicClassToUpdate.add(entityLicClass);
    //         }

    //         update rmeLicClassToUpdate;
    //     }
    // }

    // /*
    //  * Refer to process map
    //  * https://www.lucidchart.com/documents/edit/b919cacf-1793-4f22-9385-b22e77693246/dp4_fxhXgjYW
    //  */
    // private static void processEntityTypeLicense(List < Id > licenseIds) {
    //     Set < String > entityAssociatedLicenseEmployeeLicenseStatusFilter = new Set < String>{
    //             'C - Current, Valid & In Good Standing',
    //             'CM - Current, Valid & In Good Standing/Maint. Requirement Due',
    //             'CR - Current/Next Renewal Paid',
    //             'DM - Forfeited/Maintenance Requirement Due',
    //             'R - Valid Thru Expiration Date, Subject To Renewal',
    //             'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due',
    //             'Z - Current & Valid, But Subject To Disciplinary Requirement',
    //             'ZI - Automatically Forfeited Due To Insurance Loss',
    //             'ZM - Current & Valid, But Subject To Disciplinary/Maintenance'
    //             };

    //     //get license records with its related EntityAssociatedLicenses
    //     Map <Id, License__c> licenseMap = new Map <Id, License__c> ([
    //             SELECT
    //                     Id,
    //                     LicenseType__r.StatusDuetoLossofDependent__c,
    //                     LicenseType__r.ClassStatusDuetoLossof_Dependent__c,
    //                     LicenseType__r.NumberofDaysUntilAutoForfeiture__c,
    //                     (SELECT
    //                              Id,
    //                              EmployeeLicense__c
    //                     FROM ParentLicenses__r
    //                     WHERE EmployeeLicense__r.Status__c IN :entityAssociatedLicenseEmployeeLicenseStatusFilter
    //                     AND EmploymentStatus__c = 'Employed')
    //             FROM License__c
    //             WHERE Id IN :licenseIds
    //     ]);

    //     Set<Id>employeeLicenseIdsToUpdate = new Set<Id>();
    //     List<License__c> employeeLicToUpdate = new List<License__c>();

    //     //Map of the Associated Licenses with the same Employee License
    //     //DualIndicator will be set to null
    //     Map<Id, List<AssociatedLicense__c>> employeeLicIdToAssociatedLicMap = new Map<Id, List<AssociatedLicense__c>>();

    //     for (Id licId : licenseMap.keySet()) {
    //         License__c lic = licenseMap.get(licId);

    //         for (AssociatedLicense__c al : lic.Associated_Licenses__r) {
    //             if (al.EmployeeLicense__c == null) {
    //                 continue;
    //             }

    //             //Set the AssociatedLicense.EmployeeLicense.Status__c = LicenseType.StatusDuetoLossofDependent__c
    //             //Set the AssociatedLicense.EmployeeLicense.ForfeitureDate__c = LicenseType.NumberofDaysUntilAutoForfeiture__c + Today
    //             if (!employeeLicenseIdsToUpdate.contains(al.EmployeeLicense__c)) {
    //                 employeeLicenseIdsToUpdate.add(al.EmployeeLicense__c);
    //                 License__c employeeLic = new License__c();
    //                 employeeLic.Id = al.EmployeeLicense__c;
    //                 employeeLic.Status__c = lic.LicenseType__r.StatusDuetoLossofDependent__c;
    //                 employeeLic.ForfeitureDate__c = Date.today()
    //                         .addDays((Integer) lic.LicenseType__r.NumberofDaysUntilAutoForfeiture__c);
    //                 employeeLicToUpdate.add(employeeLic);
    //             }

    //             //Search for associated licenses with the same Employee License
    //             if (!employeeLicIdToAssociatedLicMap.containsKey(al.EmployeeLicense__c)) {
    //                 employeeLicIdToAssociatedLicMap.put(al.EmployeeLicense__c,
    //                         new List< AssociatedLicense__c > ());
    //             }

    //             employeeLicIdToAssociatedLicMap.get(al.EmployeeLicense__c).add(al);
    //         }
    //     }

    //     if (!employeeLicToUpdate.isEmpty()) {
    //         update employeeLicToUpdate;
    //     }

    //     //List of associated license to set dual indicator to null
    //     List<AssociatedLicense__c>associatedLicenseDualIndicatorToNull = new List<AssociatedLicense__c>();

    //     for (Id employeeLicenseId : employeeLicIdToAssociatedLicMap.keySet()) {
    //         List < AssociatedLicense__c > associatedLicenses = employeeLicIdToAssociatedLicMap.get(employeeLicenseId);
    //         if (associatedLicenses.isEmpty() && associatedLicenses.size() > 1) {
    //             for (AssociatedLicense__c al : associatedLicenses) {
    //                 al.DualIndicator__c = null;
    //             }

    //             associatedLicenseDualIndicatorToNull.addAll(employeeLicIdToAssociatedLicMap.get(employeeLicenseId));
    //         }
    //     }

    //     //Set dual indicator to null
    //     if (!associatedLicenseDualIndicatorToNull.isEmpty()) {
    //         update associatedLicenseDualIndicatorToNull;
    //     }

    //     //get license classifications
    //     Map<Id, LicenseClassification__c> licenseClassificationMap = new Map<Id, LicenseClassification__c>([
    //             SELECT
    //                     Id,
    //                     Classification__c,
    //                     License__c,
    //                     License__r.LicenseType__r.ClassStatusDuetoLossof_Dependent__c
    //             FROM LicenseClassification__c
    //             WHERE License__c IN :licenseMap.keySet()
    //             AND (Status__c = 'C - Current, Valid & In Good Standing' OR Status__c = null)
    //     ]);

    //     Map<Id, List<Id>> classificationIdLicenseClassificationsIdMap = new Map <Id, List <Id>>();
    //     Set<Id>classificationIds = new Set<Id>();

    //     for (LicenseClassification__c lc : licenseClassificationMap.values()) {
    //         if (!classificationIdLicenseClassificationsIdMap.containsKey(lc.Classification__c)) {
    //             classificationIdLicenseClassificationsIdMap.put(lc.Classification__c, new List<Id>());
    //         }
    //         classificationIdLicenseClassificationsIdMap.get(lc.Classification__c).add(lc.Id);
    //         classificationIds.add(lc.Classification__c);
    //     }

    //     if (!classificationIds.isEmpty()) {
    //         Map<Id, Classification__c> classificationMap = new Map<Id, Classification__c>([
    //                 SELECT
    //                         Id,
    //                         (SELECT Id
    //                         FROM Application_Classifications__r)
    //                 FROM Classification__c
    //                 WHERE Id IN :classificationIds
    //         ]);

    //         List<LicenseClassification__c> licenseClassificationsToUpdate = new List <LicenseClassification__c>();

    //         //if no Application Classification found
    //         //set LicenseClassification.Status__c = License.LicenseType.ClassStatusDuetoLossof_Dependent__c
    //         for (Classification__c cl : classificationMap.values()) {
    //             if (cl.Application_Classifications__r.isEmpty()) {
    //                 List < Id > licenseClassificationsIds = classificationIdLicenseClassificationsIdMap.get(cl.Id);

    //                 for (Id lcId : licenseClassificationsIds) {
    //                     LicenseClassification__c lc = new LicenseClassification__c();
    //                     lc.Id = lcId;
    //                     lc.Status__c = licenseClassificationMap.get(lcId)
    //                             .License__r
    //                             .LicenseType__r
    //                             .ClassStatusDuetoLossof_Dependent__c;
    //                     licenseClassificationsToUpdate.add(lc);
    //                 }
    //             }
    //         }

    //         if (!licenseClassificationsToUpdate.isEmpty()) {
    //             update licenseClassificationsToUpdate;
    //         }
    //     }
    // }
}