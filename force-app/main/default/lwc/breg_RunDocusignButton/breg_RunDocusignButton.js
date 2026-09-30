import { LightningElement, api } from "lwc";
import runGenerateDocWorkflow from "@salesforce/apex/BREGCaseController.runGenerateDocWorkflow";
import runGenerateDocWorkflowWithTemplate from "@salesforce/apex/BREGCaseController.runGenerateDocWorkflowWithTemplate";
import runGenerateDocWorkflowWithParams from "@salesforce/apex/BREGCaseController.runGenerateDocWorkflowWithParams";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import BREG_Docusign_Button_Success from "@salesforce/label/c.BREG_Docusign_Button_Success";
import BREG_Success from "@salesforce/label/c.BREG_Success";
import BREG_Error from "@salesforce/label/c.BREG_Error";

export default class Breg_RunDocusignButton extends LightningElement {
    @api recordId;
    @api buttonLabel = "";
    @api workflowName = "";
    @api componentTitle = "";
    @api docTemplateName = "";
    @api customParameters = "";
    showSpinner = false;
    successLabel = BREG_Success;
    errorLabel = BREG_Error;
    successDescription = BREG_Docusign_Button_Success;
    connectedCallback() {
        console.log("this.docTemplateName: " + this.docTemplateName);
    }

    async handleClick() {
        if (!this.recordId) {
            return;
        }

        this.showSpinner = true;
        try {
            await this.runWorkflow();
            this.showSuccessToast();
            this.stopSpinnerLater();
        } catch (error) {
            this.showErrorToast(error);
            this.showSpinner = false;
            }
    }

    runWorkflow() {
        if (this.customParameters) {
            return runGenerateDocWorkflowWithParams({
                recordId: this.recordId,
                workflowName: this.workflowName,
                customParameters: this.customParameters
            });
        }

        if (this.docTemplateName) {
            return runGenerateDocWorkflowWithTemplate({
                recordId: this.recordId,
                workflowName: this.workflowName,
                templateName: this.docTemplateName,
                customParameters: this.customParameters
            });
        }

        return runGenerateDocWorkflow({
            recordId: this.recordId,
            workflowName: this.workflowName
        });
    }

    showSuccessToast() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.successLabel,
                message: this.successDescription,
                variant: "success"
            })
        );
    }

    showErrorToast(error) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.errorLabel,
                message: error?.body?.message || "Unexpected error",
                variant: "error"
            })
        );
    }

    stopSpinnerLater() {
        setTimeout(() => {
            this.showSpinner = false;
        }, 25000);
    }
}