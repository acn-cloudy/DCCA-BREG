import { api, track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { addUniqueKeys } from "c/utils";
import getHistoricalStocks from "@salesforce/apex/BREGAccountAffiliationController.getHistoricalStocks";

const ENTITY_TYPES_REQUIRING_ISSUED_SHARES = ["D1", "P1", "S1", "A1", "A2", "C1", "C2"];
const ENTITY_TYPES_WITH_MODIFIED_STOCK = ["A1", "A2", "C1", "C2"];
const INACTIVE_NATURE_OF_BUSINESS = "INACTIVE";
const NO_ISSUED_SHARES_TEXT = "No issued shares";
const NO_AUTHORIZED_SHARES_TEXT = "No authorized shares";

/**
 * Stocks Annuals component (Editable Issued Shares)
 * Displays: Stock Class, Authorized Shares, Issued Shares (editable)
 */
export default class Breg_StocksAnnuals extends BaseFormComponent {
    defaultTitle = "Stocks";
    @track stocks = [];
    historicalStocks = [];
    stocksInitiated = false;

    get showEditSectionButton() {
        return this.readOnly && !this.alwaysReadOnly && this.isAnnualForm && this.hasStocks && !this.isModifiedStockEntity;
    }

    /**
     * Getter to check if there are stocks to display
     */
    get hasStocks() {
        return this.stocks && this.stocks.length > 0;
    }

    /**
     * Get the entity type from formData
     * @returns {string} Entity type value
     */
    get entityType() {
        return this.formData?.["Case.breg_Entity_Type__c"] || this.formData?.["Account.breg_Entity_Type__c"] || "";
    }

    /**
     * Get the nature of business from formData
     * @returns {string} Nature of business value
     */
    get natureOfBusiness() {
        return this.formData?.["Case.breg_Entity_Nature_Of_Business__c"] || this.formData?.["Account.breg_Purpose__c"] || "";
    }

    /**
     * Check if issued shares are required (cannot be 0)
     * Required when entity type is D1 or P1 AND nature of business is not INACTIVE
     * @returns {boolean} True if issued shares are required
     */
    get isIssuedSharesRequired() {
        const isRequiredEntityType = ENTITY_TYPES_REQUIRING_ISSUED_SHARES.includes(this.entityType);
        const isNotInactive = this.natureOfBusiness?.toUpperCase() !== INACTIVE_NATURE_OF_BUSINESS;
        return isRequiredEntityType && isNotInactive;
    }

    get isModifiedStockEntity() {
        return ENTITY_TYPES_WITH_MODIFIED_STOCK.includes(this.entityType);
    }

    async connectedCallback() {
        super.connectedCallback();

        if (this.isModifiedStockEntity) {
            this.historicalStocks = await getHistoricalStocks({accId: this.formData?.["Account.Id"]});
            this.stocksInitiated = false; // Force re-processing of stocks with modified logic
        }

        this.setStocks();
    }

    /**
     * Initialize stocks from formData
     * Called from connectedCallback and processFormData
     */
    setStocks() {

        if (!this.formData?.stocksAnnuals || this.formData.stocksAnnuals.length === 0) {
            return;
        }

        if (this.stocksInitiated && (this.isModifiedStockEntity || !this.hasStocksChanged())) {
            return;
        }

        this.stocksInitiated = true;
        let sourceStocks = [...this.formData.stocksAnnuals];

        if (sourceStocks.length === 0) {
            this.stocks = [];
            return;
        }

        const processedStocks = this.isModifiedStockEntity ? this.getModifiedStock(sourceStocks) :  this.getDefaultStock(sourceStocks);
        this.stocks = addUniqueKeys(processedStocks, "stock");

        this.dispatchCustomEvent(this.isModifiedStockEntity ? "change" : "formupdate", { field: "stocksAnnuals", value: this.stocks });
    }

    getDefaultStock(sourceStocks) {
        return sourceStocks.map((stock) => {
            // Get values using friendly names from targetFieldsMapping or fall back to SF field names
            const stockClass = stock.stockClass ?? stock["breg_Stock__c.breg_Stock_Class__c"];
            const authorizedSharesRaw = stock["breg_Stock__c.breg_Number_of_Issued_Shares__c"];
            const paidSharesRaw = stock.paidShares ?? stock["breg_Stock__c.breg_Paid_Shares__c"];

            const authorizedShares = this.normalizeToInteger(authorizedSharesRaw);
            const paidShares = this.normalizeToInteger(paidSharesRaw);
            
            return {
                ...stock,
                stockClass,

                authorizedShares: authorizedShares.isNumeric 
                    ? authorizedShares.value 
                    : null,
                authorizedSharesFormatted: authorizedShares.isNumeric 
                    ? this.formatNumber(authorizedShares.value) 
                    : String(authorizedSharesRaw ?? NO_AUTHORIZED_SHARES_TEXT),

                paidShares: paidShares.isNumeric
                    ? paidShares.value
                    : null,
                paidSharesFormatted: paidShares.isNumeric 
                    ? this.formatNumber(paidShares.value) 
                    : String(paidSharesRaw ?? NO_ISSUED_SHARES_TEXT),
                hasPaidShares: paidShares.isNumeric && paidShares.value > 0,
                isPaidSharesEditable: authorizedShares.isNumeric
            };
        });
    }

    getModifiedStock(sourceStocks) {

        const histByClass = new Map();

        this.historicalStocks.forEach(h => {
            histByClass.set(h.breg_Stock_Class__c, h);
        });

        return sourceStocks.map(stock => {
            const stockClass = stock.stockClass ?? stock["breg_Stock__c.breg_Stock_Class__c"];
            const historicalStock = histByClass.get(stockClass);
            const numberOfShares = stock.numberOfShares ?? stock["breg_Stock__c.breg_Number_of_Issued_Shares__c"] ?? 0;
            const paidShares = stock.paidShares ?? stock["breg_Stock__c.breg_Paid_Shares__c"] ?? 0;

            const numberOfSharesNorm = this.normalizeToInteger(numberOfShares);
            const paidSharesNorm = this.normalizeToInteger(paidShares);
            
            const parValue = this.parsePerValue(historicalStock?.["breg_Per_Value__c"] ?? 0);
            const parTotal = parValue == "NPV" || !numberOfSharesNorm.isNumeric ? "N/A" : numberOfSharesNorm.value * parValue;
            const amount = parValue == "NPV" || !paidSharesNorm.isNumeric ? "N/A" : paidSharesNorm.value * parValue;

            const ParValueField = this.targetFieldsMapping?.parValue || "breg_Stock__c.breg_Per_Value__c";
            const amountField = this.targetFieldsMapping?.amount || "breg_Stock__c.breg_Stock_Amount__c";

            return {
                ...stock,
                stockClass,

                numberOfShares,
                numberOfSharesFormatted: this.formatNumber(numberOfShares),

                paidShares,
                paidSharesFormatted: this.formatNumber(paidShares),

                parValue,
                parValueFormatted: parValue,

                parTotal,
                parTotalFormatted: this.formatNumber(parTotal),

                amount,
                amountFormatted: this.formatNumber(amount), 

                [ParValueField]: String(parValue),
                [amountField]: String(this.formatNumber(amount))
            };
        });
    }

    /**
     * Normalize a raw input value for issued shares, allowing only numeric values with optional formatting
     * Returns an object with isNumeric, numericValue, and displayValue properties
        * @param {string} raw - The raw input value to normalize    
        * @return {Object} Normalized value object with properties:
        *   - isNumeric: boolean indicating if the input is a valid numeric value
        *   - numericValue: the numeric value as a number (or null if not numeric)
        *   - displayValue: the value formatted for display (with thousand separators) or original string if not numeric
     */
    normalizeToInteger(raw) {

        if (raw === null || raw === undefined) {
            return { isNumeric: false, value: null };
        }

        const str = String(raw).trim();

        // If the string contains any letters, treat it as non-numeric
        if (/[a-zA-Z]/.test(str)) {
            return { isNumeric: false, value: null };
        }

        // Remove dollar signs and commas for easier processing
        let cleaned = str.replace(/\$/g, "").replace(/,/g, "");

        // Remove decimal part for normalization, we only care about the integer part for shares
        cleaned = cleaned.split(".")[0];

        // Verify that cleaned number is purely digits
        if (!/^\d+$/.test(cleaned)) {
            return { isNumeric: false, value: null };
        }

        return {
            isNumeric: true,
            value: Number(cleaned)
        };
    }

    /**
     * Parse a raw input value for per value field, allowing only valid number formats with optional currency symbols
     * Returns a normalized number or "NPV" if the input is invalid or empty
      * @param {string} raw - The raw input value to parse
      * @returns {number|string} The parsed number or "NPV" if invalid
      * Examples of valid inputs:
      * parsePerValue("100")         // 100
      * parsePerValue(".001")        // 0.001
      * parsePerValue(".01")         // 0.01
      * parsePerValue("1,000")       // 1000
      * parsePerValue("1,000.50")    // 1000.5
      * parsePerValue("1.00")        // 1
      * parsePerValue("1.000")       // 1
      * parsePerValue("400.")        // 400
      * parsePerValue("$1")          // 1
      * parsePerValue("$1,000,000")  // 1000000
      * parsePerValue("1,00")        // "NPV"
      * parsePerValue("10.X")        // "NPV"
      * parsePerValue("6 2/3")       // "NPV"
      * parsePerValue("abc")         // "NPV"
     */
    parsePerValue(raw) {
        if (raw == null) return "NPV";

        let str = String(raw).trim();
        if (str === "") return "NPV";

        // Allow only digits, spaces, commas, dots, and dollar signs
        if (!/^[\d\s.,$]+$/.test(str)) {
            return "NPV";
        }

        // Remove dollar signs and spaces for easier processing
        str = str.replace(/\$/g, "").replace(/\s/g, "");

        // If there are commas, ensure they are in the correct positions for thousand separators
        if (/,/.test(str) && !/^\d{1,3}(,\d{3})*(\.\d+)?$/.test(str)) {
            return "NPV";
        }

        // Remove thousand separators (commas) for normalization
        str = str.replace(/,/g, "");

        // If there are multiple dots, it's invalid
        if ((str.match(/\./g) || []).length > 1) {
            return "NPV";
        }

        // If it ends with a dot, just remove the dot
        if (str.endsWith(".")) {
            str = str.slice(0, -1);
        }

        // Allow numbers with optional decimal point, but not just a dot or zero values
        if ((!/^\d+(\.\d+)?$/.test(str) && !/^\.\d+$/.test(str)) || str === "0" || str === "0.0") {
            return "NPV";
        }

        const num = Number(str);
        return Number.isFinite(num) ? num : "NPV";
    }

    /**
     * Check if formData.stocks differs from current stocks
     * @returns {boolean} True if stocks have changed
     */
    hasStocksChanged() {
        if (!this.formData?.stocksAnnuals || !this.stocks) {
            return true;
        }
        if (this.formData.stocksAnnuals.length !== this.stocks.length) {
            return true;
        }

        // Compare key stock properties
        for (let i = 0; i < this.formData.stocksAnnuals.length; i++) {
            const formStock = this.formData.stocksAnnuals[i];
            const currentStock = this.stocks.find((s) => s.uniqueKey === formStock.uniqueKey);

            if (!currentStock) {
                return true;
            }

            const formNorm = this.normalizeToInteger(
                formStock.paidShares ??
                formStock["breg_Stock__c.breg_Paid_Shares__c"]
            );
            const formValue = formNorm.isNumeric ? formNorm.value : null;
            const currentValue = currentStock.paidShares ?? null;


            const formStockId = formStock["breg_Stock__c.Id"];
            const currentStockId = currentStock["breg_Stock__c.Id"];

            if (currentStockId !== formStockId || formValue !== currentValue) {
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
     * Handle changes to the Issued Shares input field
     * @param {Event} event - The blur event from the input
     */
    handlePaidSharesChange(event) {
        const stockKey = event.target.dataset.key;
        const stockIndex = this.stocks.findIndex((s) => s.uniqueKey === stockKey);

        if (stockIndex !== -1) {
            const paidShares = Number(event.target.value);
            const stock = this.stocks[stockIndex];
            const authorizedShares = stock.authorizedShares ?? 0;

            // Validate: input must be a number
            if (Number.isNaN(paidShares)) {
                event.target.setCustomValidity("Invalid number");
                return;
            }

            // Validate: no negative values
            if (paidShares < 0) {
                event.target.setCustomValidity("Issued shares cannot be negative");
                event.target.reportValidity();
                return;
            }

            // Validate: issued shares cannot exceed authorized shares
            if (paidShares > authorizedShares) {
                event.target.setCustomValidity("Issued shares cannot exceed authorized shares");
                event.target.reportValidity();
                return;
            }

            // Clear any previous custom validity
            event.target.setCustomValidity("");

            // Get the SF field name from targetFieldsMapping
            const paidSharesField = this.targetFieldsMapping?.paidShares || "breg_Stock__c.breg_Paid_Shares__c";

            // Update the stock record with both friendly name, SF field name, and formatted value
            this.stocks[stockIndex] = {
                ...stock,
                paidShares,
                paidSharesFormatted: this.formatNumber(paidShares),
                hasPaidShares: paidShares > 0,
                [paidSharesField]: String(paidShares)
            };

            this.stocks = [...this.stocks];

            // Dispatch change event to update formData
            this.dispatchCustomEvent("change", { field: "stocksAnnuals", value: this.stocks });
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
        const stockKey = inputCmp.dataset.key;
        const stock = this.stocks.find((s) => s.uniqueKey === stockKey);

        if (!stock) {
            return true;
        }

        const authorizedShares = parseFloat(stock.authorizedShares) || 0;
        const paidShares = parseFloat(inputCmp.value) || 0;

        // Validate: no negative values
        if (paidShares < 0) {
            inputCmp.setCustomValidity("Issued shares cannot be negative");
            return false;
        }

        // Validate: issued shares cannot exceed authorized shares
        if (paidShares > authorizedShares) {
            inputCmp.setCustomValidity("Issued shares cannot exceed authorized shares");
            return false;
        }

        // Validate: for entity types D1/P1 with non-INACTIVE nature of business, value cannot be 0
        if (this.isIssuedSharesRequired && paidShares === 0) {
            inputCmp.setCustomValidity("Your issued shares cannot be 0");
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