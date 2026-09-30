import { LightningElement, api, track } from "lwc";
import { Labels } from "./labels";
//import { setPageUrlParams } from "c/utils";
import getContact from "@salesforce/apex/BREGCheckoutController.getContact";

export default class Breg_DeliveryMethod extends LightningElement {
    @api accountNumber;
    //@api documents = [];

    digitalDocumentsCount = 0;
    printedDocumentsCount = 0;
    printedDocsDeliveryOption = "option1";
    printedDocsDeliveryAddress = {};
    contactData = {};
    disableContinue = false;

    @track options = [];

    cartItems;

    labels = Labels;

    // Local storage key for cart items
    CART_STORAGE_KEY = "breg_shopping_cart";

    get pdfDocumentsCountClause() {
        return this.labels.BREG_Checkout_PDFDocumentsCount.replace("{0}", this.digitalDocumentsCount);
    }

    get printedDocumentsCountClause() {
        return this.labels.BREG_Checkout_PrintedDocumentsCount.replace("{0}", this.printedDocumentsCount);
    }

    get totalPrice() {
        let total = 0;
        this.cartItems.forEach((document) => (total += document.price));
        return total;
    }

    get deliverPrintedDocsToAddress() {
        return this.printedDocsDeliveryOption === "option1";
    }

    get deliverPrintedDocsToDCCA() {
        return this.printedDocsDeliveryOption === "option2";
    }

    get hideEmail() {
        return this.digitalDocumentsCount === 0;
    }

    async connectedCallback() {
        this.options.push(
            { label: this.labels.BREG_Checkout_MailToEnteredEmail, value: "option1" },
            { label: this.labels.BREG_Checkout_PickupAtDCCA, value: "option2" }
        );
        this.cartItems = this.loadCartFromStorage();
        this.cartItems.forEach((item) => {
            if (item.format === "Printed") {
                this.printedDocumentsCount++;
            } else this.digitalDocumentsCount++;
        });
        const contact = await getContact();
        this.contactData = contact || {};
    }

    handleRadioGroupChange(event) {
        this.printedDocsDeliveryOption = event.detail.value;
    }

    handleDeliveryAddressChange(event) {
        const inputName = event.detail.value.inputName;
        const value = event.detail.value.value;
        this.printedDocsDeliveryAddress[inputName] = value;
    }

    async handleContinue() {
        try {
            this.disableContinue = true;
            this.scrollToTop();
            const deliveryDetails = {};
            let validSoFar = true;
            const contactInfoCmp = this.template.querySelector("c-breg_-contact-info");
            validSoFar = contactInfoCmp.checkValidity();
            contactInfoCmp.reportValidity();
            deliveryDetails.contact = contactInfoCmp.getValues();

            if (this.printedDocumentsCount) {
                if (this.deliverPrintedDocsToDCCA) {
                    const phoneInput = this.template.querySelector("lightning-input");
                    validSoFar &&= phoneInput.checkValidity();
                    phoneInput.reportValidity();
                    deliveryDetails.phone = phoneInput.value;
                } else if (this.deliverPrintedDocsToAddress) {
                    const addressCmp = this.template.querySelector("c-breg_-address");
                    validSoFar &&= addressCmp.checkValidity();
                    addressCmp.reportValidity();
                    console.log("printedDocsDeliveryAddress = " + JSON.stringify(this.printedDocsDeliveryAddress));
                    deliveryDetails.deliveryAddress = this.printedDocsDeliveryAddress;
                }
            }
            if (!validSoFar) {
                this.disableContinue = false;
                return;
            }

            this.dispatchEvent(
                new CustomEvent("continue", {
                    detail: {
                        amount: this.totalPrice,
                        cartItemsJson: JSON.stringify(this.cartItems),
                        deliveryDetailsJson: JSON.stringify(deliveryDetails),
                        skipPaymentCreation: false
                    }
                })
            );
        } catch (error) {
            console.error(JSON.stringify(error));
        }
    }

    // Local storage methods
    loadCartFromStorage() {
        try {
            const storedCart = localStorage.getItem(this.CART_STORAGE_KEY);
            if (storedCart && JSON.parse(storedCart) !== "[]") {
                return JSON.parse(storedCart);
            }
        } catch (error) {
            console.error("Error loading cart from localStorage:", error);
        }
        return [];
    }

    scrollToTop() {
        window.scrollTo({ top: 0, behavior: "smooth" });
    }
}