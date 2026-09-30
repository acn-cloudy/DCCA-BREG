import { LightningElement, api, track } from "lwc";
import { Labels } from "./labels";
import { getPageParamsFromUrl, setPageUrlParams } from "c/utils";
import { updateRecord } from "lightning/uiRecordApi";
import getUserInfo from "@salesforce/apex/BREGPortalUtils.getUserInfo";
import ID_FIELD from "@salesforce/schema/Case.Id";
import PROCESSING_SPEED_FIELD from "@salesforce/schema/Case.breg_Processing_Speed__c";
import PARENT_CASE_ID from "@salesforce/schema/Case.ParentId";
import updateCaseContact from "@salesforce/apex/BREGCaseControllerWithoutSharing.updateCaseContact";
import findExistingContact from "@salesforce/apex/BREGContactControllerWithoutSharing.findExistingContact";
import createNewContact from "@salesforce/apex/BREGContactControllerWithoutSharing.createNewContact";
import updateCaseSubscriptionCheckbox from "@salesforce/apex/BREGCaseControllerWithoutSharing.updateCaseSubscriptionCheckbox";
import getFees from "@salesforce/apex/BREGGetFeeForService.getFees";
import getAnnualIdByAccountAndYear from "@salesforce/apex/BREGAnnualsController.getAnnualIdByAccountAndYear";

export default class Breg_AnnualReports extends LightningElement {
    labels = Labels;
    formAction;
    searchValue = "";
    searchType;
    showSearch = true;
    showNewSearch = false;
    showQuartersTabs = false;
    annualQuarterDateStart = "";
    annualQuarterDateFinish = "";
    lateFilingDate = "";
    activeTab;
    showDetails = false;
    accountFileNumber = "";
    annualId;
    filingYear;
    currentStep = 1;
    accountName;
    processingSpeed;
    noChanges = false;
    caseId;
    accountId;
    parentCaseId;
    formData;
    formConfigId;
    @track fees;
    feesProcessed = false;
    shouldSetRecordIdForAnnualForm;
    isGuest = true;
    showContactInfoStep = false;
    disableContactContinue = false;

    get contactInfoTitle() {
        return this.labels.BREG_Annual_ContactInfoSectionTitle;
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

    get filingMustBeApprovedText() {
        return this.labels.BREG_Annuals_YourFilingMustBeApproved.replace("{0}", this.annualQuarterDateFinish);
    }

    get lateFilingAfterText() {
        return this.labels.BREG_Annuals_LateFilingAfter.replace("{0}", this.lateFilingDate);
    }

    get columnsClass() {
        return this.showSideBlock ? "slds-col slds-size_1-of-1 slds-large-size_2-of-3 slds-p-right_large" : "slds-size_1-of-1";
    }

    connectedCallback() {
        window.addEventListener("popstate", this.getParamsFromUrl());
        this.getParamsFromUrl();
        this.fetchUserInfo();
    }

    @api getParamsFromUrl() {
        const { page, fileNumber, year, shouldSetRecordId, annualId, caseId, parentCaseId, accountId, formAction, formConfigId } = getPageParamsFromUrl();
        this.accountFileNumber = fileNumber?.replace("%20", " ");
        this.filingYear = year;
        this.shouldSetRecordIdForAnnualForm = shouldSetRecordId;
        this.annualId = annualId;
        this.caseId = caseId;
        this.accountId = accountId;
        this.parentCaseId = parentCaseId;
        this.formAction = formAction;
        if (formConfigId) {
            this.formConfigId = formConfigId;
        }
        switch (page) {
            case "details":
                this.currentStep = 1;
                this.showDetails = true;
                this.showSearch = false;
                this.showContactInfoStep = false;
                break;
            case "contact":
                if (this.isGuest) {
                    this.currentStep = 2;
                    this.showContactInfoStep = true;
                } else {
                    this.currentStep = 3;
                    this.showContactInfoStep = false;
                }
                break;
            case "verify":
                this.currentStep = 2;
                this.showContactInfoStep = false;
                break;
            case "expedited":
                this.currentStep = 3;
                this.showContactInfoStep = false;
                break;
            case "submission":
                this.currentStep = 4;
                this.showContactInfoStep = false;
                break;
            default:
                this.currentStep = 1;
                this.showDetails = false;
                this.showSearch = true;
                this.showContactInfoStep = false;
        }
    }

    handleRecordFound(event) {
        this.accountName = event.detail.accountName;
    }

    hideSideBlock() {
        this.showSideBlock = false;
    }
    handleSearch(event) {
        this.searchValue = event.detail.searchValue;
        this.searchType = event.detail.searchType;
        this.showSearch = !this.showNewSearch;
        this.template.querySelector("c-breg-_-account-search-results-table").handleSearchClick(this.searchValue, this.searchType);
    }

    handleNewSearch() {
        this.showSearchResults = false;
        this.showSearch = true;
    }
    selectedQuarter = "";

    get registeredOptions() {
        return [
            { label: "Quarter 1", value: "Q1" },
            { label: "Quarter 2", value: "Q2" },
            { label: "Quarter 3", value: "Q3" },
            { label: "Quarter 4", value: "Q4" }
        ];
    }

    async fetchUserInfo() {
        try {
            const result = await getUserInfo();
            this.isGuest = result.isGuest;
        } catch (error) {
            console.error("Error fetching user info", error);
        }
    }

    handleQuarterChange(event) {
        this.selectedQuarter = event.detail.value;

        this.changeTabContent(this.selectedQuarter);
        this.activeTab = this.selectedQuarter;
    }

    handleTabActive(event) {
        this.selectedQuarter = event.target.value;
        this.changeTabContent(this.selectedQuarter);
    }

    changeTabContent(selectedQuarter) {
        let calculatedDates = this.calculateQuarterDates(selectedQuarter);
        this.annualQuarterDateStart = calculatedDates.start;
        this.annualQuarterDateFinish = calculatedDates.finish;
        this.lateFilingDate = calculatedDates.late;
        this.showQuartersTabs = true;
    }

    calculateQuarterDates(selectedQuarter) {
        const year = new Date().getFullYear();
        const shortYear = String(year).slice(-2);
        const nextShortYear = String(year + 1).slice(-2);

        const quarters = {
            Q1: { start: `1/1/${shortYear}`, finish: `3/31/${shortYear}`, late: `4/1/${shortYear}` },
            Q2: { start: `4/1/${shortYear}`, finish: `6/30/${shortYear}`, late: `7/1/${shortYear}` },
            Q3: { start: `7/1/${shortYear}`, finish: `9/30/${shortYear}`, late: `10/1/${shortYear}` },
            Q4: { start: `10/1/${shortYear}`, finish: `12/31/${shortYear}`, late: `1/1/${nextShortYear}` }
        };

        return quarters[selectedQuarter] || { start: "", finish: "", late: "" };
    }

    handleHelpClick() {
        this.dispatchEvent(new CustomEvent("help"));
    }

    handleBack() {
        this.showDetails = false;
        this.showSideBlock = true;
        this.showSearch = !this.showNewSearch;
        setTimeout(() => {
            const table = this.template.querySelector("c-breg-_-account-search-results-table");
            if (table) {
                table.handleSearchClick(this.searchValue, this.searchType);
            } else {
                console.warn("Component not found");
            }
        }, 0);
        setPageUrlParams({
            section: "annual-report",
            page: null,
            fileNumber: null,
            year: null
        });
    }

    async goToNextStep(event) {
        this.formData = event.detail.formData;
        if (event.detail.formConfigId) {
            this.formConfigId = event.detail.formConfigId;
            await this.getFees();
        }

        if (this.currentStep === 2) {
            const targetPage = this.isGuest ? "contact" : "expedited";
            const currentParams = getPageParamsFromUrl();
            setPageUrlParams({
                ...currentParams,
                section: "annual-report",
                page: targetPage,
                fileNumber: this.accountFileNumber,
                year: this.filingYear,
                caseId: this.caseId,
                shouldSetRecordId: true,
                formConfigId: this.formConfigId
            });
            this.getParamsFromUrl();
            return;
        }

        if (event.detail && this.currentStep === 3) {
            this.processingSpeed = event.detail.selectedSpeed;
        }
        this.getParamsFromUrl();
    }

    async getFees() {
        if (this.feesProcessed) return;
        let fees = await getFees({
            fieldsToSelect: ["breg_Purchase_Type_Fee_type__c", "breg_Fee_Amount__c", "breg_Form_Code__c", "breg_Registration_Type__c", "Id"],
            filters: {
                breg_Form_Configuration__c: this.formConfigId,
                breg_Purchase_Type_Fee_type__c: "Annual Filing Fee,Archive Fees,Expedite Fees,Penalty Fees,Late Fees"
            }
        });

        if (fees) {
            this.fees = { ...fees };
            this.feesProcessed = true;
        }
    }

    handleSaveForm(event) {
        if (event.detail) {
            this.caseId = event.detail.caseId;

            // Keep caseId in URL but stay on current step until onnext.
            if (this.caseId) {
                const currentParams = getPageParamsFromUrl();
                setPageUrlParams({
                    ...currentParams,
                    shouldSetRecordId: true,
                    caseId: this.caseId
                });
            }
        }
    }

    async handleContactContinue() {
        this.disableContactContinue = true;
        try {
            const contactInfoCmp = this.template.querySelector("c-breg-_-contact-info");
            if (!contactInfoCmp) {
                return;
            }

            const validSoFar = contactInfoCmp.checkValidity();
            contactInfoCmp.reportValidity();
            if (!validSoFar) {
                return;
            }

            const contactDetails = contactInfoCmp.getValues();
            let contactId = await findExistingContact({
                firstName: contactDetails.FirstName,
                lastName: contactDetails.LastName,
                email: contactDetails.Email,
                phone: contactDetails.Phone,
                street: contactDetails.MailingStreet,
                city: contactDetails.MailingCity,
                stateCode: contactDetails.MailingStateCode || null,
                postalCode: contactDetails.MailingPostalCode,
                country: contactDetails.MailingCountryCode || "US"
            });

            if (!contactId) {
                contactId = await createNewContact({
                    firstName: contactDetails.FirstName,
                    lastName: contactDetails.LastName,
                    email: contactDetails.Email,
                    phone: contactDetails.Phone,
                    street: contactDetails.MailingStreet,
                    city: contactDetails.MailingCity,
                    stateCode: contactDetails.MailingStateCode || null,
                    postalCode: contactDetails.MailingPostalCode,
                    country: contactDetails.MailingCountryCode || "US"
                });
            }

            if (contactId) {
                await updateCaseContact({ caseId: this.caseId, contactId });
            }

            if (!this.feesProcessed && this.formConfigId) {
                await this.getFees();
            }

            this.showContactInfoStep = false;
            const currentParams = getPageParamsFromUrl();
            setPageUrlParams({
                ...currentParams,
                section: "annual-report",
                page: "expedited",
                fileNumber: this.accountFileNumber,
                year: this.filingYear,
                caseId: this.caseId,
                shouldSetRecordId: true,
                formConfigId: this.formConfigId
            });
            this.getParamsFromUrl();
        } catch (error) {
            console.error("Error saving contact info:", error);
            console.error("Apex error message:", error?.body?.message);
            console.error("Apex error body:", error?.body);
        } finally {
            this.disableContactContinue = false;
        }
    }

    handleContactBack() {
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "verify",
            fileNumber: this.accountNumber,
            year: this.filingYear,
            caseId: this.caseId,
            shouldSetRecordId: true
        });
        this.getParamsFromUrl();
    }

    updateCaseFields() {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.caseId;
        fields[PROCESSING_SPEED_FIELD.fieldApiName] = this.processingSpeed;
        fields[PARENT_CASE_ID.fieldApiName] = this.parentCaseId;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                console.log("Case updated successfully");
            })
            .catch((error) => {
                console.error("Error updating case:", error);
            });
    }

    handleAddToCart() {
        this.updateCaseFields();
        this.dispatchEvent(new CustomEvent("addtocart"));
    }

    async handleNextReport(event) {
        this.updateCaseFields();
        // Reset state for the new annual report case
        this.formData = null;
        this.feesProcessed = false;

        // Get accountId and filingYear from URL params
        const { accountId, year } = getPageParamsFromUrl();

        // Fetch the annualId for this account and filing year
        if (accountId && year) {
            const annualId = await getAnnualIdByAccountAndYear({
                accountId: accountId,
                filingYear: year
            });

            // Update URL params with the correct annualId
            if (annualId) {
                const currentParams = getPageParamsFromUrl();
                setPageUrlParams({
                    ...currentParams,
                    annualId: annualId,
                    caseId: null,
                    shouldSetRecordId: null
                });
            }
        }

        this.getParamsFromUrl();
        this.dispatchEvent(new CustomEvent("addtocart"));
    }

    async handleCheckout(event) {
        const { caseId } = getPageParamsFromUrl();
        this.caseId = caseId;
        const sendFreeReminder = event.detail.sendFreeReminder;
        const cartTotalPrice = event.detail.cartTotalPrice;
        const redirectToCartOnly = event.detail.redirectToCartOnly;
        this.updateCaseFields();
        if (cartTotalPrice > 0 || redirectToCartOnly) {
            await updateCaseSubscriptionCheckbox({ caseId: this.caseId, subscriptionCheckbox: sendFreeReminder });
            window.location.href = `/cart`;
        } else {
            window.location.href = `/checkout?page=checkout`;
        }
    }
}