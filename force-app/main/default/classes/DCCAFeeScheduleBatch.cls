/*
 * ******************************************************************************************************
 * Name: DCCAFeeScheduleBatch.cls
 * Author: PacificPoint
 * Date: 7/2/2018
 * Realted to: PaymentXBatch.cls (This batch is started as soon as PaymentXBatch ends)
 * Test class: PaymentXBatchTest.cls
 * // Set the following fields on the DCCAFeeSchedule__c record where the Status__c = 'Active':
 * 1. HIGETaxAmount__c - Sum of the pymt__PaymentX__c.HIGETaxAmount__c on all Payment Records related to the Fee Schedule
 * 2. MerchantFee__c - Sum of the pymt__PaymentX__c.MerchantFee__c on all Payment Records related to the Fee Schedule
 * 3. PPIFeeAmount__c - Sum of the pymt__PaymentX__c.PPIFeeAmount__c on all Payment Records related to the Fee Schedule
 * 4. RemitToDCCA__c - Sum of the pymt__PaymentX__c.RemitToDCCA__c on all Payment Records related to the Fee Schedule
 * 5. TransactionFee__c - Sum of the pymt__PaymentX__c.pymt__Transaction_Fee__c on all Payment Records related to the Fee Schedule
 * 6. TotalTransactionAmount__c - Sum of the pymt__PaymentX__c.pymt__Amount__c on all Payment Records related to the Fee Schedule
 * ******************************************************************************************************
 */

global class DCCAFeeScheduleBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Map<Id, FeeSchedule__c> feeScheduleMap = new Map<Id, FeeSchedule__c>();
  global Database.QueryLocator start(Database.BatchableContext bc) {
    String Query =
      'SELECT Id,' +
      'HIGETaxAmount__c,' +
      'CreditCardFee__c,' +
      'PPIFeeAmount__c,' +
      'RemitToDCCA__c,' +
      'pymt__Transaction_Fee__c,' +
      'pymt__Amount__c,' +
      'Division__c, ' +
      'FeeSchedule__c' +
      ' FROM pymt__PaymentX__c' +
      ' WHERE FeeSchedule__r.Status__c =\'Active\'';
    return Database.getQueryLocator(Query);
  }

  global void execute(
    Database.BatchableContext bc,
    List<pymt__PaymentX__c> payments
  ) {
    Map<Id, List<pymt__PaymentX__c>> paymentsMap = new Map<Id, List<pymt__PaymentX__c>>();

    for (pymt__PaymentX__c payment : payments) {
      if (!paymentsMap.containsKey(payment.FeeSchedule__c)) {
        paymentsMap.put(payment.FeeSchedule__c, new List<pymt__PaymentX__c>());
      }
      paymentsMap.get(payment.FeeSchedule__c).add(payment);
    }

    List<FeeSchedule__c> feeSchedules = [
      SELECT
        Id,
        HIGETaxAmount__c,
        CreditCardFee__c,
        PPIFeeAmount__c,
        RemitToDCCA__c,
        TransactionFee__c,
        TotalCollections__c
      FROM FeeSchedule__c
      WHERE Id IN :paymentsMap.keySet()
    ];

    for (FeeSchedule__c feeSch : feeSchedules) {
      if (!feeScheduleMap.containsKey(feeSch.Id)) {
        feeSch.HIGETaxAmount__c = 0;
        feeSch.CreditCardFee__c = 0;
        feeSch.PPIFeeAmount__c = 0;
        feeSch.RemitToDCCA__c = 0;
        feeSch.TransactionFee__c = 0;
        feeSch.TotalCollections__c = 0;
        feeScheduleMap.put(feeSch.Id, feeSch);
      }

      FeeSchedule__c existingFeeSch = feeScheduleMap.get(feeSch.Id);

      List<pymt__PaymentX__c> currentPayments = paymentsMap.get(feeSch.Id);
      for (pymt__PaymentX__c payment : currentPayments) {
        if (payment.HIGETaxAmount__c != null) {
          existingFeeSch.HIGETaxAmount__c += payment.HIGETaxAmount__c;
        }

        if (payment.CreditCardFee__c != null) {
          existingFeeSch.CreditCardFee__c += payment.CreditCardFee__c;
        }

        if (payment.PPIFeeAmount__c != null && payment.Division__c <> 'PUC') {
          existingFeeSch.PPIFeeAmount__c += payment.PPIFeeAmount__c;
        }

        if (payment.RemitToDCCA__c != null) {
          existingFeeSch.RemitToDCCA__c += payment.RemitToDCCA__c;
        }

        if (
          payment.pymt__Transaction_Fee__c != null &&
          payment.Division__c <> 'PUC'
        ) {
          existingFeeSch.TransactionFee__c += payment.pymt__Transaction_Fee__c;
        }

        if (payment.pymt__Amount__c != null) {
          existingFeeSch.TotalCollections__c += payment.pymt__Amount__c;
        }
      }
    }
      System.debug(feeScheduleMap.values());

    update feeScheduleMap.values();
  }

  global void finish(Database.BatchableContext bc) {
  }
}