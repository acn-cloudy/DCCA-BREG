import BaseFormComponent from "c/breg_BaseFormComponent";
import { getPageParamsFromUrl } from "c/utils";

export default class Breg_TNTMSMName extends BaseFormComponent {
    defaultTitle = "Trade Name";
    footerTitleT1 = "After submission, Business Name pending DCCA approval.";
    TNTMSMNameValue;

    connectedCallback() {
        super.connectedCallback();
        const { isRenewal } = getPageParamsFromUrl();
        if (isRenewal) {
            this.alwaysReadOnly = true;
        }
    }

    get showFooterTitleT1() {
        return this.formCode === "T-1" && this.readOnly;
    }
    get readOnlyTNTMSMNameValue() {
        return `${this.TNTMSMNameValue ? this.TNTMSMNameValue.toUpperCase() : this.emptyInputString}`;
    }
}