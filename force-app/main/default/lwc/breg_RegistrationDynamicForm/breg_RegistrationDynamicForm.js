import { api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { NavigationMixin } from "lightning/navigation";
import { publish, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";
import saveFormData from "@salesforce/apex/BREGRegistrationFormController.saveFormData";
import saveRelatedFiles from "@salesforce/apex/BREGRegistrationFormController.saveRelatedFiles";

import BREG_As_of from "@salesforce/label/c.BREG_As_of";
import BREG_Failed_Save_Form_Data from "@salesforce/label/c.BREG_Failed_Save_Form_Data";
import BREG_Failed_Save_File from "@salesforce/label/c.BREG_Failed_Save_File";
import BREG_Error_Saving_Form from "@salesforce/label/c.BREG_Error_Saving_Form";
import BREG_Review_Form_Errors from "@salesforce/label/c.BREG_Review_Form_Errors";

import { formatDate } from "c/utils";
import { loadStyle } from "lightning/platformResourceLoader";
import BREG_PORTAL_RESOURCES from "@salesforce/resourceUrl/BREG_portalResources";
import { getPageParamsFromUrl, setPageUrlParams } from "c/utils";

export default class Breg_RegistrationDynamicForm extends NavigationMixin(BaseFormComponent) {
    @track _formConfiguration;
    @track formElements;
    @api caseId;
    @api fullFormConfig;
    files = [];
    showSpinner = false;
    isNotGuest;
    confirmInformationValue = false;
    @api endOfQuarter;
    @api annualFilingDate;

    @api
    set formConfiguration(value) {
        this._formConfiguration = value;
        this.setFormElements();
    }
    get formConfiguration() {
        return this._formConfiguration;
    }

    @api set filesData(value) {
        this.files = value ? [...value] : [];
    }
    get filesData() {
        return this.files;
    }

    get formTitle() {
        let title = this.formConfiguration?.formName?.toUpperCase() || "";
        if (title.includes("ANNUAL STATEMENT") && this.annualFilingDate) {
            title += ` - ${BREG_As_of} ${formatDate(this.annualFilingDate)}`;
        }
        return title;
    }

    get showFormTitle() {
        return this.formTitle && !this.cmpProperties?.hideFormTitle;
    }

    get targetFullFormConfig() {
        // console.log("targetFullFormConfig called. fullFormConfig:", JSON.stringify(this.fullFormConfig));
        return this.fullFormConfig || this.formConfiguration;
    }

    get isResubmit() {
        const { formAction } = getPageParamsFromUrl();
        return formAction === 'resubmit';
    }

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.loadCustomFormStyles();
    }

    loadCustomFormStyles() {
        loadStyle(this, BREG_PORTAL_RESOURCES + "/css/BREG_customFormStyles.css")
            .then(() => {
                console.log("** BREG form styles loaded successfully");
            })
            .catch((error) => {
                console.error("** Error loading BREG form styles:", error);
            });
    }

    setFormElements() {
        this.formElements = this.formConfiguration?.elements?.map((element) => {
            return { ...element, [element?.name?.replace(/ /g, "")]: true };
        });
    }

    handleInputChangeInternalField(event) {
        const inputName = event.target.name;
        const value = this.getValueFromEvent(event);
        this[inputName + "Value"] = value;
    }

    handleInputChange(event) {
        const field = event.detail ? event.detail.value?.field : undefined;
        const value = event.detail ? event.detail.value?.value : undefined;
        this.processFormDataChange(event);
        // console.log("*** handleInputChange dynamic form");
        // console.log("*** handleInputChange this.formData: ", JSON.stringify(this.formData));

        try {
            this.dispatchEvent(
                new CustomEvent("inputchange", {
                    detail: {
                        formData: this.formData,
                        value: value,
                        field: field
                    }
                })
            );
        } catch (e) {
            console.error("Dispatch error:", e);
        }
    }

    processFormDataChange(event) {
        const formData = event.detail ? event.detail.value?.formData : undefined;
        const field = event.detail ? event.detail.value?.field : undefined;
        const value = event.detail ? event.detail.value?.value : undefined;

        if (formData) {
            this._formData = { ...this.formData, ...formData };
        } else if (field === "members") {
            const existingMembers = this.formData.members || [];
            const incomingMembers = value || [];
            // get the role from the event detail to update members if their size became 0 after deletion
            const role = event.detail?.value?.role ? event.detail.value?.role : "Member";
            const memberRole = incomingMembers[0]?.["breg_Account_Affiliation__c.breg_Role__c"] || role;
            // Filter out existing members of the same type to avoid duplicates
            const membersOtherRole = existingMembers.filter((member) => member["breg_Account_Affiliation__c.breg_Role__c"] !== memberRole);
            // The 'value' already contains the complete updated list for this member type
            const mergedMembers = membersOtherRole.concat(incomingMembers);

            // Additional safety check: ensure we're not adding the exact same data
            // const existingMembersCount = existingMembers.filter((member) => member["breg_Account_Affiliation__c.breg_Role__c"] === memberRole).length;
            // const mergedMembersCount = incomingMembers.length;
            // console.log(`*** Members update: existing ${memberRole} count: ${existingMembersCount}, new count: ${mergedMembersCount}`);

            this._formData = { ...this.formData, ...{ members: mergedMembers } };

            // console.log('Members after update:', JSON.stringify(this.formData.members));
        } else if (field === "stocks") {
            this._formData = { ...this.formData, ...{ stocks: value } };
        } else if (field === "deletedMembers") {
            const existingDeletedMembers = this.formData.deletedMembers || [];
            const incomingDeletedMembers = value || [];
            const deletedMemberRole = incomingDeletedMembers[0]?.["breg_Account_Affiliation__c.breg_Role__c"];
            const deletedMembersOtherRole = deletedMemberRole
                ? existingDeletedMembers.filter((member) => member["breg_Account_Affiliation__c.breg_Role__c"] !== deletedMemberRole)
                : existingDeletedMembers;
            this._formData = { ...this.formData, ...{ deletedMembers: deletedMembersOtherRole.concat(incomingDeletedMembers) } };
        } else {
            this._formData = { ...this.formData, ...{ [field]: value } };
        }
    }

    handleFormUpdate(event) {
        const field = event.detail ? event.detail.value?.field : undefined;
        const value = event.detail ? event.detail.value?.value : undefined;
        this.processFormDataChange(event);
        // console.log("*** handleFormUpdate dynamic form");
        //console.log("*** handleFormUpdate this.formData: ", JSON.stringify(this.formData));

        try {
            this.dispatchEvent(
                new CustomEvent("formupdate", {
                    detail: {
                        formData: this.formData,
                        value: value,
                        field: field
                    }
                })
            );
        } catch (e) {
            console.error("Dispatch error:", e);
        }
    }

    handleFileUpload(event) {
        console.log("*** handleFileUpload: ", JSON.stringify(event.detail.value.fileName), JSON.stringify(event.detail.value.configId));
        const incomingFileKey = this.getFileKey(event.detail.value);
        this.files = this.files.filter((file) => this.getFileKey(file) !== incomingFileKey).concat(event.detail.value);
    }

    handleFileRemove(event) {
        console.log("*** handleFileRemove: ", JSON.stringify(event.detail.value.configId));
        const removedFileKey = this.getFileKey(event.detail.value);
        this.files = this.files.filter((file) => this.getFileKey(file) !== removedFileKey);
    }

    getFileKey(file) {
        return `${file?.configId || ""}::${file?.uploadTarget || "generic"}`;
    }

    handleEditSectionClick(event) {
        this.dispatchEvent(
            new CustomEvent("editsection", {
                bubbles: true,
                detail: event.detail
            })
        );
    }

    handleAddMember(event) {
        this.dispatchEvent(
            new CustomEvent("addmember", {
                bubbles: true,
                detail: event.detail
            })
        );
    }

    @api
    async validateForm() {
        try {
            this.showSpinner = true;
            const formComponents = [...this.template.querySelectorAll(".form-cmp")];

            let firstInvalidComponent = null;

            // Validate each component and find the first invalid one
            await Promise.all(formComponents.map((inputCmp) => inputCmp.reportValidity()));

            for (const inputCmp of formComponents) {
                const isValid = inputCmp.checkValidity();
                if (!isValid && !firstInvalidComponent) {
                    firstInvalidComponent = inputCmp;
                }
            }

            const allValid = !firstInvalidComponent;
            console.log("*** validateForm result: ", allValid);

            if (!allValid) {
                // Scroll to the first invalid component
                if (firstInvalidComponent) {
                    firstInvalidComponent.scrollIntoView({ behavior: "smooth", block: "center" });
                    console.log("*** Scrolled to first invalid field");
                }
                this.showToast("Error", BREG_Review_Form_Errors, "error");
            }
            return allValid;
        } catch (e) {
            console.error("validateForm error:", e);
            return false;
        } finally {
            this.showSpinner = false;
        }
    }

    @api
    async saveForm(isDraft = false) {
        try {
            this.showSpinner = true;
            let formattedData = {};
            const keys = Object.keys(this.formData);
            keys.forEach((key) => {
                if (key === "members" || key === "deletedMembers" || key === "stocksAnnuals" || key === "stocksPaidIn" || key === "stocksAuthorized") {
                    formattedData[key] = this.formData[key];
                    return;
                }

                const objectName = key.split(".")[0];
                const fieldName = key.split(".")[1];
                if (!objectName || !fieldName) {
                    return;
                }

                formattedData[objectName] = formattedData[objectName] || {};
                formattedData[objectName][fieldName] = this.formData[key];
            });

            if (isDraft) {
                formattedData.Case.Status = "New";
                formattedData.Case.breg_Bypass_Validation__c = true;
            }
            if(formattedData.members && formattedData.members.length) {
                formattedData.members = formattedData.members?.filter((member) => { 
                    return member?.firstName || member?.lastName || member?.entityName;
                });
            }
            //console.log("*** formattedData", JSON.stringify(formattedData));

            try {
                const responseJson = await saveFormData({ formConfigurationId: this.formConfiguration.id, jsonData: JSON.stringify(formattedData) });
                const response = JSON.parse(responseJson);
                const caseId = response.caseId;
                if (caseId) {
                    this.caseId = caseId;
                    this._formData = { ...this.formData, "Case.Id": caseId };
                    this.setAccAffiliationIdOnMembers(response.affiliations);
                    this.setStockIdOnStocks(response.stocks, "stocksAnnuals");
                    this.setStockIdOnStocks(response.stocks, "stocksPaidIn");
                } else {
                    this.showToast("Error", BREG_Failed_Save_Form_Data, "error");
                    return false;
                }

                if (this.files) {
                    try {
                        await saveRelatedFiles({ recordId: caseId, jsonData: JSON.stringify(this.files), isResubmit: this.isResubmit });
                    } catch (fileError) {
                        console.error("Error saving file:", fileError);
                        this.showToast("Error", `${BREG_Failed_Save_File} ${fileError}`, "error");
                    }
                }
                this.dispatchCustomEvent("save", {
                    caseId: this.caseId,
                    formData: this.formData
                });
                return true;
            } catch (err) {
                let errorMsg = BREG_Error_Saving_Form;
                if (err && err.body && err.body.message) {
                    errorMsg += "\n" + err.body.message;
                }
                this.showToast("Error", errorMsg, "error");
                return false;
            }
        } catch (err) {
            console.error(err);
            this.showToast("Error", BREG_Error_Saving_Form, "error");
            return false;
        } finally {
            this.showSpinner = false;
        }
    }

    setAccAffiliationIdOnMembers(affiliations) {
        //console.log("setAccAffiliationIdOnMembers", JSON.stringify(affiliations));
        try {
            if (!affiliations || affiliations.length === 0) {
                return;
            }

            const formData = { ...this.formData };
            if (!formData?.members || formData?.members?.length === 0) {
                return;
            }

            const updatedMembers = formData.members.map((member) => {
                const affiliation = affiliations.find((aff) => aff.uniqueKey === member.uniqueKey);
                if (affiliation) {
                    return {
                        ...member,
                        "breg_Account_Affiliation__c.Id": affiliation.affiliationId
                    };
                }
                return member;
            });
            const deletedMembers = formData.deletedMembers?.map((member) => {
                const affiliation = affiliations.find((aff) => aff.uniqueKey === member.uniqueKey);
                if (affiliation) {
                    return {
                        ...member,
                        "breg_Account_Affiliation__c.Id": affiliation.affiliationId
                    };
                }
                return member;
            });

            //console.log("Members after setting affiliation IDs:", JSON.stringify(updatedMembers));
            this._formData = { ...formData, members: updatedMembers, deletedMembers: deletedMembers };
            this._cmpProperties = { ...this.cmpProperties, reloadMembers: true }; // Trigger members reload to pass IDs
        } catch (e) {
            console.error("Error in setAccAffiliationIdOnMembers:", e.message);
        }
    }

    setStockIdOnStocks(stocks, type) {
        //console.log("setStockIdOnStocks", JSON.stringify(stocks));
        try {
            if (!stocks || stocks.length === 0) {
                return;
            }

            const formData = { ...this.formData };
            if (!formData?.[type] || formData?.[type]?.length === 0) {
                return;
            }

            const updatedStocks = formData[type].map((stock) => {
                const stockRecord = stocks.find((s) => s.uniqueKey === stock.uniqueKey);
                if (stockRecord) {
                    return {
                        ...stock,
                        "breg_Stock__c.Id": stockRecord.stockId
                    };
                }
                return stock;
            });

            //console.log("Stocks after setting stock IDs:", JSON.stringify(updatedStocks));
            this._formData = { ...formData, [type]: updatedStocks };
            this._cmpProperties = { ...this.cmpProperties, reloadStocks: true }; // Trigger stock reload to pass IDs
        } catch (e) {
            console.error("Error in setStockIdOnStocks:", e.message);
        }
    }

    showToast(title, message, variant) {
        if (this.isInternal) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: title,
                    message: message,
                    variant: variant
                })
            );
        } else {
            publish(this.messageContext, MESSAGE_CHANNEL, {
                type: MESSAGE_TYPE_TOAST,
                title: title,
                message: message,
                variant: variant
            });
        }
    }

    get formElementsToRender() {
        return this.formElements.filter((element) => {
            if (element.name === "Members" && this.isMembersElementAlwaysReadOnly(element) && !this.isMembersElementPresentInFormData(element)) {
                return false;
            }

            if (!element.componentVisibilityRules) {
                return true;
            }

            const componentVisibilityRules = JSON.parse(element.componentVisibilityRules);

            // eslint-disable-next-line guard-for-in
            for (const rule in componentVisibilityRules) {
                const fieldValue = this.formData[rule];
                if (fieldValue && componentVisibilityRules[rule]?.includes(fieldValue)) {
                    return true;
                }
            }
            this.resetFormData(element);
            return false;
        });
    }

    isMembersElementAlwaysReadOnly(element) {
        const componentSettings = element.componentSettings ? JSON.parse(element.componentSettings) : {};
        return componentSettings.alwaysReadOnly === true;
    }

    isMembersElementPresentInFormData(element) {
        const targetDefaultValues = element.targetDefaultValues ? JSON.parse(element.targetDefaultValues) : {};
        const roleField = "breg_Account_Affiliation__c.breg_Role__c";
        const targetRole = targetDefaultValues[roleField];

        if (!targetRole) {
            return true;
        }

        const members = this.formData?.members || [];
        return members.some((member) => member[roleField] === targetRole);
    }

    resetFormData(formElement) {
        if (formElement.name === "Members") {
            const targetDefaultValues = formElement.targetDefaultValues ? JSON.parse(formElement.targetDefaultValues) : {};
            let members = this.formData.members || [];
            // eslint-disable-next-line guard-for-in
            for (const key in targetDefaultValues) {
                members = members.filter((member) => member[key] !== targetDefaultValues[key]);
            }
            this._formData = { ...this.formData, members: members };
        } else {
            const targetFieldsMapping = formElement.targetFieldsMapping ? JSON.parse(formElement.targetFieldsMapping) : [];
            const updatedFormData = { ...this.formData };
            // eslint-disable-next-line guard-for-in
            for (const key in targetFieldsMapping) {
                delete updatedFormData[targetFieldsMapping[key]];
            }
            this._formData = updatedFormData;
        }
    }
}