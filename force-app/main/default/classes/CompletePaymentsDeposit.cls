/*
 * -----------------------------------------------------------------------------------
 * Covered by CompletePaymentsDepositTest
 * -----------------------------------------------------------------------------------
 * Initial implementation
 * -----------------------------------------------------------------------------------
 * Changes
 * PacPoint-IC071819 - Updated for Phase 2
 * Added another condition for retrieving complete payments
 *
 * PacPoint-CL04272021 - Updated for Year 4
 * See Case 00014406
 * -----------------------------------------------------------------------------------
 */
public class CompletePaymentsDeposit {
    private String depositId;
    private Boolean isPuc = false;

    public CompletePaymentsDeposit(ApexPages.StandardController stdController) {
        this.depositId = stdController.getId();
    }

    public PageReference AddCompletePayments() {
        Database.executeBatch(new AsyncCompletePaymentsDeposit(this.depositId), 20);
        PageReference pageRef = new PageReference('/' + this.depositId);
        pageRef.setRedirect(true);
        return pageRef;
    }
}