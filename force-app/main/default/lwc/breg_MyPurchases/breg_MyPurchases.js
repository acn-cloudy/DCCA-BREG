import { LightningElement, api, track } from "lwc";
import labels from "./labels";

export default class Breg_MyPurchases extends LightningElement {
    labels = labels;
    _transactionLines = [];
    @api isMyDashboardPage = false;

    @api
    get transactionLines() {
        return this._transactionLines;
    }

    set transactionLines(value) {
        this._transactionLines = value || [];
        this.updateFormattedData();
    }

    // Download modal state
    @track isDownloadModalOpen = false;
    @track modalDocuments = [];
    modalFileType = "pdf";

    // Pagination state
    @track pagedData = [];
    @track formattedData = [];
    totalPages = 1;
    currentPage = 1;
    pageSize = 10;
    pageSizeOptions;

    // Initialize pagination options
    connectedCallback() {
        this.initializePaginationOptions();
        this.updateFormattedData();
    }

    // Initialize dropdown options with labels
    initializePaginationOptions() {
        this.pageSizeOptions = [
            { label: "10", value: "10", selected: true },
            { label: "20", value: "20", selected: false }
        ];
    }

    // Update formatted data whenever transactionLines changes
    @api
    refreshData() {
        this.updateFormattedData();
    }

    updateFormattedData() {
        this.formattedData = this._transactionLines.map((line, index) => {
            return {
                ...line,
                entityUrl: `/search-and-buy?entityId=${line.entityId}`,
                paymentConfirmationLink: `/payment-confirmation?pid=${line.paymentId}`,
                formattedPurchaseDate: this.formatDate(line.purchaseDate),
                iconName: this.iconName(line.documentType, line.isEntityListDocument, line.isAgentSearchList),
                lineIndex: index,
                uniqueKey: `${line.paymentId}-${index}`
            };
        });

        this.currentPage = 1;
        this.totalPages = Math.ceil(this.formattedData.length / this.pageSize) || 1;
        this.updatePagedData();
    }

    get formattedTransactionLines() {
        // Return all data if not on dashboard page, otherwise return paged data
        return this.isMyDashboardPage ? this.pagedData : this.formattedData;
    }

    formatDate(dateValue) {
        if (!dateValue) return "";
        const date = new Date(dateValue);
        return date.toLocaleDateString("en-US", {
            year: "numeric",
            month: "short",
            day: "numeric",
            timeZone: "UTC"
        });
    }

    iconName(documentType, isEntityListDocument, isAgentSearchList) {
        if (!documentType) return "";
        if (documentType === "Digital") {
            if (isEntityListDocument || isAgentSearchList) {
                return "doctype:csv";
            }
            return "doctype:pdf";
        } else if (documentType === "Printed") {
            return "utility:print";
        }
    }

    handleDownload(event) {
        const lineIndex = event.currentTarget.dataset.lineIndex;
        const transline = lineIndex !== undefined && this._transactionLines[lineIndex] ? this._transactionLines[lineIndex] : null;

        this.modalFileType = transline && (transline.isEntityListDocument || transline.isAgentSearchList) ? "csv" : "pdf";

        this.modalDocuments = (transline?.downloadableDocuments || []).map((doc, index) => ({
            docusignDocumentId: doc.docusignDocumentId,
            name: doc.name,
            index
        }));

        this.isDownloadModalOpen = true;
    }

    handleCloseModal() {
        this.isDownloadModalOpen = false;
        this.modalDocuments = [];
    }

    handleDownloadSingleDocument(event) {
        const docIndex = event.currentTarget.dataset.docIndex;
        const doc = this.modalDocuments[docIndex];
        if (!doc) {
            return;
        }

        const documents = [
            {
                docusignDocumentId: doc.docusignDocumentId,
                description: doc.name,
                fileType: this.modalFileType
            }
        ];

        this.dispatchEvent(new CustomEvent("downloaddocument", { detail: { documents } }));
    }

    // Update the paged data for the current page
    updatePagedData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pagedData = this.formattedData.slice(start, end);
    }

    // Pagination controls
    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePagedData();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePagedData();
        }
    }

    // Check if current page is the first page
    get isFirstPage() {
        return this.currentPage === 1;
    }

    // Check if current page is the last page
    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    // Go to first page
    goToFirstPage() {
        if (!this.isFirstPage) {
            this.currentPage = 1;
            this.updatePagedData();
        }
    }

    // Go to last page
    goToLastPage() {
        if (!this.isLastPage) {
            this.currentPage = this.totalPages;
            this.updatePagedData();
        }
    }

    // Handle page size change
    async handlePageSizeChange(event) {
        const selectedValue = event.target.value;
        this.pageSize = parseInt(selectedValue, 10);

        this.totalPages = Math.ceil(this.formattedData.length / this.pageSize) || 1;
        this.currentPage = 1;
        this.updatePagedData();
        await this.delay(50);
    }

    // Utility delay function
    delay(time) {
        return new Promise((resolve) => setTimeout(resolve, time));
    }

    // Get the display range for pagination (e.g., 1-10 of 53 items)
    get displayRange() {
        const total = this.formattedData.length;
        if (total === 0) {
            return "";
        }
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, total);
        return `${start}-${end} of ${total} items`;
    }
}