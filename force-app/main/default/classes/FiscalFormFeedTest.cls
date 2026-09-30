@IsTest
private class FiscalFormFeedTest {
    @IsTest
    static void testFeeds() {
        FiscalFormFeed feed = new FiscalFormFeed();
        feed.totalDeposit ='1.1';
        feed.bankDeposit ='1.1';
        feed.electronicFundTransfer ='1.1';
        feed.revValue ='R';
        feed.creditCardProcessing ='1.1';
        feed.others ='1.1';
        feed.totalDeposit2 ='1.1';
        System.debug(feed.funds);
        System.debug(feed.detailFund);
        System.debug(feed.fundName);
        System.debug(feed.remarks);
        System.debug(feed.bankDeposit);
        System.debug(feed.totalDeposit);
        System.debug(feed.electronicFundTransfer);
        System.debug(feed.creditCardProcessing);
        System.debug(feed.others);
        System.debug(feed.totalDeposit2);
        System.debug(feed.getTotalDepositD());
        System.debug(feed.getBankDepositD());
        System.debug(feed.getElectronicFundTransferD());
        System.debug(feed.getCreditCardProcessingD());
        System.debug(feed.getOthersD());
        System.debug(feed.getTotalDeposit2D());
        System.debug(feed.getTotalDepositDeposit());
        System.debug(feed.getBankDepositDeposit());
        System.debug(feed.getOthersDeposit());
        System.debug(feed.getElectronicFundTransferDeposit());
        System.debug(feed.getCreditCardProcessingDeposit());
        System.debug(feed.getTotalDeposit2Deposit());
        System.debug(feed.departmentNo);
        System.debug(feed.departmentDate);
        System.debug(feed.comptrollerNo);
        System.debug(feed.explanation);
        System.debug(feed.departmentalCertification);
        System.debug(feed.commerceConsumerAffairs);
        System.debug(feed.comptrollerApproval);
        System.debug(feed.comptroller);
        FiscalFormFeed.DataFeed dFeed = new FiscalFormFeed.DataFeed();
        FiscalFormFeed.DataFeed dFeed2 = new FiscalFormFeed.DataFeed();
        dFeed.amount = 1.1;
        dFeed.decimalAmount = '10';
        dFeed.costCenterValue = '32';
        dFeed.costCenterValue = '32';
        dFeed2.costCenterValue = '31';
        dFeed2.appValue = '31';
        dFeed.compareTo(dFeed2);
        System.debug(dFeed.recordId);
        System.debug(dFeed.tcValue);
        System.debug(dFeed.fValue);
        System.debug(dFeed.sValue);
        System.debug(dFeed.yrValue);
        System.debug(dFeed.appValue);
        System.debug(dFeed.dValue);
        System.debug(dFeed.decimalAmount);
        System.debug(dFeed.alltCatValue);
        System.debug(dFeed.sourceObjValue);
        System.debug(dFeed.costCenterValue);
        System.debug(dFeed.projectNumValue);
        System.debug(dFeed.projectPhValue);
        System.debug(dFeed.deptActValue);
        System.debug(dFeed.gLActValue);
        System.debug(dFeed.sLActValue);
        System.debug(dFeed.referenceNumValue);
        System.debug(dFeed.referenceSFXValue);
        System.debug(dFeed.venterNumValue);
        System.debug(dFeed.venterSFXValue);
        System.debug(dFeed.amount);
        System.debug(dFeed.transactionId);
        System.debug(dFeed.jVAmount1);
        System.debug(dFeed.jVAmount2);
        System.debug(dFeed.modValue);
        System.debug(dFeed.revValue);
        System.debug(dFeed.optionalDepartmentalDate);
        System.debug(dFeed.remarks);
    }

    @IsTest
    static void testSort() {
        Account a  = new Account();
        FiscalFormFeed.DataFeed dFeed = new FiscalFormFeed.DataFeed();
        FiscalFormFeed.DataFeed dFeed2 = new FiscalFormFeed.DataFeed();
        FiscalFormFeed.DataFeed dFeed3 = new FiscalFormFeed.DataFeed();
        FiscalFormFeed.DataFeed dFeed4 = new FiscalFormFeed.DataFeed();
        FiscalFormFeed.DataFeed dFeed5 = new FiscalFormFeed.DataFeed();
        FiscalFormFeed.DataFeed dFeed6 = new FiscalFormFeed.DataFeed();
        dFeed.appValue = '32';
        dFeed2.appValue = '31';
        dFeed3.sourceObjValue = '31';
        dFeed4.sourceObjValue = '31';
        dFeed5.costCenterValue = '32';
        dFeed6.costCenterValue = '31';
        List<FiscalFormFeed.DataFeed> feeds = new List<FiscalFormFeed.DataFeed>{dFeed, dFeed2, dFeed3, dFeed4, dFeed5, dFeed6};
        feeds.sort();
    }
}