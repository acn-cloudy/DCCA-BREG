import { LightningElement } from 'lwc';
import { Labels } from './labels';
import getUserInfo from '@salesforce/apex/BREGPortalUtils.getUserInfo';
import insertAgentSearchList from '@salesforce/apex/BREGAgentSearchController.insertAgentSearchList';

export default class Breg_AgentSearch extends LightningElement {
    labels = Labels;
    searchValue = '';
    searchType = '';
    showSearch = true;
    showTable = false;
    showErrorMessage = false;
    // showModal = false;
    isNotGuest = false;
    
    // Local storage key for cart items
    CART_STORAGE_KEY = "breg_shopping_cart";

    // Custom search types for agent search
    get customSearchTypes() {
        return [
            { label: 'Active businesses', value: 'active', selected: true },
            { label: 'All businesses', value: 'all', selected: false }
        ];
    }

    connectedCallback() {
        this.fetchUserInfo();
    }

    async fetchUserInfo() {
        try {
            const result = await getUserInfo();
            this.isNotGuest = !result.isGuest;
        } catch (error) {
            console.error("Error fetching user info", error);
        }
    }

    // Handle search from search input component
    handleSearch(event) {
        this.searchValue = event.detail.searchValue;
        this.searchType = event.detail.searchType;
        
        if (!this.searchValue || this.searchValue.trim() === '') {
            this.showErrorMessage = true;
            return;
        }
        
        this.showErrorMessage = false;
        this.showSearch = false;
        this.showTable = true;
    }

    // Handle close error message
    handleCloseError() {
        this.showErrorMessage = false;
    }

    // Handle new search
    handleNewSearch() {
        this.searchValue = '';
        this.searchType = '';
        this.showSearch = true;
        this.showTable = false;
        this.showErrorMessage = false;
    }

    // Modal handlers
    // handleMoreInfoClick(event) {
    //     event.preventDefault();
    //     this.showModal = true;
    // }

    // handleCloseModal() {
    //     this.showModal = false;
    // }

    async handleContinue(event) {
        const selectedAgents = event.detail.selectedAgents;
        
        if (!selectedAgents || selectedAgents.length === 0) {
            return;
        }
        
        // Calculate total price and total records
        let totalPrice = selectedAgents.reduce((sum, agent) => sum + (agent.price || 0), 0);
        // Add $2 for the agent search fee
        totalPrice += 2;
        const totalAgentRecords = selectedAgents.length;
        const totalBusinessRecords = selectedAgents.reduce((sum, agent) => sum + (agent.businessRecords || 0), 0);
        const agentIds = selectedAgents.map(agent => agent.agentId);

        try {
            const agentSearchListId = await insertAgentSearchList({
                agentIds: agentIds,
                searchValue: this.searchValue,
                searchType: this.searchType,
                totalAgentRecords: totalAgentRecords,
                totalBusinessRecords: totalBusinessRecords,
                totalPrice: totalPrice
            });

            const cartItem = {
                id: 'Agent Search_' + Date.now(),
                documentType: totalAgentRecords + ' agent(s)',
                companyName: 'Agent Search',
                companyUrl: '#',
                documentDate: new Date(),
                format: "Digital (CSV)",
                formatIcon: "doctype:csv",
                quantity: 1,
                unitPrice: totalPrice,
                price: totalPrice,
                isAvailableToCertify: false,
                isQuantityDisabled: true,
                type: 'Agent Search List',
                agentSearchListId: agentSearchListId
            };

            let existingCart = [];
            try {
                const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
                if (storedCart) {
                    existingCart = JSON.parse(storedCart);
                }
            } catch (error) {
                console.error("Error loading cart from localStorage:", error);
            }
            
            existingCart.push(cartItem);
            
            try {
                localStorage.setItem(this.CART_STORAGE_KEY, JSON.stringify(existingCart));
            } catch (error) {
                console.error("Error saving cart to localStorage:", error);
            }
            
            window.location.href = '/cart';
        } catch (error) {
            console.error("Error creating agent search list:", error);
        }
    }
}