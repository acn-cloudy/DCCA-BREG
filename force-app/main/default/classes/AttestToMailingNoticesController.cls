/*
 * -----------------------------------------------------------------------------------
 * Description
 *
 * -----------------------------------------------------------------------------------
 * Covered by: AttestToMailingNoticesControllerTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL10172022 - Created for case 00025290
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 10/17/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class AttestToMailingNoticesController {
    @AuraEnabled
    public static List<AttestToMailingNoticesController.Notice> getNotifications() {
        List<Notification__c> notifications = [
            SELECT
                Id,
                TimeDelivered__c
            FROM Notification__c
            WHERE Status__c = 'Completed'
            AND Scheduled__c = true
            AND SendtoPrinter__c = false
            AND MailedByAttestation__c = null
            AND TimeDelivered__c != null
            ORDER BY TimeDelivered__c ASC
        ];

        Map<Date, List<Notification__c>> tempResult = new Map<Date, List<Notification__c>>();
        //group records by date
        for (Notification__c n : notifications) {
            if (!tempResult.containsKey(n.TimeDelivered__c.date())) {
                tempResult.put(n.TimeDelivered__c.date(), new List<Notification__c>());
            }

            tempResult.get(n.TimeDelivered__c.date()).add(n);
        }

        List<AttestToMailingNoticesController.Notice> result = new List<AttestToMailingNoticesController.Notice>();
        for (Date d : tempResult.keySet()) {
            result.add(new Notice(d, tempResult.get(d)));
        }

        return result;
    }

    @AuraEnabled
    public static void executeBatch(List<AttestToMailingNoticesController.Notice> selectedRows, List<AttestToMailingNoticesController.Notice> drafts) {
        Database.executeBatch(new AttestToMailingNoticesBatch(selectedRows, drafts));
    }

    public class Notice{
        @AuraEnabled
        public Date timeDelivered{
            get;set;
        }

        @AuraEnabled
        public Integer count{
            get;set;
        }

        @AuraEnabled
        public Datetime mailedDateTime{
            get;set;
        }

        @AuraEnabled
        public String mailedBy{
            get;set;
        }

        @AuraEnabled
        public List<Notification__c> notifications{
            get;set;
        }

        public Notice() {
        }

        public Notice(Date timeDelivered, List<Notification__c> notifications) {
            this.timeDelivered = timeDelivered;
            this.mailedDateTime = Datetime.now();
            this.mailedBy = UserInfo.getName();
            this.count = notifications.size();
            this.notifications = notifications;
        }
    }
}