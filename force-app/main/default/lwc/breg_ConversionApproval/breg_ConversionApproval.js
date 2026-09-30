import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_ConversionApproval extends BaseFormComponent {
    defaultTitle = "Conversion Approval";
    conversionApprovalTypeValue;
    totalNumberOfSharesValue;
    classSeriesValue;
    numberOfSharesVotingForValue;
    numberOfSharesVotingAgainstValue;
    totalNumberOfVotesValue;
    numberOfVotesForValue;
    numberOfVotesAgainstValue;

    get conversionApprovalTypeOptions() {
        return [
            { label: "By vote of the shareholders of the converting domestic profit/professional corporation", value: "Shareholders Vote" },
            { label: "By vote of the converting domestic limited liability company", value: "LLC Vote" },
            {
                label: "The converting entity was a foreign profit corporation, a foreign limited liability company, a foreign limited partnership, a foreign limited liability limited partnership, a domestic or foreign nonprofit corporation, a domestic or foreign general partnership, or a domestic or foreign limited liability partnership.  The approval of the Plan of Conversion was duly authorized and complied with the laws under which the converting entity was incorporated, formed, organized, or qualified.",
                value: "Foreign Entity Compliance"
            },
            {
                label: "The converting entity was a domestic limited partnership or a domestic limited liability limited partnership and that a majority of the general partners have agreed to the conversion.",
                value: "Partnership General Partners"
            }
        ];
    }

    get showShareholdersVoteFields() {
        return this.conversionApprovalTypeValue === "Shareholders Vote";
    }

    get showLLCVoteFields() {
        return this.conversionApprovalTypeValue === "LLC Vote";
    }

    get conversionApprovalTypeValueReadOnly() {
        const option = this.conversionApprovalTypeOptions.find((opt) => opt.value === this.conversionApprovalTypeValue);
        let label = option ? option.label : this.conversionApprovalTypeValue;
        return `The Plan of Conversion was approved by the converting entity:  <p>${label.toUpperCase()}</p><br>`;
    }

    get totalNumberOfSharesValueReadOnly() {
        return `Total Number of Shares Outstanding: <b>${this.totalNumberOfSharesValue.toUpperCase()}</b>`;
    }

    get classSeriesValueReadOnly() {
        return `Class/Series: <b>${this.classSeriesValue.toUpperCase()}</b>`;
    }

    get numberOfSharesVotingForValueReadOnly() {
        return `Number of Shares Voting for the Conversion: <b>${this.numberOfSharesVotingForValue}</b>`;
    }

    get numberOfSharesVotingAgainstValueReadOnly() {
        return `Number of Shares Voting Against the Conversion: <b>${this.numberOfSharesVotingAgainstValue}</b>`;
    }

    get totalNumberOfVotesValueReadOnly() {
        return `Total Number of Authorized Votes: <b>${this.totalNumberOfVotesValue}</b>`;
    }

    get numberOfVotesForValueReadOnly() {
        return `Number of Votes for the Conversion: <b>${this.numberOfVotesForValue}</b>`;
    }

    get numberOfVotesAgainstValueReadOnly() {
        return `Number of Votes Against the Conversion: <b>${this.numberOfVotesAgainstValue}</b>`;
    }
}