import { LightningElement, api } from "lwc";
import runMethodByName from "@salesforce/apex/BREGCaseController.runMethodByName";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import { RefreshEvent } from "lightning/refresh";
import BREG_Success from "@salesforce/label/c.BREG_Success";
import BREG_Error from "@salesforce/label/c.BREG_Error";

export default class Breg_RunMethodButton extends LightningElement {
    @api recordId;
    @api buttonLabel = "Run Method";
    @api methodName = "";
    @api componentTitle = "";

    showSpinner = false;
    successLabel = BREG_Success;
    errorLabel = BREG_Error;

    handleClick() {
        if (!this.recordId) {
            this.showError("Record Id is not available.");
            return;
        }

        if (!this.methodName) {
            this.showError("Method name is not configured.");
            return;
        }

        this.showSpinner = true;

        runMethodByName({
            recordId: this.recordId,
            methodName: this.methodName
        })
            .then(() => {
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.dispatchEvent(new RefreshEvent());
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.successLabel,
                        message: "Method executed successfully.",
                        variant: "success"
                    })
                );

                // Fallback for containers where Lightning refresh events do not repaint standard record sections.
                window.setTimeout(() => {
                    window.location.reload();
                }, 400);
            })
            .catch((error) => {
                this.showError(error?.body?.message || "Unexpected error");
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.errorLabel,
                message,
                variant: "error"
            })
        );
    }
}