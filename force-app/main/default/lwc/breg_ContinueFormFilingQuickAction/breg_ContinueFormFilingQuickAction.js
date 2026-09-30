import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class Breg_ContinueFormFilingButton extends NavigationMixin(LightningElement) {
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    
    set recordId(recordId) {
        if (recordId !== this._recordId) {
            this._recordId = recordId;
       }
    }

    @api invoke() {
        console.log("*** invoke");
        console.log("*** recordId:", this.recordId);
        this.navigateToFormFiling();
    }

    /**
     * Navigate to Form Filing page with case ID
     */
    navigateToFormFiling() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'BREG_Form_Filing'
            },
            state: {
                c__caseId: this.recordId
            }
        });
    }
}