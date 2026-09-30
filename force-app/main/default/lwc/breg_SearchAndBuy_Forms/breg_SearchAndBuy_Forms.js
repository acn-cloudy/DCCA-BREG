import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { Labels } from './labels';
import { navigateToPage } from "c/utils";

export default class Breg_SearchAndBuy_Forms extends NavigationMixin(LightningElement) {
    labels = Labels;
    @api forms;
    @api isInternalContext = false;
    @api recordId;
    @api isAccountObject;

    /**
     * Check if forms are available to display
     */
    get hasForms() {
        return this.forms && Array.isArray(this.forms) && this.forms.length > 0;
    }

    /**
     * Get mailto link for email address
     */
    get emailHref() {
        return `mailto:${this.labels.emailAddress}`;
    }

    /**
     * Handle Fill out Form button click
     */
    handleFillOutForm(event) {
        const formId = event.target.dataset.formId;
        const isRenewal = event.target.dataset.isRenewal === 'true';

        if (formId) {
            if(this.isInternalContext) {
                let stateParams = {
                    c__formConfigId: formId,
                    c__isRenewal: isRenewal,
                }

                if (this.isAccountObject) {
                    stateParams.c__accountId = this.recordId;
                } else {
                    stateParams.c__tntmsmId = this.recordId;
                }

                // Use Lightning Navigation with state parameters for internal Salesforce context
                this[NavigationMixin.Navigate]({
                    type: 'standard__navItemPage',
                    attributes: {
                        apiName: 'BREG_Form_Filing'
                    },
                    state: stateParams
                });
            } else {
                // Use URL navigation for external/community context
                let params = {
                    section: 'change',
                    formConfigId: formId,
                    isRenewal: isRenewal,
                };
                if (this.isAccountObject) {
                    params.accountId = this.recordId;
                } else {
                    params.tntmsmId = this.recordId;
                }
                navigateToPage('/manage', params);
            }
        }
    }
}