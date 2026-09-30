public with sharing class BREGAnnualRobotTestHelper {
    public class AnnualCaseInput {
        public Account entity;
        public Contact contactRecord;
        public Id annualFormId;
        public Id annualId;
        public String filingYear;
        public String workItemSeed;
        public Boolean noChanges;
        public String robotStatus;
        public Boolean overridePayment;
    }

    public static Account prepareEntity(String fileNumber) {
        Account entity = [
            SELECT Id, breg_File__c, breg_Entity_Type__c, breg_Entity_Status__c, breg_Incorporation_Date__c, breg_Bounced_Check__c, breg_BRIM_CRA_FL__c
            FROM Account
            LIMIT 1
        ];
        entity.breg_File__c = fileNumber;
        entity.breg_Entity_Type__c = 'D1';
        entity.breg_Entity_Status__c = 'Active (A)';
        entity.breg_Incorporation_Date__c = Date.today().addYears(-2);
        entity.breg_Bounced_Check__c = false;
        entity.breg_BRIM_CRA_FL__c = false;
        update entity;
        return entity;
    }

    public static Contact createContact(String seed) {
        Contact contactRecord = new Contact(FirstName = seed, LastName = 'Contact');
        insert contactRecord;
        return contactRecord;
    }

    public static Id getAnnualFormId() {
        breg_Form_Configuration__c annualForm = [
            SELECT Id, breg_Form_Code__c
            FROM breg_Form_Configuration__c
            WHERE breg_Business_Process__c = 'Annual Report'
            LIMIT 1
        ];
        if (annualForm.breg_Form_Code__c != 'ANN-DNP-1') {
            annualForm.breg_Form_Code__c = 'ANN-DNP-1';
            update annualForm;
        }
        return annualForm.Id;
    }

    public static breg_Annual__c createAnnual(Id entityId, Integer filingYear) {
        breg_Annual__c annualRecord = new breg_Annual__c(
            breg_Account__c = entityId,
            breg_Status__c = 'D',
            breg_Filing_Date__c = Date.today().addDays(-10),
            breg_Filing_Year__c = String.valueOf(filingYear),
            breg_Received_Date__c = System.now().addDays(-1)
        );
        insert annualRecord;
        return annualRecord;
    }

    public static AnnualCaseInput buildAnnualCaseInput(
        Account entity,
        Contact contactRecord,
        Id annualFormId,
        Id annualId,
        String filingYear,
        String workItemSeed,
        Boolean noChanges,
        String robotStatus,
        Boolean overridePayment
    ) {
        AnnualCaseInput input = new AnnualCaseInput();
        input.entity = entity;
        input.contactRecord = contactRecord;
        input.annualFormId = annualFormId;
        input.annualId = annualId;
        input.filingYear = filingYear;
        input.workItemSeed = workItemSeed;
        input.noChanges = noChanges;
        input.robotStatus = robotStatus;
        input.overridePayment = overridePayment;
        return input;
    }

    public static Case createAnnualCase(AnnualCaseInput input) {
        Account entityRecord = [
            SELECT Name, breg_Entity_Type__c, breg_Purpose__c, breg_Number_of_initial_members__c,
                   breg_Membership_Fees_Received__c, breg_Number_of_Shareholders__c,
                   BillingStreet, BillingCity, BillingStateCode, BillingPostalCode, BillingCountryCode,
                   breg_Billing_Address_Street_2__c, breg_Mailing_Address__Street__s,
                   breg_Mailing_Address_Street_2__c, breg_Mailing_Address__City__s,
                   breg_Mailing_Address__StateCode__s, breg_Mailing_Address__CountryCode__s,
                   breg_Mailing_Address__PostalCode__s
            FROM Account
            WHERE Id = :input.entity.Id
        ];

        Case caseRecord = new Case(
            Subject = 'Annual Robot Test ' + input.workItemSeed,
            Status = 'Received',
            Origin = 'Web',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('BREG_Case').getRecordTypeId(),
            ContactId = input.contactRecord == null ? null : input.contactRecord.Id,
            breg_No_Changes__c = input.noChanges,
            breg_Form_Configuration__c = input.annualFormId,
            breg_Form_Code__c = 'ANN-DNP-1',
            breg_Entity__c = input.entity.Id,
            breg_File__c = input.entity.breg_File__c,
            breg_Workitem_Number__c = input.workItemSeed,
            breg_Submission_Date__c = System.now().addHours(-1),
            breg_Annual_Report_Filing_Year__c = input.filingYear,
            breg_Annual__c = input.annualId,
            breg_Annual_Robot_Status__c = input.robotStatus,
            breg_Override_Payment__c = input.overridePayment,
            breg_Name_of_the_Entity__c = entityRecord.Name,
            breg_Entity_Type__c = entityRecord.breg_Entity_Type__c,
            breg_Entity_Nature_Of_Business__c = entityRecord.breg_Purpose__c,
            breg_Number_of_initial_members__c = entityRecord.breg_Number_of_initial_members__c,
            breg_Membership_Fees_Received__c = entityRecord.breg_Membership_Fees_Received__c,
            breg_Number_of_Shareholders__c = entityRecord.breg_Number_of_Shareholders__c,
            breg_Mailing_Address__Street__s = entityRecord.breg_Mailing_Address__Street__s,
            breg_Mailing_Address_Number_and_Street_2__c = entityRecord.breg_Mailing_Address_Street_2__c,
            breg_Mailing_Address__City__s = entityRecord.breg_Mailing_Address__City__s,
            breg_Mailing_Address__StateCode__s = entityRecord.breg_Mailing_Address__StateCode__s,
            breg_Mailing_Address__CountryCode__s = entityRecord.breg_Mailing_Address__CountryCode__s,
            breg_Mailing_Address__PostalCode__s = entityRecord.breg_Mailing_Address__PostalCode__s,
            breg_Company_Address__Street__s = entityRecord.BillingStreet,
            breg_Company_Address_Street2__c = entityRecord.breg_Billing_Address_Street_2__c,
            breg_Company_Address__City__s = entityRecord.BillingCity,
            breg_Company_Address__StateCode__s = entityRecord.BillingStateCode,
            breg_Company_Address__CountryCode__s = entityRecord.BillingCountryCode,
            breg_Company_Address__PostalCode__s = entityRecord.BillingPostalCode
        );
        insert caseRecord;
        attachMatchingAffiliationsAndStocksToCase(caseRecord.Id, input.entity.Id);
        return caseRecord;
    }

    public static void attachMatchingAffiliationsAndStocksToCase(Id caseId, Id entityId) {
        List<breg_Account_Affiliation__c> entityAffs = [
            SELECT breg_Role__c, breg_Type__c, breg_Entity_Name__c, breg_Entity_Location__c,
                   breg_Entity_Location_Country__c, breg_First_Name__c, breg_Last_Name__c,
                   breg_Address__CountryCode__s, breg_Address__Street__s, breg_Address_Street_2__c,
                   breg_Address__StateCode__s, breg_Address_State_Text__c, breg_Address__City__s,
                   breg_Address__PostalCode__s, breg_Officer_Director_Titles__c
            FROM breg_Account_Affiliation__c
            WHERE breg_Entity__c = :entityId AND breg_End_Date__c = null AND breg_Status__c = 'A'
        ];
        List<breg_Account_Affiliation__c> caseAffs = new List<breg_Account_Affiliation__c>();
        for (breg_Account_Affiliation__c aff : entityAffs) {
            breg_Account_Affiliation__c caseAff = aff.clone(false, true, false, false);
            caseAff.breg_Case__c = caseId;
            caseAff.breg_Entity__c = null;
            caseAffs.add(caseAff);
        }
        if (!caseAffs.isEmpty()) {
            insert caseAffs;
        }

        List<breg_Stock__c> entityStocks = [
            SELECT breg_Class_Series__c, breg_Per_Value__c, breg_Class_Detail__c,
                   breg_Number_of_Issued_Shares__c, breg_Paid_Shares__c, breg_Remarks__c,
                   breg_Stock_Amount__c, breg_Stock_Class__c
            FROM breg_Stock__c
            WHERE breg_Account__c = :entityId AND breg_Start_Date__c != null AND breg_End_Date__c = null
        ];
        List<breg_Stock__c> caseStocks = new List<breg_Stock__c>();
        for (breg_Stock__c stock : entityStocks) {
            breg_Stock__c caseStock = stock.clone(false, true, false, false);
            caseStock.breg_Case__c = caseId;
            caseStock.breg_Account__c = null;
            caseStock.breg_Start_Date__c = null;
            caseStock.breg_End_Date__c = null;
            caseStocks.add(caseStock);
        }
        if (!caseStocks.isEmpty()) {
            insert caseStocks;
        }
    }

    public static breg_Document__c createPublicInitialFilingDocument(Case caseRecord) {
        breg_Document__c documentRecord = new breg_Document__c(
            Name = caseRecord.Subject + ' - Initial Filing.pdf',
            breg_Case__c = caseRecord.Id,
            breg_Docusign_Document_Id__c = 'doc-' + caseRecord.Id,
            breg_Is_Public__c = true,
            breg_Is_Irrelevant__c = false,
            breg_Is_Initial_Filing__c = true
        );
        insert documentRecord;
        return documentRecord;
    }
}