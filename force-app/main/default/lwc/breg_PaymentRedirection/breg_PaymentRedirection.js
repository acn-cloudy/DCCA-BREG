import { LightningElement } from "lwc";

export default class Breg_PaymentRedirection extends LightningElement {
    // Local storage key for cart
    CART_STORAGE_KEY = "breg_shopping_cart";

    connectedCallback() {
        try {
            this.clearCartLocalStorage();
            // Get the payment ID from the URL
            const urlParams = new URLSearchParams(window.location.search);
            const paymentId = urlParams.get("pid");
            // Check if we're running inside an iframe
            if (window.parent && window.parent !== window && paymentId != null) {
                // Redirect the parent page to the payment confirmation page
                window.parent.location.href = "/payment-confirmation?pid=" + paymentId;
            } else {
                window.location.href = "/";
            }
        } catch (error) {
            console.error("Error during payment redirection:", error);
            // Fallback redirection
            window.location.href = "/";
        }
    }

    // Clear cart from local storage
    clearCartLocalStorage() {
        localStorage.removeItem(this.CART_STORAGE_KEY);
    }
}