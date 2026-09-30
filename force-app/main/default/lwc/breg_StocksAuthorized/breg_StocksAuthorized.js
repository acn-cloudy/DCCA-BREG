import { api, track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { addUniqueKeys, formatCurrency } from "c/utils";

/**
 * Authorized Capital Stocks component (Read-only)
 * Displays: Class, No. of Shares, Par Value, Par Total
 */
export default class Breg_StocksAuthorized extends BaseFormComponent {
    defaultTitle = "Authorized Capital";
    @track stocks = [];
    stocksInitiated = false;

    /**
     * Hide edit button - this table is always read-only
     */
    get showEditSectionButton() {
        return false;
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
        if (!this.formData?.stocksAuthorized || this.formData.stocksAuthorized.length === 0) {
            return;
        }

        // Check if stocks data has actually changed
        if (this.stocksInitiated && !this.hasStocksChanged()) {
            return;
        }
        
        this.stocksInitiated = true;
        const processedStocks = this.formData.stocksAuthorized.map((stock) => {
            // Get values using friendly names from targetFieldsMapping or fall back to SF field names
            const classSeries = stock.classSeries ?? stock["breg_Stock__c.breg_Class_Series__c"];
            const sharesCount = stock.sharesCount ?? stock["breg_Stock__c.breg_Shares_Count__c"];
            const parValue = stock.parValue ?? stock["breg_Stock__c.breg_Par_Value__c"];
            const parTotal = stock.parTotal ?? stock["breg_Stock__c.breg_Par_Total__c"];
            
            return {
                ...stock,
                classSeries,
                sharesCount,
                sharesCountFormatted: this.formatNumber(sharesCount),
                parValue,
                parValueFormatted: formatCurrency(parValue),
                parTotal,
                parTotalFormatted: formatCurrency(parTotal)
            };
        });
        
        this.stocks = addUniqueKeys(processedStocks, "stock");
        
        // Dispatch formupdate to sync with parent
        this.dispatchCustomEvent("formupdate", { field: "stocksAuthorized", value: this.stocks });
    }

    /**
     * Check if formData.stocks differs from current stocks
     * @returns {boolean} True if stocks have changed
     */
    hasStocksChanged() {
        if (!this.formData?.stocksAuthorized || !this.stocks) {
            return true;
        }
        if (this.formData.stocksAuthorized.length !== this.stocks.length) {
            return true;
        }
        
        // Compare key stock properties
        for (let i = 0; i < this.formData.stocksAuthorized.length; i++) {
            const formStock = this.formData.stocksAuthorized[i];
            const currentStock = this.stocks.find(s => s.uniqueKey === formStock.uniqueKey);
            
            if (!currentStock) {
                return true;
            }
            
            const formSharesCount = formStock.sharesCount ?? formStock["breg_Stock__c.breg_Shares_Count__c"];
            const formParValue = formStock.parValue ?? formStock["breg_Stock__c.breg_Par_Value__c"];
            
            if (currentStock.sharesCount !== formSharesCount || 
                currentStock.parValue !== formParValue) {
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
     * Override reportValidity - always valid since read-only
     */
    @api
    reportValidity() {
        return true;
    }

    /**
     * Override checkValidity - always valid since read-only
     */
    @api
    checkValidity() {
        return true;
    }
}