import { LightningElement, track, wire } from "lwc";
import getAccountData from "@salesforce/apex/BREGAnnualsController.getAccountData";
import getProcessingPrices from "@salesforce/apex/BREGAnnualsController.getProcessingPrices";
import { Labels } from "./labels";
import { getPageParamsFromUrl, setPageUrlParams } from "c/utils";
import utils from "c/utils";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import ANNUAL_OBJECT from "@salesforce/schema/breg_Annual__c";
import STATUS_FIELD from "@salesforce/schema/breg_Annual__c.breg_Status__c";

export default class Breg_AnnualTransactionsPage extends LightningElement {
    accountFileNumber;
    @track accountName;
    @track accountRegDate;
    @track accounStatus;
    @track goodStanding;
    @track rows = [];
    @track filteredAnnuals = [];
    labels = Labels;
    latestDate;
    endOfQuarter;
    isShowDetailedRecord = false;
    @track delinquentYears = [];
    showModal = false;
    entityType;
    prices;
    recordId;
    minFilingYear;
    get penaltyFee() {
        return (Math.round(this.prices?.penalty * 100) / 100).toFixed(2);
    }
    nonprofitTypes = ["D2", "F2", "C1", "C2", "A1", "A2", "D9"]; //TODO add to some settings
    chosenReportEvent;

    picklistMap = {};

    @wire(getObjectInfo, { objectApiName: ANNUAL_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: "$objectInfo.data.defaultRecordTypeId",
        fieldApiName: STATUS_FIELD
    })
    wiredPicklist({ data, error }) {
        if (data) {
            this.picklistMap = Object.fromEntries(data.values.map((item) => [item.value, item.label]));
            this.getData();
        }
    }

    getLabelByValue(value) {
        return this.picklistMap[value];
    }

    get modalText() {
        let subSequentalYears = this.delinquentYears.slice(1);
        let today = new Date();
        let currentYear = today.getFullYear();
        return this.nonprofitTypes.includes(this.entityType)
            ? `
            ${this.labels.BREG_Annual_Report_Not_Submitted_No_Fee.replace("{1}", this.delinquentYears[0])}<br/>
            ${
                subSequentalYears.length > 1
                    ? this.labels.BREG_Annual_Report_Must_Be_Submitted_With_Multiple.replace("{1}", this.delinquentYears[0]).replace(
                          "{2}",
                          subSequentalYears.join(", ")
                      )
                    : this.labels.BREG_Annual_Report_Must_Be_Submitted_With.replace("{1}", this.delinquentYears[0]).replace(
                          "{2}",
                          subSequentalYears.join(", ")
                      )
            }
            `
            : `${this.labels.BREG_Annual_Report_Not_Submitted_With_Fee.replace("{1}", this.delinquentYears[0]).replace("{2}", (Math.round(this.penaltyFee * (currentYear - this.delinquentYears[0]) * 100) / 100).toFixed(2))}<br/>
            ${this.labels.BREG_Annual_Report_Must_Be_Submitted_With.replace("{1}", this.delinquentYears[0])
                .replace("{2}", subSequentalYears.join(", "))
                .replace("{3}", subSequentalYears.length > 1 ? "s" : "")}<br/><br/>
            <b>${this.labels.BREG_Annual_Late_Fee_Explanation_Title}</b><br/>
            ${this.labels.BREG_Annual_Late_Fee_Explanation.replace("{1}", this.penaltyFee).replace("{2}", (Math.round(this.penaltyFee * 2 * 100) / 100).toFixed(2))}
            `;
    }

    handleModalContinue() {
        this.showModal = false;
        this.openAnnualReport(this.chosenReportEvent);
    }

    handleModalCancel() {
        this.showModal = false;
    }

    @wire(getProcessingPrices)
    wiredPrices({ data, error }) {
        if (data) {
            this.prices = data;
        } else if (error) {
            console.error("Failed to load processing prices", error);
        }
    }

    get cardTitle() {
        return this.accountName + " (" + this.accountFileNumber + ")";
    }
    get goodStandingMessage() {
        let result = this.labels.BREG_Annuals_To_help_keep_your_company_in_good_standing.replace("{1}", this.latestDate?.getFullYear().toString())
            .replace("{2}", this.endOfQuarter)
            .replace("{3}", this.endOfQuarter)
            .replace("{4}", this.endOfQuarter);
        return result;
    }

    get annualsNotExists() {
        return !this.filteredAnnuals || this.filteredAnnuals.length === 0;
    }

    get helpMessage() {
        return ` ${this.labels.BREG_Annuals_or_call} ${this.labels.BREG_Annuals_ContactNumber}.`;
    }

    get penaltyFeeMessage() {
        let result = this.labels.BREG_Annuals_If_you_submit_your_annual_report_after.replace("{1}", this.latestDate?.getFullYear().toString())
            .replace("{2}", this.endOfQuarter)
            .replace("{3}", this.penaltyFee);
        return result;
    }

    get shouldShowPenaltyFeeMessage() {
        return !this.nonprofitTypes.includes(this.entityType);
    }

    get delinquentMessage() {
        let replacementMessage = "";
        let result;
        if (this.delinquentYears.length > 1) {
            replacementMessage = this.delinquentYears.join(", ");
            result = this.labels.BREG_Annuals_Your_annual_report_is_delinquent.replace("{0}", replacementMessage);
            result = result.replace("{1}", this.labels.BREG_Annuals_reports_are);
        } else if (this.delinquentYears.length === 1) {
            result = this.labels.BREG_Annuals_Your_annual_report_is_delinquent.replace("{0}", this.delinquentYears[0]);
            result = result.replace("{1}", this.labels.BREG_Annuals_report_is);
        }
        return result;
    }

    get isDelinquent() {
        return this.delinquentYears.length > 0;
    }

    columns = [
        { label: "Filing Year", fieldName: "filingYear", type: "text" },
        { label: "Report due date", fieldName: "filingDueDate", type: "text", wrapText: true },
        { label: "Date Received", fieldName: "receivedDate", type: "date", typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            timeZone: 'UTC'
        } },
        { label: "Status", fieldName: "status", type: "text" },
        {
            label: "Action and next steps",
            type: "button",
            typeAttributes: {
                label: { fieldName: "actionText" },
                name: "beginReport",
                variant: { fieldName: "actionVariant" },
                disabled: { fieldName: "actionDisabled" }
            },
            initialWidth: 250
        }
    ];

    getData() {
        if (this.accountFileNumber) {
            getAccountData({ fileNumber: null, accountId: this.recordId })
                .then((result) => {
                    this.accountName = result.accountName;
                    this.accountRegDate = result.registrationDate;
                    this.accounStatus = result.accountStatus;
                    this.dispatchEvent(new CustomEvent("found", { detail: { accountName: this.accountName } }));
                    this.goodStanding = result.isInGoodStanding;
                    this.entityType = result.entityType;

                    const today = new Date();
                    this.latestDate = new Date(null);

                    let maxAnnuals;

                    switch (this.accounStatus) {
                        case "Active (A)":
                            maxAnnuals = 1;
                            break;

                        case "Annual report 1 yr delinquent (1)":
                            maxAnnuals = 2;
                            break;

                        // case "Annual report 2 yr delinquent (2)":
                        //     maxAnnuals = 3;
                        //     break;

                        default:
                            maxAnnuals = 2;
                            break;
                    }

                    this.filteredAnnuals = (result.annuals || []).filter((an, index) => index < maxAnnuals);

                    let todayPlusYear = new Date(new Date().setFullYear(new Date().getFullYear() + 1))
                    this.latestDate = this.filteredAnnuals && this.filteredAnnuals.length > 0 ? new Date(null) : todayPlusYear;
                    const allowedToFileStatuses = ["D", "Not Filed", "N", "Delinquent"];
                    const annualsAllowedToFile = (this.filteredAnnuals || []).filter((an) => allowedToFileStatuses.includes(an.status));
                    this.minFilingYear = annualsAllowedToFile.length ? Math.min(...annualsAllowedToFile.map((an) => Number(an.filingYear))) : null;
                    this.rows =
                        this.filteredAnnuals?.map((an) => {
                            let showButton = this.getShowButton(an.filingYear, an.status);
                            if (an.status === "D") {
                                this.delinquentYears.push(an.filingYear);
                            }
                            const dueDate = new Date(an.filingDueDate);
                            let filingDueDateDisplay = an.filingDueDate;
                            if (!isNaN(dueDate) && dueDate < today) {
                                filingDueDateDisplay += ` (Overdue)`;
                            }
                            if (!isNaN(this.latestDate) && dueDate > this.latestDate) {
                                this.latestDate = dueDate;
                            }
                            return {
                                ...an,
                                filingDueDate: filingDueDateDisplay,
                                status: this.getLabelByValue(an.status),
                                actionText: this.getActionText(showButton, an.filingYear),
                                actionVariant: showButton ? "success" : "base",
                                actionDisabled: !showButton
                            };
                        }) || [];
                    //this.fillMissingAnnualReports();
                    // commentd as we already have legacy data and annual generation process and don't need to feel the gaps
                    this.endOfQuarter = utils.getQuarterEndDate(this.latestDate);
                })
                .catch((error) => {
                    console.error("Error loading account data", error.message);
                });
        }
    }

    connectedCallback() {
        const { fileNumber, accountId } = getPageParamsFromUrl();
        this.accountFileNumber = fileNumber.split(" ")[0];
        this.recordId = accountId;
    }

    isFirstAnnualFiling(filingYear) {
        const expectedFirstYear = this.minFilingYear;
        return Number(filingYear) === expectedFirstYear;
    }


    getActionText(showButton, year) {
        return showButton
            ? `Begin ${year} Report`
            : `The ${String(Number(year) - 1)} report will have to be submitted before you can start the ${year} report.`;
    }

    getShowButton(filingYear, status) {
        let isFirstRow = this.isFirstAnnualFiling(filingYear);
        const allowedToFileStatuses = ["D", "Not Filed", "N", "Delinquent"];
        const accountStatusIsSuitToShowButton =
            this.accounStatus === "Active (A)" ||
            this.accounStatus === "Annual report 1 yr delinquent (1)";
        const showButton = isFirstRow && allowedToFileStatuses.includes(status) && accountStatusIsSuitToShowButton;
        return showButton;
    }

    getQuarterDueDate = (year, quarter) => {
        switch (quarter) {
            case 1:
                return `${year}-03-31`;
            case 2:
                return `${year}-06-30`;
            case 3:
                return `${year}-09-30`;
            case 4:
                return `${year}-12-31`;
            default:
                return "";
        }
    };

    handleBack() {
        this.dispatchEvent(new CustomEvent("back"));
    }

    handleFileAnnualButton(event) {
        this.chosenReportEvent = event;
        if (this.delinquentYears.length > 0) {
            this.showModal = true;
        } else {
            this.openAnnualReport(this.chosenReportEvent);
        }
    }

    openAnnualReport(event) {
        const row = event.detail.row;
        const filingYear = row.filingYear;
        const annualId = row.annualId;

        // Preserve existing URL parameters including caseId and parentCaseId
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "verify",
            fileNumber: this.accountFileNumber,
            accountId: this.recordId,
            year: filingYear,
            annualId: annualId
        });
        this.dispatchEvent(new CustomEvent("fileannual"));
    }

    showDetailedRecord() {
        window.location.href = `/search-and-buy?entityId=${this.recordId}`;
    }
}