import {LightningElement, api, wire, track} from 'lwc';
import runClearanceCheck from '@salesforce/apex/LicenseTaxClearancerController.runClearanceCheck';
import {CloseActionScreenEvent} from 'lightning/actions';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

export default class LicenseTaxClearancer extends LightningElement {
    @api recordId;
    apiCallInitiated = false;
    hideSpinner = false;
    message = 'Running. Please don\'t close this window.';

    renderedCallback() {
        if (this.recordId && !this.apiCallInitiated) {
            this.apiCallInitiated = true;
            let recordId = this.recordId;
            runClearanceCheck({recordId}).then(res => {
                this.message = res;
            }).catch(e => {
                const toastEvent = new ShowToastEvent({
                    title: 'Error!',
                    message: 'Something went wrong. Please contact your administrator.',
                    variant: 'error'
                });
                this.dispatchEvent(toastEvent);
                this.closeQuickAction();
            }).finally(() => {
                this.hideSpinner = true;
            });
        }
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}