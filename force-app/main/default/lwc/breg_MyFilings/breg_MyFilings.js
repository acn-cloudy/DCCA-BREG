import { LightningElement, api, track, wire } from "lwc";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import LightningConfirm from "lightning/confirm";
import BregModalPopup from "c/breg_ModalPopup";
import BREG_Empty_Filtered_List_Message from "@salesforce/label/c.BREG_Empty_Filtered_List_Message";
import { navigateToPage } from "c/utils";

import CASE_OBJECT from "@salesforce/schema/Case";
import STATUS_FIELD from "@salesforce/schema/Case.Status";

import FORM_CONFIG_OBJECT from "@salesforce/schema/breg_Form_Configuration__c";
import getFormTypeOptions from "@salesforce/apex/BREGUtils.getFormTypeOptions";
import getExpediteFee from "@salesforce/apex/BREGCaseController.getExpediteFee";
import getFormConfiguration from "@salesforce/apex/BREGPortalUtils.getFormConfiguration";
import isExpeditedProcessingDisabled from "@salesforce/apex/BREGPaymentController.isExpeditedProcessingDisabled";

import { Labels } from "./labels";

export default class Breg_MyFilings extends LightningElement {
    CART_STORAGE_KEY = "breg_shopping_cart";

    labels = Labels;

    @api allFilingsCount = 0;
    @track stageOptions;
    @track typeOptions;
    nameFilterValue = "";
    numberFilterValue = "";
    @api selectedStage = "all";
    selectedType = "all";
    typeSearchValue = "";
    isTypeDropdownOpen = false;
    closeTypeDropdownTimeout;

    @track recordTypeIdCase;
    @track recordTypeIdForm;
    sortedBy = 'lastUpdated';
    sortDirection = 'desc';
    @track showExpeditedDisabledModal = false;

    _data;
    @api
    get data() {
        return this._data;
    }
    set data(value) {
        this._data = JSON.parse(JSON.stringify(value));
        this._data.forEach((item) => {
            let rowActions = [];
            if (item.status !== "Withdrawn") {
                if (item.allowedForView) {
                    rowActions.push({ label: "View", name: "view" });
                }
                if (item.allowedForContinuation) {
                    rowActions.push({ label: "Continue", name: "continue" });
                }
                if (item.allowedForWithdrawal) {
                    rowActions.push({ label: "Stop Processing", name: "withdraw" });
                }
                if (item.allowedForExpedition) {
                    rowActions.push({ label: "Expedite", name: "expedite" });
                }
                if (item.allowedForResubmission) {
                    rowActions.push({ label: "Re-submit", name: "resubmit" });
                }
                if (item.allowedForReopening) {
                    rowActions.push({ label: "Re-open", name: "reopen" });
                }
                if (item.allowedForRemoval) {
                    rowActions.push({ label: "Remove", name: "remove" });
                }
            }
            if(item.status?.toLowerCase() === 'new') {
                item.status = 'Draft';
            }
            item.rowActions = rowActions;
        });
    }

    emptyListLabel = BREG_Empty_Filtered_List_Message;
    get isFilingsExists() {
        return this.allFilingsCount > 0;
    }
    get isFilteredEmpty() {
        return this.allFilingsCount > 0 && this._data?.length === 0;
    }

    get columns() {
        if (this.isFilingsExists) {
            return [
                { label: "Name", fieldName: "name", sortable: true, wrapText: true },
                { label: "Status", fieldName: "status", sortable: true, wrapText: true },
                { label: "Work Item ID", fieldName: "workItemNumber", sortable: true, wrapText: true },
                { label: "Form Type", fieldName: "formType", sortable: true, wrapText: true },
                { label: "Received Date", fieldName: "lastUpdated", type: "date", sortable: true },
                { label: "Resubmission Due Date", fieldName: "resubmissionDueDate", type: "date", 
                    typeAttributes: {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                        timeZone: 'UTC'
                    }, 
                    sortable: true 
                },
                {
                    type: "action",
                    typeAttributes: {
                        rowActions: {
                            fieldName: "rowActions"
                        }
                    }
                }
            ];
        }
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    caseMetadata({ data }) {
        if (data) {
            this.recordTypeIdCase = data.defaultRecordTypeId;
        }
    }

    @wire(getObjectInfo, { objectApiName: FORM_CONFIG_OBJECT })
    formConfigMetadata({ data }) {
        if (data) {
            this.recordTypeIdForm = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: "$recordTypeIdCase",
        fieldApiName: STATUS_FIELD
    })
    statusValues({ data }) {
        if (data) {
            let hasDraftStatus = false;
        
            // Map data and transform "New" to "Draft" on the fly
            const dynamicOptions = data.values.map((val) => {
                const isNew = val.value?.toLowerCase() === 'new' || val.label?.toLowerCase() === 'new';
        
                // If it's "New", rename it to "Draft"
                if (isNew) {
                    hasDraftStatus = true;
                    return { label: 'Draft', value: 'New' };
                }
        
                return {
                    label: val.label,
                    value: val.value
                };
            });
        
            // Construct final array
            this.stageOptions = [
                { label: `All (${this.allFilingsCount})`, value: "all" },
                // Only add a fresh "Draft" if "New" wasn't found
                ...(hasDraftStatus ? [] : [{ label: 'Draft', value: 'New' }]),
                ...dynamicOptions
            ];
        }
    }

    @wire(getFormTypeOptions)
    wiredFormTypes({ data, error }) {
        if (data) {
            this.typeOptions = data;
            this.syncTypeSearchValueFromSelection();
        } else if (error) {
            console.error("Error loading form types:", error);
        }
    }

    get filteredTypeOptions() {
        const options = this.typeOptions || [];
        const searchTerm = (this.typeSearchValue || "").trim().toLowerCase();

        if (!searchTerm) {
            return options;
        }

        return options.filter((option) => (option.label || "").toLowerCase().includes(searchTerm));
    }

    get isFilteredTypeOptionsEmpty() {
        return this.filteredTypeOptions.length === 0;
    }

    handleTypeSearchInput(event) {
        this.typeSearchValue = event.target.value;
        this.isTypeDropdownOpen = true;
    }

    handleTypeInputFocus() {
        clearTimeout(this.closeTypeDropdownTimeout);
        if (this.selectedType === "all") {
            // Keep the selected value as "all", but clear text to show placeholder and full list while searching.
            this.typeSearchValue = "";
        }
        this.isTypeDropdownOpen = true;
    }

    handleTypeInputBlur() {
        this.closeTypeDropdownTimeout = setTimeout(() => {
            this.isTypeDropdownOpen = false;
            this.syncTypeSearchValueFromSelection();
        }, 150);
    }

    handleTypeOptionMouseDown(event) {
        event.preventDefault();

        const { value, label } = event.currentTarget.dataset;
        this.selectedType = value;
        this.typeSearchValue = label;
        this.isTypeDropdownOpen = false;
        clearTimeout(this.closeTypeDropdownTimeout);
    }

    syncTypeSearchValueFromSelection() {
        const selectedOption = (this.typeOptions || []).find((option) => option.value === this.selectedType);
        this.typeSearchValue = selectedOption ? selectedOption.label : "";
    }

    handleExpeditedDisabledModalClose() {
        this.showExpeditedDisabledModal = false;
    }

    async handleAction(event) {
        const { action, row } = event.detail;

        const params = {
            formAction: action.name,
            caseId: row.recordId
        };
        
        if (row.formCategory === 'Annual') {
            params.section = 'annual-report';
            params.page = 'verify';
            params.fileNumber = row.fileNumber;
            params.annualId = row.annualId;
            params.year = row.annualReportFilingYear;
        } else if (row.formCategory === 'Change') {
            params.section = 'change';
        }

        if (row.tntmsmId) {
            params.tntmsmId = row.tntmsmId;
        }
        if (row.entityId) {
            params.accountId = row.entityId;
        }

        // View
        if (action.name === 'view') {
            window.open(`/payment-confirmation?pid=${row.paymentId}`, '_blank');
        }
        // Continue
        else if (action.name === 'continue') {
            params.shouldSetRecordId = true;
            if (row.formCategory === 'Annual' || row.formCategory === 'Change') {
                navigateToPage('/manage', params);
            } else {
                navigateToPage('/start', params);
            }
        } 
        // Re-submit (updates the rejected Case itself, not a child Case)
        else if (action.name === 'resubmit') {
            params.shouldSetRecordId = true;
            if (row.formCategory === 'Annual' || row.formCategory === 'Change') {
                navigateToPage('/manage', params);
            } else {
                navigateToPage('/start', params);
            }
        } 
        // Re-open
        else if (action.name === 'reopen') {
            params.shouldSetRecordId = true;
            if (row.formCategory === 'Annual' || row.formCategory === 'Change') {
                navigateToPage('/manage', params);
            } else {
                navigateToPage('/start', params);
            }
        } 
        // Remove
        else if (action.name === 'remove') {
            const confirmed = await BregModalPopup.open({
                message: 'Are you sure you want to remove your filing?',
                header: 'Remove Filing',
                cancelLabel: 'Cancel',
                confirmLabel: 'Remove'
            });
            if (confirmed) {
                this.dispatchEvent(new CustomEvent('removefilingrequested', { detail: { recordId: row.recordId } }));
            }
        }
        // Withdraw
        else if (action.name === 'withdraw') {
            if (await this.confirm(this.labels.BREG_Withdrawal_Confirmation)) {
                const nextFormConfig = await getFormConfiguration({ formSuffix: "WD", businessProcess: "Change" });
                if (nextFormConfig) {
                    let params = {
                        parentCaseId: row.recordId,
                        formConfigId: nextFormConfig?.id,
                        section: "change",
                        isRenewal: false
                    };
                    navigateToPage("/manage", params);
                    return;
                }
            }
        } 
        // Expedite
        else if (action.name === 'expedite') {
            const isDisabled = await isExpeditedProcessingDisabled();

            if (isDisabled) {
                this.showExpeditedDisabledModal = true;
                return;
            }

            const fees = await getExpediteFee({ filingId: row.recordId });
            this.addItemsToCart([
                {
                    id: "Expedite Fee - " + row.nameOfTheEntity,
                    companyName: row.nameOfTheEntity,
                    companyUrl: row.entityId ? '/search-and-buy?entityId=' + row.entityId : '#',
                    documentType: "Expedite Fee",
                    documentDate: new Date(),
                    //documentFormatDate: entity.RegistrationNumber,
                    //format: "Digital (PDF)",
                    //formatIcon: "doctype:pdf",
                    quantity: 1,
                    unitPrice: fees && fees.length ? fees[0].breg_Fee_Amount__c : 0,
                    price: fees && fees.length ? fees[0].breg_Fee_Amount__c : 0,
                    certifyPrice: 0,
                    isCertified: false,
                    isQuantityDisabled: true
                }
            ]);
            this.dispatchEvent(
                new CustomEvent("expeditefiling", {
                    detail: {
                        filingId: row.recordId
                    }
                })
            );
        }
    }


    async confirm(message) {
        const result = await LightningConfirm.open({
            message: message,
            variant: "headerless",
            label: "Confirm Action"
            // setting theme would have no effect
        });
        return result;
    }

    handleFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;

        switch (field) {
            case "nameFilter":
                this.nameFilterValue = value;
                break;
            case "numberFilter":
                this.numberFilterValue = value;
                break;
            case "stageFilter":
                this.selectedStage = value;
                break;
            case "typeFilter":
                this.selectedType = value;
                break;
            default:
                console.warn("Unexpected filter field:", field);
        }
    }

    handleApplyFilters() {
        this.dispatchEvent(
            new CustomEvent("filtersapplied", {
                detail: {
                    nameFilterValue: this.nameFilterValue,
                    selectedStage: this.selectedStage,
                    selectedType: this.selectedType,
                    numberFilterValue: this.numberFilterValue
                }
            })
        );
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this._data];

        cloneData.sort((a, b) => {
            let aVal = a[sortedBy];
            let bVal = b[sortedBy];

            // Handle null/undefined values
            if (aVal == null) aVal = '';
            if (bVal == null) bVal = '';

            // Handle date comparisons
            if (sortedBy === 'lastUpdated' || sortedBy === 'resubmissionDueDate') {
                aVal = new Date(aVal).getTime() || 0;
                bVal = new Date(bVal).getTime() || 0;
            }

            // Compare values
            if (aVal < bVal) {
                return sortDirection === 'asc' ? -1 : 1;
            } else if (aVal > bVal) {
                return sortDirection === 'asc' ? 1 : -1;
            }
            return 0;
        });

        this._data = cloneData;
        this.sortedBy = sortedBy;
        this.sortDirection = sortDirection;
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
        } catch (error) {
            console.error("Error adding items to cart:", error);
        }
    }
}