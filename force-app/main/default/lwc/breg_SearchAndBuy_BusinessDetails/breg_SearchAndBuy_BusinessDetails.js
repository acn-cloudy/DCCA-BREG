import { LightningElement, api, wire, track } from "lwc";
import { Labels } from "./labels";
import getBusinessDetailsWrapper from "@salesforce/apex/BREGBusinessDetailsController.getBusinessDetailsWrapper";
import createRDPMSAdhocRequests from "@salesforce/apex/BREGBusinessDetailsController.createRDPMSAdhocRequests";

import { getPicklistValues, getObjectInfo } from "lightning/uiObjectInfoApi";
import BREG_TN_TM_SM_OBJECT from "@salesforce/schema/breg_TN_TM_SM__c";
import BREG_STATUS_FIELD from "@salesforce/schema/breg_TN_TM_SM__c.breg_Status__c";
import {
    annualFilingColumns,
    otherFilingColumns,
    accountAffiliationColumns,
    stockColumns,
    tnTmSmColumns,
    buyAvailableDocsColumns
} from "./datatableConfigs";

import { formatCurrency } from "c/utils";

export default class Breg_SearchAndBuy_BusinessDetails extends LightningElement {
    labels = Labels;

    @api recordId; // Account or breg_TN_TM_SM__c record ID passed from parent
    @api activeTab;
    @api showOnlyAvailableDocumentsTab = false;
    @api showOnlyFormsTab = false;
    @track statusValueToLabelMap = {};

    get showHeader() {
        return !this.showOnlyAvailableDocumentsTab && !this.showOnlyFormsTab;
    }

    get showCompanyInformationTab() {
        return !this.showOnlyAvailableDocumentsTab && !this.showOnlyFormsTab;
    }

    get showFormsTab() {
        return this.showOnlyFormsTab || !this.showOnlyAvailableDocumentsTab;
    }

    get showAvailableDocumentsTab() {
        return this.showOnlyAvailableDocumentsTab || !this.showOnlyFormsTab;
    }

    get isInternalContextForFormsTab() {
        return this.showOnlyFormsTab;
    }

    get isInternalContextForAvailableDocumentsTab() {
        return this.showOnlyAvailableDocumentsTab;
    }

    // Loading state
    isLoading = true;

    // Data properties from controller wrapper
    companyInfoFields = [];
    annualFilingData = [];
    otherFilingData = [];
    accountAffiliationData = [];
    stockData = [];
    tnTmSmData = [];
    buyAvailableDocsData = [];
    formConfigurationsData = [];

    // Object type to determine what to display
    isAccountObject = false;
    isTnTmSmObject = false;
    isInGoodStanding = false;
    goodStandingMessage = "";

    // Entity name for header
    entityName = "";
    entityTypeLabel = "";
    entityTypeValue = "";

    // Imported column configurations
    annualFilingColumns = annualFilingColumns;
    otherFilingColumns = otherFilingColumns;
    accountAffiliationColumns = accountAffiliationColumns;
    stockColumns = stockColumns;
    tnTmSmColumns = tnTmSmColumns;
    buyAvailableDocsColumns = buyAvailableDocsColumns;

    trntmsmDefaultRecordTypeId;

    // Wire to get object info for record type
    @wire(getObjectInfo, { objectApiName: BREG_TN_TM_SM_OBJECT })
    objectInfo({ data }) {
        if (data) {
            this.trntmsmDefaultRecordTypeId = data.defaultRecordTypeId;
        }
    }

    // Wire to get picklist values for status
    @wire(getPicklistValues, { recordTypeId: "$trntmsmDefaultRecordTypeId", fieldApiName: BREG_STATUS_FIELD })
    statusPicklistValues({ data }) {
        if (data) {
            this.statusValueToLabelMap = data.values.reduce((map, item) => {
                map[item.value] = item.label;
                return map;
            }, {});
        }
    }

    // Wire method to get business details
    @wire(getBusinessDetailsWrapper, { entityId: "$recordId" })
    wiredBusinessDetails({ error, data }) {
        if (data) {
            this.isLoading = false;
            // Extract data from wrapper
            this.companyInfoFields = data.companyInfo?.fields || [];
            this.annualFilingData = data.companyInfo?.annualFilingData || [];
            this.formConfigurationsData = data.formConfigurationsData || [];
            // Transform account affiliation data to replace semicolons with forward slashes
            this.accountAffiliationData = (data.companyInfo?.accountAffiliationData || []).map((record) => ({
                ...record,
                breg_Officer_Director_Titles__c: record.breg_Officer_Director_Titles__c ? record.breg_Officer_Director_Titles__c.replace(/;/g, " / ") : ""
            }));

            this.otherFilingData = data.companyInfo?.otherFilingData || [];
            this.stockData = data.companyInfo?.stockData || [];
            this.tnTmSmData = (data.companyInfo?.tnTmSmData || []).map((record) => ({
                ...record,
                breg_TM_SM_Category__c:
                    !record.breg_TM_SM_Category__c || record.breg_Type__c === "Trade Name"
                        ? this.labels.noCategorySelected
                        : record.breg_TM_SM_Category__c,
                nameUrl: `/search-and-buy?entityId=${record.Id}`,
                breg_Status__c: this.statusValueToLabelMap[record.breg_Status__c] || record.breg_Status__c
            }));

            this.buyAvailableDocsData = (data.buyAvailableDocsData || []).map((record) => ({
                ...record,
                id: this.recordId + "_" + record.id,
                purchase:
                    record.availability == 'Available Now' || record.availability == 'Available by Mail or Pickup' ? formatCurrency(record.purchasePrice) : '❌ Contact BREG'
            }));

            // Determine entity type based on backend response
            this.isAccountObject = data.objectType === "Account";
            this.isTnTmSmObject = data.objectType === "breg_TN_TM_SM__c";

            // Set entity name, type label, and value from backend
            this.entityName = data.entityName || "";
            this.entityTypeLabel = data.entityTypeLabel || "";
            this.entityTypeValue = data.entityTypeValue || "";
            this.isInGoodStanding = data.isInGoodStanding || false;
            this.goodStandingMessage = data.goodStandingMessage || "";

            createRDPMSAdhocRequests({ recordId: this.recordId })
                .then(() => {
                })
                .catch((error) => {
                    console.error("Error creating RDPMS Adhoc Requests:", error);
                });
        } else if (error) {
            this.isLoading = false;
            console.error("Error fetching business details:", error);
            // Emit custom event to parent component when entity is not found
            const entityNotFoundEvent = new CustomEvent("entitynotfound", {
                detail: {
                    entityId: this.recordId,
                    error: error
                }
            });
            this.dispatchEvent(entityNotFoundEvent);
        }
    }

    renderedCallback() {
        let tabset = this.template.querySelector("lightning-tabset");

        if (!tabset) {
            return;
        }

        tabset.classList.add("custom-tabset-style");

        let style = document.createElement("style");
        style.innerText = `
             .custom-tabset-style .slds-tabs_default__link {
                  font-size: 11.75pt;
             }
        `;

        tabset.appendChild(style);

        // Navigate to the active tab when content is rendered
        if (this.activeTab) {
            this.navigateToTab(this.activeTab);
        }
    }

    // Navigate to tab
    navigateToTab(tabName) {
        const tabset = this.template.querySelector("lightning-tabset");
        if (tabset) {
            tabset.activeTabValue = tabName;
        }
    }

    // Getter for entity name in header
    get displayName() {
        return this.entityName || "";
    }

    // Getter for entity type label in header
    get displayEntityType() {
        return this.entityTypeLabel || "";
    }

    // Handle back to search results
    handleBackToSearch() {
        // Dispatch custom event to parent component
        const backEvent = new CustomEvent("backtosearch");
        this.dispatchEvent(backEvent);
    }
}