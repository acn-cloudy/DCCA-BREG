import { LightningElement, api } from "lwc";
import { Labels } from "./labels";
import { setPageUrlParams } from "c/utils";

export default class Breg_AnnualsLoginPage extends LightningElement {
    labels = Labels;
    @api accountNumber;
    handleGuest() {
        setPageUrlParams({
            page: "payment",
            fileNumber: this.accountNumber,
            year: null
        });
        this.dispatchEvent(new CustomEvent("continue"));
    }

    handleSSO() {
        window.open("https://my.hawaii.gov", "_blank");
    }
}