import { LightningElement, api, track } from 'lwc';

export default class NameClearenceSearchPanel extends LightningElement {
    @api searchTerm = '';
    @api searchStatus = 'idle'; // idle, success, error

    @track showMinLengthError = false;

    get isSearchDisabled() {
        return !this.searchTerm || this.searchTerm.trim().length < 2;
    }

    get isClearDisabled() {
        return !this.searchTerm || this.searchTerm.trim().length === 0;
    }

    get showStatus() {
        return this.searchStatus === 'success' || this.searchStatus === 'error';
    }

    get isSuccessStatus() {
        return this.searchStatus === 'success';
    }

    get isErrorStatus() {
        return this.searchStatus === 'error';
    }

    handleSearchTermChange(event) {
        const newValue = event.target.value;
        this.showMinLengthError = newValue.length > 0 && newValue.length < 2;
        
        // Dispatch the term change to parent
        this.dispatchEvent(new CustomEvent('termsearch', {
            detail: { searchTerm: newValue }
        }));
    }

    handleKeyDown(event) {
        // Clear error state when user starts typing
        if (this.showMinLengthError) {
            this.showMinLengthError = false;
        }

        // Execute search on Enter key
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearchClick();
        }
    }

    handleSearchClick() {
        const term = this.searchTerm ? this.searchTerm.trim() : '';
        
        if (term.length < 2) {
            this.showMinLengthError = true;
            return;
        }

        this.showMinLengthError = false;
        
        // Dispatch search event to parent
        this.dispatchEvent(new CustomEvent('search', {
            detail: { searchTerm: term }
        }));
    }

    handleClear() {
        this.showMinLengthError = false;
        
        // Dispatch term change with empty value
        this.dispatchEvent(new CustomEvent('termsearch', {
            detail: { searchTerm: '' }
        }));

        // Focus back on input
        const input = this.template.querySelector('lightning-input');
        if (input) {
            input.focus();
        }
    }
}