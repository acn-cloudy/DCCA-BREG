import { LightningElement, api, track, wire } from "lwc";
import { Labels } from "./labels";
import getSearchResults from "@salesforce/apex/BREGSearchAndBuyController.getSearchResults";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import STATUS_FIELD from "@salesforce/schema/Account.breg_Entity_Status__c";
import BUSINESS_STRUCTURE_FIELD from "@salesforce/schema/Account.breg_Business_Structure__c";
import { setPageUrlParams } from "c/utils";

export default class Breg_AccountSearchResultsTable extends LightningElement {
    // Picklist and object info
    accountInfo;
    recordTypeOptions;
    statusOptions;
    entityTypeOptions;
    pageSizeOptions;
    @track selectedRecordIds = [];
    // Data
    @track pagedData = [];
    @track data = [];
    // Condition states
    @api includeFilters = false;
    @api showNewSearch = false;
    @api includeRecordType = false;
    @api showSearchResults = false;
    @api includeTnTmSm = false;
    @api excludeAccounts = false;
    @api isOnlyTnTmSmType = false;
    @api includeTransactions = false;
    @api includeNotificationsFields;
    @api notificationCategory;
    showSpinner = false;
    isAnnualsContext = false;
    isNotificationsContext = false;
    // Pagination state
    totalPages = 1;
    currentPage = 1;
    pageSize = 10;
    isFirstPage;
    isLastPage;
    totalResults = 0;
    // Error
    @track error;
    // Table and filter options
    @track columns;
    @api searchValue = "";
    @api searchType = "begins";
    @api searchByNumber = false;
    @api filterRecordType = "all";
    @api filterStatus = "all";
    @api filterEntityType = "all";
    recordLimit = 300;
    // Labels
    labels = Labels;

    // Set columns for the datatable
    setColumns() {
        this.columns = [
            ...(this.isNotificationsContext
                ? [{ label: "Name", fieldName: "businessName", type: "text", cellAttributes: { alignment: "left" } }]
                : [
                      {
                          label: "Name",
                          type: "customNameButton",
                          typeAttributes: {
                              label: { fieldName: "businessName" },
                              recordId: { fieldName: "recordId" },
                              fileNumber: { fieldName: "fileNumber" },
                              sourceObject: { fieldName: "sourceObject" }
                          },
                          initialWidth: 450
                      }
                  ]),
            ...(this.includeRecordType ? [{ label: this.labels.recordType, fieldName: "recordType", type: "text" }] : []),
            ...(this.includeNotificationsFields
                ? [{ label: this.labels.BREG_Column_Type, fieldName: "type", type: "text" }]
                : [{ label: this.labels.fileNumber, fieldName: "fileNumber", type: "text" }]),
            ...(this.includeNotificationsFields
                ? [
                      {
                          label: this.labels.BREG_Expires,
                          fieldName: "expirationDate",
                          type: "date",
                          typeAttributes: {
                              year: "numeric",
                              month: "short",
                              day: "numeric",
                              timeZone: "UTC"
                          }
                      }
                  ]
                : [{ label: this.labels.status, fieldName: "status", type: "text" }]),
            ...(this.includeNotificationsFields
                ? [
                      {
                          type: "button",
                          label: this.labels.BREG_Details,
                          typeAttributes: {
                              label: this.labels.BREG_View,
                              name: "viewDetails",
                              title: this.labels.BREG_View_Details,
                              variant: "base"
                          }
                      }
                  ]
                : []),
            ...(this.includeNotificationsFields
                ? [
                      {
                          type: "button",
                          fieldName: "actionLabel",
                          label: this.labels.BREG_Action,
                          typeAttributes: {
                              label: { fieldName: "actionLabel" },
                              name: "selectRow",
                              title: this.labels.BREG_Select_Row,
                              variant: "base",
                              disabled: { fieldName: "actionDisabled" }
                          }
                      }
                  ]
                : [])
        ];
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case "viewDetails":
                this.handleViewDetails(row);
                break;
            case "selectRow":
                this.handleSelectRow(row);
                break;
            default:
                console.log("wrong action name");
        }
    }

    handleNameCellOpened(event) {
        const { recordId, fileNumber, sourceObject } = event.detail;
        this.openDetailsComponent(recordId, fileNumber, sourceObject);
    }

    handleViewDetails(row) {
        window.location.href = `/search-and-buy?entityId=${row.recordId}`;
    }

    handleSelectRow(row) {
        if (!this.selectedRecordIds.includes(row.recordId)) {
            this.selectedRecordIds.push(row.recordId);
        }

        this.pagedData = this.pagedData.map((item) => {
            if (item.recordId === row.recordId) {
                return {
                    ...item,
                    actionLabel: this.labels.BREG_Selected,
                    actionDisabled: true
                };
            }
            return item;
        });

        this.dispatchEvent(
            new CustomEvent("selected", {
                detail: {
                    recordIds: this.selectedRecordIds
                }
            })
        );
    }

    openDetailsComponent(recordId, fileNumber, sourceObject) {
        if (this.isAnnualsContext) {
            setPageUrlParams({
                section: "annual-report",
                page: "details",
                fileNumber: fileNumber,
                accountId: recordId,
                year: null
            });
        }
        this.dispatchEvent(
            new CustomEvent("opendetails", {
                detail: {
                    recordId: recordId,
                    sourceObject: sourceObject
                }
            })
        );
    }

    // Wire to get Account object info and set record type options
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    wiredAccountInfo({ error, data }) {
        if (data) {
            this.accountInfo = data;
        } else if (error) {
            this.error = error;
            console.error("Error retrieving object info: ", error);
        }
    }

    // Wire to get status picklist values
    @wire(getPicklistValues, {
        recordTypeId: "$accountInfo.defaultRecordTypeId",
        fieldApiName: STATUS_FIELD
    })
    wiredStatusPicklistValues({ error, data }) {
        if (data) {
            let picklistOptions = data.values;
            this.statusOptions = picklistOptions.filter(item => item.value !== 'New (Y)').map((item) => ({
                label: item.label,
                value: item.value,
                selected: item.value === this.filterStatus
            }));
            this.statusOptions.unshift({
                label: this.labels.all,
                value: "all",
                selected: this.filterStatus === "all"
            });
        } else if (error) {
            this.error = error;
            console.error("Error retrieving picklist values: ", error);
        }
    }

    // Wire to get entity type picklist values
    @wire(getPicklistValues, {
        recordTypeId: "$accountInfo.defaultRecordTypeId",
        fieldApiName: BUSINESS_STRUCTURE_FIELD
    })
    wiredEntityTypePicklistValues({ error, data }) {
        if (data) {
            let entityTypeOptions = data.values;
            this.entityTypeOptions = entityTypeOptions.map((item) => ({
                label: item.label,
                value: item.value,
                selected: item.value === this.filterEntityType
            }));
            this.entityTypeOptions.push({
                label: "Other",
                value: "other",
                selected: this.filterEntityType === "other"
            });
            this.entityTypeOptions.unshift({
                label: this.labels.all,
                value: "all",
                selected: this.filterEntityType === "all"
            });
        } else if (error) {
            this.error = error;
            console.error("Error retrieving picklist values: ", error);
        }
    }

    // Lifecycle hook to initialize options
    async connectedCallback() {
        if (window.location.href.includes("annual")) {
            this.isAnnualsContext = true;
        } else if (window.location.href.includes("notification")) {
            this.isNotificationsContext = true;
        }
        this.setColumns();
        this.initializeOptions();
    }

    // Initialize dropdown options with labels
    initializeOptions() {
        this.recordTypeOptions = [
            { label: this.labels.all, value: "all", selected: this._filterRecordType === "all" },
            { label: this.labels.recordTypeEntity, value: "Entity", selected: this._filterRecordType === "Entity" },
            // { label: this.labels.recordTypeReservation, value: "Reservation", selected: this._filterRecordType === "Reservation" },
            {
                label: this.labels.recordTypePublicityRightsName,
                value: "Publicity Rights Name",
                selected: this._filterRecordType === "Publicity Rights Name"
            },
            { label: this.labels.recordTypeTradeName, value: "Trade Name", selected: this._filterRecordType === "Trade Name" },
            { label: this.labels.recordTypeTrademark, value: "Trademark", selected: this._filterRecordType === "Trademark" },
            { label: this.labels.recordTypeServiceMark, value: "Service Mark", selected: this._filterRecordType === "Service Mark" },
            { label: "Pending Filing", value: "Pending Filing", selected: this._filterRecordType === "Pending Filing" }
        ];

        this.pageSizeOptions = [
            { label: "10", value: "10", selected: true },
            { label: this.labels.all, value: "all", selected: false }
        ];
    }

    // Call Apex to get accounts based on search and filter criteria
    async getSearchResultsApex() {
        try {
            this.showSpinner = true;
            this.error = undefined;

            const searchInputs = {
                searchType: this.searchType,
                searchInputValue: this.searchValue,
                recordType: this.filterRecordType,
                status: this.filterStatus,
                entityType: this.filterEntityType,
                searchByNumber: this.searchByNumber,
                includeTnTmSm: this.includeTnTmSm,
                includeTransactions: this.includeTransactions,
                excludeAccounts: this.excludeAccounts,
                isOnlyTnTmSmType: this.isOnlyTnTmSmType,
                queryLimit: this.recordLimit,
                includeNotifications: this.includeNotificationsFields,
                notificationCategory: this.notificationCategory
            };

            this.data = await getSearchResults({ searchInputs: searchInputs });
            this.data = this.data.map((row) => {
                const isAvailable = row.notificationsAvailable;

                return {
                    ...row,
                    actionLabel: isAvailable ? this.labels.BREG_Select : "Unavailable",
                    actionDisabled: !isAvailable
                };
            });
            //console.log("Search results: ", JSON.stringify(this.data));
            if (this.data.length > 0) {
                this.totalResults = this.data[0].totalResults;
            }

            this.currentPage = 1;
            this.totalPages = Math.ceil(this.data.length / this.pageSize) || 1;
            this.updatePagedData();
        } catch (error) {
            this.error = error;
            console.error("Error loading accounts:", error);
            this.currentPage = 1;
            this.totalPages = 0;
            this.data = [];
            this.pagedData = [];
        } finally {
            this.showSpinner = false;
        }
    }

    // Handlers for filter input changes
    handleFilterRecordTypeChange(event) {
        this.filterRecordType = event.target.value;
    }

    handleFilterStatusChange(event) {
        this.filterStatus = event.target.value;
    }

    handleFilterEntityTypeChange(event) {
        this.filterEntityType = event.target.value;
    }

    // Apply filters and refresh data
    async handleApplyFilters() {
        this.showSpinner = true;
        // Notify parent of all current filter values when filters are applied
        this.dispatchEvent(
            new CustomEvent("filtersapplied", {
                detail: {
                    filters: {
                        recordType: this.filterRecordType,
                        status: this.filterStatus,
                        entityType: this.filterEntityType
                    }
                }
            })
        );
        await this.getSearchResultsApex();
        this.updatePagedData();
        this.showSpinner = false;
    }

    // Handle search button click
    @api
    async handleSearchClick(searchValue, searchType) {
        this.searchType = searchType;
        this.searchValue = searchValue;
        if (!this.searchValue) {
            return;
        }
        this.showSpinner = true;
        await this.getSearchResultsApex();
        this.showSearchResults = true;
        this.updatePagedData();
        this.showSpinner = false;
    }

    // Update the paged data for the current page
    updatePagedData() {
        if (this.pageSize >= this.data.length) {
            // Show all items when page size is greater than or equal to total data
            this.pagedData = this.data;
        } else {
            // Normal pagination
            const start = (this.currentPage - 1) * this.pageSize;
            const end = start + this.pageSize;
            this.pagedData = this.data.slice(start, end);
        }
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

    // Reset search and filters
    handleNewSearch() {
        //TODO
        this.dispatchEvent(new CustomEvent("newsearch"));
        this.showSearchResults = false;
        this.searchValue = "";
        this.searchType = "begins";
        // Note: Filter values are controlled by parent component and will be reset via @api properties
        this.pageSize = 10;
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

        if (selectedValue === "all") {
            this.pageSize = this.data.length; // Set page size to total data length
        } else {
            this.pageSize = parseInt(selectedValue, 10);
        }

        this.totalPages = Math.ceil(this.data.length / this.pageSize) || 1;
        this.currentPage = 1;
        this.updatePagedData();
        await this.delay(50);
    }

    // Utility delay function
    delay(time) {
        return new Promise((resolve) => setTimeout(resolve, time));
    }

    // Error state getter
    get hasError() {
        return this.error !== undefined;
    }

    // Error message getter
    get errorMessage() {
        return this.error ? (this.error.body ? this.error.body.message : this.error.message) : "";
    }

    // Get the display range for pagination (e.g., 1-10 of 53 items)
    get displayRange() {
        const total = this.data.length;
        if (total === 0) {
            return "";
        }
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, total);
        return `${start}-${end} of ${total} items`;
    }

    // Check if results have reached the limit and should show warning message
    get showLimitWarning() {
        return this.data.length >= this.recordLimit;
    }

    // Get the limit warning message
    get limitWarningMessage() {
        return this.labels.limitWarningMessage.replace("{0}", this.recordLimit).replace("{1}", this.totalResults);
    }
}