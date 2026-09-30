public with sharing class BREGWebTradeMarks2Case extends BREGWebDataItemMapper {
    private static final String SOURCE_TABLE = 'breg_WEB_WEB_TRADE_MARKS__c';
    private static final Map<String, String> CASE_FORM_CODE_BY_WEB_FORM_TYPE = new Map<String, String>{
        'T1' => 'T-1',
        'T2' => 'T-2',
        'T3' => 'T-3'
    };
    private static final Map<String, String> SUBJECT_BY_FORM_CODE = new Map<String, String>{
        'T-1' => 'Trade Name T-1',
        'T-2' => 'Trademark T-2',
        'T-3' => 'Service Mark T-3'
    };

    @TestVisible
    private static final Map<String, String> TRADE_TYPE_MAP = new Map<String, String>{
        'TN' => 'Trade Name',
        'TM' => 'Trademark',
        'SM' => 'Service Mark',
        'PR' => 'Publicity Rights Name'
    };

    public BREGWebTradeMarks2Case(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        super(wrappersByWorkitemId, SOURCE_TABLE);
    }

    public override Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Map<String, List<SObject>> resultsByWorkitemId = super.PrepareData(workitemIds);
        Map<String, breg_WEB_WEB_FILING_INFO__c> filingInfoByWorkitemId = getFilingInfoByWorkitemId(workitemIds);
        Map<String, List<breg_TN_TM_SM__c>> relatedTnTmSmsByWorkitemId = getRelatedTnTmSmsByWorkitemId(
            resultsByWorkitemId,
            filingInfoByWorkitemId
        );

        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            BREGWebFilingWrapper webFilingWrapper = wrappersByWorkitemId.get(workitemId);
            if (webFilingWrapper == null) {
                continue;
            }

            mapToCaseFields(
                (breg_WEB_WEB_TRADE_MARKS__c) records[0],
                filingInfoByWorkitemId.get(workitemId),
                relatedTnTmSmsByWorkitemId.get(workitemId),
                webFilingWrapper.WebCase
            );

            // if (webFilingWrapper.WebCase.breg_Entity__c != null) {
            //     for (SObject record : records) {
            //         webFilingWrapper.TradeMarks.add(
            //             buildTradeMark((breg_WEB_WEB_TRADE_MARKS__c) record, webFilingWrapper.WebCase.breg_Entity__c, workitemId)
            //         );
            //     }
            // }
        }

        return resultsByWorkitemId;
    }

    private void mapToCaseFields(
        breg_WEB_WEB_TRADE_MARKS__c webTradeMark,
        breg_WEB_WEB_FILING_INFO__c webFilingInfo,
        List<breg_TN_TM_SM__c> relatedTnTmSms,
        Case webCase
    ) {
        webCase.breg_TNTMSM_Type__c = TRADE_TYPE_MAP.get(webTradeMark.breg_WEB_TRADE_TYPE__c);
        webCase.breg_TNTMSM_Certificate__c = webTradeMark.breg_WEB_CERTIFICATE_NO__c != null // empty on web objects
            ? String.valueOf(webTradeMark.breg_WEB_CERTIFICATE_NO__c.intValue())
            : null;
        webCase.breg_TNTMSM_Description__c = webTradeMark.breg_WEB_TRADE_NAME__c;

        webCase.breg_Applicant_Origination_Type__c = 'Originator';

        if (String.isBlank(webCase.breg_TNTMSM_Certificate__c) && relatedTnTmSms != null && !relatedTnTmSms.isEmpty()) {
            webCase.breg_TNTMSM_Certificate__c = relatedTnTmSms[0].breg_Cert_Number__c;
            webCase.breg_TNTMSM_Registration_Type__c = 'Renewal';
        } else {
            webCase.breg_TNTMSM_Registration_Type__c = 'New';
        }

        String caseFormCode = resolveCaseFormCode(webFilingInfo);
        if (String.isNotBlank(caseFormCode)) {
            webCase.breg_Form_Code__c = caseFormCode;
            webCase.Subject = SUBJECT_BY_FORM_CODE.get(caseFormCode);
        }

        if (caseFormCode == 'T-1') {
            webCase.breg_Entity_Nature_Of_Business__c = webTradeMark.breg_WEB_PURPOSE__c;
            webCase.breg_TNTMSM_Classification__c = '0 - NO CATEGORY SELECTED';
        } else if (caseFormCode == 'T-2' || caseFormCode == 'T-3') {
            webCase.breg_TNTMSM_Goods_Or_Services__c = webTradeMark.breg_WEB_PURPOSE__c;
            webCase.breg_TNTMSM_Mode_Or_Manner__c = webTradeMark.breg_WEB_NOTES__c;
        }
    }

    private Map<String, breg_WEB_WEB_FILING_INFO__c> getFilingInfoByWorkitemId(Set<String> workitemIds) {
        Map<String, breg_WEB_WEB_FILING_INFO__c> filingInfoByWorkitemId = new Map<String, breg_WEB_WEB_FILING_INFO__c>();
        if (workitemIds == null || workitemIds.isEmpty()) {
            return filingInfoByWorkitemId;
        }

        for (breg_WEB_WEB_FILING_INFO__c filingInfo : [
            SELECT Id, breg_WEB_Case__c, breg_WEB_FORM_TYPE__c
            FROM breg_WEB_WEB_FILING_INFO__c
            WHERE breg_WEB_Case__c IN :workitemIds
        ]) {
            filingInfoByWorkitemId.put(filingInfo.breg_WEB_Case__c, filingInfo);
        }

        return filingInfoByWorkitemId;
    }

    private Map<String, List<breg_TN_TM_SM__c>> getRelatedTnTmSmsByWorkitemId(
        Map<String, List<SObject>> resultsByWorkitemId,
        Map<String, breg_WEB_WEB_FILING_INFO__c> filingInfoByWorkitemId
    ) {
        Map<String, List<breg_TN_TM_SM__c>> relatedTnTmSmsByWorkitemId = new Map<String, List<breg_TN_TM_SM__c>>();
        Map<String, String> historyKeyByWorkitemId = new Map<String, String>();
        Set<String> tradeNames = new Set<String>();
        Set<String> tradeTypes = new Set<String>();
        Set<String> accountNames = new Set<String>();
        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            BREGWebFilingWrapper webFilingWrapper = wrappersByWorkitemId.get(workitemId);
            
            if (records == null || records.isEmpty()) {
                continue;
            }

            breg_WEB_WEB_TRADE_MARKS__c webTradeMark = (breg_WEB_WEB_TRADE_MARKS__c) records[0];
            String tradeName = webTradeMark.breg_WEB_TRADE_NAME__c;
            String tradeType = TRADE_TYPE_MAP.get(webTradeMark.breg_WEB_TRADE_TYPE__c);
            if (String.isBlank(tradeName) || String.isBlank(tradeType)) {
                continue;
            }

            tradeNames.add(tradeName);
            tradeTypes.add(tradeType);
            accountNames.add(webFilingWrapper?.WebCase?.breg_Name_of_the_Entity__c);
            historyKeyByWorkitemId.put(workitemId, buildHistoryKey(tradeName, tradeType));
        }

        if (tradeNames.isEmpty() || tradeTypes.isEmpty()) {
            return relatedTnTmSmsByWorkitemId;
        }
        System.debug('BREGWebTradeMarks2Case.getRelatedTnTmSmsByWorkitemId: tradeNames=' + tradeNames);
        System.debug('BREGWebTradeMarks2Case.getRelatedTnTmSmsByWorkitemId: tradeTypes=' + tradeTypes);
        System.debug('BREGWebTradeMarks2Case.getRelatedTnTmSmsByWorkitemId: accountNames=' + accountNames);

        Date today = Date.today();
        Map<String, List<breg_TN_TM_SM__c>> relatedTnTmSmsByHistoryKey = new Map<String, List<breg_TN_TM_SM__c>>();
        for (breg_TN_TM_SM__c relatedTnTmSm : [
            SELECT Id, Name, breg_Type__c, breg_Cert_Number__c
            FROM breg_TN_TM_SM__c
            WHERE Name IN :tradeNames
                AND breg_Type__c IN :tradeTypes
                AND breg_End_Date__c = NULL
                AND breg_Status__c = 'A'
                AND breg_Account__r.Name IN :accountNames
                AND breg_Expiration_Date__c > :today
            ORDER BY CreatedDate DESC
        ]) {
            addHistoryTnTmSm(relatedTnTmSmsByHistoryKey, relatedTnTmSm);
        }

        for (String workitemId : historyKeyByWorkitemId.keySet()) {
            String historyKey = historyKeyByWorkitemId.get(workitemId);
            if (relatedTnTmSmsByHistoryKey.containsKey(historyKey)) {
                relatedTnTmSmsByWorkitemId.put(workitemId, relatedTnTmSmsByHistoryKey.get(historyKey));
            }
        }

        System.debug('BREGWebTradeMarks2Case.getRelatedTnTmSmsByWorkitemId: relatedTnTmSmsByWorkitemId=' + relatedTnTmSmsByWorkitemId);
        return relatedTnTmSmsByWorkitemId;
    }

    private void addHistoryTnTmSm(Map<String, List<breg_TN_TM_SM__c>> relatedTnTmSmsByHistoryKey, breg_TN_TM_SM__c relatedTnTmSm) {
        if (relatedTnTmSm == null || String.isBlank(relatedTnTmSm.Name) || String.isBlank(relatedTnTmSm.breg_Type__c)) {
            return;
        }

        String historyKey = buildHistoryKey(relatedTnTmSm.Name, relatedTnTmSm.breg_Type__c);
        if (!relatedTnTmSmsByHistoryKey.containsKey(historyKey)) {
            relatedTnTmSmsByHistoryKey.put(historyKey, new List<breg_TN_TM_SM__c>());
        }
        relatedTnTmSmsByHistoryKey.get(historyKey).add(relatedTnTmSm);
    }

    private String buildHistoryKey(String tradeName, String formCode) {
        return tradeName + '::' + formCode;
    }

    private String resolveCaseFormCode(breg_WEB_WEB_FILING_INFO__c webFilingInfo) {
        if (webFilingInfo == null || String.isBlank(webFilingInfo.breg_WEB_FORM_TYPE__c)) {
            return null;
        }
        return CASE_FORM_CODE_BY_WEB_FORM_TYPE.get(webFilingInfo.breg_WEB_FORM_TYPE__c);
    }

    // private breg_TN_TM_SM__c buildTradeMark(breg_WEB_WEB_TRADE_MARKS__c webTradeMark, String accountId, String workItemId) {
    //     breg_TN_TM_SM__c tradeMark = new breg_TN_TM_SM__c();

    //     tradeMark.breg_Account__c = accountId;
    //     //tradeMark.breg_Case__c = workItemId;
    //     tradeMark.breg_BRIM_TRADE_MARK_ID__c = webTradeMark.breg_WEB_TRADE_MARK_ID__c;

    //     String tradeName = webTradeMark.breg_WEB_TRADE_NAME__c;
    //     tradeMark.Name = tradeName != null ? tradeName.left(255) : null;
    //     tradeMark.breg_Trade_Name__c = tradeName;

    //     tradeMark.breg_Type__c = TRADE_TYPE_MAP.get(webTradeMark.breg_WEB_TRADE_TYPE__c);

    //     tradeMark.breg_File__c = webTradeMark.breg_WEB_FILE_NO__c != null ? String.valueOf(webTradeMark.breg_WEB_FILE_NO__c.intValue()) : null;
    //     tradeMark.breg_File_Suffix__c = webTradeMark.breg_WEB_FILE_SUFFIX__c;

    //     tradeMark.breg_Registration_Date__c = webTradeMark.breg_WEB_REGISTRATION_DT__c;
    //     tradeMark.breg_Start_Date__c = webTradeMark.breg_WEB_START_DT__c;

    //     tradeMark.breg_XREF_Name1__c = webTradeMark.breg_WEB_XREF_NAME_1__c;
    //     tradeMark.breg_XREF_Name2__c = webTradeMark.breg_WEB_XREF_NAME_2__c;

    //     return tradeMark;
    // }
}