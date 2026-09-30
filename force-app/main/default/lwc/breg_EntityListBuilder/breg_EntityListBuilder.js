import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import upsertList from "@salesforce/apex/BREGEntityListBuilderController.upsertList";
import Breg_ELB_Disclaimer from "c/breg_ELB_Disclaimer";

export default class Breg_EntityListBuilder extends NavigationMixin(LightningElement) {
    currentStep = "0";
    collectedData = {};
    newEntityListId = "";
    error;

    // Local storage key for cart (must match cart component)
    CART_STORAGE_KEY = "breg_shopping_cart";

    get isFirstStep() {
        return this.currentStep === "0";
    }

    get isLastStep() {
        return this.currentStep === "4";
    }

    get previousLabel() {
        return this.isFirstStep ? "Start" : "Previous";
    }

    get nextLabel() {
        var result = "Next";
        if (this.isLastStep) {
            result = "Finish";
        } else if (this.isStep0) {
            result = "Start";
        } else if (this.isStep1) {
            result = "Next";
        } else if (this.isStep2) {
            result = "Next";
        } else if (this.isStep3) {
            result = "Next";
        }
        return result;
    }

    get isStep0() {
        return this.currentStep === "0";
    }
    get isStep1() {
        return this.currentStep === "1";
    }

    get isStep2() {
        return this.currentStep === "2";
    }

    get isStep3() {
        return this.currentStep === "3";
    }

    get isStep4() {
        return this.currentStep === "4";
    }

    async handleNext() {
        var stepCmp = this.refs.stepComponent0;
        if (this.currentStep === "1") {
            stepCmp = this.refs.stepComponent1;
        } else if (this.currentStep === "2") {
            stepCmp = this.refs.stepComponent2;
        } else if (this.currentStep === "3") {
            stepCmp = this.refs.stepComponent3;
        } else if (this.currentStep === "4") {
            stepCmp = this.refs.stepComponent4;
        }
        console.log("Before validate", stepCmp);
        const isValid = stepCmp.validate();

        if (isValid) {
            console.log("Validated Data:", this.collectedData);
            // Proceed to next step or save
        } else {
            console.warn("Step is invalid");
            return;
        }
        if (this.isLastStep) {
            // Final logic here (e.g., submit)
            
            // save the data
            await this.handleSave();            
            // form the cart items
            const cartItems = this.formCartItems();
            // Add items to localStorage cart
            this.addItemsToCart(cartItems);

            console.log("Wizard finished");

            return;
        }
        if (this.isFirstStep) {
            // Show disclaimer modal
            console.log("Opening disclaimer modal");
            const result = await Breg_ELB_Disclaimer.open({
                // `label` is not included here in this example.
                // it is set on lightning-modal-header instead
                size: "small",
                description: "Accessible description of modal's purpose",
                contentMain:
                    "The State of Hawaii makes no guarantee as to the accuracy of the information accessed, the timeliness of delivery of transactions, delivery to the correct party, preservation of the privacy and security of users and makes no warranties, including WARRANTY OF MERCHANTABILITY and fitness for a particular purpose.\r\rUser is advised that if the information obtained herein is to be reasonably relied upon, user should confirm the accuracy of such information with the provider thereof.\r\n\r\nLists are generated from a database that is updated every half-hour.",
                contentBold:
                    "By continuing, you are indicating that you have read and understand the foregoing. It also implies that the user agrees to abide by the foregoing terms and conditions."
            });
            // if modal closed with X button, promise returns result = 'undefined'
            // if modal closed with OK button, promise returns result = 'okay'
            console.log(result);
            if (result === "okay") {
                this.currentStep = String(Number(this.currentStep) + 1);
            }
        } else {
            this.currentStep = String(Number(this.currentStep) + 1);
        }
    }

    // Navigate to the cart page
    navigateToCart() {
        // this[NavigationMixin.Navigate]({
        //     type: "comm__namedPage",
        //     attributes: { name: "BREG_Cart__c" }
        // });
        window.location.href = `/cart`;
    }

    //form cart items
    formCartItems() {
        const entitiesInfo = this.template.querySelector("c-breg_-e-l-b_-search-summary").getEntitiesInfo();
        const cartItems = [
            {
                id: "Entity List Item",
                companyName: entitiesInfo.Name,
                //companyUrl: entity.EntityType,
                documentType: "Entity List",
                documentDate: new Date(),
                //documentFormatDate: entity.RegistrationNumber,
                format: "Digital (CSV)",
                formatIcon: "doctype:csv",
                quantity: entitiesInfo.recordsFound,
                unitPrice: entitiesInfo.pricePerRecord,
                price: entitiesInfo.total,
                certifyPrice: 0,
                isCertified: false,
                isQuantityDisabled: true,
                type: 'Entity List',
                entityListId: this.newEntityListId,
                feeId: entitiesInfo.feeId
            }
        ];
        console.log("Cart items formed:", JSON.stringify(cartItems));
        return cartItems;
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

            // Dispatch event to notify parent components that cart was updated
            this.dispatchEvent(
                new CustomEvent("itemsaddedtocart", {
                    bubbles: true,
                    composed: true,
                    detail: {
                        itemsAdded: itemsToAdd.length,
                        cartTotal: updatedCart.length
                    }
                })
            );
        } catch (error) {
            console.error("Error adding items to cart:", error);
        }
    }

    handlePrevious() {
        if (!this.isFirstStep) {
            this.currentStep = String(Number(this.currentStep) - 1);
        }
    }

    handleStepData(event) {
        this.collectedData = { ...this.collectedData, ...event.detail };
        console.log("handled data:", JSON.stringify(this.collectedData));
    }
    handleReturnToStep(event) {
        this.currentStep = event.detail.stepNum;
        console.log("Returning to step:", this.currentStep);
    }

    async upsertEntityList() {
        try {
            this.newEntityListId = await upsertList({ input: this.collectedData })
            this.error = undefined;
        }
        catch (error) {
            this.error = error;
            this.recordsFound = undefined;
            this.pricePerRecord = undefined;
            this.total = undefined;
        }
    }

    async handleSave() {
        console.log("Saving data:", JSON.stringify(this.collectedData));
        await this.upsertEntityList();
        console.log("Entity List ID:", this.newEntityListId);
        this.navigateToCart();

        // TODO: call Apex to save data
    }

    handleReset() {
        this.collectedData = {};
        this.currentStep = "0";
    }
}