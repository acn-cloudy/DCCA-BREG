import { LightningElement } from "lwc";
import { getPageParamsFromUrl, setPageUrlParams } from "c/utils";
import getUserInfo from "@salesforce/apex/BREGPortalUtils.getUserInfo";
import createPayment from "@salesforce/apex/BREGPaymentController.createPayment";
import updateCasesProcessingSpeed from "@salesforce/apex/BREGCaseControllerWithoutSharing.updateCasesProcessingSpeed"; 

export default class Breg_CheckoutPage extends LightningElement {
    isLoginPage = false;
    isLoginRedirectionPage = false;
    isPaymentMethodPage = false;
    isCreateContactPage = false;
    isDocumentsDeliveryMethod = false;
    isLoading = false;
    userInfo;
    // Local storage key for cart items
    CART_STORAGE_KEY = "breg_shopping_cart";
    // Form types that require user to be logged in (no guest checkout allowed)
    FORM_TYPES_REQUIRING_LOGIN = [
        "nbr form",
        "tntmsm form",
        "change form",
        "cra registration form",
        "name reservation form"
    ];

    connectedCallback() {
        this.loadCartFromStorage();
        this.getParamsFromUrl();
    }

    async getParamsFromUrl() {
        this.isLoginPage = false;
        this.isLoginRedirectionPage = false;
        this.isPaymentMethodPage = false;
        this.isCreateContactPage = false;
        const { page, id } = getPageParamsFromUrl();
        this.page = page;
        this.userInfo = await this.fetchUserInfo();
        switch (page) {
            case "login":
                if (this.userInfo?.isGuest) {
                    this.isLoginPage = true;
                } else {
                    setPageUrlParams({ page: "checkout" });
                    if (this.anyDeliverableEntitiesInCart()) {
                        this.isDocumentsDeliveryMethod = true;
                    } else
                        this.createPaymentAndNavigate({
                            amount: this.totalPrice,
                            cartItemsJson: JSON.stringify(this.cartItems),
                            deliveryDetailsJson: null,
                            skipPaymentCreation: false
                        });
                }
                break;
            case "checkout":
                if (this.requiresLoginForCheckout()) {
                    this.isLoginRedirectionPage = true;
                } else if (this.anyDeliverableEntitiesInCart()) {
                    this.isDocumentsDeliveryMethod = true;
                } else {
                    this.createPaymentAndNavigate({
                        amount: this.totalPrice,
                        cartItemsJson: JSON.stringify(this.cartItems),
                        deliveryDetailsJson: null,
                        skipPaymentCreation: false
                    });
                }
                break;
            case "payment":
                this.isPaymentMethodPage = true;
                break;
            case "contact":
                this.isCreateContactPage = true;
                break;
            default:
                this.isLoginPage = true;
        }
    }

    /**
     * Check if any cart item requires login (no guest checkout allowed)
     * @returns {boolean} true if cart contains form types requiring login
     */
    requiresLoginForCheckout() {
        if (!this.cartItems || this.cartItems.length === 0) {
            return true;
        }
        if (!this.userInfo?.isGuest) {
            return false;
        }

        return this.cartItems.some((item) => {
            const type = item.type?.toLowerCase();
            return type && this.FORM_TYPES_REQUIRING_LOGIN.includes(type);
        });
    }

    async fetchUserInfo() {
        try {
            return await getUserInfo();
        } catch (error) {
            console.error("Error fetching user info", error);
        }
    }

    // Local storage methods
    loadCartFromStorage() {
        try {
            const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
            if (storedCart && JSON.parse(storedCart) !== "[]") {
                this.cartItems = JSON.parse(storedCart);
            } else {
                this.cartItems = [];
            }
        } catch (error) {
            console.error("Error loading cart from localStorage:", error);
            this.cartItems = [];
        }
    }

    get totalPrice() {
        return this.cartItems && this.cartItems.length > 0 ? this.cartItems.reduce((total, item) => total + item.price, 0) : 0;
    }

    handleContinueAfterDeliveryMethod(event) {
        this.createPaymentAndNavigate(event.detail);
    }

     getCasesWithExpediteSpeed(cartItems) {
        let caseIds = [];
        for (let item of cartItems) {
            if (item.id.startsWith("exp-fee") && item.price > 0) {
                caseIds.push(item.caseId);
            }
        }
        return caseIds;

    }

    async setExpeditedSpeedForCases(caseIds) {
        try {
            await updateCasesProcessingSpeed({ caseIds });
            console.log("Cases updated successfully");
        } catch (error) {
            console.error("Error updating cases:", error);
        }
    }

    //{ amount, cartItemsJson, deliveryDetailsJson }
    async createPaymentAndNavigate(details) {
        this.isLoading = true;
        //console.log("*** details = " + JSON.stringify(details));
        const paymentId = await createPayment(details);

        if (details.amount === 0 && this.cartItems && this.cartItems.length > 0) {
            let caseIdsToExpedite = this.getCasesWithExpediteSpeed(this.cartItems);
            if (caseIdsToExpedite.length > 0) {
                await this.setExpeditedSpeedForCases(caseIdsToExpedite);
            }
            this.clearCartLocalStorage();
            window.parent.location.href = "/payment-confirmation?pid=" + paymentId;
        } else {
            window.location.href = `/payment?pid=${paymentId}`;
        }

        this.isLoading = false;
    }

    // Clear cart from local storage
    clearCartLocalStorage() {
        localStorage.removeItem(this.CART_STORAGE_KEY);
    }

    anyDeliverableEntitiesInCart() {
        return this.cartItems.find((item) => item.format && item.type == "Document" /*["Printed", "Digital (PDF)"].includes(item.format)*/);
    }
}