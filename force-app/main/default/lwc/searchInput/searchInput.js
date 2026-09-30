import { LightningElement, api } from 'lwc';
import UtililtyIcons from '@salesforce/resourceUrl/UtililtyIcons';

export default class SearchInput extends LightningElement {

    @api placeholder;
    @api value = '';
    @api label;
    @api isLoading = false;

    get searchIcon() { return UtililtyIcons + '#search'; }
    get clearIcon() { return UtililtyIcons + '#clear'; }
    get inputValue() { return this.value || ''; }

    handleInputChange(e) {
        this.value = e.target.value;
        this._dispatchValueChangeEvent();
    }

    handleKeyDown(e){
        if (e.key === 'Enter') {
            e.preventDefault();            
            
            console.log(e.currentTarget.value);
            this.value = e.currentTarget.value;
            this._dispatchValueChangeEvent();
            this._dispatchValueSubmitEvent();
        }
    }

    clearInput(e) {
        this.value = '';
        this._dispatchValueChangeEvent();
        this._dispatchValueSubmitEvent();
    }

    _dispatchValueChangeEvent() {
        this.dispatchEvent(new CustomEvent('valuechange', { detail : { value : this.value }}));
    }

    _dispatchValueSubmitEvent() {
        this.dispatchEvent(new CustomEvent('valuesubmit', { detail : { value : this.value }}));
    }
}