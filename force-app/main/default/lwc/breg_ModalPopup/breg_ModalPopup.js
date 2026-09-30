import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class Breg_ModalPopup extends LightningModal {
    @api message;
    @api header = "Confirm";
    @api cancelLabel = "Cancel";
    @api confirmLabel = "Confirm";

    handleCancel() {
        this.close(false);
    }

    handleConfirm() {
        this.close(true);
    }
}