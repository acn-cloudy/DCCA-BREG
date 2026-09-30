import { LightningElement, api, track } from "lwc";
import { Labels } from "./labels";
import createPayment from "@salesforce/apex/BREGPaymentController.createPayment";
import { NavigationMixin } from "lightning/navigation";

export default class Breg_SearchAndBuy_BuyAvailableDocs extends NavigationMixin(LightningElement) {
    labels = Labels;

    // API properties to receive data from parent
    @api accountName;
    @api recordId;
    @api isAccountObject;
    @api buyAvailableDocs = [];
    @api buyAvailableDocsColumns = [];
    isLoading = false;
    @track cartItems = [];

    loadCartFromStorage() {
        try {
            const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
            if (storedCart && JSON.parse(storedCart) !== "[]") {
                this.cartItems = JSON.parse(storedCart);
            } else {
                this.cartItems = [];
            }
        } catch (error) {
            console.error("Error loading cart from localStorage:", error);
            this.cartItems = [];
        }
    }
    get totalPrice() {
        return this.cartItems && this.cartItems.length > 0 ? this.cartItems.reduce((total, item) => total + item.price, 0) : 0;
    }

    async createTransactionAndNavigate(details) {
        this.isLoading = true;
        try {
            const transactionId = await createPayment(details);
            await this[NavigationMixin.Navigate]({
                type: "standard__recordPage",
                attributes: {
                    recordId: transactionId,
                    objectApiName: "Transaction__c",
                    actionName: "view"
                }
            });
        } catch (error) {
            console.error("Error creating transaction:", error);
        } finally {
            this.isLoading = false;
            localStorage.setItem(this.CART_STORAGE_KEY, JSON.stringify([]));
        }
    }

    // Local state
    availableToCertifyPrice = 10;
    selectedRows = [];
    @track selectedRecords = [];
    showErrorMessage = false;
    selectedDocumentType = "all";
    filteredDocs = [];
    @api isInternalContext = false;
    get addToCartLabel() {
        return this.isInternalContext ? "Add to Cart and Go to Terminal" : this.labels.addToCart;
    }

    // Document type options for picklist
    documentTypeOptions = [
        { label: this.labels.all, value: "all", selected: true },
        { label: this.labels.documentTypeAnnualFiling, value: "Annual Filing", selected: false },
        { label: this.labels.documentTypeCOGS, value: "COGS", selected: false },
        { label: this.labels.documentTypeTrademark, value: "Trademark", selected: false },
        { label: this.labels.documentTypeTradeName, value: "Trade Name", selected: false },
        { label: this.labels.documentTypeServiceMark, value: "Service Mark", selected: false }
    ];

    // Local storage key for cart (must match cart component)
    CART_STORAGE_KEY = "breg_shopping_cart";

    // Initialize filtered docs when buyAvailableDocs changes
    connectedCallback() {
        this.filteredDocs = [...this.buyAvailableDocs];
        this.loadCartFromStorage();
    }

    // Handle document type change
    handleDocumentTypeChange(event) {
        this.selectedDocumentType = event.target.value;
    }

    // Handle apply filters button click
    handleApplyFilters() {
        this.applyFilters();
    }

    // Apply filters based on selected document type
    applyFilters() {
        if (this.selectedDocumentType === "all") {
            this.filteredDocs = [...this.buyAvailableDocs];
            return;
        }

        this.filteredDocs = this.buyAvailableDocs.filter((doc) => {
            const docName = doc.documentAndTradeName?.toLowerCase() || "";
            const docId = doc.id || "";

            switch (this.selectedDocumentType) {
                case "COGS":
                    return docId.startsWith("COGS") || docName.includes("certificate of good standing");
                case "Annual Filing":
                    return docName.includes("annual filing");
                case "Trademark":
                    return docName.includes("(trademark)") || docName.toLowerCase().includes("trademark");
                case "Trade Name":
                    return docName.includes("(trade name)") || docName.toLowerCase().includes("trade name");
                case "Service Mark":
                    return docName.includes("(service mark)") || docName.toLowerCase().includes("service mark");
                default:
                    return true;
            }
        });
    }

    get showFilters() {
        return this.isAccountObject;
    }

    // Handle row selection in Buy Available Docs datatable
    // Only allow selection of rows with availability = 'Available Now'
    handleRowSelection(event) {
        const availableRows = [];
        const availableRecords = [];

        event.detail.selectedRows.forEach(row => {
            if (row.availability === 'Available Now' || row.availability === 'Available by Mail or Pickup') {
                // Use lowercase 'id' to match the wrapper property
                availableRows.push(row.id);
                availableRecords.push(row);
            }
        });

        this.selectedRows = availableRows;
        this.selectedRecords = availableRecords;

        // Force datatable to only show available rows as selected
        const datatable = this.refs.buyAvailableDocsDatatable;
        if (datatable) {
            datatable.selectedRows = availableRows;
        }

        // Clear error message when selection changes
        this.showErrorMessage = false;
    }

    // Handle Add to Cart button click
    handleAddToCart() {
        if (this.selectedRecords.length > 0) {
            // Transform selected records to cart items format
            const cartItems = this.selectedRecords.map((row) => {
                return {
                    id: row.id,
                    companyName: this.accountName || "Unknown Company",
                    companyUrl: "/search-and-buy?entityId=" + this.recordId,
                    documentType: row.documentAndTradeName,
                    documentDate: row.effectiveDate,
                    documentFormatDate: this.formatDate(row.effectiveDate),
                    format: row.type,
                    formatIcon: row.type === "Printed" ? "utility:print" : "doctype:pdf",
                    quantity: 1,
                    unitPrice: row.purchasePrice,
                    price: row.purchasePrice,
                    isAvailableToCertify: row.isAvailableToCertify,
                    isCertified: false,
                    certifyPrice: row.isAvailableToCertify ? row.certifyPrice : 0,
                    certifyFeeId: row.certifyFeeId || null,
                    isQuantityDisabled: row.type !== "Printed",
                    type: 'Document',
                    feeId: row.feeId || null
                };
            });

            // Add items to localStorage cart
            this.addItemsToCart(cartItems);

            // Clear selection after adding to cart
            this.selectedRows = [];
            this.selectedRecords = [];

            // Clear selection in datatable
            const datatable = this.refs.buyAvailableDocsDatatable;
            if (datatable) {
                datatable.selectedRows = [];
            }
            if (this.isInternalContext) {
                this.createTransactionAndNavigate({
                    amount: this.totalPrice,
                    cartItemsJson: JSON.stringify(cartItems),
                    skipPaymentCreation: true
                });
            }
        } else {
            this.showErrorMessage = true;
        }
    }

    // Handle close error message
    handleCloseError() {
        this.showErrorMessage = false;
    }

    // Helper method to format date
    formatDate(dateString) {
        if (!dateString) return "";
        const date = new Date(dateString);
        return date.toLocaleDateString("en-US", {
            year: "numeric",
            month: "short",
            day: "numeric"
        });
    }

    // Helper method to add items to cart in localStorage
    addItemsToCart(newItems) {
        try {
            // Get existing cart items from localStorage
            const existingCartJson = localStorage.getItem(this.CART_STORAGE_KEY);
            let existingCart = [];

            if (existingCartJson) {
                existingCart = JSON.parse(existingCartJson);
            }

            // Filter out items that already exist in cart (check by item ID)
            const existingIds = existingCart.map((item) => item.id);
            const itemsToAdd = newItems.filter((item) => !existingIds.includes(item.id));

            // Add only new items to existing cart
            const updatedCart = [...existingCart, ...itemsToAdd];

            // Save updated cart back to localStorage
            localStorage.setItem(this.CART_STORAGE_KEY, JSON.stringify(updatedCart));

            // Dispatch event to notify parent components that cart was updated
            this.dispatchEvent(
                new CustomEvent("itemsaddedtocart", {
                    bubbles: true,
                    composed: true,
                    detail: {
                        itemsAdded: itemsToAdd.length,
                        cartTotal: updatedCart.length
                    }
                })
            );
        } catch (error) {
            console.error("Error adding items to cart:", error);
        }
    }
}