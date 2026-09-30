import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getAnnualFillingsForInternalUser from "@salesforce/apex/BREGAnnualsController.getAnnualFillingsForInternalUser";
import getFormConfiguration from "@salesforce/apex/BREGPortalUtils.getFormConfiguration";

const NOT_FILED_STATUSES = ["N", "D"];
export default class Breg_AnnualFillingInternal extends NavigationMixin(LightningElement) {
    @api recordId;
    accountData;
    annualRecords = [];
    formConfiguration;
    error;
    isLoading = true;

    @wire(getAnnualFillingsForInternalUser, { accountId: "$recordId" })
    wiredAccountData({ error, data }) {
        this.isLoading = false;
        if (data) {
            const annualRecords = data.Annuals__r || [];
            const sortedAnnualRecords = [...annualRecords].sort((left, right) => {
                const leftYear = Number(left.breg_Filing_Year__c);
                const rightYear = Number(right.breg_Filing_Year__c);
                return leftYear - rightYear;
            });
            this.accountData = data;
            this.error = undefined;

            /*
             * "File An Annual" button will be enabled for the oldest report with "Not Filed" status,
             * and if there are multiple reports with "Not Filed" status,
             * only the oldest one can be filed while the others can only be amended.
             */
            const minNotFiledYear = annualRecords.reduce((minYear, annual) => {
                if (!NOT_FILED_STATUSES.includes(annual.breg_Status__c)) {
                    return minYear;
                }
                const filingYear = Number(annual.breg_Filing_Year__c);
                return Number.isNaN(filingYear) ? minYear : Math.min(minYear, filingYear);
            }, Number.POSITIVE_INFINITY);

            /*
             * Populate the isNotFiled property. If isNotFiled = false, it means that only an amendment can be submitted.
             * Amendment is available for annual reports for the last 2 years and can be submitted by internal users only; older reports will not be displayed in this component at all.
             */
            this.annualRecords = sortedAnnualRecords.map((annual) => {
                const isNotFiled = NOT_FILED_STATUSES.includes(annual.breg_Status__c);
                const filingYear = Number(annual.breg_Filing_Year__c);
                const isminFilingYear = isNotFiled && Number.isFinite(minNotFiledYear) && Number.isFinite(filingYear) && filingYear === minNotFiledYear;
                return {
                    ...annual,
                    isNotFiled: isNotFiled,
                    buttonLabel: isNotFiled ? "File An Annual" : "File An Annual (Amendment)",
                    disabled: isNotFiled && !isminFilingYear
                };
            });
        } else if (error) {
            this.error = error;
            this.annualRecords = [];
        }
    }

    get hasRecords() {
        return this.annualRecords && this.annualRecords.length > 0;
    }

    navigateToAnnualRecord(event) {
        const annualId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: annualId,
                objectApiName: "breg_Annual__c",
                actionName: "view"
            }
        });
    }

    async handleFileAnnual(event) {
        const target = event.currentTarget || event.target;
        if (!target || !target.dataset) {
            console.error("No dataset found on event target");
            return;
        }

        const annualId = target.dataset.id;
        const filingYear = target.dataset.filingYear;
        const isNotFiled = target.dataset.isNotFiled === "true";

        await this.loadFormConfiguration();

        let stateParams = {
            c__formConfigId: this.formConfiguration?.id,
            // c__readOnly: true,
            c__accountId: this.recordId,
            c__annualId: annualId,
            c__filingYear: filingYear,
            c__isAmendedAnnualReport: !isNotFiled
        };
        // Use Lightning Navigation with state parameters for internal Salesforce context
        this[NavigationMixin.Navigate]({
            type: "standard__navItemPage",
            attributes: {
                apiName: "BREG_Form_Filing"
            },
            state: stateParams
        });
    }

    async loadFormConfiguration() {
        this.isLoading = true;
        try {
            const formConfiguration = await getFormConfiguration({
                businessProcess: "Annual Report",
                formSuffix: this.accountData?.breg_Entity_Type__c
            });

            this.formConfiguration = formConfiguration;
        } catch (error) {
            console.error("*** loadFormConfiguration error:", error);
        }
        this.isLoading = false;
    }
}