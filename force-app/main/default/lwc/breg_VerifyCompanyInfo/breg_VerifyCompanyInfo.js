import { LightningElement, api, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { publish, MessageContext } from "lightning/messageService";
import { MESSAGE_TYPE_TOAST } from "c/breg_constants";
import MESSAGE_CHANNEL from "@salesforce/messageChannel/breg_MessageChannel__c";
import getAccountWithRelationshipsById from "@salesforce/apex/BREGAccountAffiliationController.getAccountWithRelationshipsById";
import getAccountWithRelationshipsByFileNumber from "@salesforce/apex/BREGAccountAffiliationController.getAccountWithRelationshipsByFileNumber";
import getCaseWithRelations from "@salesforce/apex/BREGPortalUtils.getCaseWithRelations";
import { Labels } from "./labels";
import { setPageUrlParams, getPageParamsFromUrl, getQuarterEndDate, getNextQuarterStartDate, setFormData } from "c/utils";
import getFormConfiguration from "@salesforce/apex/BREGPortalUtils.getFormConfiguration";

export default class Breg_VerifyCompanyInfo extends NavigationMixin(LightningElement) {
    labels = Labels;
    @api filingYear;
    @api annualId;
    @api formAction;
    _accountId;
    @api accountNumber;
    _caseId;
    @api parentCaseId;
    @api shouldSetRecordId;
    @track accountData;
    startOfNextQuarter;
    endOfQuarter;
    annualFilingDate;
    caseRecord;
    skipCaseDataProcessing = false;

    @track formComponentProperties = {};
    @track formConfiguration;
    @track _formData = {};
    @track formDataTemp = {};
    initialFormData = {};

    @api isCertified = false;
    isNoChanges = true;
    isLoading = false;
    showModal = false;
    isEditMode = false;

    dynamicFormsComponent;

    @wire(MessageContext)
    messageContext;

    @api
    get formData() {
        return this._formData;
    }
    set formData(value) {
        this._formData = value;
    }

    @api
    get caseId() {
        return this._caseId;
    }
    set caseId(value) {
        this._caseId = value;
        // process case only if account data is already loaded
        if (this.accountData?.Id) {
            this.processCaseData();
        }
    }

    @api
    get accountId() {
        return this._accountId;
    }
    set accountId(value) {
        this._accountId = value;
        this.processAccountData();
    }

    get stepTitle() {
        return this.labels.BREG_Annuals_Please_review_company_info.replace("{1}", this.filingYear);
    }

    get yearReport() {
        return this.labels.BREG_Annuals_Year_Report.replace("{1}", this.filingYear);
    }

    get overdueDate() {
        return this.labels.BREG_Annuals_Overdue_date.replace("{1}", this.startOfNextQuarter ? this.startOfNextQuarter : "");
    }

    get dueDate() {
        return this.labels.BREG_Annuals_Due_date.replace("{1}", this.endOfQuarter ? this.endOfQuarter : "");
    }

    get reportDateMessage(){
        let today = new Date();
        if ( today > new Date(this.endOfQuarter) ) {
            return this.overdueDate;
        } else {
            return this.dueDate;
        }
    }

    get tileTitle() {
        return `${this.accountData?.Name} (${this.accountData?.breg_File__c})`;
    }

    get step2title() {
        return `Step 2: Verify your company information (${this.filingYear})`; //TODO
    }

    connectedCallback() {
        this.formComponentProperties = {
            readOnly: true
        };
    }

    showEditSectionModal = false;
    editSectionModalTitle = false;
    formConfigurationEditModal = {};
    formComponentPropertiesEditModal = {};
    formDataEditModal = {};
    isMemberEdit = false;
    isMemberAdd = false;

    handleEditSectionClick(event) {
        const title = event.detail.title;
        const member = event.detail.member;
        this.formConfigurationEditModal = { ...event.detail.formConfig };

        this.formComponentPropertiesEditModal = {
            readOnly: false,
            hideFormTitle: true
        };
        const formData = { ...this.formDataTemp };

        if (member) {
            this.isMemberEdit = true;
            formData.members = [member];
            this.formComponentPropertiesEditModal.hideMemberActions = true;
            this.formComponentPropertiesEditModal.memberInitiated = true;
        } else {
            this.isMemberEdit = false;
        }

        this.editSectionModalTitle = `Edit ${title?.toLowerCase()}`;
        this.formDataEditModal = { ...formData };
        this.showEditSectionModal = true;
    }

    setComponentProperties(property, value) {
        this.formComponentProperties[property] = value;
        this.formComponentProperties = { ...this.formComponentProperties };
    }

    handelCancelEditSectionModal() {
        this.showEditSectionModal = false;
    }
    handelSaveFormEditSectionModal(event) {
        const formData = event?.detail?.value?.formData;
        if (!formData) {
            console.warn("No formData received from edit section modal.");
            return;
        }

        if (this.isMemberEdit) {
            const members = [...this.formDataTemp.members];
            const editedMember = formData.members[0];
            const memberIndex = members.findIndex((member) => member.uniqueKey === editedMember.uniqueKey);
            if (memberIndex !== -1) {
                members[memberIndex] = editedMember;
            } else {
                console.warn("Edited member not found in current members.");
            }
            formData.members = members;
        } else if (this.isMemberAdd) {
            const newMember = formData.members[0];
            const members = [...this.formDataTemp.members, newMember];
            formData.members = members;
        }

        this._formData = { ...formData };
        this.formDataTemp = { ...this.formData };

        this.setComponentProperties("reloadMembers", true);
        
        this.showEditSectionModal = false;
        this.isMemberEdit = false;
        this.isMemberAdd = false;
    }

    handleAddMember(event) {
        const title = event.detail.title;
        const member = event.detail.member;
        this.formConfigurationEditModal = { ...event.detail.formConfig };
        this.editSectionModalTitle = `Add ${title?.toLowerCase()}`;

        this.formComponentPropertiesEditModal = {
            readOnly: false,
            hideFormTitle: true,
            hideMemberActions: true,
            memberInitiated: true
        };

        const formData = { ...this.formDataTemp };
        formData.members = [member];
        this.formDataEditModal = { ...formData };
        this.isMemberAdd = true;
        this.showEditSectionModal = true;
    }

    async processAccountData() {
        this.isLoading = true;
        try {
            if (this.accountId) {
                this.accountData = await getAccountWithRelationshipsById({ accId: this.accountId });
            } else if (this.accountNumber) {
                this.accountData = await getAccountWithRelationshipsByFileNumber({ fileNumber: this.accountNumber });
            }
            console.log("accountData", JSON.stringify(this.accountData));

            // Extract endOfQuarter from the account's annual records
            let matchingAnnual = this.accountData?.Annuals__r?.find((item) => item.breg_Filing_Year__c === this.filingYear);
            let dueDate = matchingAnnual?.breg_Filing_Due_Date__c;
            this.annualFilingDate = matchingAnnual?.breg_Filing_Date__c;
            this.startOfNextQuarter = getNextQuarterStartDate(dueDate);
            this.endOfQuarter = getQuarterEndDate(dueDate);
            if(this.accountData?.breg_File__c) {
                this.accountNumber = this.accountData?.breg_File__c;
            }

            await this.loadFormConfiguration();
            // Call setFormData after formConfiguration is loaded
            this.setFormData();

            if (this.caseId) {
                await this.processCaseData();
            }
        } catch (error) {
            console.error("Error loading account details:", error);
        }

        this.isLoading = false;
    }

    async processCaseData() {
        if (this.formData != null && Object.keys(this.formData).length > 0) {
            console.warn("formData is not empty, skipping case data processing.");
            return;
        }
        if (this.skipCaseDataProcessing) {
            console.warn("skipCaseDataProcessing is true, skipping case data processing.");
            return;
        }
        if (!this.caseId) {
            console.warn("No caseId provided, skipping case data processing.");
            return;
        }
        this.caseRecord = await getCaseWithRelations({ caseId: this.caseId });
        const formData = setFormData({
            formConfiguration: this.formConfiguration,
            record: this.caseRecord,
            useSourceFieldsMapping: false,
            shouldSetRecordId: this.shouldSetRecordId
        });
        formData["Case.breg_Entity_Type__c"] = this.caseRecord?.breg_Entity_Type__c;
        if (this.parentCaseId) {
            formData["Case.ParentId"] = this.parentCaseId;
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

        // If case has no stocks but account has stocks, preserve account stocks as initial data
        // These will be used to create new stock records related to the current case
        if (
            (!formData.stocksAnnuals || formData.stocksAnnuals.length === 0) &&
            this.formDataTemp.stocksAnnuals &&
            this.formDataTemp.stocksAnnuals.length > 0
        ) {
            formData.stocksAnnuals = this.formDataTemp.stocksAnnuals;
        }

        if (
            (!formData.stocksPaidIn || formData.stocksPaidIn.length === 0) &&
            this.formDataTemp.stocksPaidIn &&
            this.formDataTemp.stocksPaidIn.length > 0
        ) {
            formData.stocksPaidIn = this.formDataTemp.stocksPaidIn;
        }

        // if ((!formData.stocksAuthorized || formData.stocksAuthorized.length === 0) &&
        //     this.formDataTemp.stocksAuthorized && this.formDataTemp.stocksAuthorized.length > 0) {
        //     formData.stocksAuthorized = this.formDataTemp.stocksAuthorized;
        // }

        this._formData = { ...this.formDataTemp, ...formData };
        this.formDataTemp = { ...this.formData };
        this.skipCaseDataProcessing = true;
    }

    async loadFormConfiguration() {
        this.isLoading = true;
        try {
            const formConfiguration = await getFormConfiguration({
                businessProcess: "Annual Report",
                formSuffix: this.accountData?.breg_Entity_Type__c
            });

            this.formConfiguration = formConfiguration;
        } catch (error) {
            console.error("*** loadFormConfiguration error:", error);
        }
        this.isLoading = false;
    }

    setFormData() {
        const formData = setFormData({
            formConfiguration: this.formConfiguration,
            record: this.accountData,
            useSourceFieldsMapping: true,
            shouldSetRecordId: false
        });
        formData["Account.Id"] = this.accountData?.Id;
        formData["Account.breg_Entity_Type__c"] = this.accountData?.breg_Entity_Type__c;
        formData["Case.breg_Annual_Report_Filing_Year__c"] = this.filingYear;
        formData["Case.breg_Entity__c"] = this.accountData?.Id;
        formData["Case.breg_Portal_User_Entity_Selected__c"] = this.accountData?.Id;
        formData["Case.breg_Annual__c"] = this.annualId;
        if (this.formData != null && Object.keys(this.formData).length > 0) {
            this.initialFormData = { ...formData };
        } else {
            // Do not set formData if caseId exists because it will be set in the processCaseData method
            // This is needed for correct initialization of the 'members' array
            if (!this.caseId) {
                this._formData = { ...formData };
            }
            this.formDataTemp = { ...formData };
            this.initialFormData = { ...formData };
        }
    }

    setFormComponentProperties(property, value) {
        this.formComponentProperties[property] = value;
        this.formComponentProperties = { ...this.formComponentProperties };
    }


    async saveForm() {
        let savedSuccessfully = false;
        const formValid = await this.validateForm();
        if (formValid) {
            savedSuccessfully = await this.dynamicFormsComponent.saveForm();
            this.setFormComponentProperties("readOnly", true);
            if (savedSuccessfully) {
                this.isEditMode = false;
                this.showToast("Success", "Form saved successfully", "success");
            }
        }
        return savedSuccessfully;
    }

    handleFormDataChange(event) {
        this.formDataTemp = event.detail.formData;
    }

    handleSaveFormEvent(event) {
        this._caseId = event?.detail?.value?.caseId;
        const formData = event?.detail?.value?.formData;

        this._formData = { ...formData };
        this.formDataTemp = { ...this.formData };
        this.skipCaseDataProcessing = true;

        this.dispatchEvent(new CustomEvent("save", { detail: { caseId: this.caseId } }));
    }

    findDynamicFormsComponent() {
        this.dynamicFormsComponent = this.template.querySelector("c-breg_-registration-dynamic-form");
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: "comm__namedPage",
            attributes: {
                name: "Home"
            }
        });
    }

    handlePrev() {
        // this._formData = { ...this.formDataTemp };
        // Preserve existing URL parameters including caseId and parentCaseId
        const currentParams = getPageParamsFromUrl();
        setPageUrlParams({
            ...currentParams,
            section: "annual-report",
            page: "details",
            fileNumber: this.accountNumber,
            year: null
        });
        this.dispatchEvent(new CustomEvent("previous"));
    }

    async handleNext() {
        this.checkForChanges();
        if (this.isNoChanges) {
            const formValid = await this.validateForm();
            if (formValid) {
                this.showModal = true;
            }            
        } else {
            this.proceedNext();
        }
    }

    async validateForm() {
        this.findDynamicFormsComponent();
        const formValid = await this.dynamicFormsComponent.validateForm();
        return formValid;
    }

    handleModalCancel() {
        this.showModal = false;
    }

    handleModalContinue() {
        this.showModal = false;
        this.proceedNext();
    }

    async proceedNext() {
        const savedSuccessfully = await this.saveForm();
        if (!savedSuccessfully) return;

        this.dispatchEvent(
            new CustomEvent("next", {
                detail: {
                    noChanges: this.isNoChanges,
                    formData: this.formData,
                    formConfigId: this.formConfiguration.id
                }
            })
        );
    }

    checkForChanges() {
        this.isNoChanges = true;

        // console.log('*** checkForChanges - initialFormData:', JSON.stringify(this.initialFormData, null, 2));
        // console.log('*** checkForChanges - formDataTemp:', JSON.stringify(this.formDataTemp, null, 2));

        // Iterate through all keys in initialFormData
        for (const key in this.initialFormData) {
            if (!Object.prototype.hasOwnProperty.call(this.initialFormData, key)) continue;

            const initialValue = this.initialFormData[key];
            const tempValue = this.formDataTemp[key];

            if (key == "Case.breg_Partnership_Location__c" || key == "Case.breg_Is_Manager_Managed__c") {
                continue;
            }

            // Special handling for members array
            if (key === "members") {
                if (!this.compareMembersArray(initialValue, tempValue)) {
                    console.log(`*** Members array has changes`);
                    this.isNoChanges = false;
                    break;
                }
            } else if (key === "stocksAnnuals" || key === "stocksPaidIn" || key === "stocksAuthorized") {
                // Special handling for stocks arrays
                if (!this.compareStocksArray(initialValue, tempValue)) {
                    console.log(`*** ${key} array has changes`);
                    this.isNoChanges = false;
                    break;
                }
            } else {
                // Compare primitive values
                if (initialValue !== tempValue) {
                    console.log(`*** Field "${key}" has changed from "${initialValue}" to "${tempValue}"`);
                    this.isNoChanges = false;
                    break;
                }
            }
        }

        this._formData = { ...this.formDataTemp, "Case.breg_No_Changes__c": this.isNoChanges };

        console.log(`*** checkForChanges result - isNoChanges: ${this.isNoChanges}`);
    }

    compareMembersArray(initialMembers, tempMembers) {
        // Check if the number of members is the same
        if (initialMembers.length !== tempMembers.length) {
            console.log(`*** compareMembersArray: Length mismatch - initial: ${initialMembers.length}, temp: ${tempMembers.length}`);
            return false;
        }

        // Create a normalized representation of each member for comparison
        // Only include properties that exist in the initial member
        const normalizeMember = (member, referenceKeys) => {
            // Sort properties to ensure consistent comparison, only use keys from reference
            const sorted = referenceKeys.sort().reduce((acc, key) => {
                acc[key] = member[key];
                return acc;
            }, {});
            return JSON.stringify(sorted);
        };

        // Get all unique keys from initial members to use as reference
        const initialKeys = new Set();
        initialMembers.forEach((member) => {
            Object.keys(member).forEach((key) => initialKeys.add(key));
        });
        const referenceKeys = Array.from(initialKeys);

        // Create sets of normalized member strings, using only initial keys
        const initialSet = initialMembers.map((member) => normalizeMember(member, referenceKeys)).sort();
        const tempSet = tempMembers.map((member) => normalizeMember(member, referenceKeys)).sort();

        // Compare the sorted arrays
        for (let i = 0; i < initialSet.length; i++) {
            if (initialSet[i] !== tempSet[i]) {
                console.log(`*** compareMembersArray: Member mismatch detected`);
                console.log(`*** Initial member: ${initialSet[i]}`);
                console.log(`*** Temp member: ${tempSet[i]}`);
                return false;
            }
        }

        console.log("*** compareMembersArray: All members are equal (order-independent)");
        return true;
    }

    /**
     * Compare two stocks arrays for equality (order-independent).
     * @param {Array} initialStocks - The initial stocks array.
     * @param {Array} tempStocks - The temporary/current stocks array.
     * @returns {boolean} True if arrays are equal, false otherwise.
     */
    compareStocksArray(initialStocks, tempStocks) {
        // Handle null/undefined cases
        if (!initialStocks && !tempStocks) {
            return true;
        }
        if (!initialStocks || !tempStocks) {
            console.log(`*** compareStocksArray: One array is null/undefined`);
            return false;
        }

        // Check if the number of stocks is the same
        if (initialStocks.length !== tempStocks.length) {
            console.log(`*** compareStocksArray: Length mismatch - initial: ${initialStocks.length}, temp: ${tempStocks.length}`);
            return false;
        }

        // Create a normalized representation of each stock for comparison
        // Only include properties that exist in the initial stock
        const normalizeStock = (stock, referenceKeys) => {
            // Sort properties to ensure consistent comparison, only use keys from reference
            const sorted = referenceKeys.sort().reduce((acc, key) => {
                if(key === 'paidShares')
                {
                    acc[key] = this.normalizeToInteger(stock[key]).value || 0;
                } else {
                    acc[key] = stock[key];
                }
                return acc;
            }, {});
            return JSON.stringify(sorted);
        };

        // Get all unique keys from initial stocks to use as reference
        const initialKeys = new Set();
        initialStocks.forEach((stock) => {
            Object.keys(stock).forEach((key) => initialKeys.add(key));
        });
        const referenceKeys = Array.from(initialKeys);

        // Create sets of normalized stock strings, using only initial keys
        const initialSet = initialStocks.map((stock) => normalizeStock(stock, referenceKeys)).sort();
        const tempSet = tempStocks.map((stock) => normalizeStock(stock, referenceKeys)).sort();

        // Compare the sorted arrays
        for (let i = 0; i < initialSet.length; i++) {
            if (initialSet[i] !== tempSet[i]) {
                console.log(`*** compareStocksArray: Stock mismatch detected`);
                console.log(`*** Initial stock: ${initialSet[i]}`);
                console.log(`*** Temp stock: ${tempSet[i]}`);
                return false;
            }
        }

        console.log("*** compareStocksArray: All stocks are equal (order-independent)");
        return true;
    }

    normalizeToInteger(raw) {

        if (raw === null || raw === undefined) {
            return { isNumeric: false, value: null };
        }

        const str = String(raw).trim();

        // If the string contains any letters, treat it as non-numeric
        if (/[a-zA-Z]/.test(str)) {
            return { isNumeric: false, value: null };
        }

        // Remove dollar signs and commas for easier processing
        let cleaned = str.replace(/\$/g, "").replace(/,/g, "");

        // Remove decimal part for normalization, we only care about the integer part for shares
        cleaned = cleaned.split(".")[0];

        // Verify that cleaned number is purely digits
        if (!/^\d+$/.test(cleaned)) {
            return { isNumeric: false, value: null };
        }

        return {
            isNumeric: true,
            value: Number(cleaned)
        };
    }

    showToast(title, message, variant) {
        publish(this.messageContext, MESSAGE_CHANNEL, {
            type: MESSAGE_TYPE_TOAST,
            title: title,
            message: message,
            variant: variant
        });
    }
}