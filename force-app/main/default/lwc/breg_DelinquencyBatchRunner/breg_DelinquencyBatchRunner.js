import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runDelinquencyBatch from '@salesforce/apex/BREGDelinquencyBatchController.runDelinquencyBatch';
import getReportUrls from '@salesforce/apex/BREGDelinquencyBatchController.getReportUrls';

export default class Breg_DelinquencyBatchRunner extends LightningElement {
    isPreviewMode = true;
    isRunning = false;
    showSuccessMessage = false;
    successMessage = '';
    previewReportUrl = '';
    regularReportUrl = '';

    get isButtonDisabled() {
        return this.isRunning;
    }

    get successMessageClass() {
        return this.showSuccessMessage ? 'slds-show' : 'slds-hide';
    }

    async connectedCallback() {
        await this.loadReportUrls();
    }

    async loadReportUrls() {
        try {
            const reportUrls = await getReportUrls();
            this.previewReportUrl = reportUrls.previewReportUrl;
            this.regularReportUrl = reportUrls.regularReportUrl;
        } catch (error) {
            console.error('Error loading report URLs:', error);
        }
    }

    handlePreviewModeChange(event) {
        this.isPreviewMode = event.target.checked;
    }

    async handleRunBatch() {
        this.isRunning = true;
        this.showSuccessMessage = false;

        try {
            const result = await runDelinquencyBatch({
                isPreview: this.isPreviewMode
            });

            if (result.success) {
                if (this.isPreviewMode) {
                    this.successMessage = `Batch job (Preview Mode) started successfully! Job ID: ${result.jobId}`;
                } else {
                    this.successMessage = `Batch job started successfully! Job ID: ${result.jobId}`;
                }
                this.showSuccessMessage = true;

                // Show toast notification
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: this.successMessage,
                        variant: 'success'
                    })
                );
            } else {
                throw new Error(result.error || 'Unknown error occurred');
            }
        } catch (error) {
            console.error('Error running batch:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to start batch job: ' + error.body?.message || error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.isRunning = false;
        }
    }

}