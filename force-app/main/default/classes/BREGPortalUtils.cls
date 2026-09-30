public without sharing class BREGPortalUtils {
    public static FormConfiguration getFormConfiguration(String formConfigId) {
        return getFormConfiguration(formConfigId, null, null, null, null, null, null, null, null, null, null);
    }

    public static FormConfiguration getFormConfiguration(
        String businessProcess,
        String businessLocation,
        String businessStructure,
        String businessProfit,
        String registrationType,
        String corporationType,
        String cooperativeType,
        String stockType,
        String partnershipType,
        String formSuffix
    ) {
        return getFormConfiguration(
            null,
            businessProcess,
            businessLocation,
            businessStructure,
            businessProfit,
            registrationType,
            corporationType,
            cooperativeType,
            stockType,
            partnershipType,
            formSuffix
        );
    }

    @AuraEnabled
    public static FormConfiguration getFormConfiguration(
        String formConfigId,
        String businessProcess,
        String businessLocation,
        String businessStructure,
        String businessProfit,
        String registrationType,
        String corporationType,
        String cooperativeType,
        String stockType,
        String partnershipType,
        String formSuffix
    ) {
        String query =
            ' SELECT Name,' +
            '    breg_Form_Instruction_URL__c,' +
            '    breg_What_is_this_Form__c,' +
            '    breg_Days_After_Submission_hold_Approval__c,' +
            '    breg_Required_Information__c,' +
            '    breg_Suffix_Code__c,' +
            '    breg_Business_Process__c,' +
            '    breg_Business_Location__c,' +
            '    breg_Business_Structure__c,' +
            '    breg_Profit_Type__c,' +
            '    breg_Registration_Type__c,' +
            '    breg_Corporation_Type__c,' +
            '    breg_Cooperative_Type__c,' +
            '    breg_Form_Name__c,' +
            '    breg_Form_Code__c,' +
            '    breg_Stock_Type__c,' +
            '    breg_Partnership_Type__c,' +
            '    breg_Entity_Type__c,' +
            '    breg_Linked_Form__c,' +
            '    (SELECT breg_Component_Name__c,' +
            '            breg_Order__c,' +
            '            breg_Label_Override__c,' +
            '            breg_Label_Override_2__c,' +
            '            breg_Label_Override_Long__c,' +
            '            breg_Label_Override_Long2__c,' +
            '            breg_Component_Settings__c,' +
            '            breg_Source_Fields_Mapping__c,' +
            '            breg_Target_Fields_Mapping__c,' +
            '            breg_Component_Visibility_Rules__c,' +
            '            breg_Target_Default_Values__c,' +
            '            breg_Is_Internal_Only__c,' +
            '            breg_Is_Read_Only__c' +
            '     FROM breg_Form_Configuration_Items__r' +
            '     ORDER BY breg_Order__c)' +
            ' FROM breg_Form_Configuration__c' +
            ' WHERE ';

        if (formConfigId != null) {
            query += ' Id = :formConfigId';
        } else {
            if (formSuffix != null && businessProcess != null) {
                // Used for Annual forms
                query += ' breg_Business_Process__c = :businessProcess';
                query += ' AND breg_Suffix_Code__c = :formSuffix';
            } else {
                query +=
                    ' breg_Business_Process__c = :businessProcess' +
                    ' AND breg_Business_Location__c = :businessLocation' +
                    ' AND breg_Business_Structure__c = :businessStructure' +
                    ' AND breg_Profit_Type__c = :businessProfit' +
                    ' AND breg_Registration_Type__c = :registrationType' +
                    ' AND breg_Corporation_Type__c = :corporationType' +
                    ' AND breg_Cooperative_Type__c = :cooperativeType' +
                    ' AND breg_Stock_Type__c = :stockType' +
                    ' AND breg_Partnership_Type__c = :partnershipType';
            }
        }

        query += ' WITH USER_MODE ORDER BY breg_Linked_Form__c NULLS LAST';

        List<breg_Form_Configuration__c> formConfigs = Database.query(query);

        if (formConfigs.isEmpty()) {
            return null;
        }

        breg_Form_Configuration__c dbFormConfig = formConfigs[0];
        FormConfiguration formConfig = new FormConfiguration(dbFormConfig);
        Boolean isPortalUser = isPortalUser();

        for (breg_Form_Configuration_Item__c dbConfigItem : dbFormConfig.breg_Form_Configuration_Items__r) {
            // Skip internal-only items for portal users
            if (isPortalUser && dbConfigItem.breg_Is_Internal_Only__c == true) {
                continue;
            }

            FormElement element = new FormElement(dbConfigItem.Id, dbConfigItem.breg_Component_Name__c, (Integer) dbConfigItem.breg_Order__c);
            element.labelOverride = dbConfigItem.breg_Label_Override__c;
            element.labelOverride2 = dbConfigItem.breg_Label_Override_2__c;
            element.labelOverrideLong = dbConfigItem.breg_Label_Override_Long__c;
            element.labelOverrideLong2 = dbConfigItem.breg_Label_Override_Long2__c;
            element.targetFieldsMapping = dbConfigItem.breg_Target_Fields_Mapping__c;
            element.targetDefaultValues = dbConfigItem.breg_Target_Default_Values__c;
            element.sourceFieldsMapping = dbConfigItem.breg_Source_Fields_Mapping__c;
            element.componentSettings = dbConfigItem.breg_Component_Settings__c;
            element.componentVisibilityRules = dbConfigItem.breg_Component_Visibility_Rules__c;
            element.isReadOnly = dbConfigItem.breg_Is_Read_Only__c;
            formConfig.elements.add(element);
        }

        return formConfig;
    }

    public class FormConfiguration {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String prefix { get; set; }
        @AuraEnabled
        public String whatIsThisForm { get; set; }
        @AuraEnabled
        public Integer daysAfterSubmissionHoldApproval { get; set; }
        @AuraEnabled
        public String requiredInformation { get; set; }
        @AuraEnabled
        public String suffix { get; set; }
        @AuraEnabled
        public String formName { get; set; }
        @AuraEnabled
        public String formCode { get; set; }
        @AuraEnabled
        public String businessProcess { get; set; }
        @AuraEnabled
        public String businessLocation { get; set; }
        @AuraEnabled
        public String businessStructure { get; set; }
        @AuraEnabled
        public String businessProfit { get; set; }
        @AuraEnabled
        public String registrationType { get; set; }
        @AuraEnabled
        public String corporationType { get; set; }
        @AuraEnabled
        public String stockType { get; set; }
        @AuraEnabled
        public String partnershipType { get; set; }
        @AuraEnabled
        public String entityType { get; set; }
        @AuraEnabled
        public String linkedForm { get; set; }
        @AuraEnabled
        public List<FormElement> elements { get; set; }

        public FormConfiguration(breg_Form_Configuration__c formConfig) {
            this.id = formConfig.Id;
            this.prefix = formConfig.Name;
            this.formName = formConfig.breg_Form_Name__c;
            this.formCode = formConfig.breg_Form_Code__c;
            this.suffix = formConfig.breg_Suffix_Code__c;
            this.whatIsThisForm = (formConfig.breg_Form_Instruction_URL__c != null &&
                formConfig.breg_What_is_this_Form__c != null &&
                formConfig.breg_What_is_this_Form__c.contains('/{instructionURL}'))
                ? formConfig.breg_What_is_this_Form__c.replace('/{instructionURL}', formConfig.breg_Form_Instruction_URL__c)
                : formConfig.breg_What_is_this_Form__c;
            this.daysAfterSubmissionHoldApproval = formConfig.breg_Days_After_Submission_hold_Approval__c != null
                ? Integer.valueOf(formConfig.breg_Days_After_Submission_hold_Approval__c)
                : null;
            this.requiredInformation = formConfig.breg_Required_Information__c;
            this.businessProcess = formConfig.breg_Business_Process__c;
            this.businessLocation = formConfig.breg_Business_Location__c;
            this.businessStructure = formConfig.breg_Business_Structure__c;
            this.businessProfit = formConfig.breg_Profit_Type__c;
            this.registrationType = formConfig.breg_Registration_Type__c;
            this.corporationType = formConfig.breg_Corporation_Type__c;
            this.stockType = formConfig.breg_Stock_Type__c;
            this.partnershipType = formConfig.breg_Partnership_Type__c;
            this.entityType = formConfig.breg_Entity_Type__c;
            this.linkedForm = formConfig.breg_Linked_Form__c;
            this.elements = new List<FormElement>();
        }
    }

    public class FormElement {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public Integer order { get; set; }
        @AuraEnabled
        public String labelOverride { get; set; }
        @AuraEnabled
        public String labelOverride2 { get; set; }
        @AuraEnabled
        public String labelOverrideLong { get; set; }
        @AuraEnabled
        public String labelOverrideLong2 { get; set; }
        @AuraEnabled
        public String targetFieldsMapping { get; set; }
        @AuraEnabled
        public String targetDefaultValues { get; set; }
        @AuraEnabled
        public String sourceFieldsMapping { get; set; }
        @AuraEnabled
        public String componentSettings { get; set; }
        @AuraEnabled
        public String componentVisibilityRules { get; set; }
        @AuraEnabled
        public Boolean isReadOnly { get; set; }

        public FormElement(String id, String name, Integer order) {
            this.id = id;
            this.name = name;
            this.order = order;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isHomeWarningBannerEnabled() {
        BREG_Setting__c setting = BREG_Setting__c.getOrgDefaults();
        return setting != null && setting.Home_Warning_Banner_Enabled__c == true;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserInfo() {
        Boolean isGuest = UserInfo.getUserType() == 'Guest';
        if (isGuest) {
            return new Map<String, Object>{ 'isGuest' => true };
        }

        User u = [SELECT Contact.Name FROM User WHERE Id = :UserInfo.getUserId()];
        return new Map<String, Object>{ 'isGuest' => false, 'name' => u.Contact?.Name, 'id' => u.Id };
    }

    @AuraEnabled(cacheable=true)
    public static String getSSOUrl(String retUrl) {
        String loginUrl;
        if (Test.isRunningTest()) {
            loginUrl = '/services/auth/sso/sso';
        } else {
            loginUrl = Network.getLoginUrl(Network.getNetworkId());
        }
        String communityUrl = String.isNotBlank(loginUrl) ? loginUrl.replace('/login', '') : '';
        String startUrl = String.isNotBlank(retUrl) ? retUrl : '/?redirectAfterLogin=true';

        Auth.AuthConfiguration authConfig = new Auth.AuthConfiguration(communityUrl, startUrl);
        List<AuthProvider> authPrvs = authConfig.getAuthProviders();
        String ssoUrl = communityUrl + '/services/auth/sso/sso';

        return !authPrvs.isEmpty() ? ssoUrl : '/login';
    }

    @AuraEnabled
    public static Boolean needsProfileCompletion() {
        if (UserInfo.getUserType() == 'Guest') {
            return false;
        }
        User theUser = [SELECT BREG_Portal_Registration_Complete__c FROM User WHERE Id = :UserInfo.getUserId()];
        return !theUser.BREG_Portal_Registration_Complete__c;
    }


    @AuraEnabled
    public static void deleteCase(Id caseId) {
        Case caseToDelete = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
        delete caseToDelete;
    }

    @AuraEnabled(cacheable=true)
    public static Case getCaseWithRelations(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID cannot be null');
        }

        try {
            return BREGAddressProtectionUtils.cleanProtectedCaseData([
                SELECT
                    Id,
                    Subject,
                    Status,
                    breg_Amendment_Adoption_Date__c,
                    breg_Amendment_Adoption_Method__c,
                    //breg_Annual_Activities__c,
                    breg_Annual_Report_Filing_Year__c,
                    breg_Annual__c,
                    breg_Applicant_Entity_File__c,
                    breg_Applicant_Entity_Location__c,
                    breg_Applicant_Entity_Type_Description__c,
                    breg_Applicant_Entity_Type__c,
                    breg_Applicant_First_Name__c,
                    breg_Applicant_Is_Entity__c,
                    breg_Applicant_Last_Name__c,
                    breg_Applicant_Location_Type__c,
                    breg_Applicant_Name__c,
                    breg_Applicant_Origination_Type__c,
                    breg_Applicant_Status__c,
                    breg_Application_Amendment__c,
                    breg_Authorized_Shares_Class_Series__c,
                    breg_Authorized_Shares_Count__c,
                    breg_BRIM_FILE_NO__c,
                    breg_Boundaries__c,
                    breg_Bypass_Status_Change_Validation__c,
                    breg_Bypass_Validation__c,
                    breg_Cancellation_Date__c,
                    breg_Cancelled_Shares_Class_Series__c,
                    breg_Cancelled_Shares_Count__c,
                    breg_Class_Series__c,
                    breg_Classification__c,
                    breg_Company_Address__City__s,
                    breg_Company_Address__CountryCode__s,
                    breg_Company_Address_Has_Changed__c,
                    breg_Company_Address__StateCode__s,
                    breg_Company_Address_State__c,
                    breg_Company_Address__Street__s,
                    breg_Company_Address_Street2__c,
                    breg_Company_Address__PostalCode__s,
                    breg_Conversion_Approval_Method__c,
                    breg_Correction_Statement__c,
                    breg_Date_Of_Formation__c,
                    breg_Delinquent_Payment_Amount__c,
                    breg_Delivery_Address__City__s,
                    breg_Delivery_Address__CountryCode__s,
                    breg_Delivery_Address__PostalCode__s,
                    breg_Delivery_Address__Street__s,
                    breg_Delivery_Address__StateCode__s,
                    breg_Delivery_Address_State_Text__c,
                    breg_Delivery_Address_Street2__c,
                    breg_Delivery_Method__c,
                    breg_Designation_of_Membership__c,
                    breg_Dissociated_Member_Name__c,
                    breg_Dissolution_Date__c,
                    breg_Dissolution_Reason_Type__c,
                    breg_Dissolution_Reason__c,
                    breg_Document_To_Be_Corrected__c,
                    breg_Document_Type__c,
                    breg_Document__c,
                    breg_Duration_Period__c,
                    breg_ESWM_WFWORKITEM_ID__c,
                    breg_Effective_Date_Time_Formula_AM_PM__c,
                    breg_Effective_Date_Time_Formula_Time__c,
                    breg_Effective_Date_Time_Type__c,
                    breg_Effective_Date_Time__c,
                    breg_Effective_Date__c,
                    breg_Entity_Formed_Type__c,
                    breg_Entity_Jurisdiction_Has_Changed__c,
                    breg_Entity_Jurisdiction__c,
                    breg_Entity_name__c,
                    breg_Entity_Nature_Of_Business__c,
                    breg_Entity_Profit_Type__c,
                    breg_Entity_Term_To_Expire__c,
                    breg_Entity_Type_Description__c,
                    breg_Entity_Type_Has_Changed__c,
                    breg_Entity_Type__c,
                    breg_Entity__c,
                    breg_Expiration_Date__c,
                    breg_Fictitious_Name_Is_Included__c,
                    breg_File_Suffix__c,
                    breg_File__c,
                    breg_Filing_Date__c,
                    breg_Form_Code__c,
                    breg_Form_Configuration__c,
                    breg_Formation_State__c,
                    breg_Incorrect_Statement__c,
                    breg_Is_Allowed_Generate_Reinstatem_Cert__c,
                    breg_Is_Expiration_Date_Specified__c,
                    breg_Is_Manager_Managed__c,
                    breg_Is_Renewal__c,
                    breg_Last_Rejection_Date__c,
                    breg_Logo__c,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address_Has_Changed__c,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address_Number_and_Street_2__c,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address_State__c,
                    breg_Mailing_Address__PostalCode__s,
                    breg_Mailing_Date__c,
                    breg_Mailing_Status__c,
                    breg_Manner__c,
                    breg_Members_Liability_Details__c,
                    breg_Members_Liability_Type__c,
                    breg_Membership_Fees_Received__c,
                    breg_Name_for_Reservation__c,
                    breg_Name_Reserved_Is_New__c,
                    breg_Name_of_the_Entity__c,
                    breg_New_Entity_Jurisdiction__c,
                    breg_New_Entity_Name__c,
                    breg_New_Entity_Type__c,
                    breg_New_Registrant_Address_State_Text__c,
                    breg_New_Registrant_Address_Street_2__c,
                    breg_New_Registrant_Address__c,
                    breg_New_Registrant_Address__CountryCode__s,
                    breg_New_Registrant_Address__Street__s,
                    breg_New_Registrant_Address__StateCode__s,
                    breg_New_Registrant_Address__City__s,
                    breg_New_Registrant_Address__PostalCode__s,
                    breg_New_Registrant_Type__c,
                    breg_New_Registrant_First_Name__c,
                    breg_New_Registrant_Is_Entity__c,
                    breg_New_Registrant_Last_Name__c,
                    breg_New_Registrant_Name__c,
                    breg_New_Mailing_Address_State_Text__c,
                    breg_New_Mailing_Address_Street_2__c,
                    breg_New_Mailing_Address__c,
                    breg_New_Mailing_Address__CountryCode__s,
                    breg_New_Mailing_Address__Street__s,
                    breg_New_Mailing_Address__StateCode__s,
                    breg_New_Mailing_Address__City__s,
                    breg_New_Mailing_Address__PostalCode__s,
                    breg_New_Company_Address_State_Text__c,
                    breg_New_Company_Address_Street_2__c,
                    breg_New_Company_Address__c,
                    breg_New_Company_Address__CountryCode__s,
                    breg_New_Company_Address__Street__s,
                    breg_New_Company_Address__StateCode__s,
                    breg_New_Company_Address__City__s,
                    breg_New_Company_Address__PostalCode__s,
                    breg_No_Changes__c,
                    breg_Number_of_Delinquent_Annual_Reports__c,
                    breg_Number_of_Shareholders__c,
                    breg_Number_of_Shares_Against__c,
                    breg_Number_of_Shares_For__c,
                    breg_Number_of_Votes_Against__c,
                    breg_Number_of_Votes_For__c,
                    breg_Number_of_common_shares__c,
                    breg_Number_of_copies_to_be_certified__c,
                    breg_Number_of_initial_members__c,
                    breg_Organizing_Articles_Changes__c,
                    breg_Other_Amendment_Details__c,
                    breg_Outstanding_Shares_Class_Series__c,
                    breg_Outstanding_Shares_Count__c,
                    breg_Owned_Shares_Count__c,
                    breg_Paid_In_Amount__c,
                    breg_Par_Total__c,
                    breg_Par_Value_Of_Each_Share__c,
                    breg_Partnership_Begin_Business_Date__c,
                    breg_Partnership_Location_Type__c,
                    breg_Partnership_Location__c,
                    breg_Partnership_Type__c,
                    breg_Powers__c,
                    breg_Present_Registrant_Name__c,
                    breg_Print_Name_And_Office_Title__c,
                    breg_Processing_Speed__c,
                    breg_Property_Rights_Rule__c,
                    breg_Property_Rights__c,
                    breg_Provisions_Restrictions__c,
                    breg_Publication_Date_1__c,
                    breg_Publication_Date_2__c,
                    breg_Publication_Date_3__c,
                    breg_Publication_Date_4__c,
                    breg_Publication_Name__c,
                    breg_Publication_Type__c,
                    breg_Purpose_Organization_Is_Organized__c,
                    breg_Purposes__c,
                    breg_Qualification_Amendment_Option__c,
                    breg_Refund_Payment__c,
                    breg_Reg_Agent_Has_Changed__c,
                    breg_Registered_Agent_Address__City__s,
                    breg_Registered_Agent_Address__CountryCode__s,
                    breg_Reg_Agent_Address_Has_Changed__c,
                    breg_Reg_Agent_Address_State__c,
                    breg_Registered_Agent_Address__StateCode__s,
                    breg_Registered_Agent_Address__Street__s,
                    breg_Reg_Agent_Address_Street2__c,
                    breg_Registered_Agent_Address__PostalCode__s,
                    breg_Reg_Agent_Address__c,
                    breg_Reg_Agent_Entity_Location__c,
                    breg_Reg_Agent_Entity_Name__c,
                    breg_Reg_Agent_First_Name__c,
                    breg_Reg_Agent_Is_Entity__c,
                    breg_Reg_Agent_Last_Name__c,
                    breg_Reg_Agent_Type__c,
                    breg_Rejection_Reason_Description__c,
                    breg_Remaining_Shares_Class_Series__c,
                    breg_Remaining_Shares_Count__c,
                    breg_Renewal_for_Certificate_Number__c,
                    breg_Reopened_Date__c,
                    breg_Required_Statements__c,
                    breg_Resolution_Date__c,
                    breg_Resubmission_Due_Date__c,
                    breg_Resubmission_Received_Date__c,
                    breg_Signed_By_Company_Name__c,
                    breg_Signed_By_Entity_Name__c,
                    breg_Signed_By_Name__c,
                    breg_Signed_By_First_Name__c,
                    breg_Signed_By_Last_Name__c,
                    breg_Signed_By_Title__c,
                    breg_Signed_By_Title_Text__c,
                    breg_Signed_By_Office_Held__c,
                    breg_Signed_By__c,
                    breg_Signed_Date__c,
                    breg_Signature__c,
                    breg_Stock_Type__c,
                    breg_Submission_Date__c,
                    breg_Subscribe_Owner_Free_Email_Alerts__c,
                    breg_TNTMSM_Certificate__c,
                    breg_TNTMSM_Classification__c,
                    breg_TNTMSM_Description__c,
                    breg_TNTMSM_Entity_Type__c,
                    breg_TNTMSM_First_Used_Anywhere__c,
                    breg_TNTMSM_First_Used_Hawaii__c,
                    breg_TNTMSM_Goods_or_Services__c,
                    breg_TNTMSM_Is_Symbol_Included__c,
                    breg_TNTMSM_Mode_Or_Manner__c,
                    breg_TNTMSM_Registration_Type__c,
                    breg_TNTMSM_Type__c,
                    breg_TN_TM_SM__c,
                    breg_Terms__c,
                    breg_The_Corporation_Has_Members__c,
                    breg_Total_Number_of_Memberships__c,
                    breg_Total_Number_of_Shares__c,
                    breg_Total_Number_of_Votes__c,
                    breg_Update_Child_Entity__c,
                    breg_Written_Approval_Type__c,
                    breg_Written_Consent_Date__c,
                    breg_Years_of_Delinquent_Annual_Reports__c,
                    breg_GP_Case__c,
                    breg_Is_LLP_Registration__c,
                    breg_GP_Entity_Name__c,
                    breg_GP_Entity__c,
                    breg_GP_Already_Registered__c,
                    ParentId,
                    (
                        SELECT
                            Id,
                            breg_Account__c,
                            breg_Address_State_Text__c,
                            breg_Address_Street_2__c,
                            breg_Address__c,
                            breg_Address__CountryCode__s,
                            breg_Address__Street__s,
                            breg_Address__StateCode__s,
                            breg_Address__City__s,
                            breg_Address__PostalCode__s,
                            breg_As_of_Date__c,
                            breg_Case__c,
                            breg_Contact__c,
                            breg_End_Date__c,
                            breg_Entity_Location__c,
                            breg_Entity_Location_Country__c,
                            breg_Entity_Name__c,
                            breg_Entity_Type_Description__c,
                            breg_Entity_Type__c,
                            breg_Entity__c,
                            breg_File__c,
                            breg_First_Name__c,
                            breg_Last_Name__c,
                            breg_Number_of_shares__c,
                            breg_Officer_Director_Titles__c,
                            breg_Officer_Director_Other_Title__c,
                            breg_Titles_Are_Vacant__c,
                            breg_Role__c,
                            breg_Start_Date__c,
                            breg_TN_TM_SM__c,
                            breg_Transaction__c,
                            breg_Type__c,
                            breg_Title__c,
                            breg_Officer_Director_Titles_Formula__c,
                            breg_Title_Text__c,
                            breg_Signed_By_First_Name__c,
                            breg_Signed_By_Last_Name__c,
                            breg_Signature__c
                        FROM Account_Affiliations__r // breg_Account_Affiliation__c
                        WHERE breg_To_Remove__c = false
                    ),
                    (
                        SELECT
                            Id,
                            breg_Stock_Class__c,
                            breg_Number_of_Issued_Shares__c,
                            breg_Account__c,
                            breg_Case__c,
                            breg_Class_Series__c,
                            breg_Per_Value__c,
                            breg_Stock_Amount__c,
                            breg_Paid_Shares__c,
                            breg_Class_Detail__c,
                            breg_Remarks__c
                        FROM Stocks__r
                        WHERE breg_End_Date__c = NULL AND breg_Start_Date__c = NULL
                        ORDER BY breg_Stock_Class__c ASC
                    ),
                    (
                        SELECT Id, Name, breg_Docusign_Document_Id__c, breg_Type__c, breg_Case__c, breg_Form_Configuration_Item__c
                        FROM Documents__r
                        WHERE breg_Form_Configuration_Item__c != NULL
                        ORDER BY CreatedDate DESC
                    )
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ]);
        } catch (Exception e) {
            System.debug('Error retrieving case: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve case record: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String getGP1Form(String residenceCountry) {
        try {
            String suffix;
            if (residenceCountry == 'US') {
                suffix = 'G5';
            } else
                suffix = 'G6';
            return [
                SELECT Id
                FROM breg_Form_Configuration__c
                WHERE Name = 'GP-1' AND breg_Suffix_Code__c = :suffix
                LIMIT 1
            ]
            .Id;
        } catch (Exception ex) {
            System.debug('*** BREGRegistrationFormController.getGP1Form' + ex.getMessage() + '\n' + ex.getStackTraceString());
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public class CaseWithdrawalDataWrapper {
        @AuraEnabled
        public Id parentCaseId;
        @AuraEnabled
        public String entityName;
        @AuraEnabled
        public String workitemNumber;
        @AuraEnabled
        public Date submissionDate;
        @AuraEnabled
        public String formCode;
        @AuraEnabled
        public String formName;
        @AuraEnabled
        public Decimal totalAmount;
    }

    @AuraEnabled
    public static List<CaseWithdrawalDataWrapper> getCasesForWithdrawal(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            throw new AuraHandledException('Case IDs cannot be null or empty');
        }

        try {
            Map<Id, Case> casesById = getCasesByIdForWithdrawal(caseIds);
            Set<Id> transactionIds = getTransactionIdsFromCases(casesById.values());
            Map<Id, Transaction__c> transactionsById = getTransactionsById(transactionIds);

            List<CaseWithdrawalDataWrapper> results = new List<CaseWithdrawalDataWrapper>();
            for (Id caseId : caseIds) {
                results.add(buildCaseWithdrawalWrapper(casesById.get(caseId), transactionsById));
            }

            return results;
        } catch (Exception e) {
            System.debug('Error retrieving case for withdrawal: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve case record for withdrawal: ' + e.getMessage());
        }
    }

    private static Map<Id, Case> getCasesByIdForWithdrawal(List<Id> caseIds) {
        return new Map<Id, Case>(
            [
                SELECT
                    Id,
                    breg_Entity_name__c,
                    breg_Workitem_Number__c,
                    breg_Form_Code__c,
                    breg_Submission_Date__c,
                    breg_Form_Configuration__r.breg_Form_Name__c,
                    (
                        SELECT Transaction__c
                        FROM Transaction_Lines__r
                        LIMIT 1
                    )
                FROM Case
                WHERE Id IN :caseIds
            ]
        );
    }

    private static Set<Id> getTransactionIdsFromCases(List<Case> caseRecords) {
        Set<Id> transactionIds = new Set<Id>();

        for (Case caseRecord : caseRecords) {
            if (!caseRecord.Transaction_Lines__r.isEmpty() && caseRecord.Transaction_Lines__r[0].Transaction__c != null) {
                transactionIds.add(caseRecord.Transaction_Lines__r[0].Transaction__c);
            }
        }

        return transactionIds;
    }

    private static Map<Id, Transaction__c> getTransactionsById(Set<Id> transactionIds) {
        if (transactionIds.isEmpty()) {
            return new Map<Id, Transaction__c>();
        }

        return new Map<Id, Transaction__c>(
            [
                SELECT Id, TotalAmount__c
                FROM Transaction__c
                WHERE Id IN :transactionIds
            ]
        );
    }

    private static CaseWithdrawalDataWrapper buildCaseWithdrawalWrapper(Case caseRecord, Map<Id, Transaction__c> transactionsById) {
        CaseWithdrawalDataWrapper result = new CaseWithdrawalDataWrapper();

        if (caseRecord == null) {
            return result;
        }

        result.parentCaseId = caseRecord.Id;
        result.entityName = caseRecord.breg_Entity_name__c;
        result.workitemNumber = caseRecord.breg_Workitem_Number__c;
        result.submissionDate = caseRecord.breg_Submission_Date__c == null ? null : caseRecord.breg_Submission_Date__c.date();
        result.formCode = caseRecord.breg_Form_Code__c;
        result.formName = caseRecord.breg_Form_Configuration__r == null ? null : caseRecord.breg_Form_Configuration__r.breg_Form_Name__c;

        if (!caseRecord.Transaction_Lines__r.isEmpty()) {
            Id transactionId = caseRecord.Transaction_Lines__r[0].Transaction__c;
            Transaction__c transactionRecord = transactionsById.get(transactionId);
            result.totalAmount = transactionRecord == null ? null : transactionRecord.TotalAmount__c;
        }

        return result;
    }

    /**
     * @description Check if the current user is a portal user (Guest or authenticated community user)
     * @return Boolean true if portal user, false if internal user
     */
    private static Boolean isPortalUser() {
        // Guest users are portal users
        if (UserInfo.getUserType() == 'Guest') {
            return true;
        }

        // Check if user has a ContactId (community/portal users have ContactId, internal users don't)
        User currentUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return currentUser.ContactId != null;
    }

    public static List<breg_Document__c> getDocuments(Set<Id> docIds) {
        return [
            SELECT Id, Name, breg_Case__c, breg_Docusign_Document_Id__c, breg_Template_Document__r.breg_Docusign_Document_Id__c, breg_Template_Document__r.breg_Case__c, breg_Template_Document__r.Name
            FROM breg_Document__c
            WHERE Id IN :docIds
        ];
    }
}