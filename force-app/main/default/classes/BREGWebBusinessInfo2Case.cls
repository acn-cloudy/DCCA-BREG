public with sharing class BREGWebBusinessInfo2Case extends BREGWebDataItemMapper {
    private static final String SOURCE_TABLE = 'breg_WEB_WEB_BUSINESS_INFO__c';

    public BREGWebBusinessInfo2Case(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        super(wrappersByWorkitemId, SOURCE_TABLE);
    }

    public override Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Map<String, List<SObject>> resultsByWorkitemId = super.PrepareData(workitemIds);

        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            breg_WEB_WEB_BUSINESS_INFO__c businessInfo = (breg_WEB_WEB_BUSINESS_INFO__c) records[0];
            Case webCase = wrappersByWorkitemId.get(workitemId).WebCase;

            // check if this mapping is correct
            webCase.breg_BRIM_FILE_NO__c = businessInfo.breg_WEB_FILE_NO__c;
            webCase.breg_File_Suffix__c = businessInfo.breg_WEB_FILE_SUFFIX__c;
            webCase.breg_Entity_Type__c = businessInfo.breg_WEB_FILE_SUFFIX__c;

            // Date mapping
            webCase.breg_Partnership_Begin_Business_Date__c = businessInfo.breg_WEB_COMMENCE_DT__c;
            webCase.breg_Date_Of_Formation__c = businessInfo.breg_WEB_INCORPORATION_DT__c ?? businessInfo.breg_WEB_ORGANIZATION_DT__c;
            if (webCase.breg_Expiration_Date__c == null) {
                webCase.breg_Expiration_Date__c = businessInfo.breg_WEB_EXPIRATION_DT__c;
            }

            // Location mapping
            webCase.breg_Entity_Jurisdiction__c = businessInfo.breg_WEB_COUNTRY_OF_INC__c ?? 'US';
            Integer localityOfIncorporationId = businessInfo.breg_WEB_LOCALITY_OF_INC__c == null
                ? null
                : businessInfo.breg_WEB_LOCALITY_OF_INC__c.intValue();
            webCase.breg_Formation_State__c = BREGZipCodeUtils.getStateCodeById(localityOfIncorporationId) ?? 'HI';

            if (businessInfo.breg_WEB_PURPOSE__c != null) {
                webCase.breg_Purposes__c = businessInfo.breg_WEB_PURPOSE__c != null ? businessInfo.breg_WEB_PURPOSE__c.left(3000) : null;
                webCase.breg_Entity_Nature_Of_Business__c = businessInfo.breg_WEB_PURPOSE__c;
            }

            webCase.breg_The_Corporation_Has_Members__c = 
                businessInfo.breg_WEB_NO_MEMBERS_FL__c != null && businessInfo.breg_WEB_NO_MEMBERS_FL__c == 'Y' 
                ? true : false;

            // LLC specific fields
            webCase.breg_Number_of_initial_members__c = businessInfo.breg_WEB_INITIAL_LLC_MEMBERS__c;
            webCase.breg_Is_Manager_Managed__c = businessInfo.breg_WEB_PARTNER_MAINTENANCE__c == 'MGR' ? true : false;
            if (businessInfo.breg_WEB_PARTNER_TERMS__c != null && businessInfo.breg_WEB_PARTNER_TERMS__c == 'AT-WILL') {
                webCase.breg_Duration_Period__c = 'At-will';
            }

            // Limits
            webCase.breg_BRIM_LIMIT_1__c = businessInfo.breg_WEB_LIMIT_1__c;
            webCase.breg_BRIM_LIMIT_2__c = businessInfo.breg_WEB_LIMIT_2__c;
            webCase.breg_BRIM_LIMIT_DT__c = businessInfo.breg_WEB_LIMIT_DT__c;
        }

        return resultsByWorkitemId;
    }
}