public with sharing class BREGWebStock2BREGStock extends BREGWebDataItemMapper {
    private static final String SOURCE_TABLE = 'breg_WEB_WEB_STOCKS__c';

    public BREGWebStock2BREGStock(Map<String, BREGWebFilingWrapper> wrappersByWorkitemId) {
        super(wrappersByWorkitemId, SOURCE_TABLE);
    }

    public override Map<String, List<SObject>> PrepareData(Set<String> workitemIds) {
        Map<String, List<SObject>> resultsByWorkitemId = super.PrepareData(workitemIds);
        for (String workitemId : resultsByWorkitemId.keySet()) {
            List<SObject> records = resultsByWorkitemId.get(workitemId);
            if (records.isEmpty()) {
                continue;
            }
            BREGWebFilingWrapper webFilingWrapper = wrappersByWorkitemId.get(workitemId);
            if (webFilingWrapper == null) {
                continue;
            }

            List<breg_WEB_WEB_STOCKS__c> stocks = new List<breg_WEB_WEB_STOCKS__c>();
            for (SObject record : records) {
                breg_WEB_WEB_STOCKS__c webStock = (breg_WEB_WEB_STOCKS__c) record;
                stocks.add(webStock);
                if (webFilingWrapper.WebCase.breg_Entity__c != null  && webStock.breg_WEB_WEB_ACTION_CODE__c != 'D') {
                    webFilingWrapper.Stocks.add(buildStock(webStock, webFilingWrapper.WebCase.breg_Entity__c));
                }
            }
            mapToCaseFields(stocks, webFilingWrapper.WebCase);
        }
        return resultsByWorkitemId;
    }

    private void mapToCaseFields(List<breg_WEB_WEB_STOCKS__c> stocks, Case webCase) {
        webCase.breg_Stock_Type__c = 'With Stock';

        String parValue = stocks[0].breg_WEB_PAR_VALUE__c;
        webCase.breg_Par_Value_Of_Each_Share__c = normalizeDecimal(parValue);

        for (breg_WEB_WEB_STOCKS__c stock : stocks) {
            String sharesCnt = stock.breg_WEB_SHARES_CNT__c;
            webCase.breg_Number_of_common_shares__c = normalizeDecimal(sharesCnt);
            String paidShares = stock.breg_WEB_PAID_SHARES__c;
            webCase.breg_Outstanding_Shares_Count__c = normalizeDecimal(paidShares);
            break;
            
        }
    }

    private breg_Stock__c buildStock(breg_WEB_WEB_STOCKS__c webStock, String accountId) {
        breg_Stock__c stock = new breg_Stock__c();
        stock.breg_Case__c = webStock.breg_Web_Case__c;
        stock.breg_Account__c = accountId;
        stock.breg_BRIM_STOCK_ID__c = webStock.breg_WEB_STOCK_ID__c;
        stock.breg_Stock_Class__c = webStock.breg_WEB_STOCK_CLASS__c;
        stock.breg_Stock_Amount__c = webStock.breg_WEB_STOCK_AMOUNT__c;
        stock.breg_Number_of_Issued_Shares__c = webStock.breg_WEB_SHARES_CNT__c;
        stock.breg_Paid_Shares__c = webStock.breg_WEB_PAID_SHARES__c;
        stock.breg_Per_Value__c = webStock.breg_WEB_PAR_VALUE__c;
        stock.breg_Remarks__c = webStock.breg_WEB_REMARKS__c;
        // stock.breg_Start_Date__c = webStock.breg_WEB_START_DT__c;
        // stock.breg_End_Date__c = webStock.breg_WEB_END_DT__c;
        return stock;
    }

    private Decimal normalizeDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String normalizedValue = value.replaceAll('[^0-9.]', '');

        return String.isBlank(normalizedValue)
            ? null
            : Decimal.valueOf(normalizedValue);
    }
}