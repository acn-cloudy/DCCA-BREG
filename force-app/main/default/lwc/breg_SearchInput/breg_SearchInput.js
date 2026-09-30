import { LightningElement, api } from 'lwc';
import { Labels } from './labels';

export default class Breg_SearchInput extends LightningElement {
    labels = Labels;
    searchTypeOptions;
    @api placeholder;
    @api searchButtonLabel;
    @api showSearchButton = false;
    @api searchValue = '';
    @api customSearchTypes; // Custom search type options
    searchType = 'begins';

    // Lifecycle hook to initialize options
    async connectedCallback() {
        this.setSearchTypeOptions();
    }

    // Handlers for search changes
    handleInputChange(event) {
        this.searchValue = event.target.value;
    }

    handleTypeChange(event) {
        this.searchType = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearchClick();
        }
    }

    handleSearchClick() {
        this.dispatchEvent(new CustomEvent('search', {
            detail: {
                searchValue: this.searchValue,
                searchType: this.searchType
            }
        }));
    }

    // Set search type options for the search bar
    setSearchTypeOptions() {
        if (this.customSearchTypes && this.customSearchTypes.length > 0) {
            // Use custom search types if provided
            this.searchTypeOptions = this.customSearchTypes;
            // Set initial searchType to first option value
            if (this.customSearchTypes[0] && this.customSearchTypes[0].value) {
                this.searchType = this.customSearchTypes[0].value;
            }
        } else {
            // Use default search types
            this.searchTypeOptions = [
                { label: this.labels.beginsWith, value: 'begins', selected: true },
                { label: this.labels.contains, value: 'contains', selected: false }
            ];
        }
    }
}