import { track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { NavigationMixin } from "lightning/navigation";
import { Labels } from "./labels";
import BREG_HelpText_FC_Signature from "@salesforce/label/c.BREG_HelpText_FC_Signature";
import BREG_HelpText_FLLC_Signature from "@salesforce/label/c.BREG_HelpText_FLLC_Signature";
import BREG_Applicant_Individual_Signature_Description from "@salesforce/label/c.BREG_Applicant_Individual_Signature_Description";

const HELP_TEXT_LABELS = {
    BREG_HelpText_FC_Signature,
    BREG_HelpText_FLLC_Signature
};

// Map of titles to their corresponding entity type codes
const ENTITY_TYPES_BY_TITLE = {
    "Chairperson of the Board of Directors": "D1,P1,S1,A1,C1,F1",
    President: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Vice President": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    Secretary: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    Treasurer: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Chief Executive Officer": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Chief Financial Officer": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Chief Operating Officer": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Senior Vice President": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Executive Vice President": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Vice Chairman": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    Controller: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Assistant Controller": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Assistant Secretary": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Assistant Treasurer": "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    Fiduciary: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    Receiver: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    Trustee: "D1,P1,S1,A1,C1,F1,D2,F2,A2,C2,C6",
    "Benefit Director": "S1",
    "Presiding Officer of the Board of Directors": "D2,F2,A2,C2",
    Member: "C5,C6",
    Manager: "C5,C6",
    "Authorized person": "C6",
    "Authorized signatory": "C6",
    "General partner": "G5,G6,K5,K6,L5,L6,Q5,Q6",
    Other: "A1,A2,D1,D2,D9,F1,F2,G5,G6,K5,K6,L5,L6,P1,Q5,Q6,S1,C1,C2,C6"
};

const SIGNATURE_APPLICANT_DESCRIPTIONS_BY_TYPE = {
    Corporation: "For corporations, application must be signed by an authorized officer of the corporation.",
    Partnership: "For general or limited partnerships, application must be signed by a general partner.",
    "Limited Liability Company":
        "For Limited Liability Company, application must be signed by a manager of a manager-managed company or by a member of a member-managed company."
};

const OFFICE_HELD_API_NAME = "Office Held of the applicant";
const CASE_SIGNED_BY_FIELD_API_NAME = "Case.breg_Signed_By__c";
const CASE_IS_MANAGER_MANAGED_FIELD_API_NAME = "Case.breg_Is_Manager_Managed__c";
const DEFAULT_SIGNATURE_LABEL = "Signature - Type name to sign";
const DEFAULT_NAME_SELECTOR_LABEL = "Name";
const DEFAULT_TITLE_SELECTOR_LABEL = "Title";
const MEMBER_TITLE = "Member";
const MANAGER_TITLE = "Manager";

export default class Breg_Signature extends NavigationMixin(BaseFormComponent) {
    labels = Labels;
    defaultTitle = "Signature";
    @track members = [];
    membersMap = new Map();
    signedByTypeValue;
    signedByEntityNameValue;
    signedByTitleSelectorValue;
    signedByTitleTextValue;
    signedByNameSelectorValue;
    signedByNameTextValue;
    signedByFirstNameValue;
    signedByLastNameValue;
    signedByApplicantTypeValue;
    signedByOfficeHeldValue;
    signatureValue;
    @track signers = [];
    signedByNameSelectorOptions = [];
    applicantTypeDescription;
    applicantTypeReadOnly = false;
    officeHeldApiName = OFFICE_HELD_API_NAME;
    showSignedByError = false;
    previousApplicantMemberType;

    dependentFieldsMapping = {
        signedByType: [
            "signedByEntityName",
            "signedByTitleSelector",
            "signedByTitleText",
            "signedByNameSelector",
            "signedByNameText",
            "signedByFirstName",
            "signedByLastName"
        ],
        signedByApplicantType: ["signedByOfficeHeld", "signature", "signedByNameText", "signedByFirstName", "signedByLastName"]
    };

    get signedByTypeOptions() {
        return [
            { label: "Individual", value: "Individual" },
            { label: "Entity", value: "Entity" }
        ];
    }

    get signedByTitleSelectorOptions() {
        let options = [];
        if (this.componentSettings?.signedByTitleSelectorOptions) {
            options = this.getTitleOptions(this.componentSettings?.signedByTitleSelectorOptions, this.entityType);
        } else {
            options = this.getTitlesByEntityType(this.entityType) || [];
        }
        
        if (this.componentSettings?.restrictMemberManagerTitle === true) {
            const isManagerManaged = this.formData?.[CASE_IS_MANAGER_MANAGED_FIELD_API_NAME];
            if (isManagerManaged != undefined) {
                const requiredTitle = isManagerManaged ? MANAGER_TITLE : MEMBER_TITLE;
                return options.filter((opt) => opt.value === requiredTitle);
            }
        }

        return options;
    }

    getTitleOptions(options, entityType) {
        // 1. Look for an object that has "all" as a key
        let match = options.find((opt) => "all" in opt);

        // 2. If no "all" match, look for the entityType as a key
        if (!match) {
            match = options.find((opt) => entityType in opt);
        }

        // 3. Return the titles if found, otherwise an empty array
        if (!match) {
            return [];
        }

        // Get the titles array from either "all" or the entityType key
        const titles = match.all || match[entityType];

        return titles.map((title) => {
            return {
                // If the value is "other" (case-insensitive check), set label to "OTHER"
                label: title.toLowerCase() === "other" ? "OTHER" : title,
                value: title
            };
        });
    }

    get signatureLabel() {
        let label =
            this.componentSettings?.signatureLabel == null
                ? DEFAULT_SIGNATURE_LABEL
                : `Signature of ${this.componentSettings.signatureLabel} - Type name to sign`;
        if (this.readOnly) {
            label = "Signature";
        }
        return label;
    }

    get applicantTypeReadOnlyValue() {
        return this.isApplicant
            ? this.applicantTypeYesLabel.toUpperCase()
            : `${this.labels.BREG_I_am_the.toUpperCase()} ${this.signedByOfficeHeldValue.toUpperCase()} ${this.officeHeldLabel.replace("(office held)", "").trim().toUpperCase()}`;
    }

    get signedByNameSelectorLabel() {
        return this.componentSettings?.signatureLabel == null ? DEFAULT_NAME_SELECTOR_LABEL : `Name of ${this.componentSettings.signatureLabel}`;
    }

    get signedByTitleSelectorLabel() {
        return this.componentSettings?.signatureLabel == null ? DEFAULT_TITLE_SELECTOR_LABEL : `Title of ${this.componentSettings.signatureLabel}`;
    }

    get signedByTitleTextLabel() {
        return this.signedByTitleSelectorValue === "Other" ? `${this.signedByTitleSelectorLabel} (Other)` : this.signedByTitleSelectorLabel;
    }

    get showSignedByType() {
        const showField = "signedByType" in this.targetFieldsMapping && this.isEntityTypeInVisibilityFilter();

        if (!showField && this.signedByTypeValue !== "Individual" && !this.showSignedByApplicantType) {
            this.signedByTypeValue = "Individual";
            this.dispatchCustomEvent("formupdate", { formData: { [CASE_SIGNED_BY_FIELD_API_NAME]: this.signedByTypeValue } });
        }

        return showField;
    }

    get showSignedByApplicantType() {
        return this.targetFieldsMapping && "signedByApplicantType" in this.targetFieldsMapping;
    }

    get showSignedByEntityName() {
        return "signedByEntityName" in this.targetFieldsMapping && (this.signedByTypeValue === "Entity" || !("signedByType" in this.targetFieldsMapping));
    }

    get showSignedByOfficeHeld() {
        return "signedByOfficeHeld" in this.targetFieldsMapping && this.signedByApplicantTypeValue === OFFICE_HELD_API_NAME;
    }

    get showSignedByTitleSelector() {
        return (
            "signedByTitleSelector" in this.targetFieldsMapping && 
            this.signedByTitleSelectorOptions.length > 0 &&
            (
            !this.componentSettings?.titleForEntityOnly ||
            this.signedByTypeValue === "Entity"
            )
            //&& //this.signedByTypeValue === "Entity" ||
            // (this.formCode === "FC-1" || this.formCode === "FLLC-1" || !("signedByType" in this.targetFieldsMapping))
        );
    }

    get showSignedByTitleText() {
        return (
            "signedByTitleText" in this.targetFieldsMapping &&
            (
                !this.componentSettings?.titleForEntityOnly ||
                this.signedByTypeValue === "Entity"
            ) &&
            (
                !this.showSignedByTitleSelector ||
                (this.showSignedByTitleSelector && this.signedByTitleSelectorValue === "Other")
            )
        );
    }

    get showSignedByNameSelector() {
        return "signedByNameSelector" in this.targetFieldsMapping && this.signedByNameSelectorOptions.length > 0;
    }

    get showSignedByNameText() {
        return (
            "signedByNameText" in this.targetFieldsMapping &&
            (!this.showSignedByNameSelector || (this.showSignedByNameSelector && this.signedByNameSelectorValue === "Other")) &&
            (this.signedByApplicantTypeValue === OFFICE_HELD_API_NAME || !this.showSignedByApplicantType || this.componentSettings?.alwaysShowName)
        );
    }

    get showSignedByFullName() {
        return (
            "signedByFirstName" in this.targetFieldsMapping &&
            "signedByLastName" in this.targetFieldsMapping &&
            (!this.showSignedByNameSelector || (this.showSignedByNameSelector && this.signedByNameSelectorValue === "Other")) &&
            (this.signedByApplicantTypeValue === OFFICE_HELD_API_NAME || !this.showSignedByApplicantType || this.componentSettings?.alwaysShowName)
        );
    }

    get showSignature() {
        return (
            "signature" in this.targetFieldsMapping &&
            (this.signedByApplicantTypeValue === OFFICE_HELD_API_NAME || !this.showSignedByApplicantType || this.componentSettings?.alwaysShowSignature)
        );
    }

    get showSignatureHelpTextPopup() {
        return this.showSignature && this.componentSettings?.signatureHelpTextPopup;
    }

    get signatureHelpTextMessage() {
        if (this.componentSettings?.signatureHelpTextPopup) {
            return HELP_TEXT_LABELS[this.componentSettings.signatureHelpTextPopup] || "";
        }
    }

    /*
     * Applicant fields
     */
    get isApplicant() {
        return this.signedByApplicantTypeValue === "Applicant";
    }

    get isNotApplicant() {
        return this.signedByApplicantTypeValue === OFFICE_HELD_API_NAME;
    }

    get applicantTypeLabel() {
        return this.componentSettings?.applicantTypeLabel || "Are you signing as an applicant?";
    }

    get applicantTypeYesLabel() {
        return this.componentSettings?.applicantTypeYesLabel || "I am the applicant.";
    }

    get officeHeldLabel() {
        return this.componentSettings?.officeHeldLabel || "(office held) of the applicant named in the foregoing application.";
    }

    get signedByApplicantTypeReadOnly() {
        return this.readOnly || this.applicantTypeReadOnly;
    }

    get signedByOfficeHeldReadOnly() {
        return this.signedByApplicantTypeValue !== OFFICE_HELD_API_NAME || this.readOnly;
    }

    get signedByFieldsetClass() {
        let cls = "slds-form-element";
        if (this.required && this.showSignedByError) {
            cls += " slds-has-error slds-is-required";
        } else if (this.required) {
            cls += " slds-is-required";
        }
        return cls;
    }

    get requiredSignedByTitleText() {
        return (
            this.required &&
            this.showSignedByTitleText &&
            !(
                this.componentSettings?.optionalSignedByTitleText === true &&
                this.signedByTypeValue === "Individual"
            )
        );
    }


    get showEntityNameLabel() {
        return this.componentSettings?.showEntityNameLabel === true;
    }

    get entityNameLabelValue() {
        return this.companyName || "";
    }

    handleInputBlur(event) {
        super.handleInputBlur(event);

        const inputName = event?.target.dataset.name || event?.target.name;
        if (inputName === "signedByOfficeHeld") {
            this.validateOfficeHeld();
        }
    }

    handleInputChange(event) {
        super.handleInputChange(event);

        const inputName = event.target.dataset.name || event.target.name;
        let value = this.getValueFromEvent(event);

        // Prefill first and last name when member is selected
        if (inputName === "signedByNameSelector") {
            let firstName;
            let lastName;
            if (this.membersMap.has(value)) {
                const member = this.membersMap.get(value);
                firstName = member.firstName;
                lastName = member.lastName;
            }
            this.signedByFirstNameValue = firstName;
            this.signedByLastNameValue = lastName;
            const formData = {
                [this.getFieldName("signedByFirstName")]: firstName,
                [this.getFieldName("signedByLastName")]: lastName
            };
            this.dispatchCustomEvent("formupdate", { formData });
        }

        if (inputName === "signedByApplicantType") {
            this.validateOfficeHeld();
        }
    }

    processFormData() {
        super.processFormData();
        const signedByNameSelectorNames = [];

        if (this.formData.members?.length) {
            this.members = this.formData.members;
        }

        this.signedByNameSelectorOptions = [];
        this.signers = [];

        this.members.forEach((member) => {
            // Set members map
            this.membersMap.set(member.memberName, member);

            // Set member names for selector options
            if (member["breg_Account_Affiliation__c.breg_Role__c"] !== "Agent" && member["breg_Account_Affiliation__c.breg_Type__c"] !== "Entity") {
                if (this.componentSettings?.signedByNameSelectorRolesAndTitlesFilter) {
                    if (this.shouldIncludeSigner(member, this.componentSettings?.signedByNameSelectorRolesAndTitlesFilter)) {
                        signedByNameSelectorNames.push(member.memberName);
                    }
                } else {
                    signedByNameSelectorNames.push(member.memberName);
                }
            }

            // Set signers list based on filter
            if (this.shouldIncludeSigner(member, this.componentSettings?.signersRolesAndTitlesFilter)) {
                this.signers.push(member);
            }
        });

        const uniqueSigners = [...new Set(signedByNameSelectorNames)];
        this.signedByNameSelectorOptions = uniqueSigners
            .filter((signer) => signer && typeof signer === "string" && signer.trim() !== "")
            .map((signer) => {
                return {
                    label: signer.toUpperCase().trim(),
                    value: signer.toUpperCase().trim()
                };
            });

        if (this.signedByNameSelectorOptions.length > 0 && !this.componentSettings?.signedByNameSelectorRolesAndTitlesFilter?.excludeOtherOption) {
            this.signedByNameSelectorOptions.push({ label: "OTHER", value: "Other" });
        }

        this.processApplicantSignature();
        this.applyRestrictedMemberManagerDefault();
    }

    processApplicantSignature() {
        if (!this.showSignedByApplicantType) return;
        if (this.componentSettings?.alwaysShowName) return; // used for T-4 form to do not lock signature fields

        const applicant = this.members?.find((member) => {
            return member["breg_Account_Affiliation__c.breg_Role__c"] === "Applicant";
        });

        if (!applicant) return;

        const applicantType = applicant.memberType;
        const applicantEntityType = applicant.TNTMSMEntityType;

        const firstName = applicant.firstName;
        const lastName = applicant.lastName;
        const fullName = applicant.memberName;

        const applicantTypeFieldName = this.getFieldName("signedByApplicantType");
        const applicantNameFieldName = this.getFieldName("signedByApplicantName");
        const firstNameFieldName = this.getFieldName("signedByFirstName");
        const lastNameFieldName = this.getFieldName("signedByLastName");
        const signatureFieldName = this.getFieldName("signature");
        const signedByOfficeHeldFieldName = this.getFieldName("signedByOfficeHeld");

        let formData = {};
        let sendEvent = false;

        const switchedFromApplicantToEntity = this.previousApplicantMemberType === "Individual" && applicantType === "Entity";

        if (applicantType === "Individual") {
            this.signedByApplicantTypeValue = "Applicant";
            this.applicantTypeDescription = BREG_Applicant_Individual_Signature_Description;
            this.applicantTypeReadOnly = true;

            this.previousApplicantMemberType = "Individual";

        } else if (applicantType === "Entity") {

            this.applicantTypeDescription = SIGNATURE_APPLICANT_DESCRIPTIONS_BY_TYPE[applicantEntityType] || "";

            if (applicantEntityType !== "Other") {
                this.signedByApplicantTypeValue = OFFICE_HELD_API_NAME;
                this.applicantTypeReadOnly = true;
            } else {
                this.applicantTypeReadOnly = false;
            }

            if (switchedFromApplicantToEntity) {
                formData = {
                    [firstNameFieldName]: null,
                    [lastNameFieldName]: null,
                    [signatureFieldName]: null,
                    [applicantNameFieldName]: null,
                    [signedByOfficeHeldFieldName]: null
                };
                sendEvent = true;
            }

            this.previousApplicantMemberType = "Entity";

        } else {
            this.applicantTypeReadOnly = false;
        }

        if (applicantTypeFieldName && this.formData[applicantTypeFieldName] !== this.signedByApplicantTypeValue) {
            formData[applicantTypeFieldName] = this.signedByApplicantTypeValue;
            formData[signedByOfficeHeldFieldName] = null;
            this.signedByOfficeHeldValue = null;
            sendEvent = true;
        }

        if (applicantNameFieldName && this.formData[applicantNameFieldName] !== fullName && this.signedByApplicantTypeValue === "Applicant") {
            formData = {
                [applicantNameFieldName]: fullName,
                [firstNameFieldName]: firstName,
                [lastNameFieldName]: lastName,
                [signatureFieldName]: fullName
            };
            sendEvent = true;
        }

        if (sendEvent) {
            this.dispatchCustomEvent("formupdate", { formData });
        }
    }

    applyRestrictedMemberManagerDefault() {
        if (this.componentSettings?.restrictMemberManagerTitle !== true) { 
            return;
        }

        const isManagerManaged = this.formData?.["Case.breg_Is_Manager_Managed__c"];
        if (isManagerManaged === undefined || isManagerManaged === null) {
            return;
        }

        const defaultTitle = isManagerManaged ? MANAGER_TITLE : MEMBER_TITLE;

        if (this.signedByTitleSelectorValue === defaultTitle) {
            return;
        }

        this.signedByTitleSelectorValue = defaultTitle;

        const fieldName = this.getFieldName("signedByTitleSelector");
        if (fieldName) {
            this.dispatchCustomEvent("change", {field: fieldName, value: defaultTitle});
        }
    }

    shouldIncludeSigner(member, filter) {
        if (!member?.memberName?.trim() || !filter) {
            return false;
        }

        try {
            const rolesTitlesFilter = typeof filter === "string" ? JSON.parse(filter) : filter;
            const memberRole = member["breg_Account_Affiliation__c.breg_Role__c"];
            const memberTitle = member["breg_Account_Affiliation__c.breg_Officer_Director_Titles_Formula__c"];

            // Check if the role is in the filter
            if (!(memberRole in rolesTitlesFilter)) {
                return false;
            }

            const allowedTitles = rolesTitlesFilter[memberRole];

            // If array is empty, include all members with that role
            if (!allowedTitles || allowedTitles.length === 0) {
                return true;
            }

            // If array has titles, check if member's title matches
            return allowedTitles.includes(memberTitle);
        } catch (error) {
            console.error("Error in shouldIncludeSigner:", error.message);
            return false;
        }
    }

    isEntityTypeInVisibilityFilter() {
        const filter = this.componentSettings?.signedByTypeVisibilityFilterByEntityType;
        if (!filter) {
            return true; // If no filter, show by default
        }

        try {
            const allowedEntityTypes = filter.split(";").map((type) => type.trim());
            return allowedEntityTypes.includes(this.entityType);
        } catch (error) {
            console.error("Error in isEntityTypeInVisibilityFilter:", error);
            return true;
        }
    }

    getTitlesByEntityType(entityType) {
        if (!entityType) {
            return [];
        }

        const titles = Object.keys(ENTITY_TYPES_BY_TITLE)
            .filter((title) => {
                const entityTypes = ENTITY_TYPES_BY_TITLE[title];
                return entityTypes.split(",").includes(entityType);
            })
            .map((title) => ({
                label: title.toUpperCase(),
                value: title
            }));

        return titles;
    }

    handleChangeSigner(event) {
        const member = event.detail.value.member;
        if (!member) return;

        const memberIndex = this.members.findIndex((m) => m.uniqueKey === member.uniqueKey);
        if (memberIndex !== -1) {
            // Create a new array to trigger reactivity
            const updatedMembers = [...this.members];
            updatedMembers[memberIndex] = { ...updatedMembers[memberIndex], ...member };
            this.members = updatedMembers;
        }
        const formData = {};
        formData.members = this.members;
        this.dispatchCustomEvent("formupdate", { formData });
    }

    validateApplicantType() {
        let isValid = true;
        if (this.showSignedByApplicantType && !this.signedByApplicantTypeValue) {
            isValid = false;
            this.showSignedByError = true;
        } else {
            this.showSignedByError = false;
        }
        return isValid;
    }

    validateOfficeHeld() {
        let isValid = true;
        const officeHeldInput = this.template.querySelector('[data-name="signedByOfficeHeld"]');

        if (!officeHeldInput) return isValid;

        officeHeldInput.setCustomValidity("");

        if (this.signedByApplicantTypeValue === OFFICE_HELD_API_NAME && !this.signedByOfficeHeldValue) {
            console.log("**** Setting custom validity for signedByOfficeHeld", this.signedByApplicantTypeValue, this.signedByOfficeHeldValue);
            officeHeldInput.setCustomValidity("Complete this field.");
            isValid = false;
        }
        officeHeldInput.reportValidity();
        return isValid;
    }

    reportValidity() {
        const baseValid = super.reportValidity();

        const officeHeldValid = this.validateOfficeHeld();
        const applicantTypeValid = this.validateApplicantType();

        return baseValid && officeHeldValid && applicantTypeValid;
    }
}