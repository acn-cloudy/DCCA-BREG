/********************************************************************************************************
 *    Handler Name:  PaymentAllHandler.cls
 *    Date:  10/1/2018
 *
 *    Trigger: PaymentAll.trigger
 *    Test class: PaymentAllHandlerTest.cls
 ********************************************************************************************************/

public class PaymentAllHandler {
  public static Boolean runPaymentXStart = true;
  //Handler for before insert methods
  public void onBeforeInsert(
    list<pymt__PaymentX__c> newList,
    map<id, pymt__PaymentX__c> newMap
  ) {
    List<String> paymentNames = new List<String>();
    for (pymt__PaymentX__c record : newList) {
      //Fix: PaymentXBatch not executed for refunds
      //@See Case 00007073
      if (
        (record.pymt__Status__c == 'Completed' ||
        record.pymt__Status__c == 'Voided') && record.FeeSchedule__c != null
      ) {
        record.FeeSchedule__c = null;
      }

      paymentNames.add(record.Name);
    }
    List<Transaction__c> tansactions = [
      SELECT Id, Name, TempPaymentType__c, TempMemo__c
      FROM Transaction__c
      WHERE name IN :paymentNames
    ];
    Map<String, Transaction__c> transactionMap = new Map<String, Transaction__c>(
      tansactions
    );
    Map<String, String> transactionIdMap = new Map<String, String>();
    for (Transaction__c record : tansactions) {
      transactionIdMap.put(record.Name, record.Id);
    }
    for (pymt__PaymentX__c record : newList) {
      if (record.Transaction__c == null) {
        record.Transaction__c = transactionIdMap.get(record.Name);
      }
      if (
        record.Transaction__c != null &&
        transactionMap.containsKey(record.Transaction__c)
      ) {
        if (
          transactionMap.get(record.Transaction__c).TempPaymentType__c != null
        ) {
          record.pymt__Payment_Type__c = transactionMap.get(
              record.Transaction__c
            )
            .TempPaymentType__c;
        }
        if (transactionMap.get(record.Transaction__c).TempMemo__c != null) {
          record.pymt__Memo__c = transactionMap.get(record.Transaction__c)
            .TempMemo__c;
        }
      }
      System.debug('######record#######' + record.pymt__Amount__c);
    }

    for (pymt__PaymentX__c record : newList) {
      if (record.TerminalPaymentRecord__c) {
        PVLRenewApp.runSync = true;
      }
    }

    checkDepositIfExisting(newList);
  }
  //Handler for after insert methods
  public void onAfterInsert(
    list<pymt__PaymentX__c> newList,
    map<id, pymt__PaymentX__c> newMap
  ) {
    ChangeTransactionLineStatus(newList, newMap, 'insert');
    PaymentXStart(newList, newMap, 'insert');
    createCollectionAllications(newMap);
  }

  //Handler for before Update methods
  public void onBeforeUpdate(
    list<pymt__PaymentX__c> newList,
    map<id, pymt__PaymentX__c> newMap,
    map<id, pymt__PaymentX__c> oldMap
  ) {
    checkDepositIfExisting(newList);
  }

  //Handler for after Update methods
  public void onAfterUpdate(
    list<pymt__PaymentX__c> newList,
    map<id, pymt__PaymentX__c> newMap,
    map<id, pymt__PaymentX__c> oldMap
  ) {
    ChangeTransactionLineStatus(newList, oldMap, 'update');
    PaymentXStart(newList, oldMap, 'update');
  }

  //Handler for before Deletes methods
  /*public void onBeforeDelete(list<pymt__PaymentX__c> oldList , map<id, pymt__PaymentX__c> oldMap) {

    }
    //Handler for after Deletes methods
    public void onAfterDelete(list<pymt__PaymentX__c> oldList , map<id, pymt__PaymentX__c> oldMap) {

    }*/

  // 00006264
  // create Collection Allocation for Refunds
  private void createCollectionAllications(Map<id, pymt__PaymentX__c> newMap) {
    List<pymt__PaymentX__c> refundPayments = new List<pymt__PaymentX__c>();
    // filter refund payments
    for (String key : newMap.keySet()) {
      pymt__PaymentX__c payment = newMap.get(key);
      if (
        payment.pymt__Transaction_Type__c == 'Refund' &&
        payment.Transaction__c != null
      ) {
        refundPayments.add(newMap.get(key));
      }
    }
    if (refundPayments.isEmpty())
      return;
    // create map: transactionId => paymentId
    Map<String, pymt__PaymentX__c> transactionIdToPaymentMap = new Map<String, pymt__PaymentX__c>();
    for (pymt__PaymentX__c payment : refundPayments) {
      transactionIdToPaymentMap.put(payment.Transaction__c, payment);
    }

    List<String> transactionIdList = new List<String>(
      transactionIdToPaymentMap.keySet()
    );

    // query all transactions has TransactionGroup__c
    List<Transaction__c> childrenTransactions = [
      SELECT Id, TransactionGroup__c
      FROM Transaction__c
      WHERE TransactionGroup__c = :transactionIdList
    ];
    Map<String, Transaction__c> childrenTransactionsMap = new Map<String, Transaction__c>(
      childrenTransactions
    );
    // get all transactionGroups
    Set<String> transactionGroups = new Set<String>();
    for (Transaction__c trans : childrenTransactions) {
      transactionGroups.add(trans.TransactionGroup__c);
    }

    // get all transactions Id:
    // including all transaction Id in childrenTransactions and TransactionGroup__c not exist in transactionIdList
    // 1.all transaction Id in childrenTransactions
    List<String> transactionIds = new List<String>();
    for (Transaction__c trans : childrenTransactions) {
      transactionIds.add(trans.Id);
    }
    // 2.TransactionGroup__c not exist in transactionIdList
    for (pymt__PaymentX__c payment : refundPayments) {
      if (!transactionGroups.contains(payment.Transaction__c)) {
        transactionIds.add(payment.Transaction__c);
      }
    }

    // get all transactionLines requested for refund.
    // Lines flagged PartialRefundApply__c are prioritised first, then FIFO by Name (auto-number).
    List<TransactionLine__c> transactionLines = [
      SELECT
        Id,
        Transaction__c,
        Payment__c,
        RefundAmount__c,
        PartialRefundApply__c,
        Name
      FROM TransactionLine__c
      WHERE Transaction__c = :transactionIds AND RequestRefund__c = TRUE
      ORDER BY PartialRefundApply__c DESC, Name ASC
    ];
    if (transactionLines.isEmpty())
      return;

    // Group the ordered lines by the refund payment they belong to (direct transaction or, for a
    // group payment, via the child transaction's TransactionGroup__c). The query order is preserved
    // within each group, so priority + FIFO ordering carries over per payment.
    Map<Id, pymt__PaymentX__c> paymentById = new Map<Id, pymt__PaymentX__c>(
      refundPayments
    );
    Map<Id, List<TransactionLine__c>> paymentToLines = new Map<Id, List<TransactionLine__c>>();
    for (TransactionLine__c transactionLine : transactionLines) {
      if (transactionLine.Transaction__c == null) {
        continue;
      }
      pymt__PaymentX__c payment = transactionIdToPaymentMap.get(
        transactionLine.Transaction__c
      );
      if (
        payment == null &&
        childrenTransactionsMap.containsKey(transactionLine.Transaction__c)
      ) {
        String tranGroup = childrenTransactionsMap.get(
            transactionLine.Transaction__c
          )
          .TransactionGroup__c;
        payment = transactionIdToPaymentMap.get(tranGroup);
      }
      if (payment == null) {
        continue;
      }
      if (!paymentToLines.containsKey(payment.Id)) {
        paymentToLines.put(payment.Id, new List<TransactionLine__c>());
      }
      paymentToLines.get(payment.Id).add(transactionLine);
    }

    List<CollectionsAllocation__c> newCollectionsAllocations = new List<CollectionsAllocation__c>();

    // For each refund payment, allocate to its lines in priority/FIFO order, capping the running
    // total at the refund payment amount. pymt__Amount__c is stored negative for refunds, so the
    // magnitude is the cap; RefundAmount__c is the per-line requested amount.
    for (Id paymentId : paymentToLines.keySet()) {
      pymt__PaymentX__c payment = paymentById.get(paymentId);
      Decimal remainingRefund = (payment.pymt__Amount__c == null)
        ? 0
        : Math.abs(payment.pymt__Amount__c);

      for (TransactionLine__c transactionLine : paymentToLines.get(paymentId)) {
        if (remainingRefund <= 0) {
          break;
        }
        Decimal lineRefund = transactionLine.RefundAmount__c;
        if (lineRefund == null || lineRefund <= 0) {
          continue;
        }
        // cap this line at whatever refund balance is left
        Decimal allocAmount = (lineRefund < remainingRefund)
          ? lineRefund
          : remainingRefund;
        // The Collection Allocation Record is created with the following fields:
        // Allocation Type: "Payment Allocation"
        // Payment: PaymentId
        // Transaction: TransactionLine.Transaction
        CollectionsAllocation__c collectionsAllocation = new CollectionsAllocation__c(
          AllocationType__c = 'Payment Allocation',
          TransactionLine__c = transactionLine.Id,
          AmountAllocated__c = allocAmount * -1,
          Transaction__c = transactionLine.Transaction__c,
          Payment__c = payment.Id
        );
        newCollectionsAllocations.add(collectionsAllocation);
        remainingRefund -= allocAmount;
      }
    }
    if (!newCollectionsAllocations.isEmpty())
      insert newCollectionsAllocations;
  }

  private void PaymentXStart(
    list<pymt__PaymentX__c> newList,
    map<id, pymt__PaymentX__c> newOldMap,
    String actionType
  ) {
    if (System.isFuture() || System.isBatch() || !runPaymentXStart)
      return;

    Set<Id> pIds = new Set<Id>();
    for (pymt__PaymentX__c pp : newList) {
      if (actionType == 'insert') {
        if (
          (pp.pymt__Status__c == 'Completed' ||
          pp.pymt__Status__c == 'Voided') && pp.FeeSchedule__c == null
        ) {
          pIds.add(pp.Id);
        }
      }
      if (actionType == 'update') {
        pymt__PaymentX__c oldpp = newOldMap.get(pp.Id);
        if (pp.FeeSchedule__c == null) {
          if (
            (pp.pymt__Status__c == 'Completed' &&
            oldpp.pymt__Status__c != 'Completed') ||
            (pp.pymt__Status__c == 'Voided' &&
            oldpp.pymt__Status__c != 'Voided')
          ) {
            pIds.add(pp.Id);
          }
        }
      }
    }
    PVLProcess__e process = new PVLProcess__e();
    process.Type__c = 'Create collection allocation';
    process.Payload__c = JSON.serialize(pIds);
    EventBus.publish(process);
  }
  public static void PaymentXStart(Set<Id> pIds) {
    // Set up Fee Schedule.
    (new PaymentXBatch())
      .execute(
        null,
        [
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
          WHERE Id IN :pIds
        ]
      );
    // Create collection allocation records.
    (new PaymentAllocateTransactionLinesBatch())
      .execute(
        null,
        [
          SELECT Id, Transaction__c, RemainingAmounttoAllocate__c
          FROM pymt__PaymentX__c
          WHERE
            FeeSchedule__c != NULL
            AND PPIFeeAmount__c != NULL
            AND pymt__Transaction_Type__c != 'Refund'
            AND RemainingAmounttoAllocate__c > 0
            AND pymt__Status__c = 'Completed'
            AND Id IN :pIds
        ]
      );
  }

  private void ChangeTransactionLineStatus(
    list<pymt__PaymentX__c> newList,
    map<id, pymt__PaymentX__c> newOldMap,
    String actionType
  ) {
    Set<Id> paymentIds = new Set<Id>();
    for (pymt__PaymentX__c pp : newList) {
      if (actionType == 'insert' && pp.pymt__Status__c == 'Completed')
        paymentIds.add(pp.Id);
      if (
        actionType == 'update' &&
        ((pp.pymt__Status__c == 'Completed' &&
        newOldMap.get(pp.Id).pymt__Status__c != 'Completed') ||
        pp.Transaction__c != newOldMap.get(pp.Id).Transaction__c)
      )
        paymentIds.add(pp.Id);
    }

    if (paymentIds.size() > 0) {
      List<pymt__PaymentX__c> allGroupTransPayment = [
        SELECT Id, Transaction__c
        FROM pymt__PaymentX__c
        WHERE Id IN :paymentIds AND Transaction__r.TransactionType__c = 'Group'
      ];
      Map<Id, Id> transGroupMap = new Map<Id, Id>();
      for (pymt__PaymentX__c pay : allGroupTransPayment) {
        if (!transGroupMap.containsKey(pay.Transaction__c)) {
          transGroupMap.put(pay.Transaction__c, pay.Id);
        }
      }

      List<Transaction__c> allTranscations = [
        SELECT
          Id,
          TransactionGroup__c,
          (
            SELECT Id, PaidStatus__c, Payment__c
            FROM TransactionLines__r
            WHERE PaidStatus__c NOT IN ('Paid', 'Refunded')
          )
        FROM Transaction__c
        WHERE TransactionGroup__c IN :transGroupMap.keySet()
      ];
      List<TransactionLine__c> tlinetoupdate = new List<TransactionLine__c>();
      for (Transaction__c t : allTranscations) {
        for (TransactionLine__c tlines : t.TransactionLines__r) {
          tlines.PaidStatus__c = 'Paid';
          tlines.Payment__c = transGroupMap.get(t.TransactionGroup__c);
          tlinetoupdate.add(tlines);
        }
      }

      if (tlinetoupdate.size() > 0)
        update tlinetoupdate;
    }
  }

  private static void checkDepositIfExisting(list<pymt__PaymentX__c> newList) {
    Set<Id> depositIds = new Set<Id>();
    Set<Id> existingDepositIds = new Set<Id>();
    for (pymt__PaymentX__c record : newList) {
      if (record.DepositBatch__c != null)
        depositIds.add(record.DepositBatch__c);
    }

    // Check existing Deposits
    for (Deposits__c deposit : [
      SELECT Id
      FROM Deposits__c
      WHERE Id IN :depositIds
    ]) {
      existingDepositIds.add(deposit.Id);
    }

    // Set to null DepositBatch__c if Deposit ID not existing
    for (pymt__PaymentX__c record : newList) {
      if (
        record.DepositBatch__c != null &&
        !existingDepositIds.contains(record.DepositBatch__c)
      )
        record.DepositBatch__c = null;
    }
  }
}