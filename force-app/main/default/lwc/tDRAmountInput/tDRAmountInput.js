import {LightningElement, api} from 'lwc';

export default class TDRAmountInput extends LightningElement {
    @api value;
    @api name;
    hasNegativeVal = false;
    hasRendered = false;
    isInput = false;

    connectedCallback() {
        if (this.value && this.value < 0) {
            this.hasNegativeVal = true;
        }
    }

    renderedCallback() {
        if (!this.hasRendered) {
            this.handleOnblur();
            this.hasRendered = true;
        }
    }

    get displayVal() {
        if (!this.value) {
            return;
        }

        return this.hasNegativeVal ? this.value * -1 : this.value;
    }

    handleRowAmountChange(e) {
        this.value = e.target.value;
        this.dispatchEvent(new CustomEvent('change', {detail: e}));
    }

    handleOnFocus() {
        this.isInput = true;
        setTimeout(() => {
            this.template.querySelector('lightning-input').focus();
        }, 50);
    }

    handleOnblur(e) {
        this.hasNegativeVal = this.value && this.value < 0;
        this.isInput = false;
        if (this.hasNegativeVal) {
            setTimeout(() => {
                this.template.querySelector('div').style = 'color:red;';
            }, 50);
        }
    }
}