import { LightningElement, api } from "lwc";
import { Labels } from "./labels";

export default class Breg_Popup extends LightningElement {
    @api visible = false;
    @api title;
    @api message;
    @api nextButtonLabel;
    @api cancelButtonLabel;
    @api hideNextButton = false;
    labels = Labels;

    get showNextButton() {
        return !this.hideNextButton;
    }

    handleContinue() {
        this.dispatchEvent(new CustomEvent("continue"));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent("cancel"));
    }
}