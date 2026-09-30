import { LightningElement, api, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import Id from "@salesforce/user/Id";
import EMAIL_FIELD from "@salesforce/schema/User.Email";
import ENTITY_NAME_FIELD from "@salesforce/schema/Case.breg_Entity_name__c";
import { getRecord } from "lightning/uiRecordApi";
import getFees from "@salesforce/apex/BREGGetFeeForService.getFees";
import checkIsNBRForm from "@salesforce/apex/BREGRegistrationFormController.isNBRForm";
import getFormCategory from "@salesforce/apex/BREGRegistrationFormController.checkFormCategory";
import isExpeditedProcessingDisabled from "@salesforce/apex/BREGPaymentController.isExpeditedProcessingDisabled";
import { LABELS } from "./labels";

export default class Breg_FormsAndFees extends NavigationMixin(LightningElement) {
    @api caseId;
    @api parentCaseId;
    // Local storage key for cart (must match cart component)
    CART_STORAGE_KEY = "breg_shopping_cart";

    @api companyName;
    @api accountId;
    @api tntmsmId;
    @api entityType;
    @api entityTypeForFees;
    @api registrationType;
    @api companyDateFormedOn;
    @api isGpAndLlpRegistration;
    @api formAction;
    @api formData;
    // Local storage key for cart (must match cart component)
    @track items = [];

    @track _formConfiguration = {};
    businessSuffix;
    formCode;
    formConfigId;
    linkedForm;
    isLoading = true;
    email;

    sendFreeReminder = false;
    showReminderSection = false;
    reminderSectionTitle;
    reminderSectionCheckboxLabel;

    @track showExpeditedDisabledModal = false;

    @api
    get formConfiguration() {
        return this._formConfiguration;
    }
    set formConfiguration(value) {
        this._formConfiguration = value;
        this.businessSuffix = this._formConfiguration?.suffix;
        this.formCode = this._formConfiguration?.formCode;
        this.formName = this._formConfiguration?.formName;
        this.formConfigId = this._formConfiguration?.id;
        this.linkedForm = this._formConfiguration?.linkedForm;
        this.processFormsAndFees();
    }

    get totalPrice() {
        let total = 0;
        this.items
            .filter((item) => item.includePrice)
            .forEach((item) => {
                total += item.price;
            });
        return total;
    }

    get buttonLabel() {
        return "Pay Now";
    }

    get actionLabel() {
        return this.formAction?.toLowerCase() === "resubmit" ? "resubmit" : "submit";
    }

    connectedCallback() {
        console.log("connected forms and fees");
    }

    @wire(getRecord, { recordId: Id, fields: [EMAIL_FIELD] })
    userDetails({ error, data }) {
        if (error) {
            this.error = error;
        } else if (data) {
            if (data.fields.Email.value != null) {
                this.email = data.fields.Email.value;
            }
            this.setReminderSection();
        }
    }

    @wire(getRecord, { recordId: "$caseId", fields: [ENTITY_NAME_FIELD] })
    caseDetails;

    async processFormsAndFees() {
        this.expeditedProcessingDisabled = await isExpeditedProcessingDisabled();
        const formCategory = await getFormCategory({ formCode: this.formCode });
        let fees = await getFees({
            fieldsToSelect: ["breg_Purchase_Type_Fee_type__c", "breg_Fee_Amount__c", "breg_Form_Code__c", "breg_Registration_Type__c", "breg_Entity_Type__c", "breg_Cashier_Code__c", "Id"],
            filters: {
                breg_Form_Configuration__c: this.formConfigId,
                breg_Purchase_Type_Fee_type__c: "Form Fees,Archive Fees,Expedite Fees,Penalty Fees,Certify"
            }
        });
        // TODO: remove after after all fees will be uploaded correctly
        fees = fees.filter((fee) => {
            return fee.breg_Form_Code__c != null;
        });

        if (this.entityTypeForFees) {
            let feesByEntityTypes = {};
            feesByEntityTypes = fees.filter((fee) => {
                return fee.breg_Entity_Type__c === this.entityTypeForFees;
            });
            if (Object.keys(feesByEntityTypes).length > 0) {
                fees = feesByEntityTypes;
            }
        }

        if (this.registrationType) {
            let feesByRegistrationTypes = {};
            feesByRegistrationTypes = fees.filter((fee) => {
                if (this.registrationType === "New") {
                    return fee.breg_Registration_Type__c == undefined;
                }
                return fee.breg_Registration_Type__c === this.registrationType;
            });
            if (Object.keys(feesByRegistrationTypes).length > 0) {
                fees = feesByRegistrationTypes;
            }
        }

        const formFee = fees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Form Fees");
        const archiveFee = fees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Archive Fees");
        const expediteFee = fees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Expedite Fees");
        const penaltyFee = fees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Penalty Fees");
        const certifyFee = fees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Certify");
        const formType = formCategory ? formCategory + " Form" : null;

        const filingItemName = this.formName ? this.formName + " filing with DCCA" : "filing with DCCA";
        this.items = [
            {
                id: 0,
                name: filingItemName,
                price: this.getFeeAmount(formFee),
                includePrice: true,
                type: formType,
                caseId: this.caseId,
                feeId: formFee?.Id,
                certifyFeeId: certifyFee?.Id,
                certifyPrice: certifyFee ? this.getFeeAmount(certifyFee) : 0,
                expeditePrice: expediteFee && !this.isResubmit() ? expediteFee.breg_Fee_Amount__c : 0,
                expediteFeeId: expediteFee?.Id,
                isGpForm: false
            }
        ];
        if (archiveFee) {
            const archiveItemName = this.getItemName("Archive Fee");
            this.items.push({
                id: 1,
                name: archiveItemName /**[<a>Review</a>] */,
                price: this.getFeeAmount(archiveFee),
                includePrice: true,
                type: formType,
                caseId: this.caseId,
                feeId: archiveFee?.Id
            });
        }
        if (penaltyFee) {
            let price = this.getFeeAmount(penaltyFee);
            let monthsOverdue = this.getMonthsOverdue(this.companyDateFormedOn);

            // Multiply penalty fee by months overdue for GP-1 form
            if (this.formCode === "GP-1") {
                price = price * monthsOverdue;
            }

            // Only apply penalty if it's GP-1 form and at least 1 month overdue or if it's other form
            if (this.formCode !== "GP-1" || (this.formCode === "GP-1" && monthsOverdue >= 1)) {
                const penaltyItemName = this.getItemName("Penalty Fee");
                this.items.push({
                    id: 3,
                    name: penaltyItemName,
                    price: this.getFeeAmount(penaltyFee),
                    includePrice: true,
                    type: formType,
                    caseId: this.caseId,
                    feeId: penaltyFee?.Id
                });
            }
        }

        // Add GP fees when LLP-1 and FLLP-1 forms are registered along with GP-1 form
        if (this.isGpFeesIncluded()) {
            let gpFees = await getFees({
                fieldsToSelect: [
                    "breg_Purchase_Type_Fee_type__c",
                    "breg_Fee_Amount__c",
                    "breg_Form_Code__c",
                    "breg_Registration_Type__c",
                    "breg_Entity_Type__c",
                    "Id",
                    "breg_Form_Configuration__r.breg_Form_Name__c"
                ],
                filters: {
                    breg_Form_Configuration__c: this.linkedForm,
                    breg_Purchase_Type_Fee_type__c: "Form Fees,Archive Fees,Expedite Fees,Penalty Fees,Certify"
                }
            });

            const gpFormName = gpFees?.[0]?.breg_Form_Configuration__r?.breg_Form_Name__c;
            const gpFormFee = gpFees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Form Fees");
            this.items.push({
                id: 5,
                name: gpFormName + " filing with DCCA",
                price: this.getFeeAmount(gpFormFee),
                includePrice: true,
                type: formType,
                caseId: this.caseId,
                feeId: gpFormFee?.Id,
                isGpForm: true
            });
            const gpArchiveFee = gpFees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Archive Fees");
            if (gpArchiveFee) {
                this.items.push({
                    id: 6,
                    name: gpFormName + " - Archive Fee" /**[<a>Review</a>] */,
                    price: this.getFeeAmount(gpArchiveFee),
                    includePrice: true,
                    type: formType,
                    caseId: this.caseId,
                    feeId: gpArchiveFee?.Id
                });
            }
            const gpExpediteFee = gpFees.find((fee) => fee.breg_Purchase_Type_Fee_type__c === "Expedite Fees");
            if (gpExpediteFee && !this.isResubmit()) {
                this.items.push({
                    id: 7,
                    name: gpFormName + " - Expedite* Fee",
                    price: gpExpediteFee.breg_Fee_Amount__c,
                    isDeletable: true,
                    includePrice: false,
                    expeditedReviewAction: "Add Expedited Review",
                    hasTooltip: true,
                    showTooltip: false,
                    tooltipText: "More info",
                    tooltipHeader: "Expedited Info",
                    tooltipBody: LABELS.BREG_FormsAndFees_Expedited_Tooltip_Text,
                    caseId: this.caseId,
                    type: formType,
                    feeId: gpExpediteFee?.Id
                });
            }
        }

        if (expediteFee && !this.isResubmit()) {
            const expediteItemName = this.getItemName("Expedite* Fee");
            this.items.push({
                id: 2,
                name: expediteItemName,
                price: expediteFee.breg_Fee_Amount__c,
                isDeletable: true,
                includePrice: false,
                expeditedReviewAction: "Add Expedited Review",
                hasTooltip: true,
                showTooltip: false,
                tooltipText: "More info",
                tooltipHeader: "Expedited Info",
                tooltipBody: LABELS.BREG_FormsAndFees_Expedited_Tooltip_Text,
                caseId: this.caseId,
                type: formType,
                feeId: expediteFee?.Id
            });
        }

        this.isLoading = false;
    }

    getItemName(itemName) {
        if (this.isGpFeesIncluded()) {
            return this.formName + " - " + itemName;
        }
        return itemName;
    }

    isGpFeesIncluded() {
        return (
            ((this.formCode === "LLP-1" || this.formCode === "FLLP-1") && this.isGpAndLlpRegistration) ||
            ((this.formCode === "GP-2" || this.formCode === "GP-4") && this.parentCaseId)
        );
    }

    async setReminderSection() {
        if (!this.formCode) return;

        if (this.formCode === "T-1") {
            this.reminderSectionTitle = LABELS.BREG_Reminder_Trade_Name_Title;
            this.reminderSectionCheckboxLabel = LABELS.BREG_Reminder_Trade_Name_Confirmation_Label;
        } else if (this.formCode === "T-2") {
            this.reminderSectionTitle = LABELS.BREG_Reminder_Trademark_Title;
            this.reminderSectionCheckboxLabel = LABELS.BREG_Reminder_Trademark_Confirmation_Label;
        } else if (this.formCode === "T-3") {
            this.reminderSectionTitle = LABELS.BREG_Reminder_Service_Mark_Title;
            this.reminderSectionCheckboxLabel = LABELS.BREG_Reminder_Service_Mark_Confirmation_Label;
        } else {
            let isNBRForm = await checkIsNBRForm({ formCode: this.formCode });
            if (isNBRForm === true || isNBRForm === "true") {
                this.reminderSectionTitle = LABELS.BREG_Reminder_NBR_Title;
                this.reminderSectionCheckboxLabel = LABELS.BREG_Reminder_NBR_Confirmation_Label;
            }
        }

        if (this.reminderSectionTitle && this.reminderSectionCheckboxLabel && !this.isResubmit()) {
            this.reminderSectionCheckboxLabel = this.reminderSectionCheckboxLabel.replace("{!User.Email}", this.email);
            this.showReminderSection = true;
            this.sendFreeReminder = true;
        }
    }

    isResubmit() {
        return this.formAction?.toLowerCase() === "resubmit";
    }

    getFeeAmount(fee) {
        if (fee == null || this.isResubmit()) {
            return 0;
        } else {
            return fee.breg_Fee_Amount__c;
        }
    }

    get showExpeditedInfo(){
        return !this.isResubmit() && !this.expeditedProcessingDisabled;
    }

    getMonthsOverdue() {
        if (!this.companyDateFormedOn) return 0;

        const formedDate = new Date(this.companyDateFormedOn);
        const currentDate = new Date();
        const diffInTime = currentDate - formedDate;
        const diffInMonths = Math.floor(diffInTime / (1000 * 60 * 60 * 24 * 30));

        return diffInMonths;
    }

    handleExpeditedDisabledModalClose() {
        this.showExpeditedDisabledModal = false;
    }

    handleChangeFreeEmailsCheck(event) {
        this.sendFreeReminder = event.target.checked;
    }

    async handleExpeditedReview(event) {
        const itemId = parseInt(event.target.dataset.itemId, 10);
        const expeditedItem = this.items.find((item) => item.id === itemId);

        if (!expeditedItem) {
            return;
        }

        const includePrice = !expeditedItem.includePrice;

        if (includePrice) {
            const isDisabled = await isExpeditedProcessingDisabled();

            if (isDisabled) {
                this.showExpeditedDisabledModal = true;
                return;
            }
        }

        this.items = this.items.map((item) => {
            if (item.id !== itemId) return item;

            return {
                ...item,
                includePrice,
                expeditedReviewAction: includePrice ? "Remove Expedited Review" : "Add Expedited Review"
            };
        });
    }

    handlePayNow() {
        this.storeToCart();
        const cartTotalPrice = this.cartTotalPrice;
        this.dispatchEvent(
            new CustomEvent("paynow", {
                bubbles: true,
                composed: true,
                detail: {
                    sendFreeReminder: this.sendFreeReminder,
                    cartTotalPrice: cartTotalPrice
                }
            })
        );
        //this.navigateTo("BREG_Cart__c");
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent("back"));
    }

    handleTooltipHover(event) {
        const itemId = parseInt(event.target.dataset.itemId, 10);
        const targetItem = this.items.find((item) => item.id === itemId);
        if (targetItem) {
            targetItem.showTooltip = !targetItem.showTooltip;
        }
    }

    storeToCart() {
        const cartItems = this.formCartItems();
        // Add items to localStorage cart
        this.addItemsToCart(cartItems);
    }

    //form cart items
    formCartItems() {
        const cartItems = [];
        const caseSubject = this.formData["Case.Subject"];
        const effectiveCompanyName = this.companyName || caseSubject || "";
        // Generate a unique key for this group of items
        const groupKey = `${effectiveCompanyName}_${Date.now()}`;

        this.items
            .filter((item) => item.includePrice)
            .forEach((item) => {
                let companyUrl = this.accountId
                    ? "/search-and-buy?entityId=" + this.accountId
                    : this.tntmsmId
                      ? "/search-and-buy?entityId=" + this.tntmsmId
                      : "#";

                let itemName = item.name;
                itemName = itemName.replace("Expedite*", "Expedite");
                const expectedPrefix = this.formName + " - ";
                if (this.formName && !this.isGpFeesIncluded() && !item.name.startsWith(this.formName)) {
                    itemName = expectedPrefix + itemName;
                }

                const parentNamePrefix = item.name?.replace(/\s*filing with DCCA$/i, "").trim();
                const matchedExpediteFee = this.items.find((feeItem) => {
                    if (!feeItem?.isDeletable || !feeItem?.name?.includes("Expedite* Fee")) {
                        return false;
                    }

                    if (parentNamePrefix) {
                        return feeItem.name.startsWith(parentNamePrefix);
                    }

                    return feeItem.name === "Expedite* Fee";
                });

                cartItems.push({
                    id: itemName + " - " + this.caseId,
                    companyName: effectiveCompanyName,
                    companyUrl: companyUrl,
                    documentType: itemName, // + " - " + this.companyName,
                    documentDate: new Date(),
                    //documentFormatDate: entity.RegistrationNumber,
                    //format: "Digital (PDF)",
                    //formatIcon: "doctype:pdf",
                    quantity: 1,
                    unitPrice: item.price ? item.price : 0,
                    price: item.price ? item.price : 0,
                    certifyPrice: item.certifyPrice ? item.certifyPrice : 0,
                    isCertified: false,
                    isAvailableToCertify: item.certifyFeeId ? true : false,
                    certifyFeeId: item.certifyFeeId,
                    isQuantityDisabled: true,
                    isDeleteDisabled: !itemName.includes("filing with DCCA") || item.isGpForm,
                    isPrimaryItem: itemName.includes("filing with DCCA") && !item.isGpForm,
                    expeditePrice: item.expeditePrice || 0,
                    expediteFeeId: item.expediteFeeId,
                    isExpediteSelected: Boolean(matchedExpediteFee?.includePrice),
                    key: groupKey,
                    caseId: item.caseId,
                    type: item.type,
                    feeId: item.feeId
                });
            });
        //console.log("Cart items formed:", JSON.stringify(cartItems));
        return cartItems;
    }

    get cartTotalPrice() {
        const existingCartJson = localStorage.getItem(this.CART_STORAGE_KEY);
        if (existingCartJson) {
            const existingCart = JSON.parse(existingCartJson);
            const totalPrice = existingCart.reduce((total, item) => {
                return total + (item?.price ?? 0);
            }, 0);
            return totalPrice;
        } else {
            return 0;
        }
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
            const newIds = newItems.map((item) => item.id);
            const nonDuplicatedItems = newItems.filter((item) => !newIds.includes(item.id));

            // Add only new items to existing cart
            const updatedCart = [...nonDuplicatedItems, ...newItems];

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
}