public with sharing class FiscalFormFeed {
    public List<DataFeed> funds {set;get;}
    public String dateStr {set;get;}
    public String detailFund {set;get;}
    public String fundName {set;get;}
    public String remarks {set;get;}
    public String revValue {set;get;}
    public String getTotalDepositDeposit() {
        return getDecimalStr(getTotalDepositD());
    }

    public String getBankDepositDeposit() {
        return getDecimalStr(getBankDepositD());
    }

    public static String getDecimalStr(Decimal val) {
        if (val != null) {
            String numStr = String.valueOf(val);
            List<String> numStrSplit = numStr.split('\\.');
            if (numStrSplit.size() > 1) {
                numStr = numStrSplit[1];
            } else {
                numStr = '0';
            }

            if (numStr.length() == 1) {
                numStr = numStr + '0';
            }

            return numStr;
        }

        return '';
    }

    public String totalDeposit {set;get;}
    public String bankDeposit {set;get;}
    public String electronicFundTransfer {set;get;}
    public String creditCardProcessing {set;get;}
    public String others {set;get;}
    public String totalDeposit2 {set;get;}
    public Decimal getTotalDepositD() {
        if(totalDeposit != null && totalDeposit != '') {
            return Decimal.valueOf(totalDeposit);
        }
        return null;
    }
    public Decimal getBankDepositD() {
        if(bankDeposit != null && bankDeposit != '') {
            return Decimal.valueOf(bankDeposit);
        }
        return null;
    }
    public Decimal getElectronicFundTransferD() {
        if(electronicFundTransfer != null && electronicFundTransfer != '') {
            return Decimal.valueOf(electronicFundTransfer);
        }
        return null;
    }

    public String getElectronicFundTransferDeposit() {
        return getDecimalStr(getElectronicFundTransferD());
    }

    public Decimal getCreditCardProcessingD() {
        if(creditCardProcessing != null && creditCardProcessing != '') {
            return Decimal.valueOf(creditCardProcessing);
        }
        return null;
    }

    public String getCreditCardProcessingDeposit() {
        return getDecimalStr(getCreditCardProcessingD());
    }

    public Decimal getOthersD() {
        if(others != null && others != '') {
            return Decimal.valueOf(others);
        }
        return null;
    }
    public String getOthersDeposit() {
        return getDecimalStr(getOthersD());
    }

    public Decimal getTotalDeposit2D() {
        if(totalDeposit2 != null && totalDeposit2 != '') {
            return Decimal.valueOf(totalDeposit2);
        }
        return null;
    }

    public String getTotalDeposit2Deposit() {
        return getDecimalStr(getTotalDeposit2D());
    }

    public String departmentNo {set;get;}
    public String departmentDate {set;get;}
    public String comptrollerNo {set;get;}
    public String explanation {set;get;}
    public String departmentalCertification {set;get;}
    public String commerceConsumerAffairs {set;get;}
    public String comptrollerApproval {set;get;}
    public String comptroller {set;get;}
    public class DataFeed implements Comparable {
        public String recordId {set;get;}
        public String indexValue {set;get {
            if(indexValue == null) {
                return '';
            }
            return indexValue;
        }}
        public String elemKey {set;get;}
        public String tcValue {set;get;}
        public String fValue {set;get;}
        public String sValue {set;get;}
        public String yrValue {set;get;}
        public String appValue {set;get;}
        public String dValue {set;get;}
        public String alltCatValue {set;get;}
        public String sourceObjValue {set;get;}
        public String costCenterValue {set;get;}
        public String projectNumValue {set;get;}
        public String projectPhValue {set;get;}
        public String deptActValue {set;get;}
        public String gLActValue {set;get;}
        public String sLActValue {set;get;}
        public String referenceNumValue {set;get;}
        public String referenceSFXValue {set;get;}
        public String venterNumValue {set;get;}
        public String venterSFXValue {set;get;}
        public Decimal amount {set;get;}
        public String decimalAmount{set;get{
            return getDecimalStr(amount);
        }}
        public String transactionId {set;get;}
        public String jVAmount1 {set;get;}
        public String jVAmount2 {set;get;}
        public String modValue {set;get;}
        public String revValue {set;get;}
        public String optionalDepartmentalDate {set;get;}
        public String remarks {set;get;}
        public Integer compareTo(Object compareTo) {
            // Cast argument to OpportunityWrapper
            DataFeed compareToFeed = (DataFeed)compareTo;

             Boolean appValuesNotNull = appValue != null && compareToFeed.appValue != null;
             Boolean costCenterValuesNotNull = costCenterValue != null && compareToFeed.costCenterValue != null;
             Boolean sourceObjectValuesNotNull = sourceObjValue != null && compareToFeed.sourceObjValue != null;
            // The return value of 0 indicates that both elements are equal.
            Integer returnValue = 0;
            if (appValue == null && compareToFeed.appValue != null) {
                returnValue = -1;
            } else if (compareToFeed.appValue == null && appValue != null) {
                returnValue = 1;
            } else if (appValuesNotNull && Integer.valueOf(appValue) > Integer.valueOf(compareToFeed.appValue)) {
                returnValue = 1;
            } else if (appValuesNotNull && Integer.valueOf(appValue) < Integer.valueOf(compareToFeed.appValue)) {
                returnValue = -1;
            } else if (costCenterValue == null && compareToFeed.costCenterValue != null) {
                returnValue = -1;
            } else if (compareToFeed.costCenterValue == null && costCenterValue != null) {
                returnValue = 1;
            } else if (costCenterValuesNotNull && Integer.valueOf(costCenterValue) > Integer.valueOf(compareToFeed.costCenterValue)) {
                returnValue = 1;
            } else if (costCenterValuesNotNull && Integer.valueOf(costCenterValue) < Integer.valueOf(compareToFeed.costCenterValue)) {
                returnValue = -1;
            } else if (sourceObjValue == null && compareToFeed.sourceObjValue != null) {
                returnValue = -1;
            } else if (compareToFeed.sourceObjValue == null && sourceObjValue != null) {
                returnValue = 1;
            } else if (sourceObjectValuesNotNull && Integer.valueOf(sourceObjValue) > Integer.valueOf(compareToFeed.sourceObjValue)) {
                returnValue = 1;
            } else if (sourceObjectValuesNotNull && Integer.valueOf(sourceObjValue) < Integer.valueOf(compareToFeed.sourceObjValue)) {
                returnValue = -1;
            }
            return returnValue;
        }
    }
    public class SearchFeed{
        public Date cutOffDate {set;get;}
        public Date startDate {set;get;}
        public String division {set;get;}
        public String fundType {set;get;}
        public String fundAccounts {set;get;}
        public String paymentType {set;get;}
        public String selectedDeposits {set;get;}
    }
}