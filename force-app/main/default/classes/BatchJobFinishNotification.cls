/*
 * -----------------------------------------------------------------------------------
 * Description
 * -----------------------------------------------------------------------------------
 * Covered by: BatchJobFinishNotificationTest
 * -----------------------------------------------------------------------------------
 * PacPoint-CL05202022 - Created for PVL Case 00021634
 * -----------------------------------------------------------------------------------
 * Initial implementation
 *
 * @author chris.loyola@pacificpointcorp.com
 *
 * @created 05/20/2022
 * -----------------------------------------------------------------------------------
 * Changes
 * -----------------------------------------------------------------------------------
 */
public class BatchJobFinishNotification {
    private String batchJobName;
    private String licenseTypeName;

    public BatchJobFinishNotification(String batchJobName) {
        this.batchJobName = batchJobName;
    }

    public BatchJobFinishNotification(String batchJobName, String licenseTypeName) {
        this(batchJobName);
        this.licenseTypeName = licenseTypeName;
    }

    public void sendEmail() {
        List<OrgWideEmailAddress> fromAddress = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'DCCA No Reply'];
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();

        if (!fromAddress.isEmpty()) {
            msg.setOrgWideEmailAddressId(fromAddress[0].Id);
        }

        String subject = 'Ho\'ala ' + this.batchJobName + ' Batch Job Complete';
        String plainTextBody = 'Hi ' + UserInfo.getName() + ',\n\n';
        if (this.licenseTypeName != null) {
            plainTextBody += 'The ' + this.batchJobName +
                    ' for License Type: ' +
                    this.licenseTypeName +
                    ' has been run successfully.';
        } else {
            plainTextBody += 'The ' + this.batchJobName + ' has been run successfully.';
        }

        List<String> toAddress = new List<String>();
        toAddress.add(UserInfo.getUserEmail());

        msg.setSubject(subject);
        msg.setPlainTextBody(plainTextBody);
        msg.setToAddresses(toAddress);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{msg});
    }
}