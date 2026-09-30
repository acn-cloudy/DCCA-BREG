import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class Breg_ELB_Disclaimer extends LightningModal {
    @api contentMain;
    @api contentBold;

    handleContinue() {
        this.close("okay");
    }
    handleClose() {
        this.close("close");
    }
}