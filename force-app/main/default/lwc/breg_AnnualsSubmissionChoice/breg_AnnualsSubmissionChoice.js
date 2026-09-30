import { LightningElement, api, wire, track } from "lwc";
import { Labels } from "./labels";
import getAccountData from "@salesforce/apex/BREGAnnualsController.getAccountData";
import { setPageUrlParams, getPageParamsFromUrl, openPdfInNewTab } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import { formatCurrency } from "c/utils";
import Id from "@salesforce/user/Id";
import EMAIL_FIELD from "@salesforce/schema/User.Email";
import { getRecord } from "lightning/uiRecordApi";
import isExpeditedProcessingDisabled from "@salesforce/apex/BREGPaymentController.isExpeditedProcessingDisabled";
import getInitialFilingDocument from "@salesforce/apex/BREGPaymentController.getInitialFilingDocument";
import downloadDocument from "@salesforce/apex/BREGPaymentController.downloadDocument";

const PROCESSING_EXPEDITED = "Expedited";

export default class Breg_AnnualsSubmissionChoice extends NavigationMixin(LightningElement) {
    // Public API
    @api accountName;
    @api accountNumber;
    @api filingYear;
    @api processingSpeed;
    @api accountId;
    @api caseId;
    @api formAction;
    redirectToCartOnly = false;

    // Labels and pricing
    labels = Labels;
    sendFreeReminder = false;
    email;
    localExpedited;
    currentArchiveFee;
    entityType;
    nonprofitTypes = ["D2", "F2", "C1", "C2", "A1", "A2", "D9"]; //TODO add to some settings

    // UI state
    isOnline = true;
    showModal = false;
    isArchivePopup = false;
    isExpeditedPopup = false;
    isNextReportPopup = false;

    // Modal content
    modalTitle;
    modalText;
    modalContinueLabel;
    modalCancelLabel;
    modalHideNextButton = false;
    @track accountData;

    // Local storage key for cart (must match cart component)
    CART_STORAGE_KEY = "breg_shopping_cart";

    // Fees
    @track _fees;
    feesProcessed = false;
    annualFilingFee;
    expeditedFee;
    archiveFee;
    lateFee;
    annualFilingFeeId;
    expeditedFeeId;
    archiveFeeId;
    lateFeeId;
    parentCaseId;

    @api
    get fees() {
        return this._fees;
    }
    set fees(value) {
        this._fees = value;
        this.processFees();
    }

    processFees() {
        //console.log("Processing fees:", JSON.stringify(this.fees));
        if (this.feesProcessed) return;
        if (this.fees) {
            // Convert object to array if needed
            const feesArray = Array.isArray(this.fees) ? this.fees : Object.values(this.fees);

            // Annual Filing Fee
            this.annualFilingFeeId = feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Annual Filing Fee")?.Id;
            this.annualFilingFee = this.getFeeAmount(
                feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Annual Filing Fee")?.breg_Fee_Amount__c
            );
            // Expedited Fee
            this.expeditedFeeId = feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Expedite Fees")?.Id;
            this.expeditedFee = this.getFeeAmount(
                feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Expedite Fees")?.breg_Fee_Amount__c
            );
            // Archive Fee
            this.archiveFeeId = feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Archive Fees")?.Id;
            this.archiveFee = this.getFeeAmount(
                feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Archive Fees")?.breg_Fee_Amount__c
            );
            // Late Fee
            this.lateFeeId = feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Late Fees")?.Id;
            this.lateFee = this.getFeeAmount(
                feesArray.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Late Fees")?.breg_Fee_Amount__c
            );

            this.feesProcessed = true;
        }
    }

    async handleChangeProcessingSpeed() {
        if (!this.isExpedited) {
            const isDisabled = await isExpeditedProcessingDisabled();

            if (isDisabled) {
                this.modalTitle = "Expedited processing";
                this.modalText = "Expedited processing is temporarily not available.";
                this.modalContinueLabel = "OK";
                this.modalCancelLabel = this.labels.BREG_Close;
                this.modalHideNextButton = false;
                this.isArchivePopup = false;
                this.isExpeditedPopup = false;
                this.isNextReportPopup = false;
                this.showModal = true;
                return;
            }
        }

        this.changeProcessingSpeed();
    }

    @wire(getRecord, { recordId: Id, fields: [EMAIL_FIELD] })
    userDetails({ error, data }) {
        if (error) {
            this.error = error;
        } else if (data) {
            if (data.fields.Email.value != null) {
                this.email = data.fields.Email.value;
            }
        }
    }

    // Wire to get account data including entity type
    @wire(getAccountData, { fileNumber: null, accountId: "$accountId" })
    wiredAccountData({ data, error }) {
        if (data) {
            console.log("Account data loaded:");
            console.log(JSON.stringify(data));
            this.accountData = data;
            this.entityType = data.entityType;
            this.accountName = data.accountName;
        } else if (error) {
            console.error("Failed to load account data", error);
        }
    }

    connectedCallback() {
        if(this.formAction?.toLowerCase() === "resubmit") {
            this.feesProcessed = false;
            this.processFees();
        }
        if (this.localExpedited === undefined) {
            this.localExpedited = this.isExpedited;
        }
    }

    // ===== COMPUTED PROPERTIES =====

    get reminderSectionTitle() {
        return this.labels.BREG_Reminder_Annual_Title;
    }

    get reminderSectionCheckboxLabel() {
        return this.labels.BREG_Reminder_Annual_Confirmation_Label.replace("{!User.Email}", this.email);
    }

    get isExpedited() {
        return this.localExpedited !== undefined ? this.localExpedited : this.processingSpeed === PROCESSING_EXPEDITED;
    }

    get showExpeditedFeeOption() {
        return this.formAction?.toLowerCase() !== "resubmit";
    }

    get annualFilingFeeText() {
        return formatCurrency(this.annualFilingFee);
    }

    get expeditedFeeText() {
        return this.isExpedited ? formatCurrency(this.expeditedFee) : formatCurrency(0);
    }

    get archiveFeeText() {
        return formatCurrency(this.archiveFee);
    }

    discount = 2.50;
    get discountText() {
        return formatCurrency(this.discount);
    }

    get lateFeeTotal() {
        let numberOfYearsLate = new Date().getFullYear() - this.filingYear;
        return numberOfYearsLate * this.lateFee;
    }

    get lateFeeText() {
        return formatCurrency(this.lateFeeTotal);
    }

    get showLate() {
        // Don't show late fee for nonprofit entity types (A1, A2, etc.)
        // const isNonprofit = this.nonprofitTypes.includes(this.entityType);
        return this.lateFeeTotal > 0;
    }

    get rawSubtotal() {
        let total = Number(this.annualFilingFee) + (this.isExpedited ? Number(this.expeditedFee) : 0) + Number(this.archiveFee);
        // Only add late fee if it should be shown (not for nonprofit entity types)
        if (this.showLate) {
            total += Number(this.lateFeeTotal);
        }
        if (this.isOnline) {
            total -= Number(this.discount);
        }
        return total > 0 ? total : 0;
    }

    get subtotal() {
        return formatCurrency(this.rawSubtotal);
    }

    get processedTime() {
        const processingTime = this.isExpedited ? this.labels.BREG_Annuals_Expedited_processing_time : this.labels.BREG_Annuals_Normal_processing_time;
        return `${this.labels.BREG_Annual_Your_report_will_be_processed_in} ${processingTime}`;
    }

    get congratsDiscountText() {
        return this.labels.BREG_Annual_Saving_discount_by_filing_online.replace("{1}", this.discountText);
    }

    get makeCheck() {
        return this.labels.BREG_Annual_Make_check_for.replace("{1}", this.subtotal);
    }

    get saveDiscount() {
        return this.labels.BREG_Annual_Save_discount.replace("{1}", this.discountText);
    }

    get expeditedLabel() {
        return this.getToggleLabel(this.isExpedited, "");
    }

    get onlineSelectedClass() {
        return this.isOnline ? "tab selected" : "tab";
    }

    get mailSelectedClass() {
        return this.isOnline ? "tab" : "tab selected";
    }

    get tileTitle() {
        return `${this.accountName} (${this.accountNumber})`;
    }

    get yearReport() {
        return this.labels.BREG_Annuals_Year_Report.replace("{1}", this.filingYear);
    }

    get discountClass() {
        return this.isOnline ? "discount" : "strike";
    }

    // ===== UI HANDLERS =====

    changeOnline(event) {
        this.isOnline = event.target.dataset.key === "online";
    }

    handleChangeFreeEmailsCheck(event) {
        this.sendFreeReminder = event.target.checked;
    }

    changeProcessingSpeed() {
        this.localExpedited = !this.localExpedited;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: { name: "Home" }
        });
    }

    handlePrev() {
        // Preserve existing URL parameters including caseId and parentCaseId
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "expedited",
            fileNumber: this.accountNumber,
            accountId: this.accountId,
            year: this.filingYear
        });
        this.dispatchEvent(new CustomEvent("previous"));
    }

    handleAddtoCart() {
        let nextAnnual = this.accountData?.annuals
            ?.filter((a) => Number(a.filingYear) > Number(this.filingYear))
            ?.sort((a, b) => Number(a.filingYear) - Number(b.filingYear))[0];
        if (nextAnnual && Number(nextAnnual.filingYear) - Number(this.filingYear) > 0) {
            this.isArchivePopup = false;
            this.isExpeditedPopup = false;
            this.isNextReportPopup = true;
            this.modalTitle = this.labels.BREG_Annuals_New_Report_Modal_Header;
            this.modalText = this.labels.BREG_Annuals_New_Report_Modal_Text.replace("{1}", this.filingYear).replace(
                "{2}",
                parseInt(this.filingYear, 10) + 1
            );
            this.modalContinueLabel = this.labels.BREG_Yes;
            this.modalCancelLabel = this.labels.BREG_No;
            this.showModal = true;
            this.addItemsToCart(this.getCartJSON());
        } else {
            this.dispatchEvent(new CustomEvent("addtocart"));
            this.redirectToCartOnly = true;
            this.handleCheckout();
        }
    }

    handleCheckout() {
        this.addItemsToCart(this.getCartJSON());
        // Preserve existing URL parameters including caseId and parentCaseId
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "login",
            fileNumber: this.accountNumber,
            accountId: this.accountId,
            year: this.filingYear
        });
        const cartTotalPrice = this.cartTotalPrice;
        this.dispatchEvent(
            new CustomEvent("checkout", {
                bubbles: true,
                composed: true,
                detail: {
                    sendFreeReminder: this.sendFreeReminder,
                    cartTotalPrice: cartTotalPrice,
                    redirectToCartOnly: this.redirectToCartOnly
                }
            })
        );
    }

    get cartTotalPrice() {
        const existingCartJson = localStorage.getItem(this.CART_STORAGE_KEY);
        if (existingCartJson) {
            const existingCart = JSON.parse(existingCartJson);
            const totalPrice = existingCart.reduce((total, item) => {
                return total + (item?.price ?? 0);
              }, 0)
            return totalPrice;
        } else {
            return 0;
        }
    }

    getCartJSON() {
        const today = new Date();
        const formattedDate = today.toISOString().split("T")[0];
        const groupKey = `${this.accountName}_${this.filingYear}_${Date.now()}`;
        const companyUrl = this.accountId ? "/search-and-buy?entityId=" + this.accountId : "#";
        const cartItems = [];

        // 1. Annual Filing Fee (always included, with discount if online)
        let annualFeePrice = this.annualFilingFee;
        if (this.isOnline && annualFeePrice > 0) {
            annualFeePrice = Number(annualFeePrice) - Number(this.discount);
        }
        cartItems.push({
            id: `${this.accountNumber}_${this.yearReport.replace(/ /g, "")}_AnnualFilingFee`,
            companyName: this.accountName,
            companyUrl: companyUrl,
            documentType: `${this.yearReport} - Annual Filing Fee`,
            documentDate: formattedDate,
            format: "Digital (PDF)",
            formatIcon: "doctype:pdf",
            quantity: 1,
            unitPrice: annualFeePrice,
            price: annualFeePrice,
            certifyPrice: 0,
            isCertified: false,
            isQuantityDisabled: true,
            isDeleteDisabled: false,
            isPrimaryItem: true,
            key: groupKey,
            type: "Annual Form",
            caseId: this.caseId,
            feeId: this.annualFilingFeeId
        });

        // 2. Expedited Fee (conditional - only if expedited is selected)
        if (this.isExpedited) {
            cartItems.push({
                id: `${this.accountNumber}_${this.yearReport.replace(/ /g, "")}_ExpeditedFee`,
                companyName: this.accountName,
                companyUrl: companyUrl,
                documentType: `${this.yearReport} - Expedite Fee`,
                documentDate: formattedDate,
                format: "Digital (PDF)",
                formatIcon: "doctype:pdf",
                quantity: 1,
                unitPrice: this.expeditedFee,
                price: this.expeditedFee,
                certifyPrice: 0,
                isCertified: false,
                isQuantityDisabled: true,
                isDeleteDisabled: true,
                isPrimaryItem: false,
                key: groupKey,
                type: "Annual Form",
                caseId: this.caseId,
                feeId: this.expeditedFeeId
            });
        }

        // 3. Archive Fee (always included)
        cartItems.push({
            id: `${this.accountNumber}_${this.yearReport.replace(/ /g, "")}_ArchiveFee`,
            companyName: this.accountName,
            companyUrl: companyUrl,
            documentType: `${this.yearReport} - Archive Fee`,
            documentDate: formattedDate,
            format: "Digital (PDF)",
            formatIcon: "doctype:pdf",
            quantity: 1,
            unitPrice: this.archiveFee,
            price: this.archiveFee,
            certifyPrice: 0,
            isCertified: false,
            isQuantityDisabled: true,
            isDeleteDisabled: true,
            isPrimaryItem: false,
            key: groupKey,
            type: "Annual Form",
            caseId: this.caseId,
            feeId: this.archiveFeeId
        });

        // 4. Late Fee (conditional - only if showLate is true)
        if (this.showLate) {
            cartItems.push({
                id: `${this.accountNumber}_${this.yearReport.replace(/ /g, "")}_LateFee`,
                companyName: this.accountName,
                companyUrl: companyUrl,
                documentType: `${this.yearReport} - Late Fee`,
                documentDate: formattedDate,
                format: "Digital (PDF)",
                formatIcon: "doctype:pdf",
                quantity: 1,
                unitPrice: this.lateFeeTotal,
                price: this.lateFeeTotal,
                certifyPrice: 0,
                isCertified: false,
                isQuantityDisabled: true,
                isDeleteDisabled: true,
                isPrimaryItem: false,
                key: groupKey,
                type: "Annual Form",
                caseId: this.caseId,
                feeId: this.lateFeeId
            });
        }

        return cartItems;
    }

    getFeeAmount(feeAmount) {
        if (feeAmount == null || this.formAction?.toLowerCase() === "resubmit") {
            return 0;
        } else {
            return Number(feeAmount);
        }
    }

    // The Initial Filing document is generated asynchronously (DocuSign workflow) right after
    // the Case is created, and isn't always ready by the time this step is reached
    INITIAL_FILING_POLL_INTERVAL_MS = 6000;
    INITIAL_FILING_POLL_MAX_ATTEMPTS = 10; // ~60s total

    async handlePrintReport() {
        // Open the tab synchronously on the click so browsers don't treat it as a popup
        const printWindow = window.open("", "_blank");
        if (printWindow) {
            printWindow.document.body.innerHTML = "<p>Preparing your annual report for printing, please wait...</p>";
        }

        try {
            const docInfo = await this.waitForInitialFilingDocument();
            if (!docInfo) {
                if (printWindow) {
                    printWindow.document.body.innerHTML =
                        "<p>Your report is still being prepared. Please try printing again in a minute.</p>";
                }
                console.error("No Initial Filing document found for case", this.caseId);
                return;
            }

            const base64Document = await downloadDocument({ docusignDocumentId: docInfo.docusignDocumentId });
            openPdfInNewTab(base64Document, printWindow);
        } catch (error) {
            if (printWindow) {
                printWindow.document.body.innerHTML = "<p>There was an error preparing your annual report. Please try again.</p>";
            }
            console.error("Error opening annual report document:", error);
        }
    }

    async waitForInitialFilingDocument() {
        for (let attempt = 0; attempt < this.INITIAL_FILING_POLL_MAX_ATTEMPTS; attempt++) {
            const docInfo = await getInitialFilingDocument({ caseId: this.caseId });
            if (docInfo) {
                return docInfo;
            }
            await this.delay(this.INITIAL_FILING_POLL_INTERVAL_MS);
        }
        return null;
    }

    delay(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    // ===== MODAL LOGIC =====

    showArchivePopup() {
        this.isArchivePopup = true;
        this.isExpeditedPopup = false;
        this.isNextReportPopup = false;
        this.modalTitle = this.labels.BREG_Annual_Archive_fee;
        this.modalText = this.labels.BREG_Annuals_Archive_Fee_Info.replaceAll("{1}", this.archiveFee);
        this.modalCancelLabel = this.labels.BREG_Close;
        this.modalHideNextButton = true;
        this.showModal = true;
    }

    showExpeditedPopup() {
        this.isExpeditedPopup = true;
        this.isArchivePopup = false;
        this.isNextReportPopup = false;
        this.modalTitle = this.labels.BREG_Annuals_Expedited_Processing;
        this.modalText = this.processedTime;
        this.modalContinueLabel = this.getToggleLabel(this.isExpedited, this.labels.BREG_Annuals_Expedited_Processing);
        this.modalCancelLabel = this.labels.BREG_Close;
        this.showModal = true;
    }

    async handleModalContinue() {
        if (this.isArchivePopup) {
            this.currentArchiveFee = this.currentArchiveFee === this.archiveFee ? (0).toFixed(2) : this.archiveFee;
        } else if (this.isExpeditedPopup) {
            await this.handleChangeProcessingSpeed();
        } else if (this.isNextReportPopup) {
            // Clear caseId and set current case as parent for the next year's report
            const currentParams = getPageParamsFromUrl();
            this.parentCaseId = currentParams.parentCaseId ? currentParams.parentCaseId : this.caseId;
            setPageUrlParams({
                ...currentParams,
                section: "annual-report",
                page: "verify",
                fileNumber: this.accountNumber,
                accountId: this.accountId,
                year: parseInt(this.filingYear, 10) + 1,
                caseId: null,
                annualId: null,
                parentCaseId: this.parentCaseId
            });
            this.dispatchEvent(new CustomEvent("nextreport"));
        }
        this.showModal = false;
    }

    handleModalCancel() {
        this.showModal = false;
        if (this.isNextReportPopup) {
            this.dispatchEvent(new CustomEvent("addtocart"));
        }
    }

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

    // ===== HELPERS =====

    getToggleLabel(isEnabled, featureLabel) {
        return `${isEnabled ? this.labels.BREG_Remove : this.labels.BREG_Add} ${featureLabel}`;
    }
}