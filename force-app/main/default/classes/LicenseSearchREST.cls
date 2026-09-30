/*
 * ___________________________________________________________________________________
 * REST API for license Search
 * Covered by:
 * __________________________________________________________________________________
 * PacPoint-CL11012020 - Created for PVL Phase 1
 * __________________________________________________________________________________
 * Initial implementation
 * 
 * @author chris.zhuang@pacificpointcorp.com
 * 
 * @created 11/01/2020
 * __________________________________________________________________________________
 */
@RestResource(urlMapping='/licenseSearch')
global without sharing class LicenseSearchREST {
    @HttpPost
    global static void doLicenseSearch() {
        RestRequest req = null;
        RestResponse res = null;
        
        try {
            String postParams = '';
            
            RestContext.response.addHeader('Content-Type', 'application/json');
            req = RestContext.request;
            res = RestContext.response;
            
            postParams = req.requestBody.toString();
            JSONRequest jObject = (JSONRequest) System.JSON.deserialize(postParams, JSONRequest.class);
            
            //default recordSize to 10
            Integer recordSize = 10;
            License_REST_API_Setting__mdt apiSetting = new License_REST_API_Setting__mdt();
            List<License_REST_API_Setting__mdt> apiSettings = [SELECT Id, Login_User_Name__c, Max_Record_Size__c
                                                               FROM License_REST_API_Setting__mdt 
                                                               WHERE Login_User_Name__c =: UserInfo.getUserName()];

            if (apiSettings.size() > 0) {
                apiSetting = apiSettings[0];

                if (apiSetting.Max_Record_Size__c != null) {
                    recordSize = Integer.valueOf(apiSetting.Max_Record_Size__c);
                }
            } else {
                if (!Test.isRunningTest()) {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 401, "Message": "You don\'t have permission to access the services."}');
                    return;
                }
            }

            //Limitation
            //if (apiSetting.API_Consumed__c != null && apiSetting.API_Limit__c != null 
            //    && apiSetting.API_Consumed__c > apiSetting.API_Limit__c) {
            //    return '{"Status": "Error", "StatusCode": 402, "Message": "You have reach your daily API limits, please contact DCCA administrator."}';
            //}

            if (String.isBlank(jObject.SearchCriteria) || jObject.SearchType == null) {
                res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 202, "Message": "The SearchCriteria and SearchType cannot be NULL."}');
                return;
            }
            
            //get profile name
            String profileName = '';
            profileName = [select name from Profile where id =: UserInfo.getProfileId()].Name;
                 
            List<License__c> li_l = new List<License__c>();
            if (jObject.SearchType == 1) {
                //1. Searching License Data by License Number (Exact)
                li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                        TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                        OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                        Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                        BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                        BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                        MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                        Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                        LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                        FROM License__c 
                        WHERE Name =: jObject.SearchCriteria];
                
                //When searching by License.Name, currently it is an exact match search only, which means they have to append the -0 to the end. For example, for license number "RN-1234-0", allow for searching by "RN-1234" to return the license RN-1234-0
                if (li_l.size() == 0) {
                    String nameString = '';
                    List<String> splitString = jObject.SearchCriteria.split('-');
                    if (splitString.size() > 1) {
                        nameString = splitString[0] + '-' + splitString[1];

                        li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                                TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                                OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                                Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                                BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                                BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                                MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                                Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                                LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                                FROM License__c 
                                WHERE Name LIKE: nameString + '%'];
                    }
                }
                
                if (li_l.size() > 0) {
                    JSONResponse response = new JSONResponse('Success', 200, 'License(s) have been found.', new List<LicenseWrapper>());
                    response.Licenses.addAll(generateLicenseWrapper(li_l));
                    response.NumberOfLicenses = li_l.size();
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    return;
                } else {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 201, "Message": "License(s) cannot be found."}');
                    return;
                }
            } else if (jObject.SearchType == 6) {
                //6. Searching License Data by License Number (Exact)
                li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                        TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                        OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                        Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                        BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                        BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                        MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                        Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                        LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                        FROM License__c 
                        WHERE Name =: jObject.SearchCriteria];
                
                //When searching by License.Name, currently it is an exact match search only, which means they have to append the -0 to the end. For example, for license number "RN-1234-0", allow for searching by "RN-1234" to return the license RN-1234-0
                if (li_l.size() == 0) {
                    String nameString = '';
                    List<String> splitString = jObject.SearchCriteria.split('-');
                    if (splitString.size() > 1) {
                        nameString = splitString[0] + '-' + splitString[1];

                        li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                                TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                                OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                                Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                                BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                                BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                                MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                                Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                                LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                                FROM License__c 
                                WHERE Name LIKE: nameString + '-%'];
                    }
                }
                
                if (li_l.size() > 0) {
                    JSONResponse response = new JSONResponse('Success', 200, 'License(s) have been found.', new List<LicenseWrapper>());
                    response.Licenses.addAll(generateLicenseWrapper(li_l));
                    response.NumberOfLicenses = li_l.size();
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    return;
                } else {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 201, "Message": "License(s) cannot be found."}');
                    return;
                }
            } else if (jObject.SearchType == 2) {
                //2. Searching License Data by Licensee’s Name (Fuzzy search with minimum length of 3 characters)
                if (jObject.SearchCriteria.length() < 3) {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 203, "Message": "The search criteria needs to be at least 3 characters."}');
                    return;
                }

                li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                        TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                        OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                        Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                        BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                        BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                        MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                        Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                        LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                        FROM License__c 
                        WHERE Licensee__r.Name LIKE: '%'+jObject.SearchCriteria +'%'
                        LIMIT :recordSize];
                if (li_l.size() > 0) {
                    JSONResponse response = new JSONResponse('Success', 200, 'License(s) have been found.', new List<LicenseWrapper>());
                    response.Licenses.addAll(generateLicenseWrapper(li_l));
                    response.NumberOfLicenses = li_l.size();
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    return;
                } else {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 201, "Message": "License(s) cannot be found."}');
                    return;
                }
            } else if (jObject.SearchType == 3) {
                //3. Searching License Data by License Name (Fuzzy search with minimum length of 3 characters)
                if (jObject.SearchCriteria.length() < 3) {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 203, "Message": "The search criteria needs to be at least 3 characters."}');
                    return;
                }

                li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                        TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                        OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                        Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                        BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                        BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                        MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                        Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                        LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                        FROM License__c 
                        WHERE LicenseName__c LIKE: '%'+jObject.SearchCriteria +'%'
                        LIMIT :recordSize];
                if (li_l.size() > 0) {
                    JSONResponse response = new JSONResponse('Success', 200, 'License(s) have been found.', new List<LicenseWrapper>());
                    response.Licenses.addAll(generateLicenseWrapper(li_l));
                    response.NumberOfLicenses = li_l.size();
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    return;
                } else {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 201, "Message": "License(s) cannot be found."}');
                    return;
                }
            } else if (jObject.SearchType == 4 && profileName == 'License RICO API Only') {
                //4. Allow for searching by License__c.Licensee__r.BPID__c exact match. Note, this should only be available to the RICO API User
                if (jObject.SearchCriteria.length() < 3) {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 203, "Message": "The search criteria needs to be at least 3 characters."}');
                    return;
                }

                li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                        TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                        OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                        Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                        BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                        BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                        MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                        Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                        LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                        FROM License__c 
                        WHERE Licensee__r.BPID__c =: jObject.SearchCriteria
                        LIMIT :recordSize];
                if (li_l.size() > 0) {
                    JSONResponse response = new JSONResponse('Success', 200, 'License(s) have been found.', new List<LicenseWrapper>());
                    response.Licenses.addAll(generateLicenseWrapper(li_l));
                    response.NumberOfLicenses = li_l.size();
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    return;
                } else {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 201, "Message": "License(s) cannot be found."}');
                    return;
                }
            } else if (jObject.SearchType == 5 && profileName == 'License RICO API Only') {
                //5. search by LastName, FirstName
                if (jObject.SearchCriteria.length() < 3) {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 203, "Message": "The search criteria needs to be at least 3 characters."}');
                    return;
                }

                String lastName = '';
                String firstName = '';
                List<String> searchString = jObject.SearchCriteria.split(' ');
                if (searchString.size() > 1) {
                    lastName = searchString[0];
                    if (searchString.size() > 2) {
                        searchString.remove(0);
                        for (Integer i=0; i < searchString.size();i++) {
                            firstName += searchString[i] + ' ';
                        }
                    } else {
                        firstName = searchString[1];
                    }
                } else {
                    lastName = searchString[0];
                }
                
                li_l = [SELECT Id, Name, LicenseType__r.Name, LicenseType__r.LicenseType__c, Licensee__r.Name, SoleOwner__c, 
                        TypeOfEntity__c, Status__c, ActiveInactive__c, ClassPrefix__c, LicenseType__r.BoardProgram__r.Name, LicenseName__c, 
                        OriginalDateofLicensure__c, EffectiveExpireDate__c, ForfeitureDate__c, MethodofLicensure__c, ExemptfromRenewal__c, 
                        Privilege__c, Restrictions__c, ConditionalLicense__c, MultiDependency__c, Dual__c, Remarks__c, ContinuingEducation__c, 
                        BusinessAddressEffectiveDate__c, BusinessAddressRestricted__c, BusinessCity__c, BusinessCode__c, BusinessCountry__c, 
                        BusinessState__c, BusinessStreet__c, BusinessZipCode__c, MailingAddressEffectiveDate__c, MailingCity__c, MailingCountry__c, 
                        MailingState__c, MailingStreet__c, MailingZipCode__c, LicensePhone__c, Licensee__r.Phone, Licensee__r.PersonEmail, 
                        Licensee__r.BusinessEmail__c, Licensee__r.MobilePhone__c, Licensee__r.BPID__c, SoleProp__c, LastModifiedDate, 
                        LicenseNameEffectiveDate__c, CumulativeExperience__c, TempLicenseExtensions__c, LossofBond__c, DisciplinaryAction__c
                        FROM License__c 
                        WHERE Licensee__r.LastName =: lastName
                        AND Licensee__r.FirstName LIKE: firstName + '%'
                        LIMIT :recordSize];
                if (li_l.size() > 0) {
                    JSONResponse response = new JSONResponse('Success', 200, 'License(s) have been found.', new List<LicenseWrapper>());
                    response.Licenses.addAll(generateLicenseWrapper(li_l));
                    response.NumberOfLicenses = li_l.size();
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    return;
                } else {
                    res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 201, "Message": "License(s) cannot be found."}');
                    return;
                }
            } else {
                res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 204, "Message": "Invalid SearchType."}');
                return;
            }
        } catch (Exception ex) {
            res.responseBody = Blob.valueOf('{"Status": "Error", "StatusCode": 400, "Message": "' + ex.getMessage() + '"}');
        }
    }
    
    public static List<LicenseWrapper> generateLicenseWrapper (List<License__c> li_l) {
        List<LicenseWrapper> lWrapper_l = new List<LicenseWrapper>();
        Set<Id> licenseId_S = new Set<Id>();
        if (li_l.size() == 0) {
            return null;
        }
        
        //get profile name
        String profileName = '';
        profileName = [select name from Profile where id =: UserInfo.getProfileId()].Name;
                        
        for (License__c li : li_l) {  
            LicenseWrapper lWrapper = new LicenseWrapper(); 
            lWrapper.LicenseId = li.Id;
            lWrapper.LicenseNumber = li.Name;
            
            if (profileName == 'License RICO API Only') {
                lWrapper.BPID = li.Licensee__r.BPID__c;
            }
            
            lWrapper.LicenseTypeCode = li.LicenseType__r.Name;
            lWrapper.LicenseTypeDescription = li.LicenseType__r.LicenseType__c;
            lWrapper.LicenseeName = li.Licensee__r.Name;
            lWrapper.SoleOwner = li.SoleOwner__c;
            lWrapper.TypeOfEntity = li.TypeOfEntity__c;
            lWrapper.Status = li.Status__c;
            lWrapper.ActiveInactive = li.ActiveInactive__c;
            lWrapper.ClassPrefix = li.ClassPrefix__c;
            lWrapper.BoardProgramName = li.LicenseType__r.BoardProgram__r.Name;
            lWrapper.LicenseName = li.LicenseName__c;
            lWrapper.OriginalDateofLicensure = li.OriginalDateofLicensure__c;
            lWrapper.EffectiveExpireDate = li.EffectiveExpireDate__c;
            lWrapper.ForfeitureDate = li.ForfeitureDate__c;
            lWrapper.MethodofLicensure = li.MethodofLicensure__c;
            lWrapper.ExemptfromRenewal = li.ExemptfromRenewal__c;
            lWrapper.Privilege = li.Privilege__c;
            lWrapper.Restrictions = li.Restrictions__c;
            lWrapper.ConditionalLicense = li.ConditionalLicense__c;
            lWrapper.MultiDependency = li.MultiDependency__c;
            lWrapper.Dual = li.Dual__c;
            lWrapper.Remarks = li.Remarks__c;
            lWrapper.ContinuingEducation = li.ContinuingEducation__c;
            lWrapper.BusinessAddressEffectiveDate = li.BusinessAddressEffectiveDate__c;
            lWrapper.BusinessAddressRestricted = li.BusinessAddressRestricted__c;
            lWrapper.BusinessCity = li.BusinessCity__c;
            lWrapper.BusinessCode = li.BusinessCode__c;
            lWrapper.BusinessCountry = li.BusinessCountry__c;
            lWrapper.BusinessState = li.BusinessState__c;
            lWrapper.BusinessStreet = li.BusinessStreet__c;
            lWrapper.BusinessZipCode = li.BusinessZipCode__c;
            lWrapper.MailingAddressEffectiveDate = li.MailingAddressEffectiveDate__c;
            lWrapper.MailingCity = li.MailingCity__c;
            lWrapper.MailingCountry = li.MailingCountry__c;
            lWrapper.MailingState = li.MailingState__c;
            lWrapper.MailingStreet = li.MailingStreet__c;
            lWrapper.MailingZipCode = li.MailingZipCode__c;
            lWrapper.LicensePhone = li.LicensePhone__c;
            lWrapper.DisciplinaryAction = li.DisciplinaryAction__c;
  
            if (profileName == 'License RICO API Only') {
                lWrapper.SoleProp = li.SoleProp__c;
                lWrapper.LastModifiedDate = li.LastModifiedDate;
                lWrapper.LicenseNameEffectiveDate = li.LicenseNameEffectiveDate__c;
                lWrapper.CumulativeExperience = li.CumulativeExperience__c;
                lWrapper.TempLicenseExtensions = li.TempLicenseExtensions__c;
                lWrapper.LossofBond = li.LossofBond__c;
            }

            lWrapper.Account = new AccountWrapper();
            lWrapper.EmployeeLicenses = new List<EmployeeLicenseWrapper>();
            lWrapper.EntityLicenses = new List<EntityLicenseWrapper>();
            lWrapper.LicenseClassifications = new List<LicenseClassificationWrapper>();
            lWrapper.LicenseNames = new List<LicenseNameWrapper>();
            lWrapper.InsuranceBonds = new List<InsuranceBondWrapper>();
            lWrapper.LicenseHistories = new List<LicenseHistoryWrapper>();
            lWrapper.LicenseConditions = new List<LicenseConditionsWrapper>();
            lWrapper.EarnedContinuingEducations = new List<EarnedContinuingEducationWrapper>();
            
            //Account
            AccountWrapper aWrapper = new AccountWrapper();
            aWrapper.Name = li.Licensee__r.Name;
            aWrapper.Phone = li.Licensee__r.Phone;
            
            if (profileName == 'License RICO API Only') {
                aWrapper.BPID = li.Licensee__r.BPID__c;
            }
            
            aWrapper.PersonalEmail = li.Licensee__r.PersonEmail;
            aWrapper.BusinessEmail = li.Licensee__r.BusinessEmail__c;
            aWrapper.MobilePhone = li.Licensee__r.MobilePhone__c;
            lWrapper.Account = aWrapper;
            licenseId_S.add(li.Id);
            lWrapper_l.add(lWrapper);
        }

        //EmployeeLicense (Only Active)
        Map<Id, List<EmployeeLicenseWrapper>> employeeLicense_M = new Map<Id, List<EmployeeLicenseWrapper>>();
        List<AssociatedLicense__c> al_l1 = [SELECT Id, Position__c, PositionStatus__c, EmployeeLicense__r.Licensee__r.Name,
                                                   EmployeeLicense__r.Name, Dual__c, EffectiveDate__c, EndDate__c, EmploymentExpireDate__c,
                                                   EntityLicense__c
                                            FROM AssociatedLicense__c 
                                            WHERE EntityLicense__c IN: licenseId_S 
                                            AND EmploymentStatus__c = 'Employed'];
        for (AssociatedLicense__c al : al_l1) {
            EmployeeLicenseWrapper elWrapper = new EmployeeLicenseWrapper();
            elWrapper.Position = al.Position__c;
            elWrapper.PositionStatus = al.PositionStatus__c;
            elWrapper.EmployeeLicenseeName = al.EmployeeLicense__r.Licensee__r.Name;
            elWrapper.EmployeeLicense = al.EmployeeLicense__r.Name;
            elWrapper.Dual = al.Dual__c;
            elWrapper.EffectiveDate = al.EffectiveDate__c;
            elWrapper.EndDate = al.EndDate__c;
            elWrapper.EmploymentExpireDate = al.EmploymentExpireDate__c;

            if (employeeLicense_M.containsKey(al.EntityLicense__c)) {
                employeeLicense_M.get(al.EntityLicense__c).add(elWrapper);
            } else {
                employeeLicense_M.put(al.EntityLicense__c, new List<EmployeeLicenseWrapper>{elWrapper});
            }
        }

        //EntityLicense (Only Active)
        Map<Id, List<EntityLicenseWrapper>> entityLicense_M = new Map<Id, List<EntityLicenseWrapper>>();
        List<AssociatedLicense__c> al_l2 = [SELECT Id, Position__c, PositionStatus__c, EntityLicense__r.Name, 
                                                   EntityLicense__r.Licensee__r.Name, Dual__c, EffectiveDate__c, 
                                                   EndDate__c, EmploymentExpireDate__c, EmployeeLicense__c
                                            FROM AssociatedLicense__c 
                                            WHERE EmployeeLicense__c IN: licenseId_S
                                            AND EmploymentStatus__c = 'Employed'];
        for (AssociatedLicense__c al : al_l2) {                        
            EntityLicenseWrapper elWrapper = new EntityLicenseWrapper();
            elWrapper.Position = al.Position__c;
            elWrapper.PositionStatus = al.PositionStatus__c;
            elWrapper.EntityLicenseeName = al.EntityLicense__r.Licensee__r.Name;
            elWrapper.EntityLicense = al.EntityLicense__r.Name;
            elWrapper.Dual = al.Dual__c;
            elWrapper.EffectiveDate = al.EffectiveDate__c;
            elWrapper.EndDate = al.EndDate__c;
            elWrapper.EmploymentExpireDate = al.EmploymentExpireDate__c;

            if (entityLicense_M.containsKey(al.EmployeeLicense__c)) {
                entityLicense_M.get(al.EmployeeLicense__c).add(elWrapper);
            } else {
                entityLicense_M.put(al.EmployeeLicense__c, new List<EntityLicenseWrapper>{elWrapper});
            }
        }

        //LicenseClassification
        Map<Id, List<LicenseClassificationWrapper>> licenseClassification_M = new Map<Id, List<LicenseClassificationWrapper>>();
        List<LicenseClassification__c> lc_l = [SELECT Id, ClassificationName__c, EffectiveStartDate__c, 
                                                      EndDate__c, RestrictedClass__c, Status__c, License__c
                                               FROM LicenseClassification__c 
                                               WHERE License__c IN: licenseId_S];
        for (LicenseClassification__c lc : lc_l) {   
            LicenseClassificationWrapper lcWrapper = new LicenseClassificationWrapper();
            lcWrapper.ClassificationName = lc.ClassificationName__c;
            lcWrapper.EffectiveStartDate = lc.EffectiveStartDate__c;
            lcWrapper.EndDate = lc.EndDate__c;
            lcWrapper.RestrictedClass = lc.RestrictedClass__c;
            lcWrapper.Status = lc.Status__c;

            if (licenseClassification_M.containsKey(lc.License__c)) {
                licenseClassification_M.get(lc.License__c).add(lcWrapper);
            } else {
                licenseClassification_M.put(lc.License__c, new List<LicenseClassificationWrapper>{lcWrapper});
            }
        }

        //LicenseName
        Map<Id, List<LicenseNameWrapper>> licenseName_M = new Map<Id, List<LicenseNameWrapper>>();
        List<LicenseName__c> ln_l = [SELECT Id, NameType__c, EffectiveDate__c, TermDate__c, Name__c, License__c
                                     FROM LicenseName__c 
                                     WHERE License__c IN: licenseId_S];
        for (LicenseName__c ln : ln_l) {   
            LicenseNameWrapper lnWrapper = new LicenseNameWrapper();
            lnWrapper.NameType = ln.NameType__c;
            lnWrapper.EffectiveDate = ln.EffectiveDate__c;
            lnWrapper.TermDate = ln.TermDate__c;
            lnWrapper.Name = ln.Name__c;

            if (licenseName_M.containsKey(ln.License__c)) {
                licenseName_M.get(ln.License__c).add(lnWrapper);
            } else {
                licenseName_M.put(ln.License__c, new List<LicenseNameWrapper>{lnWrapper});
            }
        }

        //InsuranceBond (Only Active)
        Map<Id, List<InsuranceBondWrapper>> insuranceBond_M = new Map<Id, List<InsuranceBondWrapper>>();
        List<InsuranceBond__c> ib_l = [SELECT Id, Type__c, Surety__c, PolicyNumber__c, EffectiveDate__c,
                                              TermDate__c, CancelDate__c, Amount__c, License__c, 
                                              TransactionCode__c, Historical__c
                                       FROM InsuranceBond__c 
                                       WHERE License__c IN: licenseId_S
                                       AND Status__c = 'Active'];
        for (InsuranceBond__c ib : ib_l) {   
            InsuranceBondWrapper ibWrapper = new InsuranceBondWrapper();
            ibWrapper.Type = ib.Type__c;
            ibWrapper.Surety = ib.Surety__c;
            ibWrapper.PolicyNumber = ib.PolicyNumber__c;
            ibWrapper.EffectiveDate = ib.EffectiveDate__c;
            ibWrapper.TermDate = ib.TermDate__c;
            ibWrapper.CancelDate = ib.CancelDate__c;
            ibWrapper.Amount = ib.Amount__c;
            
            if (insuranceBond_M.containsKey(ib.License__c)) {
                insuranceBond_M.get(ib.License__c).add(ibWrapper);
            } else {
                insuranceBond_M.put(ib.License__c, new List<InsuranceBondWrapper>{ibWrapper});
            }
            
            if (profileName == 'License RICO API Only') {
                ibWrapper.TransactionCode = ib.TransactionCode__c;
                ibWrapper.Historical = ib.Historical__c ;
            }
        }

        //LicenseHistory (exclude renew history)
        Map<Id, List<LicenseHistoryWrapper>> licenseHistory_M = new Map<Id, List<LicenseHistoryWrapper>>();
        List<LicenseHistory__c> lh_l = [SELECT Id, TransactionType__c, EffectiveDate__c, 
                                               TermDate__c, SuspenseDate__c, RicoNumber__c,
                                               License__c, Remarks__c, LicensePeriod__c
                                        FROM LicenseHistory__c 
                                        WHERE License__c IN: licenseId_S
                                        AND TransactionType__c != 'RNEW - RENEWED'
                                        AND TransactionType__c != 'RSTR - RESTORED (LICENSE WAS DELINQUENT/FORFEITED)'];
        for (LicenseHistory__c lh : lh_l) {   
            LicenseHistoryWrapper lhWrapper = new LicenseHistoryWrapper();
            lhWrapper.TransactionType = lh.TransactionType__c;
            lhWrapper.EffectiveDate = lh.EffectiveDate__c;
            lhWrapper.TermDate = lh.TermDate__c;
            lhWrapper.SuspenseDate = lh.SuspenseDate__c;
            lhWrapper.RicoNumber = lh.RicoNumber__c;
            
            if (profileName == 'License RICO API Only') {
                lhWrapper.Remarks = lh.Remarks__c;
                lhWrapper.LicensePeriod = lh.LicensePeriod__c;
            }

            if (licenseHistory_M.containsKey(lh.License__c)) {
                licenseHistory_M.get(lh.License__c).add(lhWrapper);
            } else {
                licenseHistory_M.put(lh.License__c, new List<LicenseHistoryWrapper>{lhWrapper});
            }
        }

        //LicenseConditions
        Map<Id, List<LicenseConditionsWrapper>> licenseCondition_M = new Map<Id, List<LicenseConditionsWrapper>>();
        List<LicenseConditions__c> lcc_l = [SELECT Id, Condition__c, Status__c, DateDue__c, License__c
                                            FROM LicenseConditions__c 
                                            WHERE License__c IN: licenseId_S];
        for (LicenseConditions__c lc : lcc_l) {   
            LicenseConditionsWrapper lcWrapper = new LicenseConditionsWrapper();
            lcWrapper.Condition = lc.Condition__c;
            lcWrapper.Status = lc.Status__c;
            lcWrapper.DateDue = lc.DateDue__c;

            if (licenseCondition_M.containsKey(lc.License__c)) {
                licenseCondition_M.get(lc.License__c).add(lcWrapper);
            } else {
                licenseCondition_M.put(lc.License__c, new List<LicenseConditionsWrapper>{lcWrapper});
            }
        }

        //EarnedContinuingEducation
        Map<Id, List<EarnedContinuingEducationWrapper>> earnedContinuingEducation_M = new Map<Id, List<EarnedContinuingEducationWrapper>>();
        List<Earned_Continuing_Education__c> ece_l = [SELECT Id, Biennium__c, CourseType__c, Credits__c, Name, License__c
                                                      FROM Earned_Continuing_Education__c 
                                                      WHERE License__c IN: licenseId_S];
        for (Earned_Continuing_Education__c ece : ece_l) {   
            EarnedContinuingEducationWrapper eceWrapper = new EarnedContinuingEducationWrapper();
            eceWrapper.Biennium = ece.Biennium__c;
            eceWrapper.CourseType = ece.CourseType__c;
            eceWrapper.Credits = ece.Credits__c;
            eceWrapper.Name = ece.Name;

            if (earnedContinuingEducation_M.containsKey(ece.License__c)) {
                earnedContinuingEducation_M.get(ece.License__c).add(eceWrapper);
            } else {
                earnedContinuingEducation_M.put(ece.License__c, new List<EarnedContinuingEducationWrapper>{eceWrapper});
            }
        }
        
        for (LicenseWrapper lw : lWrapper_l) {
            if (employeeLicense_M.containsKey(lw.LicenseId)) {
                lw.EmployeeLicenses.addAll(employeeLicense_M.get(lw.LicenseId));
            }

            if (entityLicense_M.containsKey(lw.LicenseId)) {
                lw.EntityLicenses.addAll(entityLicense_M.get(lw.LicenseId));
            }

            if (licenseClassification_M.containsKey(lw.LicenseId)) {
                lw.LicenseClassifications.addAll(licenseClassification_M.get(lw.LicenseId));
            }

            if (licenseName_M.containsKey(lw.LicenseId)) {
                lw.LicenseNames.addAll(licenseName_M.get(lw.LicenseId));
            }

            if (insuranceBond_M.containsKey(lw.LicenseId)) {
                lw.InsuranceBonds.addAll(insuranceBond_M.get(lw.LicenseId));
            }

            if (licenseHistory_M.containsKey(lw.LicenseId)) {
                lw.LicenseHistories.addAll(licenseHistory_M.get(lw.LicenseId));
            }

            if (licenseCondition_M.containsKey(lw.LicenseId)) {
                lw.LicenseConditions.addAll(licenseCondition_M.get(lw.LicenseId));
            }

            if (earnedContinuingEducation_M.containsKey(lw.LicenseId)) {
                lw.EarnedContinuingEducations.addAll(earnedContinuingEducation_M.get(lw.LicenseId));
            }
        }
        return lWrapper_l;
    }
    public class JSONRequest {
        public String SearchCriteria {get; set;}
        public Integer SearchType {get; set;}
    }      

    public class JSONResponse{
        public String Status {get; set;}
        public Integer StatusCode {get; set;}
        public String Message {get; set;}
        public Integer NumberOfLicenses {get; set;}
        public List<LicenseWrapper> Licenses {get; set;}
        //This is the contructor method.
        public JSONResponse(String Status, Integer StatusCode, String Message, List<LicenseWrapper> Licenses) {
            this.Status = Status;
            this.StatusCode = StatusCode;
            this.Message = Message;
            this.Licenses = Licenses;
        }
    }

    public class LicenseWrapper{
        public String LicenseId {get; set;}
        public String LicenseNumber {get; set;}
        public String BPID {get; set;}
        public String LicenseTypeCode {get; set;}
        public String LicenseTypeDescription {get; set;}
        public String LicenseeName {get; set;}
        public Boolean SoleOwner {get; set;}
        public String TypeOfEntity {get; set;}
        public String Status {get; set;}
        public String ActiveInactive {get; set;}
        public String ClassPrefix {get; set;}
        public String BoardProgramName {get; set;}
        public String LicenseName {get; set;}
        public Date OriginalDateofLicensure {get; set;}
        public Date EffectiveExpireDate {get; set;}
        public Date ForfeitureDate {get; set;}
        public String MethodofLicensure {get; set;}
        public Boolean ExemptfromRenewal {get; set;}
        public String Privilege {get; set;}
        public String Restrictions {get; set;}
        public Boolean ConditionalLicense {get; set;}
        public Boolean MultiDependency {get; set;}
        public Boolean Dual {get; set;}
        public String Remarks {get; set;}
        public String ContinuingEducation {get; set;}
        public Date BusinessAddressEffectiveDate {get; set;}
        public String BusinessAddressRestricted {get; set;}
        public String BusinessCity {get; set;}
        public String BusinessCode {get; set;}
        public String BusinessCountry {get; set;}
        public String BusinessState {get; set;}
        public String BusinessStreet {get; set;}
        public String BusinessZipCode {get; set;}
        public Date MailingAddressEffectiveDate {get; set;}
        public String MailingCity {get; set;}
        public String MailingCountry {get; set;}
        public String MailingState {get; set;}
        public String MailingStreet {get; set;}
        public String MailingZipCode {get; set;} 
        public String LicensePhone {get; set;}
        public Boolean DisciplinaryAction{get;set;}
        //new fields for RICO user
        public Boolean SoleProp {get; set;}
        public DateTime LastModifiedDate {get; set;} 
        public Date LicenseNameEffectiveDate {get; set;} 
        public String CumulativeExperience {get; set;} 
        public Decimal TempLicenseExtensions {get; set;} 
        public Boolean NeighborIsland {get; set;} 
        public Boolean LossofBond {get; set;} 
        
        public AccountWrapper Account {get; set;}
        public List<EmployeeLicenseWrapper> EmployeeLicenses {get; set;}
        public List<EntityLicenseWrapper> EntityLicenses {get; set;}
        public List<LicenseClassificationWrapper> LicenseClassifications {get; set;}
        public List<LicenseNameWrapper> LicenseNames {get; set;}
        public List<InsuranceBondWrapper> InsuranceBonds {get; set;}
        public List<LicenseHistoryWrapper> LicenseHistories {get; set;}
        public List<LicenseConditionsWrapper> LicenseConditions {get; set;}
        public List<EarnedContinuingEducationWrapper> EarnedContinuingEducations {get; set;}
    }

    public class AccountWrapper{
        public String Name {get; set;}
        public String Phone {get; set;}
        public String BPID {get; set;}
        public String PersonalEmail {get; set;}
        public String BusinessEmail {get; set;}
        public String MobilePhone {get; set;}
    }

    public class EmployeeLicenseWrapper{
        public String Position {get; set;}
        public String PositionStatus {get; set;}
        public String EmployeeLicenseeName {get; set;}
        public String EmployeeLicense {get; set;}
        public Boolean Dual {get; set;}
        public Date EffectiveDate {get; set;}
        public Date EndDate {get; set;}
        public Date EmploymentExpireDate {get; set;}
    }

    public class EntityLicenseWrapper{
        public String Position {get; set;}
        public String PositionStatus {get; set;}
        public String EntityLicenseeName {get; set;}
        public String EntityLicense {get; set;}
        public Boolean Dual {get; set;}
        public Date EffectiveDate {get; set;}
        public Date EndDate {get; set;}
        public Date EmploymentExpireDate {get; set;}
    }

    public class LicenseClassificationWrapper{
        public String ClassificationName {get; set;}
        public Date EffectiveStartDate {get; set;}
        public Date EndDate {get; set;}
        public Boolean RestrictedClass {get; set;}
        public String Status {get; set;}
    }

    public class LicenseNameWrapper{
        public String NameType {get; set;}
        public Date EffectiveDate {get; set;}
        public Date TermDate {get; set;}
        public String Name {get; set;}
    }

    public class InsuranceBondWrapper{
        public String Type {get; set;}
        public String Surety {get; set;}
        public String PolicyNumber {get; set;}
        public Date EffectiveDate {get; set;}
        public Date TermDate {get; set;}
        public Date CancelDate {get; set;}
        public Decimal Amount {get; set;}
        
        //new fields for RICO users
        public String TransactionCode {get; set;}
        Public Boolean Historical {get; set;}
    }

    public class LicenseHistoryWrapper{
        public String TransactionType {get; set;}
        public Date EffectiveDate {get; set;}
        public Date TermDate {get; set;}
        public Date SuspenseDate {get; set;}
        public String RicoNumber {get; set;}
        
        //new fields for RICO users
        public String Remarks {get; set;}
        public String LicensePeriod {get; set;}
    }

    public class LicenseConditionsWrapper{
        public String Condition {get; set;}
        public String Status {get; set;}
        public Date DateDue {get; set;}
    }

    public class EarnedContinuingEducationWrapper{
        public String Biennium {get; set;}
        public String CourseType {get; set;}
        public Decimal Credits {get; set;}
        public String Name {get; set;}
    }
}