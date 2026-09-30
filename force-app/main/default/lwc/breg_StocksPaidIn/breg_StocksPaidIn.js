import { api, track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { addUniqueKeys, formatCurrency } from "c/utils";

/**
 * Paid-in Capital Stocks component (Editable Amount)
 * Displays: Class, No. of Shares, Amount (editable)
 */
export default class Breg_StocksPaidIn extends BaseFormComponent {
    defaultTitle = "Paid-in Capital";
    @track stocks = [];
    stocksInitiated = false;

    get showEditSectionButton() {
        return this.readOnly && !this.alwaysReadOnly && this.isAnnualForm && this.hasStocks;
    }

    /**
     * Getter to check if there are stocks to display
     */
    get hasStocks() {
        return this.stocks && this.stocks.length > 0;
    }

    connectedCallback() {
        super.connectedCallback();
        this.setStocks();
    }

    /**
     * Initialize stocks from formData
     * Called from connectedCallback and processFormData
     */
    setStocks() {
        if (!this.formData?.stocksPaidIn || this.formData.stocksPaidIn.length === 0) {
            return;
        }

        // Check if stocks data has actually changed
        if (this.stocksInitiated && !this.hasStocksChanged()) {
            return;
        }
        
        this.stocksInitiated = true;
        const processedStocks = this.formData.stocksPaidIn.map((stock) => {
            // Get values using friendly names from targetFieldsMapping or fall back to SF field names
            const classSeries = stock.classSeries ?? stock["breg_Stock__c.breg_Class_Series__c"];
            const sharesCount = stock.sharesCount ?? stock["breg_Stock__c.breg_Shares_Count__c"];
            const amount = stock.amount ?? stock["breg_Stock__c.breg_Paid_Shares__c"];
            
            return {
                ...stock,
                classSeries,
                sharesCount,
                sharesCountFormatted: this.formatNumber(sharesCount),
                amount,
                amountFormatted: formatCurrency(amount)
            };
        });
        
        this.stocks = addUniqueKeys(processedStocks, "stock");
        
        // Dispatch formupdate to sync with parent
        this.dispatchCustomEvent("formupdate", { field: "stocksPaidIn", value: this.stocks });
    }

    /**
     * Check if formData.stocks differs from current stocks
     * @returns {boolean} True if stocks have changed
     */
    hasStocksChanged() {
        if (!this.formData?.stocksPaidIn || !this.stocks) {
            return true;
        }
        if (this.formData.stocksPaidIn.length !== this.stocks.length) {
            return true;
        }
        
        // Compare key stock properties
        for (let i = 0; i < this.formData.stocksPaidIn.length; i++) {
            const formStock = this.formData.stocksPaidIn[i];
            const currentStock = this.stocks.find(s => s.uniqueKey === formStock.uniqueKey);
            
            if (!currentStock) {
                return true;
            }
            
            const formSharesCount = formStock.sharesCount ?? formStock["breg_Stock__c.breg_Shares_Count__c"];
            const formAmount = formStock.amount ?? formStock["breg_Stock__c.breg_Paid_Shares__c"];
            
            if (currentStock.sharesCount !== formSharesCount || 
                currentStock.amount !== formAmount) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * Format a number with thousand separators
     * @param {string|number} value - The number to format
     * @returns {string} Formatted number string
     */
    formatNumber(value) {
        if (value === null || value === undefined || value === "") {
            return "";
        }
        const num = typeof value === "string" ? parseFloat(value.replace(/,/g, "")) : value;
        if (isNaN(num)) {
            return value;
        }
        return num.toLocaleString("en-US");
    }

    /**
     * Handle changes to the Class input field
     * @param {Event} event - The blur event from the input
     */
    handleClassSeriesChange(event) {
        const stockKey = event.target.dataset.key;
        const inputElement = event.target;
        const newValue = inputElement.value;
        
        const stockIndex = this.stocks.findIndex((s) => s.uniqueKey === stockKey);
        if (stockIndex !== -1) {
            // Get the SF field name from targetFieldsMapping
            const classSeriesField = this.targetFieldsMapping?.classSeries || "breg_Stock__c.breg_Class_Series__c";
            
            // Update the stock record
            this.stocks[stockIndex] = {
                ...this.stocks[stockIndex],
                classSeries: newValue,
                [classSeriesField]: newValue
            };
            this.stocks = [...this.stocks];
            
            // Dispatch change event to update formData
            this.dispatchCustomEvent("change", { field: "stocksPaidIn", value: this.stocks });
        }
    }

    /**
     * Handle changes to the No. of Shares input field
     * @param {Event} event - The blur event from the input
     */
    handleSharesCountChange(event) {
        const stockKey = event.target.dataset.key;
        const inputElement = event.target;
        const newValue = inputElement.value;
        
        const stockIndex = this.stocks.findIndex((s) => s.uniqueKey === stockKey);
        if (stockIndex !== -1) {
            const sharesNum = parseFloat(newValue) || 0;

            // Validate: no negative values
            if (sharesNum < 0) {
                inputElement.setCustomValidity("No. of Shares cannot be negative");
                inputElement.reportValidity();
                return;
            }

            // Clear any previous custom validity
            inputElement.setCustomValidity("");

            // Get the SF field name from targetFieldsMapping
            const sharesCountField = this.targetFieldsMapping?.sharesCount || "breg_Stock__c.breg_Shares_Count__c";
            
            // Update the stock record
            this.stocks[stockIndex] = {
                ...this.stocks[stockIndex],
                sharesCount: newValue,
                sharesCountFormatted: this.formatNumber(newValue),
                [sharesCountField]: newValue
            };
            this.stocks = [...this.stocks];
            
            // Dispatch change event to update formData
            this.dispatchCustomEvent("change", { field: "stocksPaidIn", value: this.stocks });
        }
    }

    /**
     * Handle changes to the Amount input field
     * @param {Event} event - The blur event from the input
     */
    handleAmountChange(event) {
        const stockKey = event.target.dataset.key;
        const inputElement = event.target;
        const newValue = inputElement.value;
        
        const stockIndex = this.stocks.findIndex((s) => s.uniqueKey === stockKey);
        if (stockIndex !== -1) {
            const amountNum = parseFloat(newValue) || 0;

            // Validate: no negative values
            if (amountNum < 0) {
                inputElement.setCustomValidity("Amount cannot be negative");
                inputElement.reportValidity();
                return;
            }

            // Clear any previous custom validity
            inputElement.setCustomValidity("");

            // Get the SF field name from targetFieldsMapping
            const amountField = this.targetFieldsMapping?.amount || "breg_Stock__c.breg_Paid_Shares__c";
            
            // Update the stock record with both friendly name, SF field name, and formatted value
            this.stocks[stockIndex] = {
                ...this.stocks[stockIndex],
                amount: newValue,
                amountFormatted: formatCurrency(newValue),
                [amountField]: newValue
            };
            this.stocks = [...this.stocks];
            
            // Dispatch change event to update formData
            this.dispatchCustomEvent("change", { field: "stocksPaidIn", value: this.stocks });
        }
    }

    /**
     * Override processFormData to initialize stocks when formData changes
     */
    processFormData() {
        this.setStocks();
    }

    /**
     * Override setComponentProperties to handle stock reload
     */
    setComponentProperties() {
        super.setComponentProperties();
        if (this.cmpProperties?.reloadStocks) {
            this.stocksInitiated = false;
            this.setStocks();
        }
    }

    /**
     * Override populateDefaultValues - not needed for stocks
     */
    populateDefaultValues() {}

    /**
     * Validate a single stock input element
     * @param {HTMLElement} inputCmp - The lightning-input element
     * @returns {boolean} True if valid
     */
    validateStockInput(inputCmp) {
        const fieldType = inputCmp.dataset.field;
        
        // Skip validation for text fields (classSeries)
        if (fieldType === "classSeries") {
            return true;
        }

        const value = parseFloat(inputCmp.value) || 0;

        // Validate: no negative values for numeric fields
        if (value < 0) {
            const fieldLabel = fieldType === "sharesCount" ? "No. of Shares" : "Amount";
            inputCmp.setCustomValidity(`${fieldLabel} cannot be negative`);
            return false;
        }

        // Clear any previous custom validity
        inputCmp.setCustomValidity("");
        return true;
    }

    /**
     * Override reportValidity for form validation
     */
    @api
    reportValidity() {
        const inputs = [...this.template.querySelectorAll("lightning-input")];
        let allValid = true;

        inputs.forEach((inputCmp) => {
            const isValid = this.validateStockInput(inputCmp);
            inputCmp.reportValidity();
            if (!isValid) {
                allValid = false;
            }
        });

        return allValid;
    }

    /**
     * Override checkValidity for form validation
     */
    @api
    checkValidity() {
        const inputs = [...this.template.querySelectorAll("lightning-input")];
        
        for (const inputCmp of inputs) {
            if (!this.validateStockInput(inputCmp) || !inputCmp.checkValidity()) {
                return false;
            }
        }
        
        return true;
    }
}