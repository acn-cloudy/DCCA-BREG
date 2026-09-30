import { LightningElement, track, wire, api } from "lwc";
import { Labels } from "./labels";
import { setPageUrlParams, getPageParamsFromUrl } from "c/utils";
import { NavigationMixin } from "lightning/navigation";
import { formatCurrency } from "c/utils";
import AnnualSubmissionChoice from "c/breg_AnnualsSubmissionChoice";
import isExpeditedProcessingDisabled from "@salesforce/apex/BREGPaymentController.isExpeditedProcessingDisabled";


export default class Breg_Expedited extends NavigationMixin(AnnualSubmissionChoice) {
    @track selectedOption = "Normal";
    labels = Labels;
    @api accountNumber;
    @api accountName;
    @api filingYear;
    @api accountId;
    @api formAction;

    @track showExpeditedDisabledModal = false;

    connectedCallback() {
        if(this.isResubmit) {
            this.selectedOption = "Normal";
            this.handleNext();
        }
    }

    get tileTitle() {
        return  `${this.accountName} (${this.accountNumber})`;
    }

    get yearReport() {
        return this.labels.BREG_Annuals_Year_Report.replace("{1}", this.filingYear);
    }

    get baseOptions() {
        if (this.feesProcessed) {
            return [
                {
                    value: "Normal",
                    label: 'Regular',
                    description: formatCurrency(this.annualFilingFee),
                    details: `${this.labels.BREG_Annuals_Average_processing_time} `,
                    term: this.labels.BREG_Annuals_Normal_processing_time
                },
                {
                    value: "Expedited",
                    label: this.labels.BREG_Annuals_Expedited_label,
                    description: `${formatCurrency(this.annualFilingFee)} + ${formatCurrency(this.expeditedFee)}`,
                    details: `${this.labels.BREG_Annuals_Average_processing_time} `,
                    term: this.labels.BREG_Annuals_Expedited_processing_time
                }
            ];
        }

        return [];
    }

    get isResubmit() {
        return this.formAction?.toLowerCase() === "resubmit";
    }

    get options() {
        return (this.baseOptions || []).map((opt) => ({
            ...opt,
            checked: opt.value === this.selectedOption,
            class: `checkbox-card slds-box slds-box_x-small slds-m-around_x-small slds-p-around_medium ${opt.value === this.selectedOption ? "slds-theme_alert-texture slds-theme_inverse" : ""}`
        }));
    }

    handleExpeditedDisabledModalClose() {
        this.showExpeditedDisabledModal = false;
    }

    async handleOptionClick(event) {
        const value = event.currentTarget.dataset.value;

        if (value === "Expedited") {
            const isDisabled = await isExpeditedProcessingDisabled();

            if (isDisabled) {
                this.showExpeditedDisabledModal = true;
                return;
            }
        }

        this.selectedOption = value;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }

    handlePrev() {
        // Preserve existing URL parameters including caseId and parentCaseId
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "verify",
            fileNumber: this.accountNumber,
            accountId: this.accountId,
            year: this.filingYear
        });
        this.dispatchEvent(new CustomEvent("previous"));
    }

    handleNext() {
        // Preserve existing URL parameters including caseId and parentCaseId
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "submission",
            fileNumber: this.accountNumber,
            accountId: this.accountId,
            year: this.filingYear
        });
        this.dispatchEvent(
            new CustomEvent("next", {
                detail: { selectedSpeed: this.selectedOption }
            })
        );
    }
}