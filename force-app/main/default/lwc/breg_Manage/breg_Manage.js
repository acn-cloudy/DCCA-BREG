import { LightningElement, wire } from "lwc";
import { subscribe, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_SECTION_CHANGE } from "c/breg_constants";
import SECTION_CHANGE_MESSAGE from "@salesforce/messageChannel/breg_MessageChannel__c";
import * as LABELS from "./labels";
import { getPageParamsFromUrl, navigateToPage } from "c/utils";
import getUserInfo from "@salesforce/apex/BREGPortalUtils.getUserInfo";

const CRA_FORM_SUFFIX = 'X-11';

export default class Breg_Manage extends LightningElement {
    section;
    isManagePage = true;
    isAnnualReportPage = false;
    isChangesPage = false;
    isCommercialAgentPage = false;
    isNotificationsPage = false;
    isTradenamePage = false;
    formConfigId;
    isNotGuest;
    category;

    sectionHeader = LABELS.Manage_a_Business;
    showSectionHeader = true;
    activeTab = "";
    // Cart State
    cartItemsCount = 0;
    cartItemsTotalPrice = 0;
    page;
    fileNumber;
    filingYear;
    get cartTabLabel() {
        return this.cartItemsCount + " ($" + this.cartItemsTotalPrice + ")";
    }
    // Local storage key for cart items (must match cart component)
    CART_STORAGE_KEY = "breg_shopping_cart";

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

    addDocumentToCart(event) {
        const cartComponent = this.template.querySelector("c-breg-_-shopping-_-cart");
        if (cartComponent) {
            cartComponent.refreshCart();
        }

        this.updateCartCountFromStorage();
    }

    handleGoToCart() {
        this.changeTab("cart");
    }

    saveCartToStorage(CART_STORAGE_KEY, cartItems) {
        try {
            localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(cartItems));
        } catch (error) {
            console.error("Error saving cart to localStorage:", error);
        }
    }

    connectedCallback() {
        this.fetchUserInfo();
        window.addEventListener("popstate", this.handlePopstate());
        this.subscribeToMessageChannel();
        this.updateCartCountFromStorage();
        const { page, fileNumber, year, formConfigId, category } = getPageParamsFromUrl();
        this.page = page;
        this.fileNumber = fileNumber;
        this.filingYear = year;
        this.formConfigId = formConfigId;
        this.category = category;
        this.updateSectionFromUrl();
    }

    async fetchUserInfo() {
        try {
            const result = await getUserInfo();
            this.isNotGuest = !result.isGuest;
        } catch (error) {
            console.error("Error fetching user info", error);
        }
    }

    @wire(MessageContext)
    messageContext;

    subscribeToMessageChannel() {
        subscribe(this.messageContext, SECTION_CHANGE_MESSAGE, (message) => {
            this.handleMessage(message);
        });
    }
    handleMessage(message) {
        let section = message.section;
        let page = message.page;
        this.changeTab("main");
        if (message.type === MESSAGE_TYPE_SECTION_CHANGE && page === "manage") {
            this.section = section;
            const newUrl = `/manage?section=${section}`;
            window.history.pushState({}, "", newUrl);
            this.loadSection(this.section);
        }
    }

    handlePopstate() {
        if (this.section === "annual-report") {
            this.template.querySelector("c-breg-_-annual-reports").getParamsFromUrl();
        }
    }

    handleSectionChange(payload) {
        this.section = payload.section;
        this.loadSection(payload.section);
    }

    handleSectionClick(event) {
        const cardId = event.target.dataset.id;
        // if (cardId !== "dashboard" && cardId !== "tradename") {
        this.loadSection(cardId);
        // }
    }

    updateSectionFromUrl() {
        const params = new URLSearchParams(window.location.search);
        this.section = params.get("section") || "manage";
        this.activeTab = params.get("tab") || "main";
        if (this.section === "help") {
            this.activeTab = "help";
        }
        if (this.activeTab === "main") {
            this.loadSection(this.section);
        }
    }

    changeTabToHelp() {
        this.activeTab = "help";
    }
    handleContinueShopping(event) {
        event.preventDefault();
        this.changeTab("main");
    }
    changeTab(tabValue) {
        this.activeTab = tabValue;
        const tabset = this.template.querySelector("lightning-tabset");
        if (tabset) {
            tabset.activeTabValue = tabValue;
        }
    }

    loadSection(section) {
        this.isManagePage = false;
        this.isAnnualReportPage = false;
        this.isChangesPage = false;
        this.isCommercialAgentPage = false;
        this.isNotificationsPage = false;
        this.isTradenamePage = false;
        this.showSectionHeader = true;

        switch (section) {
            case "dashboard":
                window.location.href = `/my-dashboard`;
                break;
            case "manage":
                this.isManagePage = true;
                this.sectionHeader = LABELS.Manage_a_Business;
                break;
            case "annual-report":
                this.isAnnualReportPage = true;
                this.sectionHeader = LABELS.Find_your_business;
                break;
            case "change":
                this.isChangesPage = true;
                this.showSectionHeader = false;
                break;
            case "commercial_agent":
                this.isCommercialAgentPage = true;
                this.sectionHeader = LABELS.Business_Filing;
                navigateToPage('/manage', {
                    section: 'change',
                    formSuffix: CRA_FORM_SUFFIX,
                });
                break;
            case "notifications":
                this.isNotificationsPage = true;
                this.sectionHeader = LABELS.My_Business_Notifications;
                break;
            case "tradename":
                this.isTradenamePage = true;
                this.sectionHeader = LABELS.Trade_Names_Marks_Publicity_Rights;
                break;
            default:
                this.isManagePage = true;
                this.sectionHeader = LABELS.Manage_a_Business;
        }
        // if (section !== "manage" && section !== "change" && !window.location.pathname.includes("section")) {
        //     const params = new URLSearchParams();
        //     params.set("section", section);
        //     if (this.page && this.fileNumber) {
        //         params.set("page", this.page);
        //         params.set("file-number", this.fileNumber);
        //         if (this.filingYear) params.set("year", this.filingYear);
        //     }
        //     if (this.page && this.category) {
        //         params.set("page", this.page);
        //         params.set("category", this.category);
        //     }

        //     const newUrl = `/manage?${params.toString()}`;
        //     window.history.pushState({}, "", newUrl);
        // }
    }

    cards = [
        {
            id: "dashboard",
            icon: "utility:apps",
            title: LABELS.My_Dashboard,
            description: LABELS.Dashboard_Help_Text,
            buttonLabel: LABELS.View_My_Dashboard
        },
        {
            id: "annual-report",
            icon: "utility:file",
            title: LABELS.Annual_Report,
            description: LABELS.File_Annual_Report,
            buttonLabel: LABELS.Start_Annual_Report_Filing
        },
        {
            id: "change",
            icon: "utility:settings",
            title: LABELS.Changes,
            description: LABELS.Request_Changes,
            linkLabel: LABELS.Change_Examples,
            linkUrl: "/change-examples",
            buttonLabel: LABELS.Start_Change_Request
        },
        {
            id: "tradename",
            icon: "utility:pin",
            title: LABELS.Trade_Names_Marks_Publicity_Rights,
            description: LABELS.Register_renew_assign,
            buttonLabel: LABELS.Manage_TN_TM_SM_PR
        },
        {
            id: "notifications",
            icon: "utility:notification",
            title: LABELS.Notifications,
            description: LABELS.Sign_up_for_reminders,
            buttonLabel: LABELS.Manage_Notifications
        },
        {
            id: "commercial_agent",
            icon: "utility:user_role",
            title: LABELS.Commercial_Registered_Agent,
            description: LABELS.Register_as_agent,
            linkLabel: LABELS.Learn_More,
            linkUrl: "/learn-more",
            buttonLabel: LABELS.Register_as_CRA
        }
    ];
}