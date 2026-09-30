/*
* ─────────────────────────────────────────────────────────
* PVL_ListBuilderFileGenerationBatchJob Class
* 
* ─────────────────────────────────────────────────────────
* PacPoint-CZ180820 - Create CSV file for List Builder Generation
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Chris Zhuang - PacificPointCorp 
* @created      2020-08-18
* ───────────────────────────────────────────────────────────
* Changes
*
* ───────────────────────────────────────────────────────────
*/
global class PVL_ListBuilderFileGenerationBatchJob implements schedulable, Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts{
    /* variables */
    public Integer batchSize;
    public pymt__PaymentX__c payment;
    public Integer recordCount;
    public Integer maxFileSize;
    //public Map<String, String> CSVData = new Map<String, String>();
    public String licenseedataCSV;
    public String sortnameCSV;
    public String classdataCSV;
    
    /* construction */
    global PVL_ListBuilderFileGenerationBatchJob() {
        /* default settings */
        this.batchSize = 200;
        this.recordCount = 0;
        this.maxFileSize = 0;
        this.payment = new pymt__PaymentX__c();
        
        this.licenseedataCSV = '';
        this.sortnameCSV = '';
        this.classdataCSV = '';
    }

    /* collect the batches of records or objects to be passed to execute */
    global DataBase.QueryLocator Start(Database.BatchableContext context) {
        String today7 = String.valueOf(System.Today() - 7); 
        String query = 'SELECT Id, NAME, pymt__Amount__c, pymt__Billing_Email__c, PVL_License_Type__c, PVL_License_Status__c, PVL_Zip_Code__c, PVL_Active_Status__c, PVL_Start_Date__c, PVL_End_Date__c, PVL_Refine_Contractor__c, PVL_Selected_Contractor__c, PVL_Pickup_Token__c, pymt__Date__c, PVL_Document_Expire_Date__c ';
        if (Test.isRunningTest()) {
            query += ' FROM pymt__PaymentX__c limit 1';
        } else {
            query += ' FROM pymt__PaymentX__c WHERE NAME = \'PVL - List Builder Payment\' AND pymt__Status__c = \'Completed\' AND pymt__Contact__r.Name = \'PVL Portal Contact\' AND PVL_Pickup_Token__c = null AND pymt__Date__c != null AND pymt__Date__c >= ' + today7 + ' ORDER BY createdDate DESC LIMIT 1'; 
        }
        List<sObject> sobjList = Database.query(query);
        
        String licenseQuery = 'SELECT Id, Name, Dual__c, LicenseType__r.Individual__c, LicenseType__r.Entity__c, LicenseType__r.BoardProgram__r.BoardProgramNumber__c,DependentLicenseeName__c,LicenseTypeDescription__c,LicenseConsecutiveNumber__c,LicenseType__r.BoardProgram__r.Name,LicenseeNameFormula__c,OriginalDateOfLicensure__c,EffectiveExpireDate__c,Status__c,ActiveInactive__c,Privilege__c, LicenseRestriction__c, ConditionalLicense__c, BusinessStreet__c, BusinessCity__c, BusinessState__c, BusinessZipCode__c, BusinessAddressRestricted__c, ClassPrefix__c FROM License__c';
        String whereCause = '';
        String orderBy = '';
 		for(sObject s : sobjList) {
        	pymt__PaymentX__c p = (pymt__PaymentX__c)s;
            this.payment = p;
            //p.PVL_License_Type__c
            List<String> licenseTypeId_L = new List<String>();
            Set<String> licenseTypeId_S = new Set<String>();
            if (p.PVL_License_Type__c != null) {
            	licenseTypeId_L = p.PVL_License_Type__c.split(',');
                licenseTypeId_S.addAll(licenseTypeId_L);
                whereCause += whereCause == '' ? ' WHERE LicenseType__c IN : licenseTypeId_S'  : ' AND LicenseType__c IN : licenseTypeId_S';
            }
                
            //p.PVL_License_Status__c
            if (p.PVL_License_Status__c != null) {
            	whereCause += whereCause == '' ? ' WHERE Status__c = \'' + p.PVL_License_Status__c + '\'' : ' AND Status__c = \'' + p.PVL_License_Status__c + '\'';
            }
                
            //p.PVL_Zip_Code__c
            List<String> zipCode_L = new List<String>();
            if (p.PVL_Zip_Code__c != null) {
            	zipCode_L = p.PVL_Zip_Code__c.split(',');
                whereCause += whereCause == '' ? ' WHERE MailingZipCode__c IN : zipCode_L' : ' AND MailingZipCode__c IN : zipCode_L';
            }
                
            //p.PVL_Active_Status__c
            if (p.PVL_Active_Status__c != null) {
            	whereCause += whereCause == '' ? ' WHERE ActiveInactive__c = \'' + p.PVL_Active_Status__c + '\'' : ' AND ActiveInactive__c = \'' + p.PVL_Active_Status__c + '\'';
            }
                
            //p.PVL_Start_Date__c
            if (p.PVL_Start_Date__c != null) {
                Datetime dt_StartDate = datetime.newInstance(p.PVL_Start_Date__c.year(), p.PVL_Start_Date__c.month(),p.PVL_Start_Date__c.day());
                String f_StartDate = dt_StartDate.formatGMT('yyyy-MM-dd');
            	whereCause += whereCause == '' ? ' WHERE OriginalDateofLicensure__c >= ' + f_StartDate : ' AND OriginalDateofLicensure__c >= ' + f_StartDate;
            }
                
            //p.PVL_End_Date__c 
            if (p.PVL_End_Date__c != null) {
                Datetime dt_EndDate = datetime.newInstance(p.PVL_End_Date__c.year(), p.PVL_End_Date__c.month(),p.PVL_End_Date__c.day());
                String f_EndDate = dt_EndDate.formatGMT('yyyy-MM-dd');
            	whereCause += whereCause == '' ? ' WHERE OriginalDateofLicensure__c <= ' + f_EndDate : ' AND OriginalDateofLicensure__c <= ' + f_EndDate;
            }
                
            //p.PVL_Refine_Contractor__c
          	if (p.PVL_Refine_Contractor__c != null && p.PVL_Refine_Contractor__c == true) {
                //p.PVL_Selected_Contractor__c 
                List<String> selectedContractor_L = new List<String>();
                if (p.PVL_Selected_Contractor__c != null) {
                    selectedContractor_L = p.PVL_Selected_Contractor__c.split(',');
                	//whereCause += whereCause == '' ? ' WHERE MailingZipCode__c IN : selectedContractor_L' : ' AND MailingZipCode__c IN : selectedContractor_L';
            	}
        	}
        }
        orderBy = ' order by LicenseType__r.BoardProgram__r.Name';
        return Database.getQueryLocator(licenseQuery + whereCause + orderBy); 
    }

    /* method for scheduling */
    @ReadOnly
    global void execute(SchedulableContext context){
        Database.executeBatch(new PVL_ListBuilderFileGenerationBatchJob(), batchSize);
    }

    /* process each batch of records */
    global void execute(Database.BatchableContext context, List<SObject> scope) {
        system.debug('MaxFileSize: ' + this.maxFileSize);
        if(this.maxFileSize >= 6000) {
            saveCSVFileInSpringCM();
        }
        
        Transient Set<Id> licenseId_S = new Set<Id>();
        Transient Map<Id, List<AssociatedLicense__c>> associatedLicense_M = new Map<Id, List<AssociatedLicense__c>>();
        Transient Map<Id, List<LicenseClassification__c>> licenseClass_M = new Map<Id, List<LicenseClassification__c>>();
        for (sObject so : scope) {
        	License__c li = (License__c) so; 
            licenseId_S.add(li.Id);
       		this.recordCount++;
        }
            
		for (AssociatedLicense__c al : [SELECT id, EntityLicense__c, Name, EmploymentStatus__c, 
                                        PositionStatus__c, Position__c, EntityLicenseType__c, EntityLicense__r.Name, 
                                        EntityName__c, EntityLicense__r.LicenseType__r.Name, 
                                        EntityLicense__r.LicenseType__r.TypeofPositionStatus__c
                                        FROM AssociatedLicense__c
                                        WHERE EntityLicense__c IN: licenseId_S AND EmploymentStatus__c = 'Employed']) {
            if (associatedLicense_M.containsKey(al.EntityLicense__c)) {
            	associatedLicense_M.get(al.EntityLicense__c).add(al);
            } else {
            	associatedLicense_M.put(al.EntityLicense__c, new List<AssociatedLicense__c>{al});
        	}
        }
          
		for (LicenseClassification__c lc : [SELECT id, License__c, Name, Classification__r.Name, Status__c, RestrictedClass__c
                                            FROM LicenseClassification__c
                                            WHERE License__c IN: licenseId_S]) {
            if (licenseClass_M.containsKey(lc.License__c)) {
            	licenseClass_M.get(lc.License__c).add(lc);
            } else {
            	licenseClass_M.put(lc.License__c, new List<LicenseClassification__c>{lc});
        	}
        }
        //create the licensee data file
        createLicenseeDataFile(scope, associatedLicense_M);
        //create the class data file
        createClassDataFile(scope, licenseClass_M);
        //create sort name data file
        createSortnameDateFile(scope);
        //reset file size
        this.maxFileSize += scope.size();
    }

    global void finish(Database.BatchableContext bc) {
        if (this.payment.Id != null) {
            //saveCSVFileInSpringCM();
            updatePaymentRecord();
            sendEmails();
        }
    }

    global void updatePaymentRecord(){
        Savepoint sp = Database.setSavepoint();
        try {
            this.payment.PVL_Pickup_Token__c = generateRandomString(64);
            Database.update(this.payment);
        } catch(DMLException e) {
            Database.rollback(sp);
            System.debug('Something happened:' + e.getMessage());
        }
    }

    private String checkNull(String inString) {
    	if (inString == null)
            return '';
        return inString;
    }

    public static String generateRandomString(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
           Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
           randStr += chars.substring(idx, idx+1);
        }
        return randStr; 
    }

    global void createLicenseeDataFile (List<sObject> sobjList, Map<Id, List<AssociatedLicense__c>> associatedLicense_M) {
        //generate body csv part
        for (sObject so : sobjList) {
            License__c li = (License__c) so;            
            //body row 1 - BoardProgram.BoardProgramNumber__c
            licenseedataCSV += checkNull(li.LicenseType__r.BoardProgram__r.BoardProgramNumber__c);
                    
            //body row 2 - License.DependentLicenseeName__c
            licenseedataCSV += ',\"' + checkNull(li.DependentLicenseeName__c) + '\"';
             
            //body row 3 - License.LicenseTypeDescription__c
            licenseedataCSV += ',\"' + checkNull(li.LicenseTypeDescription__c) + '\"';
             
            //body row 4 - License.LicenseConsecutiveNumber__c
            licenseedataCSV += ',\"' + checkNull(li.LicenseConsecutiveNumber__c) + '\"';
    
            //body row 5 - License Office - 0
            if (li.Name != null) {
                List<String> splitName_L = li.Name.split('-');
                if (splitName_L.size() >= 3) {
                    licenseedataCSV += ',\"' + splitName_L[2] + '\"';
                } else {
                    licenseedataCSV += ',\"' + '0' + '\"';
                }
            } else {
                licenseedataCSV += ',\"\"';
            }
    
            //body row 6 - Record Type - 3
            licenseedataCSV += ',\"' + '1' + '\"';
             
            //body row 7 - Board Alpha - BoardProgram.Name
            licenseedataCSV  += ',\"' + checkNull(li.LicenseType__r.BoardProgram__r.Name) + '\"';
    
            //body row 8 - BP Sortname - License.LicenseeNameFormula__c
            licenseedataCSV += ',\"' + checkNull(li.LicenseeNameFormula__c) + '\"';

            //body row 9 - Effective Date - License.OriginalDateOfLicensure__c
            if (li.OriginalDateOfLicensure__c != null) {
                Datetime dt_OriginalDate = datetime.newInstance(li.OriginalDateOfLicensure__c.year(), li.OriginalDateOfLicensure__c.month(),li.OriginalDateOfLicensure__c.day());
                String s_OriginalDate = dt_OriginalDate.formatGMT('MM/dd/yyyy');
                licenseedataCSV += ',\"' + s_OriginalDate + '\"';
            } else {
                licenseedataCSV += ',\"\"';
            }

            //body row 10 - Expiration Date - License.EffectiveExpireDate__c
            if (li.EffectiveExpireDate__c != null) {
                Datetime dt_EffectiveDate = datetime.newInstance(li.EffectiveExpireDate__c.year(), li.EffectiveExpireDate__c.month(),li.EffectiveExpireDate__c.day());
                String s_EffectiveDate = dt_EffectiveDate.formatGMT('MM/dd/yyyy');
                licenseedataCSV += ',\"' + s_EffectiveDate + '\"';
            } else {
                licenseedataCSV += ',\"\"';
            }

            //body row 11 - License Status - License.Status__c
            licenseedataCSV += ',\"' + checkNull(li.Status__c) + '\"';

            //body row 12 - Active/Inactive Indicator - License.ActiveInactive__c
            licenseedataCSV += ',\"' + checkNull(li.ActiveInactive__c) + '\"';

            AssociatedLicense__c tempAL = new AssociatedLicense__c();
            if (li.LicenseType__r.Individual__c == TRUE && associatedLicense_M.containsKey(li.Id)) {
                for (AssociatedLicense__c al : associatedLicense_M.get(li.Id)) {
                    if (al.EmploymentStatus__c == 'Employed') {
                        tempAL = al;
                        break;
                    }
                }
            } else if (li.LicenseType__r.Entity__c == TRUE && associatedLicense_M.containsKey(li.Id)) {
                for (AssociatedLicense__c al : associatedLicense_M.get(li.Id)) {
                    if (al.EmploymentStatus__c == 'Employed' 
                    && (
                        (al?.EntityLicense__r?.LicenseType__r?.Name == 'RB - Entity' && al.PositionStatus__c == 'PB - PRINCIPAL BROKER (REAL ESTATE COMMISSION)')
                        || al?.EntityLicense__r?.LicenseType__r?.TypeofPositionStatus__c == al.PositionStatus__c
                    )
                    ) {
                        tempAL = al;
                        break;
                    }
                }            
            }

            //body row 13 - Employment Position Code - AssociatedLicense.Position__c
            if (tempAL != null) {
                licenseedataCSV += ',\"' + checkNull(tempAL.Position__c) + '\"';
            } else {
                licenseedataCSV += ',\"\"';  
            }
 
            //body row 14 - Employment Status - AssociatedLicense.EmploymentStatus__c
            if (tempAL != null) {
                licenseedataCSV += ',\"' + checkNull(tempAL.EmploymentStatus__c) + '\"';
            } else {
                licenseedataCSV += ',\"\"';  
            }

            //body row 15 - Employer License Type - AssociatedLicense.Employee/EntityLicenseType__c
            if (tempAL != null) {
                licenseedataCSV += ',\"' + checkNull(tempAL.EntityLicenseType__c) + '\"';
            } else {
                licenseedataCSV += ',\"\"';  
            }

            //body row 16 - Employer License Number -AssociatedLicense.EmployeeLicense/EntityLicense.Name
            if (tempAL != null) {
                licenseedataCSV += ',\"' + checkNull(tempAL.EntityLicense__r.Name) + '\"';
            } else {
                licenseedataCSV += ',\"\"';  
            }

            //body row 17 - Employer License Office #
            licenseedataCSV += ',\"' + checkNull(li.Name) + '\"';

            //body row 18 - Employer BP Sortname - AssociatedLicense.Employee/EntityName__c
            if (tempAL != null) {
                licenseedataCSV += ',\"' + checkNull(tempAL.EntityName__c) + '\"';
            } else {
                licenseedataCSV += ',\"\"';  
            }

            //body row 19 - Special Privilege Indicator	- License.SpecialPrivilege__c
            licenseedataCSV += ',\"' + checkNull(li.Privilege__c) + '\"';

            //body row 20 - License Restriction Indicator - License.LicenseRestriction__c
            licenseedataCSV += ',\"' + checkNull(li.LicenseRestriction__c) + '\"';
            
            //body row 21 - Conditional License Indicator - License.ConditionalLicense__c
            licenseedataCSV += ',\"' + li.ConditionalLicense__c + '\"';

            //body row 22 - Business Address 1 - License.BusinessStreet__c
            licenseedataCSV += ',\"' + checkNull(li.BusinessStreet__c) + '\"';

            //body row 23 - Business Address 2 - License.BusinessStreet__c
            licenseedataCSV += ',\"' + checkNull(li.BusinessStreet__c) + '\"';

            //body row 24 - Business City - License.BusinessCity__c
            licenseedataCSV += ',\"' + checkNull(li.BusinessCity__c) + '\"';

            //body row 25 - Business State - License.BusinessState__c
            licenseedataCSV += ',\"' + checkNull(li.BusinessState__c) + '\"';

            //body row 25 - Business Zipcode - License.BusinessZipCode__c
            licenseedataCSV += ',\"' + checkNull(li.BusinessZipCode__c) + '\"';

            //body row 26 - Business Address Restriction Code - License.BusinessAddressRestricted__c
            licenseedataCSV += ',\"' + checkNull(li.BusinessAddressRestricted__c) + '\"';

            //body row 27 - Class Prefix - License.ClassPrefix__c
            licenseedataCSV += ',\"' + checkNull(li.ClassPrefix__c) + '\"';

            //add new line break
            licenseedataCSV += '\n';
        }
        
        //if (this.CSVData.containsKey('licenseedataCSV')) {
        //    this.CSVData.put('licenseedataCSV', this.CSVData.get('licenseedataCSV') + licenseedataCSV);
        //} else {
        //	this.CSVData.put('licenseedataCSV', licenseedataCSV);
        //}
    }

    global void createSortnameDateFile (List<sObject> sobjList) {
        //generate body csv part
        for (sObject so : sobjList) {
            License__c li = (License__c) so;            
            //body row 1 - BoardProgram.BoardProgramNumber__c
            sortnameCSV += checkNull(li.LicenseType__r.BoardProgram__r.BoardProgramNumber__c);
                    
            //body row 2 - License.DependentLicenseeName__c
            sortnameCSV += ',\"' + checkNull(li.DependentLicenseeName__c) + '\"';
             
            //body row 3 - License.LicenseTypeDescription__c
            sortnameCSV += ',\"' + checkNull(li.LicenseTypeDescription__c) + '\"';
             
            //body row 4 - License.LicenseConsecutiveNumber__c
            sortnameCSV += ',\"' + checkNull(li.LicenseConsecutiveNumber__c) + '\"';
    
            //body row 5 - License Office - 0
            if (li.Name != null) {
                List<String> splitName_L = li.Name.split('-');
                if (splitName_L.size() >= 3) {
                    sortnameCSV += ',\"' + splitName_L[2] + '\"';
                } else {
                    sortnameCSV += ',\"' + '0' + '\"';
                }
            } else {
                sortnameCSV += ',\"\"';
            }

            //body row 6 - Record Type - 3
            sortnameCSV += ',\"' + '3' + '\"';
             
            //body row 7 - Board Alpha - BoardProgram.Name
            sortnameCSV  += ',\"' + checkNull(li.LicenseType__r.BoardProgram__r.Name) + '\"';
    
            //body row 8 - BP Sortname - License.LicenseeNameFormula__c
            sortnameCSV += ',\"' + checkNull(li.LicenseeNameFormula__c) + '\"';
            
            //add new line break
            sortnameCSV += '\n';
        }
        
        //if (this.CSVData.containsKey('sortnameCSV')) {
        //    this.CSVData.put('sortnameCSV', this.CSVData.get('sortnameCSV') + sortnameCSV);
        //} else {
        //	this.CSVData.put('sortnameCSV', sortnameCSV);
        //}
    }
    
    global void createClassDataFile (List<sObject> sobjList, Map<Id, List<LicenseClassification__c>> licenseClass_M) {
        //generate body csv part
        for (sObject so : sobjList) {
            License__c li = (License__c) so;            
            //body row 1 - BoardProgram.BoardProgramNumber__c
            classdataCSV += checkNull(li.LicenseType__r.BoardProgram__r.BoardProgramNumber__c);
                    
            //body row 2 - License.DependentLicenseeName__c
            classdataCSV += ',\"' + checkNull(li.DependentLicenseeName__c) + '\"';
             
            //body row 3 - License.LicenseTypeDescription__c
            classdataCSV += ',\"' + checkNull(li.LicenseTypeDescription__c) + '\"';
             
            //body row 4 - License.LicenseConsecutiveNumber__c
            classdataCSV += ',\"' + checkNull(li.LicenseConsecutiveNumber__c) + '\"';
    
            //body row 5 - License Office - 0
            if (li.Name != null) {
                List<String> splitName_L = li.Name.split('-');
                if (splitName_L.size() >= 3) {
                    classdataCSV += ',\"' + splitName_L[2] + '\"';
                } else {
                    classdataCSV += ',\"' + '0' + '\"';
                }
            } else {
                classdataCSV += ',\"\"';
            }

            //body row 6 - Record Type - 3
            classdataCSV += ',\"' + '2' + '\"';

            //body row 7 - Board Alpha - BoardProgram.Name
            classdataCSV  += ',\"' + checkNull(li.LicenseType__r.BoardProgram__r.Name) + '\"';
    
            if(licenseClass_M.containsKey(li.Id)) {
                for (LicenseClassification__c lc : licenseClass_M.get(li.Id)) {
                    //body row 8 - Class Code #1~n
                    classdataCSV  += ',\"' + checkNull(lc.Classification__r.Name) + '\"';
            
                    //body row 9 - Class Status #1~n
                    classdataCSV += ',\"' + checkNull(lc.Status__c) + '\"';

                    //body row 10 - Class Restriction Code #1~n
                    classdataCSV += ',\"' + lc.RestrictedClass__c + '\"';
                }
            }
            //add new line break
            classdataCSV += '\n';
        }

        //if (this.CSVData.containsKey('classdataCSV')) {
        //    this.CSVData.put('classdataCSV', this.CSVData.get('classdataCSV') + classdataCSV);
        //} else {
        //	this.CSVData.put('classdataCSV', classdataCSV);
        //}
    }

    global void saveCSVFileInSpringCM(){
        //Write the column headers to the file string
        String ldHeader  = 'Board Code,\"Sortname\",\"License Type\",\"License Number\",\"License Office #\",\"Record Type\",\"Board Alpha\",\"License Sortname\",\"Effective Date\",\"Expiration Date\",\"License Status\",\"Active/Inactive Indicator\",\"Employment Position Code\",\"Employment Status\",\"Employer License Type\",\"Employer License Number\",\"Employer License Office #\",\"Employer BP Sortname\",\"Special Privilege Indicator\",\"License Restriction Indicator\",\"Conditional License Indicator\",\"Business Address 1\",\"Business Address 2\",\"Business City\",\"Business State\",\"Business Zipcode\",\"Business Address Restriction Code\",\"Class Prefix\"\n';
        String cdHeader = 'Board Code,\"Sortname\",\"License Type\",\"License Number\",\"License Office #\",\"Record Type\",\"Board Alpha\",\"Class Code #1\",\"Class Status\",\"Class Restriction Code\",\"Class Code #2\",\"Class Status\",\"Class Restriction Code\",\"Class Code #3\",\"Class Status\",\"Class Restriction Code\",\"Class Code #4\",\"Class Status\",\"Class Restriction Code\",\"Class Code #5\",\"Class Status\",\"Class Restriction Code\",\"Class Code #6\",\"Class Status\",\"Class Restriction Code\",\"Class Code #7\",\"Class Status\",\"Class Restriction Code\",\"Class Code #8\",\"Class Status\",\"Class Restriction Code\",\"Class Code #9\",\"Class Status\",\"Class Restriction Code\",\"Class Code #10\",\"Class Status\",\"Class Restriction Code\",\"Class Code #11\",\"Class Status\",\"Class Restriction Code\",\"Class Code #11\",\"Class Status\",\"Class Restriction Code\",\"Class Code #12\",\"Class Status\",\"Class Restriction Code\",\"Class Code #13\",\"Class Status\",\"Class Restriction Code\",\"Class Code #14\",\"Class Status\",\"Class Restriction Code\",\"Class Code #15\",\"Class Status\",\"Class Restriction Code\",\"Class Code #16\",\"Class Status\",\"Class Restriction Code\",\"Class Code #17\",\"Class Status\",\"Class Restriction Code\",\"Class Code #18\",\"Class Status\",\"Class Restriction Code\",\"Class Code #19\",\"Class Status\",\"Class Restriction Code\",\"Class Code #20\",\"Class Status\",\"Class Restriction Code\"\n';
        String snHeader  = 'Board Code,\"Sortname\",\"License Type\",\"License Number\",\"License Office #\",\"Record Type\",\"Board Alpha\",\"BP Sortname\"\n';
        Datetime dt_Today = datetime.newInstance(System.today().year(), System.today().month(),System.today().day());
        String s_Today = dt_Today.formatGMT('yyyyMMdd');
        
        Map<String, Blob> files = new Map<String, Blob>();
        files.put('licensee_data_file_' + s_Today + '.csv', Blob.valueOf(ldHeader + this.licenseedataCSV));
        files.put('class_data_file_' + s_Today + '.csv', Blob.valueOf(cdHeader + this.classdataCSV));
       	files.put('sortname_data_file_' + s_Today + '.csv', Blob.valueOf(snHeader + this.sortnameCSV));
        List<SpringCMDocument> uploadedDocument_L = SpringCMConnector.createFiles(this.payment.Id, files);
        if(uploadedDocument_L != null ) {
            for (SpringCMDocument doc : uploadedDocument_L) {
                SpringCMConnector.updateFileDescription(doc.Href, 'PVL - List Builder Generation');
            }        
        }
        
        uploadedDocument_L.clear();
        files.clear();
        this.maxFileSize = 0; 
        this.licenseedataCSV = '';
        this.sortnameCSV = '';
        this.classdataCSV = '';
    }
    
    global void sendEmails () {
        Messaging.SingleEmailMessage semail = new Messaging.SingleEmailMessage();
        OrgConfiguration__c  orgSetting = OrgConfiguration__c.getOrgDefaults();
        if(orgSetting.Use_Organization_Wide_Email__c) {
        	OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where address = 'noreply@dcca.hawaii.gov'];
        	if (owea.size() > 0) {
        		semail.setOrgWideEmailAddressId(owea[0].Id);
        	}
        } else {
            semail.setReplyTo('noreply@dcca.hawaii.gov');
            semail.setSenderDisplayName('noreply@dcca.hawaii.gov');
        }
        semail.setSubject('Your PVL List Builder List Is Ready For Pickup');
        String[] sendTo = new String[]{this.payment.pymt__Billing_Email__c};
        semail.setToAddresses(sendTo);
        String plainTextBody = '';
        plainTextBody += 'Aloha DCCA/PVL, \n\n';
        plainTextBody += 'Your PVL results list has been compiled and is ready for download. \n\n';
        plainTextBody += 'To download your results: \n';
        plainTextBody += '1) Navigate to https://mypvl.dcca.hawaii.gov/list-builder-files?pickupid=' + this.payment.PVL_Pickup_Token__c + '\n';
        plainTextBody += '2) Follow the onscreen instructions \n\n';
        String s_paymentDate = ''; 
        String s_documentExpireDate = ''; 
        if (this.payment.pymt__Date__c != null) {
            Datetime dt_paymentDate = datetime.newInstance(this.payment.pymt__Date__c.year(), this.payment.pymt__Date__c.month(), this.payment.pymt__Date__c.day());
            s_paymentDate = dt_paymentDate.formatGMT('MM/dd/yyyy');
        } 

        if (this.payment.PVL_Document_Expire_Date__c != null) {
            Datetime dt_documentExpireDate = datetime.newInstance(this.payment.PVL_Document_Expire_Date__c.year(), this.payment.PVL_Document_Expire_Date__c.month(), this.payment.PVL_Document_Expire_Date__c.day());
            s_documentExpireDate = dt_documentExpireDate.formatGMT('MM/dd/yyyy');
        } 
        
        plainTextBody += 'Your results will be available until midnight (HST) on ' + s_documentExpireDate  + '. After that time, you will no longer be able to access your list and no refunds will be given. \n\n';
        plainTextBody += 'Your PVL Result Details: \n\n';

        plainTextBody += 'Purchase Date: ' + s_paymentDate + '\n';
        plainTextBody += 'Expiration Date: ' + s_documentExpireDate + '\n';
        plainTextBody += 'Record Count: ' + this.recordCount + '\n';
        plainTextBody += 'Purchase Price: $' + this.payment.pymt__Amount__c + '\n\n';
        plainTextBody += 'Refinement Criteria Used: \n\n';

        List<String> licenseTypeId_L = new List<String>();
        Set<String> licenseTypeId_S = new Set<String>();
        if (this.payment.PVL_License_Type__c != null) {
            licenseTypeId_L = this.payment.PVL_License_Type__c.split(',');
            licenseTypeId_S.addAll(licenseTypeId_L);
        }

        List<String> licenseType_L = new List<String>();
        for (LicenseType__c l : [select Name from LicenseType__c where id IN: licenseTypeId_S]) {
            licenseType_L.add(l.Name);
        }
        string licenseType_S = string.join(licenseType_L,',');

        plainTextBody += 'License Type(s): ' + licenseType_S + '\n';
        plainTextBody += 'Zip Code(s): ' + this.payment.PVL_Zip_Code__c + '\n';
        String s_startDate = ''; 
        String s_endDate = ''; 
        if (this.payment.PVL_Start_Date__c != null) {
            Datetime dt_startDate = datetime.newInstance(this.payment.PVL_Start_Date__c.year(), this.payment.PVL_Start_Date__c.month(), this.payment.PVL_Start_Date__c.day());
            s_startDate = dt_startDate.formatGMT('MM/dd/yyyy');
        } 

        if (this.payment.PVL_End_Date__c != null) {
            Datetime dt_endDate = datetime.newInstance(this.payment.PVL_End_Date__c.year(), this.payment.PVL_End_Date__c.month(), this.payment.PVL_End_Date__c.day());
            s_endDate = dt_endDate.formatGMT('MM/dd/yyyy');
        } 

        plainTextBody += 'License Issuance Range: ' + s_startDate + ' - ' + s_endDate+ '\n';
        plainTextBody += 'License Status: ' + this.payment.PVL_License_Status__c + '\n';
        plainTextBody += 'Active Status: ' + this.payment.PVL_Active_Status__c + '\n';
        
        If (this.payment.PVL_Refine_Contractor__c == True) {
            plainTextBody += 'Refine Contractor: ' + this.payment.PVL_Refine_Contractor__c  + '\n';
            List<String> contractorId_L = new List<String>();
            if (this.payment.PVL_Selected_Contractor__c != null) {
                contractorId_L = this.payment.PVL_Selected_Contractor__c.split(',');
            }
            List<String> classification_L = new List<String>();
            for (Classification__c c : [select ID, Name from Classification__c where id IN: contractorId_L]) {
                classification_L.add(c.Name);
            }
            string classification_S = string.join(classification_L,',');    
            plainTextBody += 'Selected Contractor: ' + classification_S + '\n\n';
        } else {
            plainTextBody += '\n';
        }

        plainTextBody += 'If you have any questions or issues with obtaining your results, please contact PVL at (808) 586-3000 or email us at pvl@dcca.hawaii.gov \n\n';
        plainTextBody += 'Mahalo for using the PVL List Builder! \n\n';
        plainTextBody += 'To view a list of all the services that we provide, please visit http://secure-web.cisco.com/1J1N7MbccObdjLHBMgnutWrwAobT_19lfXFdc600dhlW1nkAIYSNqyYbQCJQp4goaAHHa-sRpm-RS2wI53oXfkfVSoic6d34DnSB2XNlsNROwM6fpWgHL8k75Mj5QT_aNgDg7HyGhR3hkk_ttvCEqsplojV4EqyIcTcdy3pDBVwyRgUtoSbhEOEL5ghlIXw60bry0fVn9o3S_R4WMGMRv9xppj2zRFlB_6DYc5fHwRrSYBuUS5NSazu-Lhh3DgnMpIs8sa--X_nzMP0Et7iGEEYC5vtmdoswBR99FcKP3-FQwCHLu2Us21pIOs3HszBdenbAIZ6qYTv7rVyEt6Ra-Yg/http%3A%2F%2Fwww.ehawaii.gov.';

        semail.setPlainTextBody(plainTextBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{semail});
    }
}