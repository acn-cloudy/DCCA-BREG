/*
* ─────────────────────────────────────────────────────────
* Controller for the D1D2DependencyRefund Lightning Component 
* ─────────────────────────────────────────────────────────
* PacPoint-TK01122023 - Created for PVL phase 1
* ───────────────────────────────────────────────────────────
* Initial implementation
* @author       Takashi Koyama - PacificPointCorp 
* @created      2023-01-12
* ───────────────────────────────────────────────────────────
* Changes
*
*
* ───────────────────────────────────────────────────────────
*/public with sharing class D1D2DependencyRefundController {
    @AuraEnabled
    public static void runD1D2DependencyRefundNotice(String recordId){
        D1D2DependencyRefundNotice d1D2DependencyRefundNotice = new D1D2DependencyRefundNotice(recordId);
        
        Database.executeBatch(d1D2DependencyRefundNotice, 200);
    }
}