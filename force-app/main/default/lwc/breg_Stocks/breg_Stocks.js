import BaseFormComponent from "c/breg_BaseFormComponent";
import { formatCurrency } from "c/utils";

export default class Breg_Stocks extends BaseFormComponent {
    defaultTitle = "Stocks";
    numberOfSharesValue;
    parValueValue;
    propertyRightsValue;
    propertyRightsRuleValue;

    propertyRightsOptions = [
        { label: "Equal", value: "Equal" },
        { label: "Unequal", value: "Unequal" }
    ];

    get showNumberOfSharesField() {
        return "numberOfShares" in this.targetFieldsMapping;
    }

    get showParValueField() {
        return "parValue" in this.targetFieldsMapping;
    }

    get showPropertyRightsField() {
        return "propertyRights" in this.targetFieldsMapping;
    }

    get showPropertyRightsRuleField() {
        return this.propertyRightsValue === "Unequal";
    }

    get numberOfSharesValueReadOnly() {
        return `Number of Common Shares: <b>${this.numberOfSharesValue}</b><br>`;
    }
    get parValueValueReadOnly() {
        return `Par Value Of Each Share: <b>${formatCurrency(this.parValueValue)}</b><br>`;
    }
    get propertyRightsValueReadOnly() {
        return `The property rights and interest of each member is: <b>${this.propertyRightsValue.toUpperCase()}</b><br>`;
    }
    get propertyRightsRuleValueReadOnly() {
        return `Rule: <b>${this.propertyRightsRuleValue.toUpperCase()}</b><br>`;
    }
}