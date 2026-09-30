/*
 * ******************************************************************************************************
 * Name: PaymentXBatch.cls
 * Author: PacificPoint
 * Date: 7/2/2018
 * Scheduler Class: PaymentXBatchScheduler.cls
 * Test class: PaymentXBatchTest.cls
 * // For all records where the Status = Completed AND the FeeSchedule__c is not populated:
 * 1. Find the matching Fee Schedule Record and populate it into the FeeSchedule__c field on the Payment record
 * 2. Set PPIFeeAmount__c, HIGETaxAmount__c and RemitToDCCA__c on the Payment Record
 * // To Schedule the batch to run hourly
 * // run the following 3 lines
 * PaymentXBatch pB = new PaymentXBatch();
 * String sch = '0 0 * * * ?';
 * String jobID = system.schedule('PaymentXBatch - Hourly Batch Schedule Job', sch, pB);
 * 1. Developer Console -> Debug -> Open Execute Anonymous Window
 * 2. Copy/paste the code and hit Execute button
 * 3. The batch should appear in Jobs / Scheduled Jobs
 * // To test the batch
 * // run the following line
 * Id batchJobId = Database.executeBatch(new PaymentXBatch());
 * 1. Developer Console -> Debug -> Open Execute Anonymous Window
 * 2. Copy/paste the code from line 24 and hit Execute button
 * ******************************************************************************************************
 *
 * @changes 08/02/2021 case 00015533
 * PacPoint-CL080221
 */

global class PaymentXBatch implements Schedulable, Database.Batchable<SObject>, Database.Stateful {
  private static Decimal getCappedPpiAmount(
    FeeSchedule__c feeSch,
    Decimal requestedPpiAmount
  ) {
    Decimal currentPpiAmount = feeSch.PPIFeeAmount__c ?? 0;
    Decimal currentPpiMaximum = calculateFeeSchedTotalPpiMax(feeSch) ?? 0;
    Decimal remainingPpiCapacity = currentPpiMaximum - currentPpiAmount;

    if (remainingPpiCapacity <= 0 || requestedPpiAmount <= 0) {
      return 0;
    }

    Decimal higeTaxRate = Math.abs((feeSch.HIGETaxPercent__c ?? 0) / 100);

    // TotalPPIMaximum__c includes HIGE tax, so each extra PPI dollar also increases the cap.
    if (higeTaxRate >= 1) {
      return requestedPpiAmount;
    }

    Decimal ppiAmountAllowedByCap = remainingPpiCapacity / (1 - higeTaxRate);
    return Math.min(requestedPpiAmount, ppiAmountAllowedByCap);
  }

  global static void schedule5min() {
    List<CronTrigger> existingJobs = [
      SELECT Id, CronJobDetail.Name
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE '%PaymentXBatch - Scheduled Job%'
    ];

    for (CronTrigger ct : existingJobs) {
      System.abortJob(ct.Id);
    }

    String sch1 = '0 0 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 00',
      sch1,
      new PaymentXBatch()
    );

    String sch2 = '0 5 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 05',
      sch2,
      new PaymentXBatch()
    );

    String sch3 = '0 10 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 10',
      sch3,
      new PaymentXBatch()
    );

    String sch4 = '0 15 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 15',
      sch4,
      new PaymentXBatch()
    );

    String sch5 = '0 20 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 20',
      sch5,
      new PaymentXBatch()
    );

    String sch6 = '0 25 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 25',
      sch6,
      new PaymentXBatch()
    );

    String sch7 = '0 30 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 30',
      sch7,
      new PaymentXBatch()
    );

    String sch8 = '0 35 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 35',
      sch8,
      new PaymentXBatch()
    );

    String sch9 = '0 40 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 40',
      sch9,
      new PaymentXBatch()
    );

    String sch10 = '0 45 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 45',
      sch10,
      new PaymentXBatch()
    );

    String sch11 = '0 50 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 50',
      sch11,
      new PaymentXBatch()
    );

    String sch12 = '0 55 * * * ?';
    System.schedule(
      'PaymentXBatch - Scheduled Job - 55',
      sch12,
      new PaymentXBatch()
    );
  }

  global static void schedule() {
    List<CronTrigger> existingJobs = [
      SELECT Id, CronJobDetail.Name
      FROM CronTrigger
      WHERE
        CronJobDetail.Name LIKE '%PaymentXBatch - Hourly Batch Schedule Job%'
    ];

    for (CronTrigger ct : existingJobs) {
      System.abortJob(ct.Id);
    }

    PaymentXBatch pB1 = new PaymentXBatch();
    String sch1 = '0 0 * * * ?';
    system.schedule(
      'PaymentXBatch - Hourly Batch Schedule Job - 00',
      sch1,
      pB1
    );
    PaymentXBatch pB2 = new PaymentXBatch();
    String sch2 = '0 15 * * * ?';
    system.schedule(
      'PaymentXBatch - Hourly Batch Schedule Job - 15',
      sch2,
      pB2
    );
    PaymentXBatch pB3 = new PaymentXBatch();
    String sch3 = '0 30 * * * ?';
    system.schedule(
      'PaymentXBatch - Hourly Batch Schedule Job - 30',
      sch3,
      pB3
    );
    PaymentXBatch pB4 = new PaymentXBatch();
    String sch4 = '0 45 * * * ?';
    system.schedule(
      'PaymentXBatch - Hourly Batch Schedule Job - 45',
      sch4,
      pB4
    );
  }

  global void execute(SchedulableContext SC) {
    Database.executeBatch(new PaymentXBatch());
  }

  global Database.QueryLocator start(Database.BatchableContext bc) {
    String integrationProfileId = GlobalUtilities.getIntegrationProfileId();
    String query =
      'SELECT Id, ' +
      'Name, ' +
      'FeeSchedule__c, ' +
      'RemitToDCCA__c, ' +
      'pymt__Date__c, ' +
      'pymt__Amount__c, ' +
      'PPIFeeAmount__c, ' +
      'HIGETaxAmount__c, ' +
      'CreditCardFee__c, ' +
      'Division__c, ' +
      'pymt__Transaction_Fee__c, ' +
      'pymt__Transaction_Type__c, ' +
      'pymt__Payment_Type__c ' +
      'FROM pymt__PaymentX__c ' +
      'WHERE (pymt__Status__c = \'Completed\' OR pymt__Status__c = \'Voided\') ' +
      'AND FeeSchedule__c = null ' +
      'AND CreatedBy.ProfileId <> \'' +
      integrationProfileId +
      '\'';
    return Database.getQueryLocator(query);
  }

  global void execute(
    Database.BatchableContext bc,
    List<pymt__PaymentX__c> payments
  ) {
    List<FeeSchedule__c> allDCCAFeeSchedules = [
      SELECT
        Id,
        BeginningDate__c,
        EndingDate__c,
        PPIFeePercent__c,
        PPIFeeAmount__c,
        TotalPPIMaximum__c,
        InflationPercent__c,
        HIGETaxPercent__c,
        MaximumPPIFees__c,
        SoftwareLicenseFees__c,
        HardwareFees__c,
        ServicesFees__c,
        HIGETaxAmount__c,
        TransactionFee__c,
        RemitToDCCA__c
      FROM FeeSchedule__c
    ];

    for (pymt__PaymentX__c payment : payments) {
      payment.PPIFeeAmount__c = payment.PPIFeeAmount__c ?? 0;
      payment.HIGETaxAmount__c = payment.HIGETaxAmount__c ?? 0;
      payment.CreditCardFee__c = payment.CreditCardFee__c ?? 0;
      payment.pymt__Transaction_Fee__c = payment.pymt__Transaction_Fee__c ?? 0;
      payment.RemitToDCCA__c = payment.RemitToDCCA__c ?? 0;

      for (FeeSchedule__c feeSch : allDCCAFeeSchedules) {
        feeSch.PPIFeeAmount__c = feeSch.PPIFeeAmount__c ?? 0;
        feeSch.HIGETaxAmount__c = feeSch.HIGETaxAmount__c ?? 0;
        feeSch.RemitToDCCA__c = feeSch.RemitToDCCA__c ?? 0;

        if (
          payment.pymt__Date__c >= feeSch.BeginningDate__c &&
          payment.pymt__Date__c <= feeSch.EndingDate__c
        ) {
          payment.FeeSchedule__c = feeSch.Id;
          Decimal ppiTotalMax = calculateFeeSchedTotalPpiMax(feeSch);

          //PPI Fee Amount Calculation only if the Division is not PUC
          if (payment.Division__c <> 'PUC') {
            if (feeSch.PPIFeeAmount__c >= ppiTotalMax) {
              payment.PPIFeeAmount__c = 0;
            } else {
              payment.pymt__Amount__c = payment.pymt__Amount__c ?? 0;
              feeSch.PPIFeePercent__c = feeSch.PPIFeePercent__c ?? 0;
              feeSch.InflationPercent__c = feeSch.InflationPercent__c ?? 0;

              Decimal requestedPpiAmount = Math.abs(
                payment.pymt__Amount__c *
                  feeSch.PPIFeePercent__c *
                  (1 + feeSch.InflationPercent__c) /
                  100
              );
              payment.PPIFeeAmount__c = getCappedPpiAmount(
                feeSch,
                requestedPpiAmount
              );

              feeSch.PPIFeeAmount__c += payment.PPIFeeAmount__c;
            }
          }

          payment.HIGETaxAmount__c = Math.abs(
            payment.PPIFeeAmount__c * feeSch.HIGETaxPercent__c / 100
          );

          if (payment.pymt__Transaction_Type__c == 'Payment') {
            if (payment.pymt__Amount__c >= 0) {
              payment.RemitToDCCA__c =
                payment.pymt__Amount__c -
                payment.PPIFeeAmount__c -
                payment.HIGETaxAmount__c -
                payment.CreditCardFee__c -
                payment.pymt__Transaction_Fee__c;
            } else {
              payment.RemitToDCCA__c =
                payment.pymt__Amount__c -
                payment.PPIFeeAmount__c -
                payment.HIGETaxAmount__c;
            }
          } else {
            if (payment.pymt__Transaction_Type__c == 'Refund') {
              if (payment.pymt__Amount__c >= 0) {
                if (payment.pymt__Payment_Type__c == 'Credit Card') {
                  payment.RemitToDCCA__c =
                    payment.pymt__Amount__c -
                    payment.PPIFeeAmount__c -
                    payment.HIGETaxAmount__c -
                    payment.CreditCardFee__c -
                    payment.pymt__Transaction_Fee__c;
                }

                if (
                  payment.pymt__Payment_Type__c == 'Check' ||
                  payment.pymt__Payment_Type__c == 'Money Order' ||
                  payment.pymt__Payment_Type__c == 'Cash' ||
                  payment.pymt__Payment_Type__c == 'Cashier\'s Check' ||
                  payment.pymt__Payment_Type__c == 'ECheck' ||
                  payment.pymt__Payment_Type__c == 'Electronic Funds Transfer'
                ) {
                  payment.RemitToDCCA__c =
                    0 -
                    payment.PPIFeeAmount__c -
                    payment.HIGETaxAmount__c -
                    payment.CreditCardFee__c -
                    payment.pymt__Transaction_Fee__c;
                }
              } else {
                payment.RemitToDCCA__c =
                  payment.pymt__Amount__c -
                  payment.PPIFeeAmount__c -
                  payment.HIGETaxAmount__c;
              }
            }
          }

          if (payment.HIGETaxAmount__c != null) {
            feeSch.HIGETaxAmount__c += payment.HIGETaxAmount__c;
          }

          if (payment.RemitToDCCA__c != null) {
            feeSch.RemitToDCCA__c += payment.RemitToDCCA__c;
          }
        }
      }
    }

    update payments;
  }

  //We need to manually calculate for TotalPPIMaximum__c, because the Formula.recalculateFormulas()
  //counts against the governor limits
  private static Decimal calculateFeeSchedTotalPpiMax(FeeSchedule__c fee) {
    return (fee.MaximumPPIFees__c ?? 0) +
      (fee.SoftwareLicenseFees__c ?? 0) +
      (fee.HardwareFees__c ?? 0) +
      (fee.ServicesFees__c ?? 0) +
      (fee.HIGETaxAmount__c ?? 0) +
      (fee.TransactionFee__c ?? 0);
  }

  global void finish(Database.BatchableContext bc) {
    DCCAFeeScheduleBatch b = new DCCAFeeScheduleBatch();

    if (!Test.isRunningTest()) {
      Id batchId = Database.executeBatch(b, 2000);
    } else {
      Id batchIdTest = Database.executeBatch(b);
    }
  }
}