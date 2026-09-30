import BaseFormComponent from "c/breg_BaseFormComponent";
import getCasesForWithdrawal from "@salesforce/apex/BREGPortalUtils.getCasesForWithdrawal";

export default class Breg_WithdrawalInfo extends BaseFormComponent {
    entityName = "";
    workitemNumber = "";
    submissionDate = null;
    formCode = "";
    formName = "";
    totalAmount = null;
    loadedForParentCaseId;

    connectedCallback() {
        super.connectedCallback();
        this.loadWithdrawalData();
    }

    processFormData() {
        super.processFormData();
        this.loadWithdrawalData();
    }

    populateDefaultValues() {}

    get formattedSubmissionDate() {
        if (!this.submissionDate) {
            return "";
        }

        try {
            const [year, month, day] = this.submissionDate.split("-");
            return `${month}/${day}/${year}`;
        } catch (error) {
            console.error("*** withdrawal info -> format date error:", error);
            return this.submissionDate;
        }
    }

    get formattedAmount() {
        if (this.totalAmount === null || this.totalAmount === undefined || Number.isNaN(Number(this.totalAmount))) {
            return "";
        }

        try {
            return new Intl.NumberFormat("en-US", {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }).format(Number(this.totalAmount));
        } catch (error) {
            console.error("*** withdrawal info -> format amount error:", error);
            return this.totalAmount;
        }
    }

    async loadWithdrawalData() {
        const parentCaseId = this.formData?.["Case.ParentId"] || this.cmpProperties?.parentCaseId || this.cmpProperties?.ParentId;

        if (!parentCaseId) {
            console.warn("*** withdrawal info -> Case.ParentId is missing; skipping data load");
            return;
        }

        if (this.loadedForParentCaseId === parentCaseId) {
            return;
        }

        try {
            const data = await getCasesForWithdrawal({ caseIds: [parentCaseId] });
            if (!Array.isArray(data) || data.length === 0) {
                return;
            }

            const withdrawalData = data.find((record) => record?.parentCaseId === parentCaseId);
            if (!withdrawalData) {
                return;
            }

            this.loadedForParentCaseId = parentCaseId;

            this.entityName = withdrawalData.entityName || "";
            this.workitemNumber = withdrawalData.workitemNumber || "";
            this.submissionDate = withdrawalData.submissionDate || null;
            this.formCode = withdrawalData.formCode || "";
            this.formName = withdrawalData.formName || "";
            this.totalAmount = withdrawalData.totalAmount;

        } catch (error) {
            console.error("*** withdrawal info -> load data error:", JSON.stringify(error));
        }
    }
}