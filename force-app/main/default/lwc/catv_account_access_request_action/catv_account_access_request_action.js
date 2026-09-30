import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import handleRequestAction from "@salesforce/apex/CATV_AccessRequestController.handleRequestAction";
import checkRequestForValidation from "@salesforce/apex/CATV_AccessRequestController.checkRequestForValidation";

export default class Catv_account_access_request_action extends LightningElement {
    @track recordId;
    @track showCancelModal = false;
    @track dataObj = {};

    @wire(CurrentPageReference)
    getDetailsFromURL(currentPageReference) {
        if (currentPageReference && currentPageReference.state.recordId) {
            this.recordId = currentPageReference.state.recordId;
        }
    }
    
    connectedCallback(){
        this.dataObj.recordId = this.recordId;

        checkRequestForValidation({
            obj: JSON.stringify(this.dataObj)
        }).catch(error => {
            // error = error.message || error.body.message;
            this.handleError(error);
            this.closeAction();
        });
    }

    handleInputChange(event) {
        if (event.target.name == 'comments') {
            this.dataObj.comments = event.target.value;
        } 
    }

    handleAction(event) {
        if (!this.isValid()) {
            return;
        }
        this.dataObj.targetAction = event.target.name;
        
        handleRequestAction({
            obj: JSON.stringify(this.dataObj)
        }).then(result => {
            if (this.dataObj.targetAction == 'approveAction') {
                this.showToast("Success", "Account Access Request Approved Successfully.", "success");
            } else {
                this.showToast("Success", "Account Access Request Rejected Successfully.", "success");
            }
        }).catch(error => {
            // error = error.message || error.body.message;
            this.handleError(error);
        }).finally(() => {
            this.closeAction();
        });
    }

    closeAction(){
        getRecordNotifyChange([{recordId: this.recordId}]);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    isValid() {
        let valid = false;
        let isAllValid = false;
        isAllValid = [
            ...this.template.querySelectorAll("lightning-textarea")
        ].reduce((validSoFar, input) => {
            input.reportValidity();
            return validSoFar && input.checkValidity();
        }, true);

        isAllValid &= [...this.template.querySelectorAll("lightning-combobox")].reduce(
            (validSoFar, input) => {
                input.reportValidity();
                return validSoFar && input.checkValidity();
            },
            true
        );

        valid = isAllValid;
        return valid;
    }

    handleError(error) {
        let errorMessage = 'Something went wrong!!';
        if (error?.body?.message) {
            errorMessage = error.message || error.body.message;
        }
        this.showToast("Error", errorMessage, "error");
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}