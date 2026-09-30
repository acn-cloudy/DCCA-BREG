import { LightningElement, api, track } from "lwc";

export default class NameClearenceSearchResultsTable extends LightningElement {
    @api searchResults = [];
    @api isLoading = false;
    @api errorMessage = "";
    @api searchStatus = "idle"; // idle, success, error
    @api totalCount = 0;

    @track sortedBy = "name";
    @track sortedDirection = "asc";

    // Pagination properties
    @track currentPage = 1;
    @track pageSize = 10;
    @track allResults = []; // Store all results for pagination

    // Table columns configuration
    get columns() {
        return [
            {
                label: "Business Name",
                fieldName: "recordURL",
                type: "url",
                sortable: true,
                cellAttributes: {
                    class: { fieldName: "nameClass" }
                },
                typeAttributes: {
                    label: { fieldName: "name" },
                    target: "_blank"
                }
            },
            {
                label: "File Number",
                fieldName: "fileNumber",
                type: "text",
                sortable: true
            },
            {
                label: "Status",
                fieldName: "status",
                type: "text",
                sortable: true,
                cellAttributes: {
                    iconName: { fieldName: "statusIcon" },
                    iconPosition: "left",
                    class: { fieldName: "statusClass" }
                }
            },
            {
                label: "Object Type",
                fieldName: "objectName",
                type: "text",
                sortable: true
            },
            {
                label: "Type",
                fieldName: "type",
                type: "text",
                sortable: true
            },
            {
                label: "Registration Date",
                fieldName: "registrationDate",
                type: "date",
                sortable: true,
                typeAttributes: {
                    year: "numeric",
                    month: "short",
                    day: "2-digit",
                    timeZone: "UTC"
                }
            }
        ];
    }

    // Computed properties
    get cardTitle() {
        if (this.isLoading) {
            return "Searching...";
        }
        if (this.hasResults) {
            return `Search Results (${this.totalCount})`;
        }
        return "Search Results";
    }

    get hasResults() {
        return this.searchResults && this.searchResults.length > 0;
    }

    get displayedCount() {
        return this.paginatedResults ? this.paginatedResults.length : 0;
    }

    get paginatedResults() {
        console.debug("Calculating paginated results for page", this.currentPage, "with page size", this.pageSize);
        console.debug("Total results available:", this.allResults ? this.allResults.length : 0);
        if (!this.allResults || this.allResults.length === 0) {
            return [];
        }

        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        console.debug("Paginating results from", startIndex, "to", endIndex);
        return this.allResults.slice(startIndex, endIndex);
    }

    get totalPages() {
        return Math.ceil((this.allResults?.length || 0) / this.pageSize);
    }

    get hasPreviousPage() {
        return this.currentPage > 1;
    }

    get notHasPreviousPage() {
        return this.currentPage <= 1;
    }

    get hasNextPage() {
        return this.currentPage < this.totalPages;
    }

    get notHasNextPage() {
        return this.currentPage >= this.totalPages;
    }

    get startRecord() {
        return this.allResults?.length > 0 ? (this.currentPage - 1) * this.pageSize + 1 : 0;
    }

    get endRecord() {
        const end = this.currentPage * this.pageSize;
        return Math.min(end, this.allResults?.length || 0);
    }

    get pageInfo() {
        return `${this.startRecord}-${this.endRecord} of ${this.allResults?.length || 0}`;
    }

    get showStatusMessage() {
        return this.searchStatus !== "idle" && !this.isLoading;
    }

    get showSuccessMessage() {
        return this.searchStatus === "success" && this.hasResults;
    }

    get showErrorMessage() {
        return this.searchStatus === "error" && this.errorMessage;
    }

    get showNoResults() {
        return this.searchStatus === "success" && !this.hasResults;
    }

    get showEmptyState() {
        return this.searchStatus === "idle" && !this.hasResults && !this.isLoading;
    }

    get showPagination() {
        return this.hasResults && this.totalPages > 1;
    }

    get isLoadMoreDisabled() {
        return this.isLoading || this.displayedCount >= this.totalCount;
    }

    // Lifecycle methods
    connectedCallback() {
        // Initialize pagination when component loads
        this.updatePaginatedData();
    }

    // Watch for changes to searchResults
    @api
    updateResults(results) {
        this.searchResults = results || [];
        this.currentPage = 1; // Reset to first page
        this.updatePaginatedData();
        this.sortedBy = "searchValue"; // Default sort by normalized search value
        this.sortedDirection = "asc"; // Default sort direction
        this.sortResults(); // Sort results after updating data
        if (this.allResults.length > 2000) {
            console.warn("Search results exceed 2000 records. Consider refining your search criteria.");
            this.allResults = this.allResults.slice(0, 2000);
        }
    }

    updatePaginatedData() {
        // This will trigger reactivity for paginatedResults
        this.allResults = [...(this.searchResults || [])];
    }

    // Event handlers
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;

        // Sort the current results
        this.sortResults();
    }

    handleViewDetails(row) {
        // Dispatch event to parent or show modal with details
        this.dispatchEvent(
            new CustomEvent("viewdetails", {
                detail: { record: row }
            })
        );
    }

    handleShowSimilar(row) {
        // Dispatch event to search for similar names
        this.dispatchEvent(
            new CustomEvent("showsimilar", {
                detail: { record: row }
            })
        );
    }

    handleLoadMore() {
        // Dispatch event to load more results
        this.dispatchEvent(new CustomEvent("loadmore"));
    }

    // Pagination event handlers
    handlePreviousPage() {
        if (this.hasPreviousPage) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.hasNextPage) {
            this.currentPage++;
        }
    }

    handleFirstPage() {
        this.currentPage = 1;
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1; // Reset to first page
    }

    get pageSizeDisplayValue() {
        return this.pageSize.toString();
    }

    get pageSizeOptions() {
        return [
            { label: "5", value: "5" },
            { label: "10", value: "10" },
            { label: "25", value: "25" },
            { label: "50", value: "50" },
            { label: "100", value: "100" }
        ];
    }

    // Helper methods
    sortResults() {
        const cloneData = [...this.allResults];
        const fieldName = this.sortedBy === "recordURL" ? "searchValue" : this.sortedBy;
        const direction = this.sortedDirection;

        const getSortKey = (value) => {
            let str = String(value).toUpperCase();
            const alphanumeric = str.replace(/[^A-Z0-9 ]/g, "");
            return { alphanumeric, original: str };
        };

        cloneData.sort((a, b) => {
            let aVal = a[fieldName] || "";
            let bVal = b[fieldName] || "";

            if (fieldName.includes("Date")) {
                aVal = new Date(aVal) || new Date(0);
                bVal = new Date(bVal) || new Date(0);
            } else {
                const aKey = getSortKey(aVal);
                const bKey = getSortKey(bVal);

                aVal = aKey.alphanumeric;
                bVal = bKey.alphanumeric;
            }

            if (direction === "asc") {
                return aVal > bVal ? 1 : aVal < bVal ? -1 : 0;
            }
            return aVal < bVal ? 1 : aVal > bVal ? -1 : 0;
        });

        this.allResults = cloneData;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
    }
}