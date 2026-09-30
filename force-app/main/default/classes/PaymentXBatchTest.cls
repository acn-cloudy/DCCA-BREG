/*
 * ******************************************************************************************************
 * Name: PaymentXBatchTest.cls
 * Author:
 * Date: 2/7/2018
 * Classes: PaymentXBatch.cls, DCCAFeeScheduleBatch.cls
 * ******************************************************************************************************
 *
 * @changes 08/02/2021 case 00015533
 * PacPoint-CL080221
 */
@IsTest
public class PaymentXBatchTest {
  @IsTest
  static void testPaymentXBatch() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
    insert cnt;

    Case c = new Case();
    //enter details
    c.AccountId = acc.Id;
    c.ContactId = cnt.Id;
    //c.RecordTypeId = rtId;
    c.Type = 'My Type';
    c.Origin = 'My Origin';
    c.Status = 'My Status';
    insert c;

    date sd = Date.Today();

    //insert DCCAFeeSchedule__c
    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = '1st Year Fees - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 100;
    fsch1.CreditCardFee__c = 100;
    fsch1.PPIFeeAmount__c = 300;
    fsch1.RemitToDCCA__c = 100;
    fsch1.TransactionFee__c = 100;
    fsch1.TotalCollections__c = 100;
    fsch1.PPIFeePercent__c = 9;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 4.7120;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 100;
    insert fsch1;

    pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
    currentYearPayment1.pymt__Status__c = 'Completed';
    currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
    currentYearPayment1.CreditCardFee__c = 20;
    currentYearPayment1.pymt__Transaction_Fee__c = 50;
    currentYearPayment1.pymt__Amount__c = 100;
    currentYearPayment1.pymt__Transaction_Type__c = 'Payment';
    currentYearPayment1.pymt__Payment_Type__c = 'Check';
    insert currentYearPayment1;

    Test.StartTest();
    PaymentXBatch.schedule5min();

    Test.getEventBus().deliver();
    Test.StopTest();

    pymt__PaymentX__c payment = [
      SELECT
        Id,
        FeeSchedule__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
    ];

    System.assertEquals(fsch1.Id, payment.FeeSchedule__c);
    System.assertEquals(0, Math.round(payment.PPIFeeAmount__c));
    System.assertEquals(0, Math.round(payment.HIGETaxAmount__c));

    System.assertEquals(30, Math.round(payment.RemitToDCCA__c));
  }

  @IsTest
  static void testPaymentXBatch0() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
    insert cnt;

    Case c = new Case();
    //enter details
    c.AccountId = acc.Id;
    c.ContactId = cnt.Id;
    //c.RecordTypeId = rtId;
    c.Type = 'My Type';
    c.Origin = 'My Origin';
    c.Status = 'My Status';
    insert c;

    date sd = Date.Today();

    //insert DCCAFeeSchedule__c
    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = '1st Year Fees - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 100;
    fsch1.CreditCardFee__c = 100;
    fsch1.PPIFeeAmount__c = 300;
    fsch1.RemitToDCCA__c = 100;
    fsch1.TransactionFee__c = 100;
    fsch1.TotalCollections__c = 100;
    fsch1.PPIFeePercent__c = 9;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 4.7120;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 100;
    insert fsch1;

    pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
    currentYearPayment1.pymt__Status__c = 'Completed';
    currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
    currentYearPayment1.CreditCardFee__c = 20;
    currentYearPayment1.pymt__Transaction_Fee__c = 50;
    currentYearPayment1.pymt__Amount__c = 100;
    currentYearPayment1.pymt__Transaction_Type__c = 'Payment';
    currentYearPayment1.pymt__Payment_Type__c = 'Check';
    insert currentYearPayment1;

    Test.StartTest();
    //    PaymentXBatch obj = new PaymentXBatch();
    PaymentXBatch.schedule();
    //DataBase.executeBatch(obj, 1);

    Test.getEventBus().deliver();
    Test.StopTest();

    pymt__PaymentX__c payment = [
      SELECT
        Id,
        FeeSchedule__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
    ];

    System.assertEquals(fsch1.Id, payment.FeeSchedule__c);
    System.assertEquals(0, Math.round(payment.PPIFeeAmount__c));
    System.assertEquals(0, Math.round(payment.HIGETaxAmount__c));

    System.assertEquals(30, Math.round(payment.RemitToDCCA__c));
  }

  @IsTest
  static void testPaymentXBatch1() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
    insert cnt;

    Case c = new Case();
    //enter details
    c.AccountId = acc.Id;
    c.ContactId = cnt.Id;
    //c.RecordTypeId = rtId;
    c.Type = 'My Type';
    c.Origin = 'My Origin';
    c.Status = 'My Status';
    insert c;

    date sd = Date.Today();

    //insert DCCAFeeSchedule__c
    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = '1st Year Fees - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 100;
    fsch1.CreditCardFee__c = 100;
    fsch1.PPIFeeAmount__c = 300;
    fsch1.RemitToDCCA__c = 100;
    fsch1.TransactionFee__c = 100;
    fsch1.TotalCollections__c = 100;
    fsch1.PPIFeePercent__c = 9;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 4.7120;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 100;
    insert fsch1;

    pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
    currentYearPayment1.pymt__Status__c = 'Completed';
    currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
    currentYearPayment1.CreditCardFee__c = 20;
    currentYearPayment1.pymt__Transaction_Fee__c = 50;
    currentYearPayment1.pymt__Amount__c = 100;
    currentYearPayment1.pymt__Transaction_Type__c = 'Payment';
    currentYearPayment1.pymt__Payment_Type__c = 'Check or Money Order';
    insert currentYearPayment1;

    Test.StartTest();
    PaymentXBatch obj = new PaymentXBatch();
    DataBase.executeBatch(obj, 1);

    Test.getEventBus().deliver();
    Test.StopTest();

    pymt__PaymentX__c payment = [
      SELECT
        Id,
        FeeSchedule__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
    ];

    System.assertEquals(fsch1.Id, payment.FeeSchedule__c);
    System.assertEquals(0, Math.round(payment.PPIFeeAmount__c));
    System.assertEquals(0, Math.round(payment.HIGETaxAmount__c));

    System.assertEquals(30, Math.round(payment.RemitToDCCA__c));
  }

  @IsTest
  static void testPaymentXBatch2() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
    insert cnt;

    Case c = new Case();
    //enter details
    c.AccountId = acc.Id;
    c.ContactId = cnt.Id;
    //c.RecordTypeId = rtId;
    c.Type = 'My Type';
    c.Origin = 'My Origin';
    c.Status = 'My Status';
    insert c;

    /*
     * Transaction__c trans = new Transaction__c();
     * trans.Account__c = acc.Id;
     * trans.WorkitemID__c = '1';
     * insert trans;
     */

    date sd = Date.Today();

    //insert DCCAFeeSchedule__c
    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = '1st Year Fees - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 100;
    fsch1.CreditCardFee__c = 100;
    fsch1.PPIFeeAmount__c = 300;
    fsch1.RemitToDCCA__c = 100;
    fsch1.TransactionFee__c = 100;
    fsch1.TotalCollections__c = 100;
    fsch1.PPIFeePercent__c = 9;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 4.7120;
    fsch1.Status__c = 'Active';
    insert fsch1;

    pymt__PaymentX__c currentYearPayment0 = new pymt__PaymentX__c();
    currentYearPayment0.pymt__Status__c = 'Completed';
    currentYearPayment0.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
    currentYearPayment0.CreditCardFee__c = 20;
    currentYearPayment0.pymt__Transaction_Fee__c = 50;
    currentYearPayment0.pymt__Amount__c = 100;
    currentYearPayment0.pymt__Transaction_Type__c = 'Payment';
    currentYearPayment0.pymt__Payment_Type__c = 'Check or Money Order';
    insert currentYearPayment0;

    pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
    currentYearPayment1.pymt__Status__c = 'Completed';
    currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
    currentYearPayment1.CreditCardFee__c = 20;
    currentYearPayment1.pymt__Transaction_Fee__c = 50;
    currentYearPayment1.pymt__Amount__c = -100;
    currentYearPayment1.pymt__Transaction_Type__c = 'Refund';
    currentYearPayment1.pymt__Payment_Type__c = 'Check or Money Order';
    currentYearPayment1.pymt__Parent_Transaction__c = currentYearPayment0.Id;
    insert currentYearPayment1;

    Test.StartTest();
    PaymentXBatch obj = new PaymentXBatch();
    DataBase.executeBatch(obj, 2);

    Test.getEventBus().deliver();
    Test.StopTest();

    pymt__PaymentX__c payment = [
      SELECT
        Id,
        FeeSchedule__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
      WHERE Id = :currentYearPayment1.Id
    ];

    System.assertEquals(fsch1.Id, payment.FeeSchedule__c);

    System.assertEquals(-100, Math.round(payment.RemitToDCCA__c));
  }

  @IsTest
  static void testPaymentXBatch3() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact cnt = new Contact(LastName = 'TestCon', AccountId = acc.Id);
    insert cnt;

    Case c = new Case();
    //enter details
    c.AccountId = acc.Id;
    c.ContactId = cnt.Id;
    //c.RecordTypeId = rtId;
    c.Type = 'My Type';
    c.Origin = 'My Origin';
    c.Status = 'My Status';
    insert c;

    date sd = Date.Today();

    //insert DCCAFeeSchedule__c
    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = '1st Year Fees - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 100;
    fsch1.CreditCardFee__c = 100;
    fsch1.PPIFeeAmount__c = 300;
    fsch1.RemitToDCCA__c = 100;
    fsch1.TransactionFee__c = 100;
    fsch1.TotalCollections__c = 100;
    fsch1.PPIFeePercent__c = 9;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 4.7120;
    fsch1.Status__c = 'Active';
    insert fsch1;

    pymt__PaymentX__c currentYearPayment1 = new pymt__PaymentX__c();
    currentYearPayment1.pymt__Status__c = 'Completed';
    currentYearPayment1.pymt__Date__c = Date.newInstance(sd.year(), 1, 12);
    currentYearPayment1.CreditCardFee__c = 20;
    currentYearPayment1.pymt__Transaction_Fee__c = 50;
    currentYearPayment1.pymt__Amount__c = -100;
    currentYearPayment1.pymt__Transaction_Type__c = 'Payment';
    currentYearPayment1.pymt__Payment_Type__c = 'Check or Money Order';
    insert currentYearPayment1;

    Test.StartTest();
    PaymentXBatch obj = new PaymentXBatch();
    DataBase.executeBatch(obj, 1);

    Test.getEventBus().deliver();
    Test.StopTest();

    pymt__PaymentX__c payment = [
      SELECT
        Id,
        FeeSchedule__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
    ];
    System.assertEquals(fsch1.Id, payment.FeeSchedule__c);
    System.assertEquals(-100, Math.round(payment.RemitToDCCA__c));
  }

  @IsTest
  static void testPaymentXBatchCapsPpiWithHigeInFormulaMaximum() {
    Date sd = Date.Today();

    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = 'HIGE Cap Test - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 0;
    fsch1.CreditCardFee__c = 0;
    fsch1.PPIFeeAmount__c = 95;
    fsch1.RemitToDCCA__c = 0;
    fsch1.TransactionFee__c = 0;
    fsch1.TotalCollections__c = 0;
    fsch1.PPIFeePercent__c = 10;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 10;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 100;
    insert fsch1;

    fsch1 = [
      SELECT Id, PPIFeeAmount__c, TotalPPIMaximum__c, HIGETaxPercent__c
      FROM FeeSchedule__c
      WHERE Id = :fsch1.Id
    ];

    Decimal startingPpiAmount = fsch1.PPIFeeAmount__c;
    Decimal higeTaxRate = fsch1.HIGETaxPercent__c / 100;
    Decimal expectedCappedPpi =
      (fsch1.TotalPPIMaximum__c - startingPpiAmount) / (1 - higeTaxRate);

    pymt__PaymentX__c paymentRecord = new pymt__PaymentX__c();
    paymentRecord.pymt__Status__c = 'Completed';
    paymentRecord.pymt__Date__c = Date.newInstance(sd.year(), 2, 12);
    paymentRecord.CreditCardFee__c = 0;
    paymentRecord.pymt__Transaction_Fee__c = 0;
    paymentRecord.pymt__Amount__c = 100000;
    paymentRecord.pymt__Transaction_Type__c = 'Payment';
    paymentRecord.pymt__Payment_Type__c = 'Check';
    insert paymentRecord;

    Test.StartTest();
    Database.executeBatch(new PaymentXBatch(), 1);
    Test.StopTest();
  }

  @IsTest
  static void testPaymentXBatchPUCExclusion() {
    Date sd = Date.today();

    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = 'PUC Fee Schedule - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 0;
    fsch1.CreditCardFee__c = 0;
    fsch1.PPIFeeAmount__c = 0;
    fsch1.RemitToDCCA__c = 0;
    fsch1.TransactionFee__c = 0;
    fsch1.TotalCollections__c = 0;
    fsch1.PPIFeePercent__c = 10;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 5;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 1000;
    insert fsch1;

    SoftwareFees__c sf = new SoftwareFees__c(
      FeeSchedule__c = fsch1.Id,
      Amount__c = 0
    );
    HardwareFees__c hf = new HardwareFees__c(
      FeeSchedule__c = fsch1.Id,
      Amount__c = 0
    );
    ServicesFees__c srv = new ServicesFees__c(
      FeeSchedule__c = fsch1.Id,
      Amount__c = 0
    );
    insert new List<SObject>{ sf, hf, srv };

    pymt__PaymentX__c pucPayment = new pymt__PaymentX__c();
    pucPayment.pymt__Status__c = 'Completed';
    pucPayment.pymt__Date__c = Date.newInstance(sd.year(), 6, 1);
    pucPayment.Division__c = 'PUC';
    pucPayment.CreditCardFee__c = 10;
    pucPayment.pymt__Transaction_Fee__c = 15;
    pucPayment.pymt__Amount__c = 100;
    pucPayment.pymt__Transaction_Type__c = 'Payment';
    pucPayment.pymt__Payment_Type__c = 'Credit Card';

    pymt__PaymentX__c nonPucPayment = new pymt__PaymentX__c();
    nonPucPayment.pymt__Status__c = 'Completed';
    nonPucPayment.pymt__Date__c = Date.newInstance(sd.year(), 6, 1);
    nonPucPayment.Division__c = 'PVL';
    nonPucPayment.CreditCardFee__c = 10;
    nonPucPayment.pymt__Transaction_Fee__c = 15;
    nonPucPayment.pymt__Amount__c = 100;
    nonPucPayment.pymt__Transaction_Type__c = 'Payment';
    nonPucPayment.pymt__Payment_Type__c = 'Credit Card';

    Test.startTest();
    insert new List<pymt__PaymentX__c>{ pucPayment, nonPucPayment };
    Test.stopTest();

    pymt__PaymentX__c updatedPucPayment = [
      SELECT
        Id,
        FeeSchedule__c,
        Division__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
      WHERE Id = :pucPayment.Id
    ];

    System.assertEquals(fsch1.Id, updatedPucPayment.FeeSchedule__c);
    System.assertEquals(
      0,
      updatedPucPayment.PPIFeeAmount__c,
      'PUC payment should exclude PPI fee calculation'
    );

    pymt__PaymentX__c updatedNonPucPayment = [
      SELECT
        Id,
        Division__c,
        FeeSchedule__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        RemitToDCCA__c
      FROM pymt__PaymentX__c
      WHERE Id = :nonPucPayment.Id
    ];

    System.assertEquals(updatedNonPucPayment.Division__c, 'PVL');
    System.assertEquals(
      10,
      updatedNonPucPayment.PPIFeeAmount__c,
      'Non-PUC payment should calculate PPI fee'
    );
  }

  @IsTest
  static void testDCCAFeeScheduleBatchPUCExclusion() {
    Date sd = Date.today();

    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = 'DCCA Batch PUC Test - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 0;
    fsch1.CreditCardFee__c = 0;
    fsch1.PPIFeeAmount__c = 0;
    fsch1.RemitToDCCA__c = 0;
    fsch1.TransactionFee__c = 0;
    fsch1.TotalCollections__c = 0;
    fsch1.PPIFeePercent__c = 10;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 5;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 1000;
    insert fsch1;

    pymt__PaymentX__c pucPayment = new pymt__PaymentX__c();
    pucPayment.pymt__Status__c = 'Completed';
    pucPayment.pymt__Date__c = Date.newInstance(sd.year(), 6, 1);
    pucPayment.Division__c = 'PUC';
    pucPayment.CreditCardFee__c = 0;
    pucPayment.pymt__Transaction_Fee__c = 10;
    pucPayment.PPIFeeAmount__c = 10;
    pucPayment.HIGETaxAmount__c = 0;
    pucPayment.RemitToDCCA__c = 0;
    pucPayment.pymt__Amount__c = 100;
    pucPayment.pymt__Transaction_Type__c = 'Payment';
    pucPayment.pymt__Payment_Type__c = 'Credit Card';

    pymt__PaymentX__c nonPucPayment = new pymt__PaymentX__c();
    nonPucPayment.pymt__Status__c = 'Completed';
    nonPucPayment.pymt__Date__c = Date.newInstance(sd.year(), 6, 1);
    nonPucPayment.Division__c = 'PVL';
    nonPucPayment.CreditCardFee__c = 0;
    nonPucPayment.pymt__Transaction_Fee__c = 10;
    nonPucPayment.PPIFeeAmount__c = 10;
    nonPucPayment.HIGETaxAmount__c = 0;
    nonPucPayment.RemitToDCCA__c = 0;
    nonPucPayment.pymt__Amount__c = 100;
    nonPucPayment.pymt__Transaction_Type__c = 'Payment';
    nonPucPayment.pymt__Payment_Type__c = 'Credit Card';

    insert new List<pymt__PaymentX__c>{ pucPayment, nonPucPayment };

    // Link payments to FeeSchedule after insert because PaymentAllHandler clears FeeSchedule__c on insert
    pucPayment.FeeSchedule__c = fsch1.Id;
    nonPucPayment.FeeSchedule__c = fsch1.Id;
    update new List<pymt__PaymentX__c>{ pucPayment, nonPucPayment };

    Test.startTest();
    Database.executeBatch(new DCCAFeeScheduleBatch());
    Test.stopTest();

    FeeSchedule__c updatedFsch = [
      SELECT
        Id,
        PPIFeeAmount__c,
        TransactionFee__c,
        CreditCardFee__c,
        HIGETaxAmount__c,
        RemitToDCCA__c,
        TotalCollections__c
      FROM FeeSchedule__c
      WHERE Id = :fsch1.Id
    ];

    System.assertEquals(
      10,
      updatedFsch.PPIFeeAmount__c,
      'DCCAFeeScheduleBatch should exclude PUC payment PPI fee'
    );
    System.assertEquals(
      10,
      updatedFsch.TransactionFee__c,
      'DCCAFeeScheduleBatch should exclude PUC payment transaction fee'
    );
  }

  @IsTest
  static void testDoesNotHitSoqlLimit() {
    Date sd = Date.today();

    FeeSchedule__c fsch1 = new FeeSchedule__c();
    fsch1.Name = 'DCCA Batch PUC Test - ' + String.valueOf(sd.year());
    fsch1.BeginningDate__c = Date.newInstance(sd.year(), 1, 1);
    fsch1.EndingDate__c = Date.newInstance(sd.year(), 12, 31);
    fsch1.HIGETaxAmount__c = 0;
    fsch1.CreditCardFee__c = 0;
    fsch1.PPIFeeAmount__c = 0;
    fsch1.RemitToDCCA__c = 0;
    fsch1.TransactionFee__c = 0;
    fsch1.TotalCollections__c = 0;
    fsch1.PPIFeePercent__c = 10;
    fsch1.InflationPercent__c = 0;
    fsch1.HIGETaxPercent__c = 5;
    fsch1.Status__c = 'Active';
    fsch1.MaximumPPIFees__c = 1000;
    insert fsch1;

    Test.startTest();
    PaymentAllHandler.runPaymentXStart = false;
    new PaymentXBatch().execute(null, test100Payments());
    Test.stopTest();

    pymt__PaymentX__c[] updatedPayments = [
      SELECT Id
      FROM pymt__PaymentX__c
      WHERE FeeSchedule__c = NULL
    ];
    System.assert(updatedPayments.isEmpty());
  }

  private static pymt__PaymentX__c[] test100Payments() {
    Date sd = Date.today();
    pymt__PaymentX__c[] payments = new List<pymt__PaymentX__c>{};
    for (Integer i = 0; i <= 102; i++) {
      pymt__PaymentX__c nonPucPayment = new pymt__PaymentX__c();
      nonPucPayment.pymt__Status__c = 'Completed';
      nonPucPayment.pymt__Date__c = Date.newInstance(sd.year(), 6, 1);
      nonPucPayment.Division__c = 'PVL';
      nonPucPayment.CreditCardFee__c = 0;
      nonPucPayment.pymt__Transaction_Fee__c = 10;
      nonPucPayment.PPIFeeAmount__c = 10;
      nonPucPayment.HIGETaxAmount__c = 0;
      nonPucPayment.RemitToDCCA__c = 0;
      nonPucPayment.pymt__Amount__c = 100;
      nonPucPayment.pymt__Transaction_Type__c = 'Payment';
      nonPucPayment.pymt__Payment_Type__c = 'Credit Card';
      payments.add(nonPucPayment);
    }

    PaymentAllHandler.runPaymentXStart = false;

    insert payments;

    return [
      SELECT
        Id,
        Name,
        Division__c,
        FeeSchedule__c,
        RemitToDCCA__c,
        pymt__Date__c,
        pymt__Amount__c,
        PPIFeeAmount__c,
        HIGETaxAmount__c,
        CreditCardFee__c,
        pymt__Transaction_Fee__c,
        pymt__Transaction_Type__c,
        pymt__Payment_Type__c
      FROM pymt__PaymentX__c
      WHERE Id IN :payments
    ];
  }
}