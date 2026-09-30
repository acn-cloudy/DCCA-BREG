import { LightningElement, api } from "lwc";
import { Labels } from "./labels";
import { getPageParamsFromUrl, setPageUrlParams } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import getUserInfo from "@salesforce/apex/BREGPortalUtils.getUserInfo";

export default class Breg_BusinessNotifications extends NavigationMixin(LightningElement) {
    showSearch = false;
    isLogged = false;
    recordId;
    sourceObject;
    selectedItems;
    selectedRecordsIds = [];
    isSelected = false;

    labels = Labels;
    searchValue = "";
    searchType;

    showNewSearch = false;
    showQuartersTabs = false;
    annualQuarterDateStart = "";
    annualQuarterDateFinish = "";
    lateFilingDate = "";
    activeTab;
    showDetails = false;
    accountFileNumber = "";
    filingYear;
    currentStep = 1;
    accountName;
    processingSpeed;
    noChanges = false;
    chosenNotificationPackages;
    chosenCategory = "";
    page;
    category;
    isOnlyTnTmSmType = false;
    excludeAccounts = false;
    includeTnTmSm = true;
    @api emptyNotifications = false;

    @api isDashboardContext = false;
    showUserGuideModal = false;

    async fetchUserInfo() {
        try {
            const result = await getUserInfo();
            this.isLogged = !result.isGuest && !this.emptyNotifications;
        } catch (error) {
            console.error("Error fetching user info", error);
        }
    }

    get isStepOne() {
        return this.currentStep === 1;
    }
    get isStepTwo() {
        return this.currentStep === 2;
    }
    get isStepThree() {
        return this.currentStep === 3;
    }
    get isStepFour() {
        return this.currentStep === 4;
    }

    connectedCallback() {
        this.fetchUserInfo();
        const { page, category, accountId } = getPageParamsFromUrl();
        this.page = page;
        this.category = category ? category : "";
        if (this.category === "tn") {
            this.excludeAccounts = true;
            this.isOnlyTnTmSmType = true;
        } else if (this.category === "business" || this.category === "annual") {
            this.includeTnTmSm = false;
        }
        this.chosenCategory = this.selectCategory(category);

        if (accountId) {
            this.selectedRecordsIds = [accountId];
            this.isSelected = true;
        }

        this.updatePageFromUrl();
    }

    updatePageFromUrl() {
        const params = new URLSearchParams(window.location.search);
        this.page = params.get("page") || "search";

        this.loadPage(this.page);
    }

    loadPage(page) {
        switch (page) {
            case "search":
                this.currentStep = 1;
                this.showSearch = true;
                break;
            case "select":
                this.currentStep = 2;
                break;
            case "send":
                this.currentStep = 3;
                break;
            case "review":
                this.currentStep = 4;
                break;
            case "payment":
                this.currentStep = 5;
                break;
            default:
                this.currentStep = 1;
                this.showSearch = true;
        }
    }

    getParamsFromUrl() {
        const { page, id, object, items, category } = getPageParamsFromUrl();
        this.isSelected = false;
        this.recordId = id;
        this.sourceObject = object;
        this.selectedItems = items;
        this.loadPage(page);
    }

    selectCategory(category) {
        switch (category) {
            case "annual":
                return "Annual Report Reminder";
            case "business":
                return "My Business Alerts";
            case "tn":
                return "Trade Name, Trademark, Service Mark Reminder";
            default:
                return "";
        }
    }

    goToPreviousStep() {
        this.currentStep = this.currentStep - 1;
    }
    goToNextStep() {
        this.currentStep = this.currentStep + 1;
    }

    goToCart(event) {
        this.dispatchEvent(new CustomEvent("addtocart"));
        this.dispatchEvent(new CustomEvent("gotocart"));
    }

    handleSSO() {
        this.isLogged = true; //TODO: add login functionality
    }

    handleSearch(event) {
        this.searchValue = event.detail.searchValue;
        this.searchType = event.detail.searchType;
        this.showSearch = !this.showNewSearch;
        this.template.querySelector("c-breg-_-account-search-results-table").handleSearchClick(this.searchValue, this.searchType);
    }

    handleSearchagain() {
        this.searchValue = "";
        this.getParamsFromUrl();
        this.showSearch = true;
        this.isSelected = false;
    }

    handleGoToSelect() {
        setPageUrlParams({
            section: "notifications",
            page: "select",
            category: this.category
        });
        this.getParamsFromUrl();
    }

    handleSelectedRecords(event) {
        this.isSelected = true;
        this.selectedRecordsIds = event.detail.recordIds;
    }

    handleGoToSend(event) {
        this.chosenNotificationPackages = event.detail.chosenNotifications;
        this.getParamsFromUrl();
    }

    handleOpenUserGuide() {
        this.showUserGuideModal = true;
    }

    handleCloseUserGuide() {
        this.showUserGuideModal = false;
    }
}