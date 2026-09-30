import { LightningElement, api } from 'lwc';
import searchAgents from '@salesforce/apex/BREGAgentSearchController.searchAgents';
import hasSubscriberProfile from '@salesforce/apex/BREGAgentSearchController.hasSubscriberProfile';
import { Labels } from './labels';

export default class Breg_AgentSearchResultsTable extends LightningElement {
    labels = Labels;
    @api searchValue;
    @api searchType;
    
    searchResults = [];
    selectedAgents = new Set();
    isLoading = false;
    error;
    showValidationError = false;
    //showSubscriberModal = false;
    
    get hasResults() {
        return !this.isLoading && !this.error && this.searchResults && this.searchResults.length > 0;
    }
    
    get hasNoResults() {
        return !this.isLoading && !this.error && this.searchResults && this.searchResults.length === 0;
    }
    
    get resultsCount() {
        return this.searchResults.length;
    }
    
    get agentsFoundText() {
        const count = this.resultsCount;
        const searchMode = this.searchType === 'active' ? 'active businesses only' : '';
        return `${count} agent${count !== 1 ? 's' : ''} found for '${this.searchValue}'${searchMode ? ', ' + searchMode : ''}:`;
    }
    
    get showingEntriesText() {
        const count = this.resultsCount;
        return `Showing 1 to ${count} of ${count} entries`;
    }
    
    get tableData() {
        return this.searchResults.map(result => ({
            ...result,
            formattedPrice: '$' + result.price.toFixed(2),
            isSelected: this.selectedAgents.has(result.agentId)
        }));
    }
    
    connectedCallback() {
        this.performSearch();
    }
    
    async performSearch() {
        this.isLoading = true;
        this.error = null;
        
        try {
            console.log('searchValue', this.searchValue);
            console.log('searchType', this.searchType);
            this.searchResults = await searchAgents({
                searchValue: this.searchValue,
                searchType: this.searchType
            });
            console.log('searchResults', this.searchResults);
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while searching';
            console.error('Error searching agents:', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    handleNewSearch() {
        this.dispatchEvent(new CustomEvent('newsearch'));
    }
    
    handleSelectAll() {
        this.selectedAgents = new Set(this.searchResults.map(r => r.agentId));
    }
    
    handleSelectNone() {
        this.selectedAgents = new Set();
    }
    
    handleCheckboxChange(event) {
        const agentId = event.target.dataset.agentId;
        if (event.target.checked) {
            this.selectedAgents.add(agentId);
        } else {
            this.selectedAgents.delete(agentId);
        }
        // Force re-render
        this.selectedAgents = new Set(this.selectedAgents);
    }
    
    // handleMoreInfoClick(event) {
    //     event.preventDefault();
    //     // Dispatch event to parent to show modal
    //     this.dispatchEvent(new CustomEvent('showmoreinfo'));
    // }
    
    async handleContinue() {
        // Validation 1: Check if any agents are selected
        if (this.selectedAgents.size === 0) {
            this.showValidationError = true;
            return;
        }
        
        // Validation 2: Check if user has subscriber profile
        try {
            /*const hasProfile = await hasSubscriberProfile();
            if (!hasProfile) {
                this.showSubscriberModal = true;
                return;
            }*/ //Commented out the subscriber profile validation as per BREG-4510 decision to reject subscriber accounts
            
            // All validations passed, proceed with continue
            const selectedData = this.searchResults.filter(r => 
                this.selectedAgents.has(r.agentId)
            );
            
            this.dispatchEvent(new CustomEvent('continue', {
                detail: { selectedAgents: selectedData }
            }));
        } catch (error) {
            this.error = error.body?.message || 'An error occurred while validating user profile';
            console.error('Error checking subscriber profile:', error);
        }
    }
    
    handleCancel() {
        this.handleNewSearch();
    }
    
    handleCloseValidationError() {
        this.showValidationError = false;
    }
    
    // handleCloseSubscriberModal() {
    //     this.showSubscriberModal = false;
    // }
}