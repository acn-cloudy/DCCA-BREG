import {LightningElement, api } from 'lwc';
import {CloseActionScreenEvent} from 'lightning/actions';
import validatedTravelApprovals from '@salesforce/apex/TravelApprovalValidator.validatedTravelApprovals';
import getURL from '@salesforce/apex/TravelApprovalValidator.redirectURL'
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class TravelApprovalValidator extends NavigationMixin(LightningElement) {
    hideSpinner = false;
    apiCallInitiated = false;
    _recordId;

    @api set recordId(value) {
        this._recordId = value;
        this.callActions(value);
    }

    get recordId() {
        return this._recordId;
    }
    callActions(recordId) {
        const {apiCallInitiated } = this;
        if (recordId && !apiCallInitiated) {
            this.apiCallInitiated = true;
            validatedTravelApprovals({recordId}).then(res => {
                const pendingRecords = res;
                console.log("pendingRecords", pendingRecords);
                if(pendingRecords && pendingRecords.length) {
                    const recordNames = pendingRecords.reduce((result, item) => {
                        result += item.Name + ",";
                        return result;
                    }, "");

                    const names = recordNames.substring(0, (recordNames.length -1));
                    const message = `Previous Travel Record ${names} is still needing a final report. Please complete final report before proceeding`;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error!',
                        message,
                        variant: 'error',
                        mode: 'sticky'
                    }));
                    this.closeQuickAction();  
                } else {
                    this.navigateToVFPage();
                    this.closeQuickAction();    
                }
            }).catch((e) => {
                console.error("exception",e);
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
    navigateToVFPage() {
        const {recordId} = this;
        const dst = "0888a7d4-34bc-4eff-9704-87d306a0a1fb";
        getURL({recordId, dst}).then( url => {
            window.location.href= url;
        });
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

}