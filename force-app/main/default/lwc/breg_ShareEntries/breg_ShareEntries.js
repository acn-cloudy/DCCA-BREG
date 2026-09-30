import BaseFormComponent from "c/breg_BaseFormComponent";
import { formatCurrency } from "c/utils";

export default class Breg_ShareEntries extends BaseFormComponent {
    defaultTitle = "Share Entries";
    classSeriesValue;
    sharesCountValue;
    parValueValue;
    parTotalValue;
    amountValue;
    outstandingSharesCountValue;
    ownedSharesCountValue;

    get showSharesCountField() {
        return this.config.targetFieldsMapping?.includes("sharesCount");
    }

    get readOnlyOutstandingSharesCountValue() {
        return this.outstandingSharesCountValue ? this.outstandingSharesCountValue : 0;
    }

    get readOnlySharesCountValue() {
        return this.sharesCountValue ? this.sharesCountValue : 0;
    }

    get readOnlyOwnedSharesCountValue() {
        return this.ownedSharesCountValue ? this.ownedSharesCountValue : 0;
    }

    get readOnlyClassSeriesValue() {
        return this.classSeriesValue ? this.classSeriesValue.toUpperCase() : this.emptyInputString;
    }

    get readOnlyParValueValue() {
        return this.parValueValue ? formatCurrency(this.parValueValue) : formatCurrency(0); //todo
    }

    get readOnlyParTotalValue() {
        return this.parTotalValue ? formatCurrency(this.parTotalValue) : formatCurrency(0);
    }

    get readOnlyAmountValue() {
        return this.amountValue ? formatCurrency(this.amountValue) : formatCurrency(0);
    }

    get showOutstandingSharesCountField() {
        return this.config.targetFieldsMapping?.includes("outstandingSharesCount");
    }

    get showOwnedSharesCountField() {
        return this.config.targetFieldsMapping?.includes("ownedSharesCount");
    }

    get showParValueField() {
        return this.config.targetFieldsMapping?.includes("parValue");
    }

    get showParTotalField() {
        return this.config.targetFieldsMapping?.includes("parTotal");
    }

    get showAmountField() {
        return this.config.targetFieldsMapping?.includes("amount");
    }
}