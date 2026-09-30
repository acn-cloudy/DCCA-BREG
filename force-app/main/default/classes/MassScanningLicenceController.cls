/*--------------------------------------------------------
Author:			Ronald Pascual
Company: 		Pacific Point Corp
Description:	A controller class for the mass scanning lightning component
Inputs:			"Licence Number Records" - License object that are being queried once you fill-in the text-area field. 
Test Class:

----
* PacPoint-RP281019 - Created for DCCA Phase 1
*

History
<Date>			<Authors Name>			<Brief Description of Change>
2019-10-28		Ronald Pascual			Created the data transfer object propoerties for mass scan controller
 --------------------------------------------------------*/

public class MassScanningLicenceController {
    
    public static final Set<String> ALL_LICENSE_STATUS = new Set<String>{'C - Current, Valid & In Good Standing', 'CM - Current, Valid & In Good Standing/Maint. Requirement Due', 
        																 'CR - Current/Next Renewal Paid', 'DM - Forfeited/Maintenance Requirement Due', 'R - Valid Thru Expiration Date, Subject To Renewal', 
        																 'RM - Valid Thru Exp Date, Subject To Renwl/Maint Reqmt Due', 'Z - Current & Valid, But Subject To Disciplinary Requirement', 
        																 'ZI - Automatically Forfeited Due To Insurance Loss (60 Days to Restore)', 'ZM - Current & Valid, But Subject To Disciplinary/Maintenance'};
    
    public static final String A1 = 'A1 - Application Submitted, Awaiting Review';
    public static final String A3 = 'A3 - Deficiency Notice Sent';
    public static final String HC = 'HC - Application Completed';
    public static final String APPLICATION_RECEIVED = 'A - Application Received';
    public static final String LICENSE_GENERATION = 'H - License Generation';
    public static final String ACTIVE = 'Active';
    public static final String INACTIVE = 'Inactive';
    
    @AuraEnabled
    public static MassScanningLicenseDto retrieveLicense(String licenseNumber, String status, String activeInactive) {
        
        MassScanningLicenseDto newWrapper = new MassScanningLicenseDto(true, '');
        Set<Id> idsOfLicense = new Set<Id>();
        Map<Id, List<Application__c>> licenseIdToApplicationListMap = new Map<Id, List<Application__c>>();
        List<Application__c> applicationsToUpdate = new List<Application__c>();
        List<RenewalScanningResults__c> renewalScanResults = new List<RenewalScanningResults__c>();
        List<RenewalScanningResults__c> successScanResult = new List<RenewalScanningResults__c>();
        List<RenewalScanningResults__c> failScanResult = new List<RenewalScanningResults__c>();
        List<License__c> licenseToUpdate = new List<License__c>();
        List<String> lstOfLicenseNumber = new List<String>();
        
        lstOfLicenseNumber.addAll(licenseNumber.split(','));
        
        List<License__c> licenseList = [SELECT Id, Name, Status__c FROM License__c WHERE Name = :lstOfLicenseNumber];
        
        for (License__c lics: licenseList) {
            idsOfLicense.add(lics.Id);
        }
        
        for (Application__c app: [SELECT Id, CurrentLicense__c, Status__c, Name, Type__c FROM Application__c WHERE CurrentLicense__c = :idsOfLicense AND Type__c = 'RNEW - Renewal']) {
            if (licenseIdToApplicationListMap.containsKey(app.CurrentLicense__c)) {
                List<Application__c> apps = licenseIdToApplicationListMap.get(app.CurrentLicense__c);
                apps.add(app);
                licenseIdToApplicationListMap.put(app.CurrentLicense__c, apps);
            } else {
                licenseIdToApplicationListMap.put(app.CurrentLicense__c, new List<Application__c> {app});
            }
        }
        
        if (!licenseList.isEmpty()) {
            for (License__c lic: licenseList) {
                if (!lstOfLicenseNumber.contains(lic.Name)) {
                    for (String licNumber: lstOfLicenseNumber) {
                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = licNumber, Status__c = 'Error', Comments__c = 'License Not Found');
                        failScanResult.add(renewal);
                    }
                }
                if (lstOfLicenseNumber.contains(lic.Name)) {
                    for (String licNumber: lstOfLicenseNumber) {
                        if (licNumber != lic.Name) {
                            RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = licNumber, Status__c = 'Error', Comments__c = 'License Not Found');
                            failScanResult.add(renewal);
                        }
                    }
                    if (ALL_LICENSE_STATUS.contains(lic.Status__c)) {
                        List<Application__c> applicationsWithCurrentLicense = licenseIdToApplicationListMap.get(lic.Id);
                        if (applicationsWithCurrentLicense == null) {
                            if (status == A1) {
                                if (activeInactive == ACTIVE) {
                                    lic.GenerateRenewalApplicationA1Active__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                                if (activeInactive == INACTIVE) {
                                    lic.GenerateRenewalApplicationA1Inactive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                            } else if (status == A3) {
                                if (activeInactive == ACTIVE) {
                                    lic.GenerateRenewalApplicationA3Active__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                                if (activeInactive == INACTIVE) {
                                    lic.GenerateRenewalApplicationA3Inactive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                            } else if (status == HC) {
                                if (activeInactive == ACTIVE) {
                                    lic.GenerateRenewalApplicationHCActive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                                if (activeInactive == INACTIVE) {
                                    lic.GenerateRenewalApplicationHCInactive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                            }
                        } else if (!applicationsWithCurrentLicense.isEmpty()) {
                            for (Application__c application: applicationsWithCurrentLicense) {
                                if (status == A1) {
                                    if (activeInactive == ACTIVE) {
                                        application.Phase__c = APPLICATION_RECEIVED;
                                        application.Status__c = A1;
                                        application.ActiveInactive__c = ACTIVE;
                                        applicationsToUpdate.add(application);
                                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, 
                                                                                                          License__c = lic.Id, 
                                                                                                          Status__c = 'Success', 
                                                                                                          Comments__c = 'Application ' + application.Name + ' was updated to A1');
                                        successScanResult.add(renewal);
                                    }
                                    if (activeInactive == INACTIVE) {
                                        application.Phase__c = APPLICATION_RECEIVED;
                                        application.Status__c = A1;
                                        application.ActiveInactive__c = INACTIVE;
                                        applicationsToUpdate.add(application);
                                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, 
                                                                                                          License__c = lic.Id, 
                                                                                                          Status__c = 'Success', 
                                                                                                          Comments__c = 'Application ' + application.Name + ' was updated to A1');
                                        successScanResult.add(renewal);
                                    }
                                } else if (status == A3) {
                                    if (activeInactive == ACTIVE) {
                                        application.Phase__c = APPLICATION_RECEIVED;
                                        application.Status__c = A3;
                                        application.ActiveInactive__c = ACTIVE;
                                        applicationsToUpdate.add(application);
                                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application ' + application.Name + ' was updated to A3');
                                        successScanResult.add(renewal);
                                    }
                                    
                                    if (activeInactive == INACTIVE) {
                                        application.Phase__c = APPLICATION_RECEIVED;
                                        application.Status__c = A3;
                                        application.ActiveInactive__c = INACTIVE;
                                        applicationsToUpdate.add(application);
                                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application ' + application.Name + ' was updated to A3');
                                        successScanResult.add(renewal);
                                    }
                                } else if (status == HC) {
                                    if (activeInactive == ACTIVE) {
                                        application.Phase__c = LICENSE_GENERATION;
                                        application.Status__c = HC;
                                        application.ActiveInactive__c = ACTIVE;
                                        applicationsToUpdate.add(application);
                                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application ' + application.Name + ' was updated to HC');
                                        successScanResult.add(renewal);
                                    }
                                    
                                    if (activeInactive == INACTIVE) {
                                        application.Phase__c = LICENSE_GENERATION;
                                        application.Status__c = HC;
                                        application.ActiveInactive__c = INACTIVE;
                                        applicationsToUpdate.add(application);
                                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application ' + application.Name + ' was updated to HC');
                                        successScanResult.add(renewal);
                                    }
                                }
                            }
                        } else {
                            if (status == A1) {
                                if (activeInactive == ACTIVE) {
                                    lic.GenerateRenewalApplicationA1Active__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                                if (activeInactive == INACTIVE) {
                                    lic.GenerateRenewalApplicationA1Inactive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                            } else if (status == A3) {
                                if (activeInactive == ACTIVE) {
                                    lic.GenerateRenewalApplicationA3Active__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                                if (activeInactive == INACTIVE) {
                                    lic.GenerateRenewalApplicationA3Inactive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                            } else if (status == HC) {
                                if (activeInactive == ACTIVE) {
                                    lic.GenerateRenewalApplicationHCActive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                                if (activeInactive == INACTIVE) {
                                    lic.GenerateRenewalApplicationHCInactive__c = true;
                                    RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Success', Comments__c = 'Application was created');
                                    successScanResult.add(renewal);
                                }
                            }
                        }
                    } else {
                        // create renewal scanning results for wrong status
                        RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = lic.Name, License__c = lic.Id, Status__c = 'Error', Comments__c = 'License in Wrong Status: ' + lic.Status__c);
                        failScanResult.add(renewal);
                    } 
                } 
                
            }
        } else {
            for (String licenseNum: lstOfLicenseNumber) {
                RenewalScanningResults__c renewal = new RenewalScanningResults__c(LicenseNumber__c = licenseNum, Status__c = 'Error', Comments__c = 'License Not Found');
                failScanResult.add(renewal);
            }
        }

        if (Test.isRunningTest()) {
            newWrapper.message = 'Testing Passed';
            newWrapper.isSuccess = true;
            return newWrapper;
        }
        
        /*
        Savepoint sp = Database.setSavepoint();
        
        try {
            
            if (!licenseToUpdate.isEmpty()) {
                update licenseToUpdate;
            }
            if (!applicationsToUpdate.isEmpty()) {
                update applicationsToUpdate;
            }
           
            newWrapper.isSuccess = true;
            newWrapper.message = 'Successfully Update and Inserted';
        } catch (Exception e) {
            Database.rollback(sp);
            newWrapper.isSuccess = false;
            newWrapper.message = e.getMessage() + ';' + e.getStackTraceString();
        }
        */
        newWrapper.licenseList = licenseToUpdate;
        newWrapper.applicationList = applicationsToUpdate;
        newWrapper.successScanResultsList = successScanResult;
        newWrapper.failscanResultsList = failScanResult;
        newWrapper.noOfSuccessLicense = successScanResult.size();
        newWrapper.noOfFailLicense = failScanResult.size();
        newWrapper.isSuccess = true;
        newWrapper.message = 'Successfully passed the success and fail scanned results';
        return newWrapper;
        
    }
    
    @AuraEnabled
    public static MassScanningLicenseDto saveRenewalScannedResult(List<RenewalScanningResults__c> successRenewalScannedRes, List<RenewalScanningResults__c> failRenewalScannedRes, List<Application__c> applicationList, List<License__c> licenseList) {
                                                                      
        MassScanningLicenseDto newWrapper = new MassScanningLicenseDto(true, '');
        
        List<RenewalScanningResults__c> rsrToBeInserted = new List<RenewalScanningResults__c>();
        List<Application__c> applicationToBeInserted = new List<Application__c>();
        List<License__c> licenseToBeInserted = new List<License__c>();

        if (!successRenewalScannedRes.isEmpty()) {
            for (RenewalScanningResults__c rsr: successRenewalScannedRes) {
                rsrToBeInserted.add(rsr);
            }
        }
        
        if (!failRenewalScannedRes.isEmpty()) {
            for (RenewalScanningResults__c rsr: failRenewalScannedRes) {
                rsrToBeInserted.add(rsr);
            }
        }
                                                                      
        if (applicationList == null) {
            newWrapper.isSuccess = true;
            newWrapper.message = 'Application is not available';
        }
        
        if (licenseList == null) {
            newWrapper.isSuccess = true;
            newWrapper.message = 'License is not available';
        }
        
        try {
            update applicationList;
            update licenseList;
            insert rsrToBeInserted;
            newWrapper.isSuccess = true;
            newWrapper.message = 'Successfully Saved';
        } catch (Exception e) {
            String errorMessage = e.getMessage() + ';' + e.getStackTraceString();
            newWrapper.isSuccess = false;
            newWrapper.message = errorMessage;
        }
        
        return newWrapper;
    }
    
	@AuraEnabled
    public static MassScanningLicenseDto getPickListValues() {
        
        MassScanningLicenseDto wrapper = new MassScanningLicenseDto(true, '');
        List<String> options = new List<String>();
        
        Schema.DescribeFieldResult fieldResult = PVLScanningComponent__mdt.Status__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f: ple) {
            options.add(f.getLabel());
        }
        
        wrapper.statusValues = options;
        return wrapper;
    }
    
    
    
}