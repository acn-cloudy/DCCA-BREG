import { wire } from "lwc";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import BaseFormComponent from "c/breg_BaseFormComponent";
import BREG_HelpText_Classification_1_3 from "@salesforce/label/c.BREG_HelpText_Classification_1_3";
import BREG_HelpText_Classification_4_5 from "@salesforce/label/c.BREG_HelpText_Classification_4_5";
import BREG_HelpText_Classification_6_8 from "@salesforce/label/c.BREG_HelpText_Classification_6_8";
import BREG_HelpText_Classification_9_10 from "@salesforce/label/c.BREG_HelpText_Classification_9_10";
import BREG_HelpText_Classification_11_15 from "@salesforce/label/c.BREG_HelpText_Classification_11_15";
import BREG_HelpText_Classification_16_17 from "@salesforce/label/c.BREG_HelpText_Classification_16_17";
import BREG_HelpText_Classification_18_20 from "@salesforce/label/c.BREG_HelpText_Classification_18_20";
import BREG_HelpText_Classification_21_24 from "@salesforce/label/c.BREG_HelpText_Classification_21_24";
import BREG_HelpText_Classification_25_29 from "@salesforce/label/c.BREG_HelpText_Classification_25_29";
import BREG_HelpText_Classification_30_31 from "@salesforce/label/c.BREG_HelpText_Classification_30_31";
import BREG_HelpText_Classification_32_34 from "@salesforce/label/c.BREG_HelpText_Classification_32_34";
import BREG_HelpText_Classification_35_38 from "@salesforce/label/c.BREG_HelpText_Classification_35_38";
import BREG_HelpText_Classification_39_42 from "@salesforce/label/c.BREG_HelpText_Classification_39_42";
import BREG_HelpText_Classification_43_45 from "@salesforce/label/c.BREG_HelpText_Classification_43_45";
import BREG_HelpText_Classification_footer from "@salesforce/label/c.BREG_HelpText_Classification_footer";

export default class Breg_Classification extends BaseFormComponent {
    defaultTitle = "Classification";
    classificationTypeValue;
    classificationTypeOptions;
    allClassificationTypeOptions = [];
    lastHandledFormCode;

    get helpTextTitle() {
        const formCode = this.formCode || this.formConfig?.formCode;
        if (!formCode) {
            return;
        }

        if (formCode === "T-2") {
            return 'Trademark Classifications and Type of Goods';
        } else if (formCode === "T-3") {
            return 'Service Mark Classifications and Type of Services';
        }
    }

    get helpTextMessage() {
        const formCode = this.formCode || this.formConfig?.formCode;
        if (!formCode) {
            return;
        }

        if (formCode === "T-2") {
            return BREG_HelpText_Classification_1_3 +
                BREG_HelpText_Classification_4_5 +
                BREG_HelpText_Classification_6_8 +
                BREG_HelpText_Classification_9_10 +
                BREG_HelpText_Classification_11_15 +
                BREG_HelpText_Classification_16_17 +
                BREG_HelpText_Classification_18_20 +
                BREG_HelpText_Classification_21_24 +
                BREG_HelpText_Classification_25_29 +
                BREG_HelpText_Classification_30_31 +
                BREG_HelpText_Classification_32_34 +
                BREG_HelpText_Classification_footer;
        } else if (formCode === "T-3") {
            return BREG_HelpText_Classification_35_38 + 
                BREG_HelpText_Classification_39_42 + 
                BREG_HelpText_Classification_43_45 + 
                BREG_HelpText_Classification_footer;
        }
    }

    renderedCallback() {
        const formCode = this.formCode || this.formConfig?.formCode;
        this.handleFormCodeReady(formCode);
    }

    @wire(getPicklistValues, { recordTypeId: "012000000000000AAA", fieldApiName: "Case.breg_TNTMSM_Classification__c" })
    classificationTypeOptionsWired({ data }) {
        const formCode = this.formCode || this.formConfig?.formCode;
        this.allClassificationTypeOptions = this.setCBOptionsFromPicklistValues(data);
        this.handleFormCodeReady(formCode, true);
    }

    handleFormCodeReady(formCode, force = false) {
        if (!formCode || !this.allClassificationTypeOptions?.length) {
            return;
        }

        if (!force && this.lastHandledFormCode === formCode) {
            return;
        }
        this.lastHandledFormCode = formCode;

        // Place imperative Apex call here if needed, e.g. this.loadSomethingFromApex(formCode);

        // If this is a T-2 form, filter out the options that are not applicable
        if (formCode === "T-2") {
            this.classificationTypeOptions = this.allClassificationTypeOptions.slice(0, 35); // all value in the picklist before '34 - Smokers Articles' value
        } else if (formCode === "T-3") {
            this.classificationTypeOptions = this.allClassificationTypeOptions.slice(35);
        } else {
            this.classificationTypeOptions = [...this.allClassificationTypeOptions];
        }
    }
}