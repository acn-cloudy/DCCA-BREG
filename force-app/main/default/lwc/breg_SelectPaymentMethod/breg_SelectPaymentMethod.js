import { LightningElement, api } from "lwc";
import { Labels } from "./labels";
import { setPageUrlParams } from "c/utils";
import { NavigationMixin } from "lightning/navigation";

export default class Breg_AnnualSelectPaymentMethod extends NavigationMixin(LightningElement) {
    chosenMethod;
    labels = Labels;
    @api accountNumber;

    handleMethodChange(event) {
        const selected = event.target.dataset.value;
        this.chosenMethod = this.chosenMethod === selected ? null : selected;
    }

    get isNextDisabled() {
        return !this.chosenMethod;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }

    handlePrevious() {
        setPageUrlParams({
            page: "login",
            fileNumber: this.accountNumber,
            year: null
        });
        this.dispatchEvent(new CustomEvent("previous"));
    }

    handleNext() {
        setPageUrlParams({
            page: "contact",
            fileNumber: this.accountNumber,
            year: null
        });
        this.dispatchEvent(new CustomEvent("next", { detail: { chosenMethod: this.chosenMethod } }));
    }
}