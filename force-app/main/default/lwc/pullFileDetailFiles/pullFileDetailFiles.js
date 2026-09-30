import { LightningElement, wire } from 'lwc';
import pullDownFiles from "@salesforce/apex/PullFileDetailFilesController.pullDownFiles";
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PullFileDetailFiles extends LightningElement {
    
    isLoading = false;
    @wire(CurrentPageReference) pageRef;
    get recordId() {
        return this.pageRef && this.pageRef.state.recordId;
    }
    connectedCallback() {
        if(this.recordId) {
            this.updateURL();
        }
    }
    renderedCallback() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    async updateURL() {
        this.isLoading = true;
        const { recordId } = this;
        try{
            await pullDownFiles({ recordId });
            this.showToast('Success', 'The file has been migrated successfully', 'success');
        } catch(error) {
            this.showToast('Error', error.body.message, 'error');
        } 
        this.isLoading = false;
        

    }
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}