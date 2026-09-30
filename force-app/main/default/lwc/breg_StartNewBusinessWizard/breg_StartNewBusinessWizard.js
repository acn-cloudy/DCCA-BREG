import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { publish, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";
import { navigateToPage, getPageParamsFromUrl, capitalizeFirstLetter, setFormData } from "c/utils";
import getUserInfo from "@salesforce/apex/BREGPortalUtils.getUserInfo";
import getCaseWithRelations from "@salesforce/apex/BREGPortalUtils.getCaseWithRelations";
import getFormConfiguration from "@salesforce/apex/BREGPortalUtils.getFormConfiguration";
import getGP1Form from "@salesforce/apex/BREGPortalUtils.getGP1Form";
import updateCaseSubscriptionCheckbox from "@salesforce/apex/BREGCaseControllerWithoutSharing.updateCaseSubscriptionCheckbox";
import downloadDocument from "@salesforce/apex/BREGPaymentController.downloadDocument";
import { createDownloadLink } from "c/utils";
import BREG_Form_Saved_Successfully from "@salesforce/label/c.BREG_Form_Saved_Successfully";

import LEARN_MORE_PROFIT_NON_PROFIT from "@salesforce/label/c.BREG_StartNewBusinessWizard_LearnMore_ProfitNonProfit";
import LEARN_MORE_TNTMSM from "@salesforce/label/c.BREG_StartNewBusinessWizard_LearnMore_TNTMSM";
import LEARN_MORE_CONTACT_INFO from "@salesforce/label/c.BREG_StartNewBusinessWizard_LearnMore_ContactInfo";
import LEARN_MORE_RESERVATION_OF_NAME from "@salesforce/label/c.BREG_StartNewBusinessWizard_LearnMore_ReservationOfName";

const INITIAL_UPLOAD_NAME_PREFIX = "For Initial: ";
const INVALID_ENTITY_TYPE_VALUES = new Set(["r7", "other"]);
// This regex is used to parse the uploaded document name to determine if it's associated with a specific form 
// section (e.g., Initial Information) and to extract the actual file name and the upload target section.
const NESTED_UPLOAD_NAME_PATTERN = /^For Initial: \[([^\]]+)\] (.+)$/;

function parseUploadedDocumentName(name) {
    const taggedNameMatch = name?.match(NESTED_UPLOAD_NAME_PATTERN);
    if (taggedNameMatch) {
        return {
            fileName: taggedNameMatch[2],
            uploadTarget: taggedNameMatch[1]
        };
    }

    if (name?.startsWith(INITIAL_UPLOAD_NAME_PREFIX)) {
        return {
            fileName: name.substring(INITIAL_UPLOAD_NAME_PREFIX.length),
            uploadTarget: undefined
        };
    }

    return {
        fileName: name,
        uploadTarget: undefined
    };
}

export default class Breg_StartNewBusinessWizard extends NavigationMixin(LightningElement) {
    @api isInternal = false;
    @track componentProperties = {};
    @track formData;
    @track formConfiguration;
    formCode;
    isLoading = false;
    whatIsThisForm;
    learnMoreProfitNonProfit = LEARN_MORE_PROFIT_NON_PROFIT;
    learnMoreTntmsm = LEARN_MORE_TNTMSM + LEARN_MORE_CONTACT_INFO;

    // URL params
    section;
    caseId;
    parentCaseId;
    accountId;
    tntmsmId;
    formConfigId;
    readOnly;
    shouldSetRecordId;
    formSuffix;
    formAction;
    gpCaseId;

    // Initial Information fields
    businessProcessValue;
    businessLocationValue;
    businessStructureValue;
    businessProfitValue;
    registrationTypeValue;
    corporationTypeValue;
    cooperativeTypeValue;
    stockTypeValue;
    partnershipTypeValue;
    gpRegisteredValue;
    gpNameValue;

    currentStep = "Initial Information";
    _isNotGuest = false;
    caseRecord;
    companyName;
    entityType;
    entityTypeForFees;
    registrationType;
    residenceCountry;
    dynamicFormsComponent;

    dependentFieldsMappingToReset = {
        businessStructure: ["businessProfit", "corporationType", "cooperativeType", "stockType", "partnershipType", "gpRegistered", "gpName"],
        businessProcess: [
            "businessLocation",
            "businessStructure",
            "businessProfit",
            "registrationType",
            "corporationType",
            "cooperativeType",
            "stockType",
            "partnershipType",
            "gpRegistered",
            "gpName"
        ],
        businessLocation: ["businessStructure", "corporationType", "cooperativeType", "stockType", "partnershipType", "gpRegistered", "gpName"],
        businessProfit: ["corporationType"],
        gpRegistered: ["gpName"]
    };

    get isNotGuest() {
        if (this.isInternal) return true;
        return this._isNotGuest;
    }

    businessProcessOptions = [
        {
            label: "I would like to register a new business in Hawaii with the Business Registration Division, Department of Commerce and Consumer Affairs",
            value: "New Business"
        },
        {
            label: "I would like to reserve a business name, to hold a name temporarily for 120 days",
            value: "Name Reservation",
            action: {
                type: "modal",
                prefix: "",
                label: "Tell me more",
                suffix: "",
                header: "Reservation of Name",
                body: LEARN_MORE_RESERVATION_OF_NAME
            }
        },
        {
            label: "I would like to register a trade name, trademark, service mark or publicity rights",
            value: "Name Registration",
            action: {
                type: "link",
                prefix: "(Renewing? Visit ",
                label: "Manage",
                suffix: ")",
                url: "/manage"
            }
        }
    ];

    businessLocationOptions = [
        { label: "Yes, it is based in Hawaii", value: "Domestic" },
        { label: "No, it is based outside of Hawaii", value: "Foreign" }
    ];

    get businessStructureOptions() {
        let businessStructureOptions = [
            { label: "Corporation", value: "Corporation" },
            { label: "General Partnership", value: "General Partnership" },
            { label: "Limited Liability Company", value: "Limited Liability Company" },
            { label: "Limited Liability Partnership", value: "Limited Liability Partnership" },
            { label: "Limited Partnership", value: "Limited Partnership" }
        ];
        /*if (this.businessLocationValue === "Domestic") {
            businessStructureOptions.unshift({ label: "Cooperative", value: "Cooperative" });
        }*/ //hidden option to create AG-1 and CONS-1 businesses from the portal according to BREG-4453
        return businessStructureOptions;
    }

    profitOptions = [
        { label: "For profit", value: "For profit" },
        { label: "Non-profit", value: "Non-profit" }
    ];

    registrationTypeOptions = [
        { label: "Trade Name", value: "Trade Name" },
        { label: "Trademark", value: "Trademark" },
        { label: "Service Mark", value: "Service Mark" },
        { label: "Publicity Rights Name", value: "Publicity Rights Name" }
    ];

    get corporationTypeOptions() {
        let options = [];
        if (this.businessProfitValue === "For profit") {
            options = [
                { label: "Profit Corporation", value: "General Profit Corporation" },
                { label: "Professional Corporation", value: "Professional Corporation" },
                { label: "Sustainable Business Corporation", value: "Sustainable Business Corporation" }
            ];
        } else if (this.businessProfitValue === "Non-profit") {
            options = [
                { label: "General Nonprofit Corporation", value: "General Nonprofit Corporation" },
                { label: "Corporation Sole", value: "Corporation Sole" }
            ];
        }
        return options;
    }

    cooperativeTypeOptions = [
        { label: "Agricultural Cooperative", value: "Agricultural Cooperative" },
        { label: "Consumer Cooperative", value: "Consumer Cooperative" }
    ];

    stockTypeOptions = [
        { label: "With Stock", value: "With Stock" },
        { label: "Without Stock", value: "Without Stock" }
    ];

    get partnershipTypeOptions() {
        let options = [];
        if (this.businessLocationValue === "Domestic") {
            options = [
                { label: "Domestic Limited Partnership", value: "Domestic Limited Partnership" },
                { label: "Domestic Limited Liability Limited Partnership", value: "Domestic Limited Liability Limited Partnership" }
            ];
        } else if (this.businessLocationValue === "Foreign") {
            options = [
                { label: "Foreign Limited Partnership", value: "Foreign Limited Partnership" },
                { label: "Foreign Limited Liability Limited Partnership", value: "Foreign Limited Liability Limited Partnership" }
            ];
        }
        return options;
    }

    get gpRegisteredOptions() {
        return [
            { label: "Yes", value: "Yes" },
            { label: "No", value: "No" }
        ];
    }

    get showRequiredInformation() {
        return this.requiredInformation != null && this.requiredInformation !== "";
    }

    get showBusinessLocationSelector() {
        return this.businessProcessValue === "New Business";
    }

    get showTradeNameSelector() {
        return this.businessProcessValue === "Name Registration";
    }

    get showBusinessStructureSelector() {
        return this.businessLocationValue !== undefined;
    }

    get showBusinessProfitSelector() {
        return this.businessStructureValue === "Corporation";
    }

    get showCorporationTypeSelector() {
        return this.businessStructureValue === "Corporation" && this.businessLocationValue === "Domestic" && this.businessProfitValue === "For profit";
    }

    get disabledCorporationTypeSelector() {
        return !this.businessProfitValue;
    }

    get showCooperativeTypeSelector() {
        return this.businessStructureValue === "Cooperative" && this.businessLocationValue === "Domestic";
    }

    get showStockTypeSelector() {
        return !!this.cooperativeTypeValue;
    }

    get showPartnershipTypeSelector() {
        return this.businessStructureValue === "Limited Partnership";
    }

    get showGPRegisteredSelector() {
        return this.businessStructureValue === "Limited Liability Partnership";
    }

    get showGPName() {
        return this.gpRegisteredValue === "Yes";
    }

    get showBackButton() {
        return this.steps.indexOf(this.currentStep) > 0;
    }

    get needToFillLLPForm() {
        return this.formCode === "GP-1" && this.gpRegisteredValue === "No";
    }

    get isGpAndLlpRegistration() {
        return this.gpCaseId || this.caseRecord?.breg_GP_Case__c;
    }

    get confirmButtonLabel() {
        return this.needToFillLLPForm ? `Continue to ${this.businessLocationValue === "Domestic" ? "LLP-1 " : "FLLP-1 "} form` : "Confirm";
    }

    get continueButtonDisabled() {
        let isDisabled = true;

        if (this.businessProcessValue === "New Business") {
            if (this.businessLocationValue === "Domestic") {
                if (this.businessStructureValue === "Corporation") {
                    // DNP-1
                    if (this.businessProfitValue === "Non-profit") {
                        isDisabled = false;
                    } // DC-1 | PC-1 | SBC-1
                    else if (this.businessProfitValue === "For profit" && this.corporationTypeValue) {
                        isDisabled = false;
                    }
                } else if (this.businessStructureValue === "Cooperative") {
                    // AG-1 | CONS-1
                    if (this.cooperativeTypeValue && this.stockTypeValue) {
                        isDisabled = false;
                    }
                } else if (this.businessStructureValue === "Limited Partnership") {
                    // LP-1
                    if (this.partnershipTypeValue) {
                        isDisabled = false;
                    }
                } else if (this.businessStructureValue === "Limited Liability Partnership") {
                    // LLP-1
                    if (this.gpRegisteredValue === "No" || (this.gpRegisteredValue === "Yes" && this.gpNameValue)) {
                        isDisabled = false;
                    }
                    // GP-1 | LLC-1
                } else if (this.businessStructureValue) {
                    isDisabled = false;
                }
            } else if (this.businessLocationValue === "Foreign") {
                if (this.businessStructureValue === "Corporation") {
                    // FC-1 (profit/non-profit)
                    if (this.businessProfitValue) {
                        isDisabled = false;
                    }
                } else if (this.businessStructureValue === "Limited Partnership") {
                    // FLP-1
                    if (this.partnershipTypeValue) {
                        isDisabled = false;
                    }
                } else if (this.businessStructureValue === "Limited Liability Partnership") {
                    // FLLP-1
                    if (this.gpRegisteredValue === "No" || (this.gpRegisteredValue === "Yes" && this.gpNameValue)) {
                        isDisabled = false;
                    }
                    // GP-1 | FLLC-1
                } else if (this.businessStructureValue) {
                    isDisabled = false;
                }
            }
            // X-1
        } else if (this.businessProcessValue === "Name Reservation") {
            isDisabled = false;
        } else if (this.businessProcessValue === "Name Registration") {
            // T-1 | T-2 | T-3
            if (this.registrationTypeValue) {
                isDisabled = false;
            }
        }

        return isDisabled;
    }

    steps = ["Initial Information", "Form Filling", "Form Review", "Forms and Fees"];

    get initialInformationStep() {
        return this.currentStep === "Initial Information";
    }

    get formDataStep() {
        return this.currentStep === "Form Filling" || this.currentStep === "Form Review";
    }

    get formFillingStep() {
        return this.currentStep === "Form Filling";
    }

    get showSaveDraftButton() {
        return this.formCode !== "WD";
    }

    get formReviewStep() {
        return this.currentStep === "Form Review";
    }

    get formsAndFeesStep() {
        return this.currentStep === "Forms and Fees";
    }

    get showTabs() {
        return !this.isInternal;
    }

    get dynamicFormsHeaderDescription() {
        let description = "";
        if (this.formReviewStep) {
            description = `
                1. Review your filing information below for accuracy.<br/>
                2. If you need to edit anything, you may go back now.<br/>
                3. Before proceeding, you will certify that the contact information is correct.
            `;
        } else {
            description = `Please read and complete all sections of this form. You may also save the form at any time to resume later. Please go to <a href="/my-dashboard">My Dashboard</a> to access the saved version of your work after you exit an unfinished form. The form will be checked for completeness upon submission.`;
        }
        return description;
    }

    get showResubmissionDueDateDescription() {
        return this.caseRecord?.Status === "Rejected" && this.caseRecord?.breg_Resubmission_Due_Date__c;
    }

    get resubmissionDueDateDescription() {
        const resubmissionDueDate = this.caseRecord?.breg_Resubmission_Due_Date__c;
        if (this.caseRecord?.Status === "Rejected" && resubmissionDueDate) {
            const date = new Date(resubmissionDueDate).toLocaleDateString("en-US", {
                month: "short",
                day: "2-digit",
                year: "numeric"
            });
            return `Resubmission Due Date: ${date}`;
        }
        return "";
    }

    get dynamicFormsHeaderTitle() {
        return "Initial Business Filing";
    }

    get files() {
        return (
            this.caseRecord?.Documents__r?.map((doc) => {
                const { fileName, uploadTarget } = parseUploadedDocumentName(doc.Name);
                return {
                    fileName,
                    fileType: doc.breg_Type__c,
                    id: doc.Id,
                    configId: doc.breg_Form_Configuration_Item__c,
                    uploadTarget
                };
            }) || []
        );
    }

    get stepsWithWhatIsITForm() {
        return this.formDataStep || this.formsAndFeesStep;
    }

    get isReviewMode() {
        return this.formDataStep && !this.formFillingStep;
    }

    get signatureConfirmDesc() {
        const el = this.formConfiguration?.elements?.find((e) => e?.name === "Signature");
        return el?.componentSettings ? (JSON.parse(el.componentSettings).signatureConfirmDesc ?? null) : null;
    }

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.setVarsFromUrlParams();

        if (this.section === "help") {
            this.activeTab = "help";
        }

        if (this.caseId) {
            this.processFormFromCase();
            this.currentStep = "Form Filling";
        } else {
            this.formData = {};
        }

        if (this.formConfigId && !this.caseId) {
            this.loadFormConfiguration();
            this.setFormConfigPropertiesFromRecord();
            this.currentStep = "Form Filling";
        }

        if (this.readOnly) {
            this.currentStep = "Form Review";
        }

        this.fetchUserInfo();

        this.componentProperties = {
            readOnly: this.readOnly,
            isInternal: this.isInternal
        };
    }

    async processFormFromCase() {
        await this.loadCaseRecord();

        if (this.caseRecord?.breg_Form_Configuration__c && !this.formConfigId) {
            this.formConfigId = this.caseRecord.breg_Form_Configuration__c;
        }

        await this.loadFormConfiguration();

        this.setFormConfigPropertiesFromRecord();

        const formData = setFormData({
            formConfiguration: this.formConfiguration,
            record: this.caseRecord,
            useSourceFieldsMapping: false,
            shouldSetRecordId: this.shouldSetRecordId
        });

        this.setDefaultValuesOnFormData(formData);
        this.formData = { ...formData };
        this.entityTypeForFees = this.resolveEntityType(this.formData);

        // Set gpRegisteredValue = No, to force filling out LLP-1/FLLP-1 if GP-1 is loaded from the case and LLP is not yet registered.
        if (this.formCode === "GP-1" && this.caseRecord?.breg_Is_LLP_Registration__c === true) {
            this.gpRegisteredValue = "No";
        }

        if (this.formCode === "LLP-1" || this.formCode === "FLLP-1") {
            if (this.caseRecord?.breg_GP_Already_Registered__c) {
                this.gpRegisteredValue = "Yes";
                this.gpNameValue = this.caseRecord?.breg_GP_Entity_Name__c;
            }
        }

        if (this.needToFillLLPForm) {
            this.businessStructureValue = "Limited Liability Partnership";
            this.setComponentProperties("needToFillLLPForm", true);
        } else {
            if (this.componentProperties?.needToFillLLPForm) {
                this.setComponentProperties("needToFillLLPForm", false);
            }
        }
    }

    async loadCaseRecord() {
        if (!this.caseId) {
            console.warn("** caseId is not set, skipping loadCaseRecord");
            return;
        }
        try {
            this.setSpinner(true);
            this.caseRecord = await getCaseWithRelations({ caseId: this.caseId });
            console.info("loaded case record", { ...this.caseRecord });
        } catch (error) {
            console.error("Error fetching case record", error);
        }
        this.setSpinner(false);
    }

    async loadFormConfiguration() {
        try {
            this.setSpinner(true);
            const formConfiguration = await getFormConfiguration({
                formConfigId: this.formConfigId,
                businessProcess: this.businessProcessValue,
                businessLocation: this.businessLocationValue,
                businessStructure: this.businessStructureValue,
                businessProfit: this.businessProfitValue,
                registrationType: this.registrationTypeValue,
                corporationType: this.corporationTypeValue,
                cooperativeType: this.cooperativeTypeValue,
                stockType: this.stockTypeValue,
                partnershipType: this.partnershipTypeValue,
                formSuffix: this.formSuffix
            });
            console.log(
                `** load config for type: 
                    ${this.businessProcessValue} 
                    location: ${this.businessLocationValue} 
                    structure: ${this.businessStructureValue}
                    profit: ${this.businessProfitValue}
                    corporation: ${this.corporationTypeValue}
                    cooperative: ${this.cooperativeTypeValue}
                    stock: ${this.stockTypeValue}
                    partnership: ${this.partnershipTypeValue}
                `
            );
            this.formConfiguration = formConfiguration;
            this.formCode = formConfiguration.formCode;
            this.whatIsThisForm = formConfiguration.whatIsThisForm;
            this.requiredInformation = formConfiguration.requiredInformation;
            //console.log("** loaded form configuration:", JSON.stringify(formConfiguration));
        } catch (error) {
            console.error("*** loadFormConfiguration error:", error);
        }
        this.setSpinner(false);
    }

    async fetchUserInfo() {
        try {
            const result = await getUserInfo();
            this._isNotGuest = !result.isGuest;
            if (this._isNotGuest) {
                this.userName = result.name;
            }
        } catch (error) {
            console.error("Error fetching user info", error);
        }
    }

    handleInputChange(event) {
        const inputName = event.target.name;
        this[`${inputName}Value`] = event.detail.value;
        this.resetDependentFieldsValue(inputName);

        if (inputName === "gmRegistered") {
            this.formData = undefined;
            this.formConfiguration = undefined;
        }
    }

    handleFormDataChange(event) {}

    handleSaveForm(event) {
        this.caseId = event?.detail?.value?.caseId;
        const formData = event?.detail?.value?.formData;
        this.formData = { ...formData };
        // console.log("*** handleSaveForm formData:", JSON.stringify(this.formData));

        let companyName;
        if (this.formData["Case.breg_Form_Code__c"] === "X-11") {
            const regAgentType = this.formData["Case.breg_Reg_Agent_Type__c"];
            if (regAgentType === "Individual") {
                companyName = this.formData["Case.breg_Reg_Agent_First_Name__c"] + " " + this.formData["Case.breg_Reg_Agent_Last_Name__c"];
            } else {
                companyName = this.formData["Case.breg_Reg_Agent_Entity_Name__c"];
            }
        } else {
            companyName = this.formData["Case.breg_Name_of_the_Entity__c"] ?? this.formData["Case.breg_TNTMSM_Description__c"] ?? this.formData["Case.breg_Name_for_Reservation__c"];
        }

        this.companyName = companyName;
        this.entityType = this.formData["Case.breg_Entity_Type__c"] ?? this.formData["Case.breg_New_Entity_Type__c"];
        this.entityTypeForFees = this.resolveEntityType(this.formData);
        this.registrationType = this.formData["Case.breg_TNTMSM_Registration_Type__c"];
        this.residenceCountry = this.formData["Case.breg_Company_Address__CountryCode__s"];
        this.companyDateFormedOn = this.formData["Case.breg_Date_Of_Formation__c"];

        // Set accountId and tntmsmId from formData if not already set
        if (!this.accountId && this.formData["Case.breg_Portal_User_Entity_Selected__c"]) {
            this.accountId = this.formData["Case.breg_Portal_User_Entity_Selected__c"];
        }
        if (!this.tntmsmId && this.formData["Case.breg_TN_TM_SM__c"]) {
            this.tntmsmId = this.formData["Case.breg_TN_TM_SM__c"];
        }

        // console.log("*** handleSaveForm");
        // console.log("*** caseId:", this.caseId);
        // console.log("*** companyName:", this.companyName);
        // console.log("*** accountId:", this.accountId);
        // console.log("*** tntmsmId:", this.tntmsmId);
        // console.log("*** registrationType:", this.registrationType);
        // console.log("*** residenceCountry:", this.residenceCountry);
        // console.log("*** companyDateFormedOn:", this.companyDateFormedOn);
    }

    getValidEntityType(value) {
        if (!value) {
            return undefined;
        }

        const normalizedValue = value.trim();
        if (!normalizedValue) {
            return undefined;
        }

        return INVALID_ENTITY_TYPE_VALUES.has(normalizedValue.toLowerCase()) ? undefined : normalizedValue;
    }

    resolveEntityType(formData, ...additionalCandidates) {
        return [
            formData["Case.breg_Entity_Type__c"],
            formData["Case.breg_New_Entity_Type__c"],
            formData["Account.breg_Entity_Type__c"],
            formData["Account.breg_Reserved_for_Entity_Type__c"],
            ...additionalCandidates
        ].find((value) => this.getValidEntityType(value));
    }

    /**
     * Helpers
     **/

    resetDependentFieldsValue(inputName) {
        const mapping = this.dependentFieldsMappingToReset[inputName];
        if (!mapping || mapping.length === 0) return;

        mapping.forEach((inputNameToRest) => {
            this[`${inputNameToRest}Value`] = undefined;
        });
    }

    resetAllFields() {
        this.businessProcessValue = undefined;
        this.businessLocationValue = undefined;
        this.businessStructureValue = undefined;
        this.businessProfitValue = undefined;
        this.corporationTypeValue = undefined;
        this.cooperativeTypeValue = undefined;
        this.stockTypeValue = undefined;
        this.partnershipTypeValue = undefined;
        this.gpRegisteredValue = undefined;
        this.gpNameValue = undefined;
        this.formConfiguration = undefined;
        this.caseId = undefined;
        this.companyName = undefined;
        this.entityType = undefined;
        this.residenceCountryName = undefined;
        this.companyDateFormedOn = undefined;
        this.currentStep = this.steps[0];
        this.formData = {};
        this.scrollToTop();
    }

    setVarsFromUrlParams() {
        const { section, caseId, parentCaseId, formConfigId, readOnly, shouldSetRecordId, formSuffix, accountId, formAction, tntmsmId, gpCaseId } =
            getPageParamsFromUrl();
        if (section !== undefined) this.section = section;
        if (caseId !== undefined) this.caseId = caseId;
        if (parentCaseId !== undefined) this.parentCaseId = parentCaseId;
        if (accountId !== undefined) this.accountId = accountId;
        if (tntmsmId !== undefined) this.tntmsmId = tntmsmId;
        if (formConfigId !== undefined) this.formConfigId = formConfigId;
        if (readOnly !== undefined) this.readOnly = readOnly;
        if (shouldSetRecordId !== undefined) this.shouldSetRecordId = shouldSetRecordId;
        if (formSuffix !== undefined) this.formSuffix = formSuffix;
        if (formAction !== undefined) this.formAction = formAction;
        if (gpCaseId !== undefined) this.gpCaseId = gpCaseId;
    }

    setDefaultValuesOnFormData(formData) {
        if (this.parentCaseId) {
            formData["Case.ParentId"] = this.parentCaseId;
        }
        if (this.accountId) {
            formData["Case.breg_Portal_User_Entity_Selected__c"] = this.accountId;
        }
        if (this.tntmsmId) {
            formData["Case.breg_TN_TM_SM__c"] = this.tntmsmId;
        }

        if (this.gpRegisteredValue === "Yes") {
            formData["Case.breg_GP_Already_Registered__c"] = true;
            formData["Case.breg_GP_Entity_Name__c"] = this.gpNameValue;
            if (!formData["Case.breg_Name_of_the_Entity__c"]) {
                formData["Case.breg_Name_of_the_Entity__c"] = this.gpNameValue;
            }
        }

        if (this.gpRegisteredValue && this.formCode !== "LLP-1" && this.formCode !== "FLLP-1") {
            formData["Case.breg_Is_LLP_Registration__c"] = true;
        }

        if (this.gpCaseId) {
            formData["Case.breg_GP_Case__c"] = this.gpCaseId;
        }

        if (this.formAction) {
            if (this.formAction === "resubmit") {
                formData["Case.breg_Form_Action__c"] = "Resubmit";
            } else if (this.formAction === "reopen") {
                formData["Case.breg_Form_Action__c"] = "Reopen";
            } else if (this.formAction === "remove") {
                formData["Case.breg_Form_Action__c"] = "Remove";
            }
        }
    }

    findDynamicFormsComponent() {
        this.dynamicFormsComponent = this.template.querySelector("c-breg_-registration-dynamic-form");
    }

    scrollToTop() {
        window.scrollTo({ top: 0, behavior: "smooth" });
    }

    setFormConfigPropertiesFromRecord() {
        if (this.formConfiguration) {
            this.businessProcessValue = this.formConfiguration.businessProcess;
            this.businessLocationValue = this.formConfiguration.businessLocation;
            this.businessStructureValue = this.formConfiguration.businessStructure;
            this.businessProfitValue = this.formConfiguration.businessProfit;
            this.registrationTypeValue = this.formConfiguration.registrationType;
            this.corporationTypeValue = this.formConfiguration.corporationType;
            this.cooperativeTypeValue = this.formConfiguration.cooperativeType;
            this.stockTypeValue = this.formConfiguration.stockType;
            this.partnershipTypeValue = this.formConfiguration.partnershipType;
        }
    }

    setStep(stepChange) {
        const currentIndex = this.steps.indexOf(this.currentStep);
        if (currentIndex !== -1) {
            const newIndex = currentIndex + stepChange;
            // Make sure the new index is within bounds
            if (newIndex >= 0 && newIndex < this.steps.length) {
                this.currentStep = this.steps[newIndex];
            } else {
                this.currentStep = this.steps[0];
            }
            this.scrollToTop();
        }

        // Update readOnly based on the current step
        this.setComponentProperties("readOnly", this.currentStep === "Form Review");

        console.log("*** current step:", this.currentStep);
    }

    setComponentProperties(property, value) {
        this.componentProperties[property] = value;
        this.componentProperties = { ...this.componentProperties };
    }

    setSpinner(isVisible) {
        if (isVisible !== undefined) {
            this.isLoading = isVisible;
        } else {
            this.isLoading = !this.isLoading;
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

    /**
     * Button Handlers
     **/

    handleContinue() {
        // By setting the formSuffix here, the loadFormConfiguration method will select GP-1 instead of LLP-1/FLLP-1, because GP-1 must be filled out first.
        if (this.gpRegisteredValue === "No") {
            if (this.businessLocationValue === "Domestic") {
                this.formSuffix = "G5";
            } else {
                this.formSuffix = "G6";
            }
            this.setComponentProperties("needToFillLLPForm", true);
        } else {
            if (this.componentProperties?.needToFillLLPForm) {
                this.setComponentProperties("needToFillLLPForm", false);
            }
            this.formSuffix = undefined;
        }

        // DNP-1, explicitly set the form suffix so SOLE-1 is not loaded
        if (this.businessStructureValue === "Corporation" && this.businessLocationValue === "Domestic" && this.businessProfitValue === "Non-profit") {
            this.formSuffix = "D2";
        }

        // Pre-populate some fields on GP or LLP form
        if (this.gpRegisteredValue) {
            const formData = { ...(this.formData || {}) };
            this.setDefaultValuesOnFormData(formData);
            this.formData = { ...formData };
        }

        this.loadFormConfiguration();
        this.setStep(1);
    }

    async handleSaveAndNew() {
        this.findDynamicFormsComponent();
        const saveResult = await this.dynamicFormsComponent.saveForm();
        if (saveResult) {
            this.showToast("Success", BREG_Form_Saved_Successfully, "success");
            this.resetAllFields();
        }
    }

    async handleSave() {
        this.findDynamicFormsComponent();
        const savedSuccessfully = await this.dynamicFormsComponent.saveForm();
        if (savedSuccessfully) {
            this.showToast("Success", BREG_Form_Saved_Successfully, "success");
            if (this.isInternal) {
                this.navigateToRecord();
            }
        }
    }

    async handleSaveDraft() {
        this.findDynamicFormsComponent();
        const savedSuccessfully = await this.dynamicFormsComponent.saveForm(true);
        if (savedSuccessfully) {
            this.showToast("Success", BREG_Form_Saved_Successfully, "success");
            navigateToPage("/my-dashboard");
        }
    }

    async handleReview() {
        this.findDynamicFormsComponent();
        //console.log("Form handleReview:", JSON.stringify(this.formData));
        const formValid = await this.dynamicFormsComponent.validateForm();
        if (formValid) {
            const savedSuccessfully = await this.dynamicFormsComponent.saveForm();
            if (savedSuccessfully) {
                this.showToast("Success", BREG_Form_Saved_Successfully, "success");
                this.setStep(1);
            }
        }
    }

    async handlePayNow(event) {
        const cartTotalPrice = event.detail.cartTotalPrice;
        const sendFreeReminder = event.detail.sendFreeReminder;

        this.isLoading = true;
        try {
            await updateCaseSubscriptionCheckbox({ caseId: this.caseId, subscriptionCheckbox: sendFreeReminder });

            if (cartTotalPrice > 0) {
                navigateToPage("/cart", {});
            } else {
                window.location.href = "/checkout?page=checkout";
            }
        } catch (error) {
            console.error("Error updating case subscription:", error);
            const message = error?.body?.message || "Unable to continue. Please try again.";
            this.showToast("Error", message, "error");
        } finally {
            this.isLoading = false;
        }
    }

    handleConfirm() {
        const contactInfoCmp = this.template.querySelector("c-breg_-account-info");
        const contactInfoValid = contactInfoCmp.checkValidity();
        contactInfoCmp.reportValidity();
        if (contactInfoValid) {
            // Navigate to LLP-1/FLLP-1 if GP is not registered and GP being filled out. Otherwise, go to Forms and Fees step.
            if (this.needToFillLLPForm) {
                let params = {};
                if (this.caseRecord?.ParentId) {
                    // Set these params when LLP case already created under the GP case to avoid creating a duplicate LLP case.
                    params = {
                        caseId: this.caseRecord.ParentId,
                        shouldSetRecordId: true
                    };
                } else {
                    params = {
                        caseId: this.caseId,
                        gpCaseId: this.caseId,
                        formConfigId: this.formConfiguration?.linkedForm
                    };
                }
                navigateToPage("/start", params);
            } else {
                this.setStep(1);
            }
        }
    }

    handleBack() {
        if ((this.formCode === "LLP-1" || this.formCode === "FLLP-1") && this.isGpAndLlpRegistration && this.currentStep === "Form Filling") {
            navigateToPage("/start", {
                caseId: this.gpCaseId || this.caseRecord?.breg_GP_Case__c,
                shouldSetRecordId: true,
                readOnly: true
                // formConfigId: this.formConfiguration?.linkedForm
            });
        } else {
            this.setStep(-1);
        }
    }

    handleCancel() {
        if (this.isInternal) {
            this.resetAllFields();
            this.navigateToCaseObj();
        } else {
            this.navigateToStart();
        }
    }

    /**
     * Navigation methods
     **/

    navigateToCaseObj() {
        this[NavigationMixin.Navigate]({
            type: "standard__objectPage",
            attributes: {
                objectApiName: "Case",
                actionName: "home"
            }
        });
    }

    navigateToStart() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }

    navigateToRecord() {
        console.log("*** navigateToRecord");
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.caseId,
                actionName: "view"
            }
        });
    }
    async handleDownloadDocument(event) {
        // Get the document ID and description
        const docusignDocumentId = event.detail.docusignDocumentId;
        const description = event.detail.description;
        const fileType = event.detail.fileType;

        if (!docusignDocumentId) {
            console.error("No document ID provided for download");
            return;
        }

        // Show loading spinner
        this.isLoading = true;

        // Call the Apex method to download the document
        try {
            const result = await downloadDocument({ docusignDocumentId: docusignDocumentId });
            if (result) {
                createDownloadLink(result, description, fileType);
                console.log("Document download initiated");
            } else {
                console.error("No document content received");
            }
        } catch (error) {
            console.error("Error downloading document:", error);
        } finally {
            // Hide loading spinner
            this.isLoading = false;
        }
    }
}