public without sharing class BREGAccountAffiliationController {
    @AuraEnabled(cacheable=true)
    public static Account getAccountWithRelationshipsById(String accId) {
        if (String.isBlank(accId)) {
            throw new AuraHandledException('Account ID is required');
        }
        return getAccountWithRelationships(accId, null);
    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountWithRelationshipsByFileNumber(String fileNumber) {
        if (String.isBlank(fileNumber)) {
            throw new AuraHandledException('Account File Number is required');
        }
        return getAccountWithRelationships(null, fileNumber);
    }

    public static Account getAccountWithRelationships(String accId, String fileNumber) {
        try {
            return BREGAddressProtectionUtils.cleanProtectedAccountData([
                SELECT
                    Id,
                    Name,
                    Description,
                    breg_Billing_Address_State_Text__c,
                    breg_Billing_Address_Street_2__c,
                    BillingCountryCode,
                    BillingCountry,
                    BillingStreet,
                    BillingCity,
                    BillingState,
                    BillingStateCode,
                    BillingPostalCode,
                    ShippingCountryCode,
                    ShippingCountry,
                    ShippingStreet,
                    ShippingCity,
                    ShippingState,
                    ShippingStateCode,
                    ShippingPostalCode,
                    breg_Additional_Entity_States__c,
                    breg_Annuals_Due_Date__c,
                    breg_BRIM_BUSINESS_ID__c,
                    breg_BRIM_CRA_FL__c,
                    breg_BRIM_FILE_NO__c,
                    breg_BRIM_LICENSE_YEAR__c,
                    breg_BRIM_LIMIT_1__c,
                    breg_BRIM_LIMIT_2__c,
                    breg_BRIM_LIMIT_DT__c,
                    breg_BRIM_LLP_FL__c,
                    breg_BRIM_MISSING_OFFICERS_FL__c,
                    breg_BRIM_NO_MEMBERS_FL__c,
                    breg_BRIM_PARTNER_MAINTENANCE__c,
                    breg_BRIM_SECURITY_DEALER_FL__c,
                    breg_Business_Structure__c,
                    breg_Certified_Register_Agent__c,
                    breg_Commence_Date__c,
                    breg_Consent__c,
                    breg_Formation_Country__c,
                    breg_Creator__c,
                    breg_Date_of_dissol_cancel_revoc_term__c,
                    breg_End_Date__c,
                    breg_Entity_Status__c,
                    breg_Entity_Type_Description__c,
                    breg_Entity_Type__c,
                    breg_ExcludedFromInvoluntaryDissolution__c,
                    breg_Expiration_Date__c,
                    breg_File_Suffix__c,
                    breg_File__c,
                    breg_Formation_Date__c,
                    breg_Good_Standing__c,
                    breg_Incorporation_Date__c,
                    breg_Issued_Date_For_Status_2_Notice__c,
                    breg_Last_Annual_Filed_Date__c,
                    breg_Location_Type__c,
                    breg_Mailing_Address__c,
                    breg_Mailing_Address_Street_2__c,
                    breg_Mailing_Address_State_Text__c,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__PostalCode__s,
                    breg_Management_Type__c,
                    breg_No_Members_flag__c,
                    breg_Notes__c,
                    breg_Partner_Term__c,
                    breg_Pending_Transaction__c,
                    breg_Purpose__c,
                    breg_Record_Type__c,
                    breg_Reserved_for_Entity_Type__c,
                    breg_Registrant_Address__c,
                    breg_Registrant_Address__CountryCode__s,
                    breg_Registrant_Address__Street__s,
                    breg_Registrant_Address_Street_2__c,
                    breg_Registrant_Address__StateCode__s,
                    breg_Registrant_Address__City__s,
                    breg_Registrant_Address__PostalCode__s,
                    breg_Registrant_First_Name__c,
                    breg_Registrant_Last_Name__c,
                    breg_Registrant_Name__c,
                    breg_Registrant_Type__c,
                    breg_Registration_Date__c,
                    breg_Reinstatement_Due_Date__c,
                    breg_Reinstatement_Effective_Date__c,
                    breg_Renewal_Date__c,
                    breg_Send_a_free_email_alert__c,
                    breg_Similar_Name__c,
                    breg_Start_Date__c,
                    breg_Formation_State__c,
                    breg_Formation_State_Label__c,
                    breg_Status_Effective_Date__c,
                    breg_Subscribe_Owner_Free_Email_Alerts__c,
                    breg_Term__c,
                    breg_Transaction__c,
                    breg_Vote_Date__c,
                    breg_Vote__c,
                    breg_Xref_Name_1__c,
                    breg_Xref_Name_2__c,
                    breg_Number_of_initial_members__c,
                    breg_Is_Manager_Managed__c,
                    (
                        SELECT
                            Id,
                            Name,
                            breg_Account__c,
                            breg_Account__r.breg_BRIM_CRA_FL__c,
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
                            breg_Contact__r.AccountId,
                            breg_Contact__r.FirstName,
                            breg_Contact__r.LastName,
                            breg_Contact__r.MailingStreet,
                            breg_Contact__r.MailingCity,
                            breg_Contact__r.MailingState,
                            breg_Contact__r.MailingStateCode,
                            breg_Contact__r.MailingPostalCode,
                            breg_Contact__r.MailingCountry
                        FROM breg_Account_Affiliations_Entity__r
                        WHERE breg_End_Date__c = NULL AND breg_Status__c = 'A'
                    ),
                    (
                        SELECT Id, breg_Status__c, breg_Filing_Date__c, breg_Filing_Due_Date__c, breg_Filing_Year__c, breg_Received_Date__c
                        FROM Annuals__r
                        WHERE breg_Status__c IN ('N', 'D')
                        ORDER BY breg_Filing_Date__c ASC
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
                            breg_Remarks__c,
                            breg_Start_Date__c,
                            breg_End_Date__c
                        FROM Stocks__r
                        WHERE breg_End_Date__c = NULL AND breg_Start_Date__c != NULL
                        ORDER BY breg_Stock_Class__c ASC
                    ),
                    (
                        SELECT Id, breg_Entity_Type__c
                        FROM ChildAccounts
                        WHERE breg_Entity_Type__c IN ('G5', 'G6')
                        LIMIT 1
                    )
                FROM Account
                WHERE Id = :accId OR ((breg_File__c = :fileNumber OR breg_File__c LIKE :(fileNumber + ' %')) AND breg_File__c != NULL)
                LIMIT 1
            ]);
        } catch (Exception e) {
            System.debug('Error retrieving case: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve case record: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static breg_TN_TM_SM__c getTNTMSMWithRelationships(String tntmsmId) {
        try {
            return BREGAddressProtectionUtils.cleanProtectedTNTMSMData([
                SELECT
                    Id,
                    Pending_Transaction__c,
                    breg_Account_Name__c,
                    breg_Account__c,
                    breg_Additional_Entity_States__c,
                    breg_BRIM_TRADE_MARK_ID__c,
                    breg_Cancellation_Date__c,
                    breg_Cert_Date__c,
                    breg_Cert_Number__c,
                    breg_Certificate__c,
                    breg_Consent__c,
                    breg_Descriptors__c,
                    breg_Details__c,
                    breg_DocuSign_Envelope_Document__c,
                    breg_End_Date__c,
                    breg_Entity_Nature_Of_Business__c,
                    breg_Expiration_Date__c,
                    breg_File_Suffix__c,
                    breg_File__c,
                    breg_Last_Renewal_Case__c,
                    breg_Last_Renewal_Submission_Date__c,
                    breg_Mailing_Address__c,
                    breg_Notes__c,
                    breg_Purpose__c,
                    breg_Registrant_Address__c,
                    breg_Registrant_First_Name__c,
                    breg_Registrant_Last_Name__c,
                    breg_Registrant_Name__c,
                    breg_Registrant_Type__c,
                    breg_Registration_Date__c,
                    breg_Registration_Type__c,
                    breg_Similar_Name__c,
                    breg_Start_Date__c,
                    breg_Status__c,
                    breg_Subscribe_Owner_Free_Email_Alerts__c,
                    breg_TM_SM_Category__c,
                    breg_Trade_Name__c,
                    breg_Trade_Type__c,
                    breg_Transaction__c,
                    breg_Type__c,
                    breg_XREF_Name1__c,
                    breg_XREF_Name2__c,
                    breg_Mailing_Address__CountryCode__s,
                    breg_Mailing_Address__Street__s,
                    breg_Mailing_Address__StateCode__s,
                    breg_Mailing_Address__City__s,
                    breg_Mailing_Address__PostalCode__s,
                    (
                        SELECT
                            Id,
                            Name,
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
                            breg_Contact__r.AccountId,
                            breg_Contact__r.FirstName,
                            breg_Contact__r.LastName,
                            breg_Contact__r.MailingStreet,
                            breg_Contact__r.MailingCity,
                            breg_Contact__r.MailingState,
                            breg_Contact__r.MailingStateCode,
                            breg_Contact__r.MailingPostalCode,
                            breg_Contact__r.MailingCountry
                        FROM breg_Account_Affiliations__r
                        WHERE breg_End_Date__c = NULL AND breg_Status__c = 'A'
                    )
                FROM breg_TN_TM_SM__c
                WHERE Id = :tntmsmId
                LIMIT 1
            ]);
        } catch (Exception e) {
            System.debug('Error retrieving case: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve case record: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<breg_Stock__c> getHistoricalStocks(String accId) {
        List<breg_Stock__c> allHistoricalStocks = [
            SELECT
                breg_Stock_Class__c,
                breg_Number_of_Issued_Shares__c,
                breg_Class_Series__c,
                breg_Per_Value__c,
                breg_Stock_Amount__c,
                breg_Paid_Shares__c,
                breg_Class_Detail__c,
                breg_Start_Date__c,
                breg_End_Date__c
            FROM breg_Stock__c
            WHERE breg_End_Date__c != NULL AND breg_Account__c = :accId
            ORDER BY breg_Stock_Class__c ASC, breg_End_Date__c DESC
        ];

        List<breg_Stock__c> filteredStocks = new List<breg_Stock__c>();
        Set<String> processedClasses = new Set<String>();

        for (breg_Stock__c stock : allHistoricalStocks) {
            if (!processedClasses.contains(stock.breg_Stock_Class__c)) {
                processedClasses.add(stock.breg_Stock_Class__c);
                filteredStocks.add(stock);
            }
        }

        return filteredStocks;
    }
}