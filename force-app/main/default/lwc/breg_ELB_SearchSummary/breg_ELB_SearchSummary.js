import { LightningElement, api } from "lwc";
import search from "@salesforce/apex/BREGEntityListBuilderController.search";

export default class Breg_ELB_SearchSummary extends LightningElement {
    @api searchInput; // Public property to receive input from parent
    recordsFound;
    pricePerRecord;
    monthlyPrice;
    total;
    feeId;
    error;
    status;
    endDate;
    startDate;
    email;
    nameOrCompany;
    recordTypes;
    zipCodes;

    connectedCallback() {
        this.total = 0;
        this.recordsFound = 0;
        this.pricePerRecord = 0;
        this.startDate = this.searchInput.startDate;
        this.endDate = this.searchInput.endDate;
        this.email = this.searchInput.email;
        this.nameOrCompany = this.searchInput.nameOrCompany;
        this.zipCodes = this.searchInput.zipCodes;
        this.status = this.searchInput.status;
        this.recordTypes = this.searchInput.recordTypes;
        console.log("searchInput SearchSummary", JSON.stringify(this.searchInput));
        if (this.searchInput) {
            this.fetchSearchResults();
        }
    }
    @api
    validate() {
        let isValid = true;
        //always return true, selection is not required on this step
        return isValid;
    }
    handleEditEntityTypesClick() {
        this.dispatchEvent(
            new CustomEvent("returntostep", {
                detail: {
                    stepNum: "1"
                }
            })
        );
    }
    handleEditRefinementClick() {
        this.dispatchEvent(
            new CustomEvent("returntostep", {
                detail: {
                    stepNum: "2"
                }
            })
        );
    }
    handleEditContactInfoClick() {
        this.dispatchEvent(
            new CustomEvent("returntostep", {
                detail: {
                    stepNum: "3"
                }
            })
        );
    }

    fetchSearchResults() {
        console.log("Fetching search results with input:", JSON.stringify(this.searchInput));
        search({ input: this.searchInput })
            .then((result) => {
                this.recordsFound = result.RecordsFound;
                this.pricePerRecord = result.PricePerRecord;
                this.total = result.Total;
                this.monthlyPrice = result.MonthlyPrice;
                this.feeId = result.FeeId;
                this.error = undefined;
            })
            .catch((error) => {
                this.error = error;
                this.recordsFound = undefined;
                this.pricePerRecord = undefined;
                this.total = undefined;
                this.feeId = undefined;
                this.monthlyPrice = undefined;
            });
    }

    @api
    getEntitiesInfo() {
        return {
            recordsFound: this.recordsFound,
            pricePerRecord: this.pricePerRecord,
            total: this.total,
            feeId: this.feeId,
            monthlyPrice: this.monthlyPrice,
            accountName: this.searchInput.name
        };
    }
}