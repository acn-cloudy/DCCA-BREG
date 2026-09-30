import { LightningElement, wire } from "lwc";
import isPaymentAuthorizationNoticeEnabled from "@salesforce/apex/BREGPaymentController.isPaymentAuthorizationNoticeEnabled";
import { Labels } from "./labels";

export default class Breg_PaymentAuthorizationNotice extends LightningElement {
    labels = Labels;

    // Controlled by BREG_Setting__c.Payment_Authorization_Notice_Enabled__c
    @wire(isPaymentAuthorizationNoticeEnabled)
    noticeEnabled;

    get isVisible() {
        return this.noticeEnabled?.data === true;
    }

    get paragraphs() {
        return [
            this.labels.authorization,
            this.labels.review,
            this.labels.dishonoredCharge,
            this.labels.eCheckStatementName,
            this.labels.nonRefundable,
            this.labels.questions
        ]
            .filter((text) => text)
            .map((text, index) => ({ key: `p-${index}`, text }));
    }
}