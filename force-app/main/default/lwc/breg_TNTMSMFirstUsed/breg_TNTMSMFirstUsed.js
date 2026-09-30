import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_TNTMSMFirstUsed extends BaseFormComponent {
    defaultTitle = "Date Trademark First Used";
    firstUsedAnywhereValue;
    firstUsedHawaiiValue;

    get firstUsedAnywhereValueReadOnly() {
        return `Anywhere: <b>${this.firstUsedAnywhereValue.replace(/-/g, "/")}</b><br>`;
    }

    get firstUsedHawaiiValueReadOnly() {
        return `Hawaii: <b>${this.firstUsedHawaiiValue.replace(/-/g, "/")}</b><br>`;
    }
}