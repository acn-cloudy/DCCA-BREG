import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_Profit extends BaseFormComponent {
    defaultTitle = "Profit";
    profitValue;

    profitOptions = [
        { label: "Profit (F/$50/B11)", value: "Profit" },
        { label: "Nonprofit (F/$25/B53)", value: "Nonprofit" }
    ];
}