import { LightningElement, track, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { Labels } from "./labels";
import { refreshApex } from "@salesforce/apex";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";
import getNotificationsForCurrentUser from "@salesforce/apex/BREGNotificationsHandler.getNotificationsForCurrentUser";
import getTransactionLineWrappers from "@salesforce/apex/BREGMyDashboardController.getTransactionLineWrappers";
import downloadDocument from "@salesforce/apex/BREGPaymentController.downloadDocument";
import { createDownloadLink, getPageParamsFromUrl } from "c/utils";
import getMyFilings from "@salesforce/apex/BREGCaseController.getMyFilings";
import getMyBusinesses from "@salesforce/apex/BREGMyDashboardController.getMyBusinesses";
import deleteCase from "@salesforce/apex/BREGPortalUtils.deleteCase";

export default class Breg_MyDashboardPage extends LightningElement {
    labels = Labels;
    activeTab = "";
    overdueCount = 0;
    draftsCount = 0;
    pendingCount = 0;
    filingsCount = 0;
    subscriptionsCount = 0;
    communicationsCount = 0;
    activeSubscriptionsCount = 0;
    myBusinessesCount = 0;
    myPurchasesCount = 0;
    cartItemsCount = 0;
    cartItemsTotalPrice = 0;
    transactionLineWrappers = [];
    isLoading = false;
    documentDownloadError = null;

    section;

    @track subscriptions;
    allFilingsCachedData;
    @track allFilings;
    @track myFilings;
    @track myDrafts;
    @track myPendings;
    DRAFT_STATUS = "New";
    PENDING_STATUS = "Pending Submission";
    chosenStatus = "all";
    cardClicked = false;
    selectedCardId = null;
    wiredNotifications;
    get cartTabLabel() {
        return this.cartItemsCount + " ($" + this.cartItemsTotalPrice + ")";
    }
    CART_STORAGE_KEY = "breg_shopping_cart";

    get emptyNotifications() {
        console.log("empty notif?", this.subscriptionsCount === 0);
        return this.subscriptionsCount === 0;
    }

    // Cart management methods
    updateCartCountFromStorage() {
        try {
            const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
            if (storedCart) {
                const cartItems = JSON.parse(storedCart);
                this.cartItemsCount = cartItems.length || 0;
                this.cartItemsTotalPrice = cartItems.reduce((total, item) => total + item.price, 0).toFixed(2);
            } else {
                this.cartItemsCount = 0;
                this.cartItemsTotalPrice = 0;
            }
        } catch (error) {
            console.error("Error reading cart count from localStorage:", error);
            this.cartItemsCount = 0;
        }
    }
    // Cart event handler to update count when cart changes
    handleCartUpdated() {
        this.updateCartCountFromStorage();
    }

    connectedCallback() {
        this.updateCartCountFromStorage();

        const { section } = getPageParamsFromUrl();
        if (section !== undefined) this.section = section;
        if (this.section === "help") {
            this.activeTab = "help";
        }
    }

    @wire(MessageContext)
    messageContext;

    @wire(getMyBusinesses)
    wiredMyBusinesses({ error, data }) {
        if (data) {
            this.myBusinesses = data;
            this.myBusinessesCount = this.myBusinesses.length;
        } else if (error) {
            console.error("Error retrieving my businesses: ", error);
        }
    }

    @wire(getTransactionLineWrappers)
    wiredTransactionLineWrappers({ error, data }) {
        if (data) {
            this.transactionLineWrappers = data;
            this.myPurchasesCount = this.transactionLineWrappers.length;
        } else if (error) {
            console.error("Error retrieving transaction line wrappers: ", error);
        }
    }

    @wire(getMyFilings)
    async wiredFilingsRecord(result) {
        this.allFilingsCachedData = result;
        const { data, error } = result;
        if (data) {
            this.allFilings = data;
            this.myFilings = this.allFilings;
            this.filingsCount = this.allFilings.length;
            this.myDrafts = this.allFilings.filter((item) => item.status === this.DRAFT_STATUS);
            this.draftsCount = this.myDrafts.length;
            this.myPendings = this.allFilings.filter((item) => item.status === this.PENDING_STATUS);
            this.pendingCount = this.myPendings.length;
        } else if (error) {
            this.error = error;
            console.error("Error retrieving record data: ", error);
        }
    }

    handleFilingsReload() {
        refreshApex(this.allFilingsCachedData);
        const { data, error } = this.allFilingsCachedData;
        if (data) {
            this.allFilings = data;
            this.myFilings = this.allFilings;
            this.filingsCount = this.allFilings.length;
            this.myDrafts = this.allFilings.filter((item) => item.status === this.DRAFT_STATUS);
            this.draftsCount = this.myDrafts.length;
            this.myPendings = this.allFilings.filter((item) => item.status === this.PENDING_STATUS);
            this.pendingCount = this.myPendings.length;
        } else if (error) {
            this.error = error;
            console.error("Error retrieving record data: ", error);
        }
    }

    @wire(getNotificationsForCurrentUser)
    wiredNotificationsRecord(result) {
        this.wiredNotifications = result;
        const { data, error } = result;

        if (data) {
            this.subscriptions = data;
            this.activeSubscriptionsCount = data.filter((sub) => sub.status?.toLowerCase() === "active").length;
            this.subscriptionsCount = data.length;
        } else if (error) {
            this.error = error;
            console.error("Error retrieving record data: ", error);
        }
    }

    handleNotificationsUpdate() {
        refreshApex(this.wiredNotifications);
    }

    delay(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    async handleDownloadDocument(event) {
        const documents = event.detail.documents;

        if (!documents || documents.length === 0) {
            this.documentDownloadError = "No documents provided for download";
            return;
        }

        this.isLoading = true;
        try {
            const results = await Promise.all(documents.map((doc) => downloadDocument({ docusignDocumentId: doc.docusignDocumentId })));

            // Process sequentially with an awaitable delay
            for (let i = 0; i < results.length; i++) {
                if (results[i]) {
                    createDownloadLink(results[i], documents[i].description, documents[i].fileType);

                    // Wait 1 second before triggering the next one
                    // This gives the browser time to process the first and prompt the user for permission
                    if (i < results.length - 1) {
                        await this.delay(1000);
                    }
                } else {
                    console.error(`No content received for ${documents[i].description}`);
                }
            }
        } catch (error) {
            console.error("Error downloading document:", error);
            console.error(error.body?.message || error.message);
            this.documentDownloadError = "Error downloading document";
        } finally {
            this.isLoading = false;
        }
    }

    get statusItems() {
        const BASE = "slds-box slds-box_x-small slds-text-align_center counter-gap";
        return [
            {
                id: "overdue",
                label: this.labels.BREG_Overdue_Due_Soon,
                value: this.overdueCount,
                boxClass: (this.selectedCardId === "overdue" ? "clicked" : "clickable") + " " + BASE
            },
            {
                id: "drafts",
                label: this.labels.BREG_Drafts,
                value: this.draftsCount,
                boxClass: (this.selectedCardId === "drafts" ? "clicked" : "clickable") + " " + BASE
            },
            {
                id: "pending",
                label: this.labels.BREG_Pending,
                value: this.pendingCount,
                boxClass: (this.selectedCardId === "pending" ? "clicked" : "clickable") + " " + BASE
            },
            {
                id: "filings",
                label: this.labels.BREG_My_Filings,
                value: this.filingsCount,
                boxClass: (this.selectedCardId === "filings" ? "clicked" : "clickable") + " " + BASE
            },
            {
                id: "subscriptions",
                label: this.labels.BREG_Active_Subscriptions,
                value: this.activeSubscriptionsCount,
                boxClass: (this.selectedCardId === "subscriptions" ? "clicked" : "clickable") + " " + BASE
            }
        ];
    }
    handleCardClick(event) {
        this.selectedCardId = event.currentTarget.dataset.id;
        switch (event.currentTarget.dataset.id) {
            case "overdue":
                this.myFilings = [...this.myFilings];
                this.chosenStatus = "all";
                this.innerTab = "overdue";
                this.setActiveTab(this.innerTab);
                break;
            case "drafts":
                this.myFilings = [...this.myDrafts];
                this.chosenStatus = this.DRAFT_STATUS;
                this.innerTab = "filings";
                this.setActiveTab(this.innerTab);
                break;
            case "pending":
                this.myFilings = [...this.myPendings];
                this.chosenStatus = this.PENDING_STATUS;
                this.innerTab = "filings";
                this.setActiveTab(this.innerTab);
                break;
            case "filings":
                this.myFilings = [...this.allFilings];
                this.chosenStatus = "all";
                this.innerTab = "filings";
                this.setActiveTab(this.innerTab);
                break;
            case "subscriptions":
                this.myFilings = [...this.myFilings];
                this.chosenStatus = "all";
                this.innerTab = "subscriptions";
                this.setActiveTab(this.innerTab);
                break;
            default:
                console.warn("Unexpected id:", event.currentTarget.dataset.id);
        }
    }

    overdueTabLabel = `${this.labels.BREG_Overdue_Due_Soon} ( ${this.overdueCount} )`;

    get myBusinessesTabLabel() {
        return `${this.labels.BREG_My_Businesses} ( ${this.myBusinessesCount} )`;
    }

    get myFilingsTabLabel() {
        return `${this.labels.BREG_My_Filings} ( ${this.filingsCount} )`;
    }

    get myPurchasesTabLabel() {
        return `${this.labels.BREG_My_Purchases} ( ${this.myPurchasesCount} )`;
    }

    get isOverduesExists() {
        return this.overdueCount > 0;
    }

    get isBusinessesExists() {
        return this.myBusinessesCount > 0;
    }

    get isFilingsExists() {
        return this.filingsCount > 0;
    }

    get isMyPurchasesExists() {
        return this.myPurchasesCount > 0;
    }

    get isSubscriptionsExists() {
        return this.subscriptionsCount > 0;
    }
    get isCommunicationsExists() {
        return this.communicationsCount > 0;
    }

    actionButtons = [
        {
            iconName: "utility:company",
            label: this.labels.BREG_Start,
            description: this.labels.BREG_Start_Description,
            action: "start"
        },
        {
            iconName: "utility:approval",
            label: this.labels.BREG_TN_TM_SM,
            description: this.labels.BREG_TN_TM_SM_Description,
            action: "trade"
        },
        {
            iconName: "utility:settings",
            label: this.labels.BREG_Changes,
            description: this.labels.BREG_Changes_Description,
            action: "manage?section=change"
        },
        {
            iconName: "utility:page",
            label: this.labels.BREG_Annual_Report,
            description: this.labels.BREG_Annual_Report_Description,
            action: "manage?section=annual-report"
        }
    ];

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    setActiveTab(tabValue) {
        let tabset = this.template.querySelectorAll("lightning-tabset")[1];
        if (tabset) {
            tabset.activeTabValue = tabValue;
        }
    }

    handleMyFilingsTabClick(event) {
        this.setActiveTab(this.innerTab);
    }

    handleInnerTabChange(event) {
        this.innerTab = event.target.value;
    }

    handleClick(event) {
        const action = event.target.dataset.action;
        window.location.href = `/${action}`;
    }

    handleContinueShopping() {
        this.activeTab = "main";
    }

    async handleRemoveFilingRequested(event) {
        const { recordId } = event.detail;
        this.isLoading = true;
        try {
            await deleteCase({ caseId: recordId });
            this.allFilings = this.allFilings.filter((filing) => filing.recordId !== recordId);
            this.myFilings = this.myFilings.filter((filing) => filing.recordId !== recordId);
            this.filingsCount = this.allFilings.length;
            this.myDrafts = this.allFilings.filter((item) => item.status === this.DRAFT_STATUS);
            this.draftsCount = this.myDrafts.length;
            this.myPendings = this.allFilings.filter((item) => item.status === this.PENDING_STATUS);
            this.pendingCount = this.myPendings.length;
            this.showToast("Success", "Filing removed successfully.", "success");
        } catch (error) {
            this.showToast("Error", error?.body?.message ?? "An error occurred while removing the filing.", "error");
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        publish(this.messageContext, MESSAGE_CHANNEL, {
            type: MESSAGE_TYPE_TOAST,
            title,
            message,
            variant
        });
    }

    handleFilingsFiltersApplied(event) {
        const { nameFilterValue, selectedStage, selectedType, numberFilterValue } = event.detail;

        let filteredFilings = this.allFilings.filter((filing) => {
            const matchesStage = selectedStage === "all" || filing.status === selectedStage;
            const matchesType = selectedType === "all" || filing.formCode === selectedType;
            const matchesName = !nameFilterValue || filing.name?.toLowerCase().includes(nameFilterValue.toLowerCase());
            const matchesNumber = !numberFilterValue || filing.workItemNumber?.toLowerCase().includes(numberFilterValue.toLowerCase());
            return matchesStage && matchesType && matchesName && matchesNumber;
        });
        if (filteredFilings) {
            this.myFilings = [...filteredFilings];
        } else {
            this.myFilings = [];
        }
    }
}