import { LightningElement, wire } from "lwc";
import { subscribe, MessageContext } from "lightning/messageService";
import SECTION_CHANGE_MESSAGE from "@salesforce/messageChannel/breg_MessageChannel__c";
import { Labels } from "./labels";

export default class Breg_SearchAndBuy extends LightningElement {
    faqsTopicName = "Search & Buy";
    labels = Labels;
    searchValue;
    searchType;
    detailedRecordId;
    detailedRecordActiveTab;
    pageLoadedWithEntityId = false;

    activeTab = "";
    section;
    
    // Search and Buy States
    showSearch = true;
    showTable = false;
    showDetails = false;
    showModal = false;
    showErrorMessage = false;
    showNotFound = false;
    showSpinner = false;

    subscription = null;

    // Cart State
    cartItemsCount = 0;
    cartItemsTotalPrice = 0;

    // Filter states for child component
    filterRecordType = "all";
    filterStatus = "all";
    filterEntityType = "all";

    get cartTabLabel() {
        return this.cartItemsCount + " ($" + this.cartItemsTotalPrice + ")";
    }

    // Local storage key for cart items (must match cart component)
    CART_STORAGE_KEY = "breg_shopping_cart";

    // Message channel
    @wire(MessageContext)
    messageContext;

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(this.messageContext, SECTION_CHANGE_MESSAGE, (message) => this.handleMessage(message));
        }
    }

    unsubscribeToMessageChannel() {
        if (this.subscription) {
            this.subscription = null;
        }
    }

    handleMessage(message) {
        let section = message.section;
        let page = message.page;
        if (page == "search-and-buy") {
            this.resetToInitialState();
            this.navigateToTab("search");
        }
    }

    // Cart management methods
    updateCartCountFromStorage() {
        try {
            const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
            if (storedCart) {
                const cartItems = JSON.parse(storedCart);
                this.cartItemsCount = cartItems.length || 0;
                this.cartItemsTotalPrice = cartItems.reduce((total, item) => total + item.price, 0).toFixed(2);
            } else {
                this.cartItemsCount = 0;
                this.cartItemsTotalPrice = 0;
            }
        } catch (error) {
            console.error("Error reading cart count from localStorage:", error);
            this.cartItemsCount = 0;
        }
    }

    // Lifecycle
    connectedCallback() {
        this.subscribeToMessageChannel();
        this.updateCartCountFromStorage();
        this.checkUrlParameters();
    }

    // Check URL parameters on component load
    checkUrlParameters() {
        const urlParams = new URLSearchParams(window.location.search);
        const entityId = urlParams.get('entityId');
        const activeTab = urlParams.get('activeTab');
        const searchTerm = urlParams.get('searchTerm');

        this.section = urlParams.get("section") || "manage";
        if (this.section === "help") {
            this.activeTab = "help";
        }
        
        if (entityId) {
            this.pageLoadedWithEntityId = true;
            // Show spinner while loading account details
            this.showSpinner = true;
            this.showSearch = false;
            this.showTable = false;
            this.showDetails = false;
            this.showModal = false;
            this.showErrorMessage = false;
            this.showNotFound = false;

            // Move to details view - child component will handle loading
            this.detailedRecordId = entityId;
            this.detailedRecordActiveTab = activeTab;
            this.showDetails = true;
            this.showSpinner = false;
        } else if (searchTerm) {
            // Handle search term from Home page navigation
            this.handleSearchFromUrl(searchTerm);
        }
    }

    // Handle search term from URL parameter
    async handleSearchFromUrl(searchTerm) {
        // Set search value and default search type
        this.searchValue = searchTerm;
        this.searchType = "begins"; // Default search type (begins with)

        // Show spinner while transitioning
        this.showSpinner = true;
        this.showSearch = false;
        this.showTable = false;
        this.showDetails = false;
        this.showModal = false;
        this.showErrorMessage = false;
        this.showNotFound = false;

        // Move to table view
        this.showSpinner = false;
        this.showTable = true;

        // Wait for table component to render
        await this.delay(50);

        // Trigger search in the table component
        const tableComponent = this.template.querySelector("c-breg-_-account-search-results-table");
        if (tableComponent) {
            tableComponent.handleSearchClick(this.searchValue, this.searchType);
        }
    }

    // Update URL with account parameter
    updateUrlWithEntityId(entityId) {
        const url = new URL(window.location);
        if (entityId) {
            url.searchParams.set('entityId', entityId);
        } else {
            url.searchParams.delete('entityId');
        }
        window.history.pushState({}, "", url);
    }

    // Update URL with active tab parameter
    updateUrlWithActiveTab(activeTab) {
        const url = new URL(window.location);
        if (activeTab) {
            url.searchParams.set('activeTab', activeTab);
        } else {
            url.searchParams.delete('activeTab');
            this.detailedRecordActiveTab = 'company-information';
        }
        window.history.pushState({}, "", url);
    }

    // Update URL with search term parameter
    updateUrlWithSearchTerm(searchTerm) {
        const url = new URL(window.location);
        if (searchTerm) {
            url.searchParams.set("searchTerm", searchTerm);
        } else {
            url.searchParams.delete("searchTerm");
        }
        window.history.pushState({}, "", url);
    }

    // Reset to initial state
    resetToInitialState() {
        // Reset all component state to initial values
        this.searchValue = null;
        this.searchType = "begins";
        this.detailedRecordId = null;
        this.pageLoadedWithEntityId = false;
        this.showSearch = true;
        this.showTable = false;
        this.showDetails = false;
        this.showModal = false;
        this.showErrorMessage = false;
        this.showNotFound = false;
        this.showSpinner = false;

        // Reset filter values
        this.filterRecordType = "all";
        this.filterStatus = "all";
        this.filterEntityType = "all";

        // Clear URL parameters
        this.updateUrlWithSearchTerm(null);
        this.updateUrlWithEntityId(null);
        this.updateUrlWithActiveTab(null);
    }

    // Search
    async handleSearch(event) {
        this.searchValue = event.detail.searchValue;
        this.searchType = event.detail.searchType;
        if (!this.searchValue || !this.searchType) {
            this.showErrorMessage = true;
            return;
        }
        this.showErrorMessage = false;
        this.showSearch = false;
        this.showTable = true;
        await this.delay(50);
        this.template.querySelector("c-breg-_-account-search-results-table").handleSearchClick(this.searchValue, this.searchType);
    }

    // New search
    handleNewSearch() {
        this.resetToInitialState();
    }

    // Open details
    handleOpenDetails(event) {
        this.detailedRecordId = event.detail.recordId;
        this.showSearch = false;
        this.showTable = false;
        this.showDetails = true;
        this.showNotFound = false;
        // Update URL with account ID
        this.updateUrlWithEntityId(event.detail.recordId);
        this.updateUrlWithActiveTab(event.detail.activeTab);
    }

    // Back to search
    async handleBackToSearch() {
        this.showDetails = false;
        this.showNotFound = false;
        this.showSearch = this.pageLoadedWithEntityId ? true : false
        this.showTable = !this.showSearch;
        this.detailedRecordId = null;
        this.pageLoadedWithEntityId = false;
        // Remove account and search term parameters from URL
        this.updateUrlWithEntityId(null);
        this.updateUrlWithSearchTerm(null);
        this.updateUrlWithActiveTab(null);
        await this.delay(50);
        if (this.showTable) {
            this.template.querySelector("c-breg-_-account-search-results-table").handleSearchClick(this.searchValue, this.searchType);
        }
    }

    // Handle account not found event from child component
    handleAccountNotFound(event) {
        console.error("Account not found:", event.detail);
        // Show 404 error page
        this.showSearch = false;
        this.showTable = false;
        this.showDetails = false;
        this.showModal = false;
        this.showErrorMessage = false;
        this.showNotFound = true;
        this.showSpinner = false;
    }

    // Utility delay function
    delay(time) {
        return new Promise((resolve) => setTimeout(resolve, time));
    }

    // Modal handlers
    handleMoreInfoClick(event) {
        event.preventDefault();
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleHelpPageClick(event) {
        event.preventDefault();
        this.showModal = false;
        // Navigate to the Help tab
        this.navigateToTab("help");
    }

    // Hide error message
    handleCloseError() {
        this.showErrorMessage = false;
    }

    // Handle help link click from 404 page
    handleNotFoundHelpClick(event) {
        event.preventDefault();
        this.resetToInitialState();
        // Navigate to the Help tab
        this.navigateToTab("help");
    }

    // Handle search again link click from 404 page
    handleSearchAgainClick(event) {
        event.preventDefault();
        this.resetToInitialState();
    }

    // Handle continue shopping from cart
    handleContinueShopping(event) {
        event.preventDefault();
        this.navigateToTab("search");
    }

    // Cart event handler to update count when cart changes
    handleCartUpdated() {
        this.updateCartCountFromStorage();
    }

    // Handle items added to cart from account details
    async handleItemsAddedToCart(event) {
        // refresh cart component
        const cartComponent = this.template.querySelector("c-breg-_-shopping-_-cart");
        if (cartComponent) {
            cartComponent.refreshCart();
        }
        this.updateCartCountFromStorage();
        this.navigateToTab("cart");
    }

    // Handle when filters are applied from child component
    handleFiltersApplied(event) {
        const { filters } = event.detail;

        // Update all filter values at once
        this.filterRecordType = filters.recordType;
        this.filterStatus = filters.status;
        this.filterEntityType = filters.entityType;
    }

    // Navigate to tab
    navigateToTab(tabName) {
        const tabset = this.template.querySelector("lightning-tabset");
        if (tabset) {
            tabset.activeTabValue = tabName;
        }
    }

    renderedCallback() {
        let tabset = this.template.querySelector('lightning-tabset');
   
        if (!tabset) {
             return;
        }
   
        tabset.classList.add('custom-tabset-style');
   
        let style = document.createElement('style');
        style.innerText = `
             .custom-tabset-style .slds-tabs_default__link {
                  font-size: 11.75pt;
             }
        `;
   
        tabset.appendChild(style);
    }
}