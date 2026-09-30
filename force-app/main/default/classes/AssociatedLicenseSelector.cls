public class AssociatedLicenseSelector {
    public static List<AssociatedLicense__c> getAssociatedLicenses(List<Id> entityLicenseIds) {
       return [
           Select Id, EndDate__c, EmploymentStatus__c, EntityLicense__c, EmployeeLicense__c, EntityLicense__r.EffectiveExpireDate__c from AssociatedLicense__c WHERE EntityLicense__c IN: entityLicenseIds
       ];
    }
    public static List<AssociatedLicense__c> getAssociatedEmployeeLicenses(List<Id> licenseIds) {
        return [
            Select Id, EmploymentStatus__c, EntityLicense__c, EmployeeLicense__c,  EmployeeLicense__r.EffectiveExpireDate__c from AssociatedLicense__c 
            WHERE EmployeeLicense__c IN: licenseIds and EmploymentStatus__c = 'Employed'
        ];
     }

     public static List<AssociatedLicense__c> getActiveBSHEntityLicenses(List<String> licenseIds) {
        return [
            Select Id, EmploymentStatus__c, EntityLicense__c, EmployeeLicense__c,  EmployeeLicense__r.EffectiveExpireDate__c from AssociatedLicense__c 
            WHERE EmployeeLicense__c IN: licenseIds and EmploymentStatus__c = 'Employed' and EmployeeLIcense__r.ActiveInactive__c = 'Active' 
            and (EndDate__c > today or EndDate__c = null) and EntityLicense__r.LicenseType__r.Name = 'BSH'
            and ((Position__c = 'BEO - BEAUTY OPERATOR' and PositionStatus__c = 'D - Designated' ) or Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)')  
        ];
     }

     public static List<AssociatedLicense__c> getActiveBASEntityLicenses(List<String> licenseIds) {
        return [
            Select Id, EmploymentStatus__c, EntityLicense__c, EmployeeLicense__c,  EmployeeLicense__r.EffectiveExpireDate__c from AssociatedLicense__c 
            WHERE EmployeeLicense__c IN: licenseIds and EmploymentStatus__c = 'Employed' and (EndDate__c > today or EndDate__c = null) and EntityLicense__r.LicenseType__r.Name = 'BAS'
            and ((Position__c = 'BAR - BARBER' and PositionStatus__c = 'D - Designated' ) or Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)')  
        ];
     }
     // 00026663
     public static List<AssociatedLicense__c> getActiveEmployerLicenses(Set<Id> recordIds) {
        return [
            Select Id, EmploymentStatus__c, EntityLicense__c, EmployeeLicense__c,  EmployeeLicense__r.EffectiveExpireDate__c from AssociatedLicense__c 
            WHERE EmploymentStatus__c = 'Terminated' and EmployeeLicense__c in: recordIds order by LastModifiedDate desc
        ];
     }
     // 00026663
     public static List<AssociatedLicense__c> getTerminatedEmployerLicenses(Set<Id> recordIds) {
        return [
            Select Id, EmploymentStatus__c, EmployeeLicense__r.LicenseType__r.AutoForfeitureStatus__c, 
            EntityLicense__r.Status__c, EntityLicense__c, EmployeeLicense__c, 
            EntityLicense__r.Ins_Expire_Cancel_Date__c,
            EmployeeLicense__r.EffectiveExpireDate__c from AssociatedLicense__c 
            WHERE EmploymentStatus__c = 'Terminated' and EmployeeLicense__c in: recordIds order by EndDate__c
        ];
     }

    //add for case 7697
    public static List<AssociatedLicense__c> getEmployedAssociatedLicenses(List<Id> entityLicenseIds) {
        return [
            Select Id, EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c WHERE EntityLicense__c IN: entityLicenseIds 
                AND EmploymentStatus__c = 'Employed' 
                AND EmployeeLicense__c != null 
                AND (EmployeeLicense__r.Status__c = 'C - Current, Valid & In Good Standing' 
                OR EmployeeLicense__r.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due'
                OR EmployeeLicense__r.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal'
                OR EmployeeLicense__r.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due')
                AND EmployeeLicense__r.ActiveInactive__c = 'Active'
        ];
    }  

    public static List<AssociatedLicense__c> getEmployedAssociatedLicensesForCheck(List<Id> entityLicenseIds) {
        return [
            Select Id, EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c WHERE EntityLicense__c IN: entityLicenseIds 
                AND EmploymentStatus__c = 'Employed' 
                AND EmployeeLicense__c != null 
                And ( EndDate__c > today OR EndDate__c = null)
                AND (EmployeeLicense__r.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due'
                OR EmployeeLicense__r.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due')
        ];
    }  

    public static List<AggregateResult> getEntityLicenseCount(List<String> employeeLicenseIds) {
        return [
            Select Count(Id) numCount, EmployeeLicense__c from AssociatedLicense__c
            where EmployeeLicense__c in: employeeLicenseIds and (EndDate__c > today or EndDate__c = null) 
            and EmploymentStatus__c = 'Employed' and EntityLicense__r.ActiveInactive__c <> 'Inactive'
            and (EntityLicense__r.Status__c = 'C - Current, Valid & In Good Standing' 
            OR EntityLicense__r.Status__c = 'CR - Current/Next Renewal Paid' 
            OR EntityLicense__r.Status__c = 'CP - Current Pending' 
            OR EntityLicense__r.Status__c = 'CM - Current, Valid & In Good Standing/Maint. Requirement Due'
            OR EntityLicense__r.Status__c = 'R - Valid Thru Expiration Date, Subject To Renewal'
            OR EntityLicense__r.Status__c = 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due'
            OR EntityLicense__r.Status__c = 'Z - Current & Valid, But Subject To Disciplinary Requirement' 
            OR EntityLicense__r.Status__c = 'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)' 
            OR EntityLicense__r.Status__c = 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance Requirement' )
            group by EmployeeLicense__c
        ];
    }

    public static List<AssociatedLicense__c> getPrincipalAssociatedLicenses(Set<String> licenseIds) {
        return [
            Select Id, EntityLicense__c 
            from AssociatedLicense__c 
            where EntityLicense__c in: licenseIds 
            and (
                (
                    EntityLicense__r.LicenseType__r.Name != 'RB - Entity'
                    AND (
                        (PositionStatus__c = 'P - PRINCIPAL' AND EntityLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'P - PRINCIPAL')
                        OR (PositionStatus__c = 'D - DESIGNATED' AND EntityLicense__r.LicenseType__r.TypeofPositionStatus__c  = 'D - DESIGNATED')
                    )
                )
                or (EntityLicense__r.LicenseType__r.Name = 'RB - Entity' AND PositionStatus__c = 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)')
            )
            and EmploymentStatus__c = 'Employed'];
    }
    public static List<AssociatedLicense__c> getEntityAssociatedLicenses(Set<String> licenseIds) {
        return [Select Id, EntityLicense__c, EntityLicense__r.EffectiveExpireDate__c from AssociatedLicense__c where EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed'];
    }

    public static List<AssociatedLicense__c> getSoleOwnerLicenses (List<String> licenseIds) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c where EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            and (PositionStatus__c = 'D - Designated' or Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)') 
            and EmployeeLicense__r.ActiveInactive__c = 'Active' and 
            (EmployeeLicenseType__c = 'MRC' or EmployeeLicenseType__c = 'MR' or EmployeeLicenseType__c = 'MC') ];
    }

    public static List<AssociatedLicense__c> getUnSoleOwnerLicenses (List<String> licenseIds) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c where EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            and PositionStatus__c = 'D - Designated'  
            and EmployeeLicense__r.ActiveInactive__c = 'Active' and 
            (EmployeeLicenseType__c = 'MRC' or EmployeeLicenseType__c = 'MR' or EmployeeLicenseType__c = 'MC') ];
    }

    public static List<AssociatedLicense__c> getActiveAssociatedLicenses(List<String> licenseIds) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c 
            from AssociatedLicense__c where EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            and (EmployeeLicenseType__c = 'MRC' or EmployeeLicenseType__c = 'MR' or EmployeeLicenseType__c = 'MC') ];
    }

    public static List<AssociatedLicense__c> getActiveAssociatedLicenses(List<String> licenseIds, Set<String> licenseTypes) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c 
            from AssociatedLicense__c where EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EmployeeLicenseType__c in: licenseTypes ];
    }


    public static List<AssociatedLicense__c> getAssociatedLicensesForEntityLicenseBSC(List<String> licenseIds) {
        return [Select Id, EntityLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c 
            from AssociatedLicense__c where EmployeeLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EntityLicenseStatus__c = 'R - Valid Thru Expiration Date, Subject To Renewal'
            and EmployeeLicense__r.ActiveInactive__c != 'Inactive'
            and EntityLicenseType__c = 'BSC'];
    }

    public static List<AssociatedLicense__c> getAssociatedLicensesForEmployeeLicenseIAndIds(Set<String> licenseIds, List<String> ids) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c, EntityLicense__r.LicenseType__r.Name, PositionStatus__c
            from AssociatedLicense__c where (EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            and EmployeeLicense__r.ActiveInactive__c != 'Inactive'
            and EmployeeLicenseType__c = 'I') or Id in: ids];
    }

    public static List<AssociatedLicense__c> getAssociatedLicensesForEmployeeLicenseI(List<String> licenseIds) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c , PositionStatus__c
            from AssociatedLicense__c where EntityLicense__c in: licenseIds and EmploymentStatus__c = 'Employed' and 
            (EndDate__c = null or EndDate__c = Today) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            and EmployeeLicense__r.ActiveInactive__c != 'Inactive'
            and EmployeeLicenseType__c = 'I'];
    }

    public static List<AssociatedLicense__c> getAssociatedBEO(Set<String> applicantIds) {
        return [Select Id, EmployeeLicense__r.LicenseType__r.Name, EntityLicense__c, EmployeeLicense__c 
            from AssociatedLicense__c where EntityLicense__r.Licensee__c in: applicantIds
            and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing'
            and EmployeeLicense__r.ActiveInactive__c != 'Inactive'
            and EmployeeLicenseType__c = 'BEO'];
    }

    public static List<AssociatedLicense__c> getAssociatedLicensesWWoSoleOwner(List<String> soleOwnerLicenseIds, List<String> unSoleOwnerLicenseIds, String employeeLicenseType) {
        return [Select Id, EntityLicense__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' and EmployeeLicense__r.ActiveInactive__c = 'Active' 
            and (EndDate__c > today or EndDate__c = null) and EmployeeLicense__r.Status__c = 'C - Current, Valid & In Good Standing' 
            and EmployeeLicense__r.LicenseType__r.Name =: employeeLicenseType
            and ((EntityLicense__c in: soleOwnerLicenseIds and (PositionStatus__c = 'D - Designated' or Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)')) 
            or (EntityLicense__c in: unSoleOwnerLicenseIds and PositionStatus__c = 'D - Designated'))];
    }
    public static List<AssociatedLicense__c> getAMDEntityAssociatedLicenses(List<String> licenseIds) {
        return [Select Id, EntityLicense__c, EmployeeLicense__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' 
            and (EndDate__c > today or EndDate__c = null) and EntityLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
            and EmployeeLicense__c in: licenseIds 
            and EntityLicense__r.LicenseType__r.Name in ('MD', 'DOS')];
    }
    public static List<AssociatedLicense__c> getCPAEmployeeAssociatedLicenses(List<String> licenseIds) {
        return [Select Id, EntityLicense__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' 
            and (EndDate__c > today or EndDate__c = null) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
            and EmployeeLicense__r.LicenseType__r.Name = 'CPA'
            and EmployeeLicense__r.Privilege__c = 'P - Permit to Practice'
            and EntityLicense__c in: licenseIds 
            and ((EntityLicense__r.LicenseType__r.Name = 'FPTP' and Position__c = 'CPA - CERTIFIED PUBLIC ACCOUNTANT' and PositionStatus__c = 'P - PRINCIPAL') or (
                EntityLicense__r.LicenseType__r.Name = 'FPTP - Sole Proprietor' and (Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)' or PositionStatus__c = 'P - PRINCIPAL')
            ))];
    }

    public static List<AssociatedLicense__c> getPHEmployeeAssociatedLicenses(List<String> licenseIds) {
        return [Select Id, EntityLicense__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' 
            and (EndDate__c > today or EndDate__c = null) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
            and EmployeeLicense__r.LicenseType__r.Name = 'PH'
            and EntityLicense__c in: licenseIds 
            and (Position__c = 'SO - INDIVIDUAL (SOLE OWNER) (ALL BOARDS)' or  PositionStatus__c= 'D - Designated')];
    }

    public static List<AssociatedLicense__c> getPestControlByEmployee(List<String> licenseIds, List<String> relatedLicenseTypes) {
        return [Select Id, EntityLicense__c, EmployeeLicense__c, PositionStatus__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' 
            and (EndDate__c > today or EndDate__c = null) and EntityLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
            and EntityLicense__r.LicenseType__r.Name in: relatedLicenseTypes
            and EmployeeLicense__c in: licenseIds and EntityActiveInactive__c = 'Active'];
    }

    public static List<AssociatedLicense__c> getPestControlByEntity(List<String> licenseIds, List<String> relatedLicenseTypes) {
        return [Select Id, EntityLicense__c, EmployeeLicense__c, PositionStatus__c from AssociatedLicense__c where EmploymentStatus__c = 'Employed' 
            and (EndDate__c > today or EndDate__c = null) and EmployeeLicenseStatus__c = 'C - Current, Valid & In Good Standing' 
            and EmployeeLicense__r.LicenseType__r.Name in: relatedLicenseTypes
            and EntityLicense__c in: licenseIds and EmployeeActiveInactive__c = 'Active'];
    }

    public static List<AssociatedLicense__c> getPDGByEntity(List<String> licenseIds, List<String> relatedLicenseTypes, String extraConditions) {
        String query = 'Select Id, EntityLicense__c, EntityLicenseType__c, EntityLicenseStatus__c, EmployeeLicense__c, EmployeeLicenseStatus__c, PositionStatus__c from AssociatedLicense__c where EmploymentStatus__c = \'Employed\' '
            + ' and (EndDate__c > today or EndDate__c = null) '
            + ' and EntityLicense__c in: licenseIds and EmployeeActiveInactive__c = \'Active\' ';
        if(relatedLicenseTypes != null ) {
            query += ' and EmployeeLicense__r.LicenseType__r.Name in: relatedLicenseTypes ';
        }
            
        query += extraConditions;
        return Database.query(query);
    }

    public static List<AssociatedLicense__c> getPDGByEmployee(List<String> licenseIds, List<String> relatedLicenseTypes, String extraConditions) {
        String query = 'Select Id, EntityLicense__c, EntityLicenseType__c, EntityLicenseStatus__c, EmployeeLicense__c, EmployeeLicenseStatus__c, PositionStatus__c from AssociatedLicense__c where EmploymentStatus__c = \'Employed\' '
           + ' and (EndDate__c > today or EndDate__c = null) '
           + ' and EmployeeLicense__c in: licenseIds and EntityActiveInactive__c = \'Active\' ';
        if(relatedLicenseTypes != null) {
            query += ' and EntityLicense__r.LicenseType__r.Name in: relatedLicenseTypes '; 
        }
        query += extraConditions;
        return Database.query(query);
    }

    public static List<AssociatedLicense__c> getAssociatedLicensesByEntity(List<String> licenseIds, List<String> relatedLicenseTypes, String extraConditions) {
        String query = 'Select Id, EntityLicense__c, EmployeeLicense__c, PositionStatus__c from AssociatedLicense__c where EmploymentStatus__c = \'Employed\' '
            + ' and (EndDate__c > today or EndDate__c = null) '
            + ' and EntityLicense__c in: licenseIds and EmployeeActiveInactive__c = \'Active\' ';
        if(relatedLicenseTypes != null ) {
            query += ' and EmployeeLicense__r.LicenseType__r.Name in: relatedLicenseTypes ';
        }
            
        query += extraConditions;
        return Database.query(query);
    }

    public static List<AssociatedLicense__c> getAssociatedLicensesByEmployee(List<String> licenseIds, List<String> relatedLicenseTypes, String extraConditions) {
        String query = 'Select Id, EntityLicense__c, EmployeeLicense__c, PositionStatus__c from AssociatedLicense__c where EmploymentStatus__c = \'Employed\' '
            + ' and (EndDate__c > today or EndDate__c = null) '
            + ' and EmployeeLicense__c in: licenseIds and EmployeeActiveInactive__c = \'Active\' ';
        if(relatedLicenseTypes != null ) {
            query += ' and EmployeeLicense__r.LicenseType__r.Name in: relatedLicenseTypes ';
        }
            
        query += extraConditions;
        return Database.query(query);
    }

    public static List<AssociatedLicense__c> getAssociatedLicensesForEmployerAddressUpdate(String extraConditions) {
        String query = 'Select Id, EmployeeLicense__c, EntityLicense__c, EffectiveDate__c from AssociatedLicense__c ';
        if(extraConditions != null) query += extraConditions;
        return Database.query(query);
     }
}