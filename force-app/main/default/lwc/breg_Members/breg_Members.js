import { wire, track } from "lwc";
import BaseFormComponent from "c/breg_BaseFormComponent";
import { addUniqueKeys } from "c/utils";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import ACCOUNT_AFFILIATION_OBJECT from "@salesforce/schema/breg_Account_Affiliation__c";
import ENTITY_TYPE_FIELD from "@salesforce/schema/breg_Account_Affiliation__c.breg_Entity_Type__c";
import OFFICER_DIRECTOR_TITLES_FIELD from "@salesforce/schema/breg_Account_Affiliation__c.breg_Officer_Director_Titles__c";

const ROLE_FIELD = "breg_Account_Affiliation__c.breg_Role__c";
const MANAGER_MANAGED_FIELD = "Case.breg_Is_Manager_Managed__c";
const MASTER_RECORD_TYPE_ID = "012000000000000AAA";

const DOMESTIC_LOCATION_VALUE = "Domestic";
const FOREIGN_LOCATION_VALUE = "Foreign";

export default class Breg_Members extends BaseFormComponent {
    defaultTitle = "";
    @track members = [];
    @track deletedMembers = [];
    isSingle;
    minimalNumbersOfMembers = 1;
    entityTypeList = [];
    officerDirectorTitlesOptions = [];
    membersInitiated = false;
    currentPage = 1;
    pageSize = 5;

    get memberLabel() {
        return this.config?.labelOverride2 || ""; // this.config.labelOverride;
    }

    get addButtonLabel() {
        return ("Add " + this.memberLabel).trim();
    }

    get showActions() {
        return !this.isSingle && !this.cmpProperties?.hideMemberActions;
    }

    get displayTitle() {
        const overrideTitle = this.config?.labelOverrideLong2;
        return overrideTitle && overrideTitle.trim() ? overrideTitle : this.title;
    }

    get showAddButton() {
        return !this.hideAddButtonsByConfigReadOnly &&
            !this.isSingle &&
            !this.cmpProperties?.hideMemberActions &&
            !this.readOnly;
    }

    get showAddButtonForAnnualForms() {
        return !this.hideAddButtonsByConfigReadOnly &&
            !this.showAddButton &&
            !this.isSingle &&
            !this.cmpProperties?.hideMemberActions &&
            this.readOnly &&
            this.isAnnualForm;
    }

    get entityTypeOptions() {
        let options = [];
        const entityTypeNames = typeof this.componentSettings?.entityTypeList === "string"
            ? this.componentSettings.entityTypeList.split(";").map((item) => item.trim())
            : [];

        options = this.entityTypeList.filter((option) =>
            entityTypeNames.includes(option.value) || entityTypeNames.includes(option.label)
        );
        
        if (this.config?.targetFieldsMapping?.includes("entityTypeDescription")) {
            options.push({ label: "OTHER", value: "Other" });
        }

        if (this.componentSettings?.removeEntityTypeLocationType) {
            options = options.map((option) => ({
                ...option,
                label: option.label?.toUpperCase()
                    .replace(DOMESTIC_LOCATION_VALUE.toUpperCase(), "")
                    .replace(FOREIGN_LOCATION_VALUE.toUpperCase(), "")
                    .trim()
            }));
        }

        return options;
    }

    @wire(getPicklistValues, {
        recordTypeId: MASTER_RECORD_TYPE_ID,
        fieldApiName: ENTITY_TYPE_FIELD
    })
    entityTypeOptionsWired({ data }) {
        this.entityTypeList = this.setCBOptionsFromPicklistValues(data);
    }

    @wire(getPicklistValues, {
        objectApiName: ACCOUNT_AFFILIATION_OBJECT,
        recordTypeId: MASTER_RECORD_TYPE_ID,
        fieldApiName: OFFICER_DIRECTOR_TITLES_FIELD
    })
    officerDirectorTitlesOptionsWired({ data }) {
        this.officerDirectorTitlesOptions = this.setCBOptionsFromPicklistValues(data);
    }

    get isDeleteMemberDisabled() {
        return this.members.length <= this.minimalNumbersOfMembers;
    }

    get memberRole() {
        return this.defaultValuesMapping?.[ROLE_FIELD];
    }

    get hideAddButtonsByConfigReadOnly() {
        return this.isAnnualForm && this.config?.isReadOnly === true;
    }

    get filteredMembers() {
        if (this.sourceFieldsMapping){
            return this.members;
        } else {
            return (this.members || []).filter((member) => member?.country);
        }
    }

    get paginatedMembers() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.filteredMembers.slice(start, end);
    }

    get totalPages() {
        return Math.ceil(this.filteredMembers.length / this.pageSize) || 1;
    }

    get showPagination() {
        return this.filteredMembers.length > this.pageSize;
    }

    get notHasPreviousPage() {
        return this.currentPage <= 1;
    }

    get notHasNextPage() {
        return this.currentPage >= this.totalPages;
    }

    get pageInfo() {
        const start = this.filteredMembers.length > 0 ? (this.currentPage - 1) * this.pageSize + 1 : 0;
        const end = Math.min(this.currentPage * this.pageSize, this.filteredMembers.length);
        return `${start}-${end} of ${this.filteredMembers.length}`;
    }

    get pageSizeDisplayValue() {
        return this.pageSize.toString();
    }

    get pageSizeOptions() {
        return [
            { label: "5", value: "5" },
            { label: "10", value: "10" },
            { label: "25", value: "25" },
            { label: "50", value: "50" }
        ];
    }

    get showMembers(){
        return (this.filteredMembers.length > 0 || this.sourceFieldsMapping != null) && this.showSection;
    }

    get showTitle(){
        return !!this.displayTitle;
    }

    connectedCallback() {
        super.connectedCallback();

        // Set isSingle based on componentSettings
        this.isSingle = this.componentSettings?.isSingle || false;

        this.setMembers();
    }

    setMembers() {
        if (!this.defaultValuesMapping || this.membersInitiated || !this.showSection) return;

        this.minimalNumbersOfMembers = this.componentSettings?.minimalNumbersOfMembers !== undefined ? this.componentSettings.minimalNumbersOfMembers : 1;
        if (this.formData?.members && this.formData.members.length > 0) {
            this.membersInitiated = true;
            let members = [];
            this.formData.members.forEach((member) => {
                if (member[ROLE_FIELD] === this.memberRole) {
                    // Create a new member object with default fields and passed member data
                    const newMember = { ...this.getMemberWithDefaultFields(), ...member };
                    // Set memberName based on firstName/lastName or entityName
                    if (newMember?.memberType === "Entity") {
                        newMember.memberName = newMember.entityName || "";
                    } else {
                        newMember.memberName = `${newMember?.firstName || ""} ${newMember?.lastName || ""}`;
                    }
                    // console.log('New Member:', JSON.stringify(newMember));
                    members.push(newMember);
                }
            });
            this.members = this.updateMemberLabels(members, "member");
        }
        // Ensure minimal number of members is met. Skip for annual forms.
        if (!this.isAnnualForm && this.members.length < this.minimalNumbersOfMembers) {
            for (let i = this.members.length; i < this.minimalNumbersOfMembers; i++) {
                const initialMember = this.getMemberWithDefaultFields();
                this.members.push(initialMember);
            }
            this.members = this.updateMemberLabels(this.members, "member");
        }

        this.members = addUniqueKeys(this.members, "member");
        // console.log("Members after processing:", JSON.stringify(this.members));

        // Update formData with the latest members
        // const formData = {...this.formData} || {};
        // formData.members = this.members;
        this.dispatchCustomEvent("formupdate", { field: "members", value: this.members });
    }

    handleAddMember() {
        const newMember = this.getMemberWithDefaultFields();

        if (this.isAnnualForm) {
            const formConfig = this.prepareFormConfigForEditSectionModal();
            this.dispatchEvent(
                new CustomEvent("addmember", {
                    detail: {
                        formConfig,
                        title: this.memberRole,
                        member: newMember
                    }
                })
            );
        } else {
            const newMembers = [...this.members, ...addUniqueKeys([newMember], "member")];
            this.members = this.updateMemberLabels(newMembers);
            this.currentPage = this.totalPages;
        }
    }

    handleDeleteMember(event) {
        if (this.members.length > this.minimalNumbersOfMembers) {
            const role = this.members[0]?.["breg_Account_Affiliation__c.breg_Role__c"] || null;
            const deletedMember = this.members.find((member) => member.uniqueKey === event.detail.memberKey);
            const newMembers = this.members.filter((member) => member.uniqueKey !== event.detail.memberKey);
            if (
                deletedMember?.id ||
                deletedMember?.["breg_Account_Affiliation__c.Id"] ||
                this.isAnnualForm ||
                this.isChangeForm
            ) {
                this.deletedMembers = [...this.deletedMembers, deletedMember];
                this.dispatchCustomEvent("change", { field: "deletedMembers", value: this.deletedMembers });
            }
            this.members = this.updateMemberLabels(newMembers);
            if (this.currentPage > this.totalPages) {
                this.currentPage = this.totalPages;
            }
            this.dispatchCustomEvent("change", { field: "members", value: this.members, role: role});
            this.dispatchCustomEvent("change", { field: "deletedMembers", value: this.deletedMembers });
        }
    }

    updateMemberLabels(members) {
        return members.map((item, index) => {
            return { ...item, ...{ label: `${this.memberLabel} (#  ${index + 1})` } };
        }, {});
    }

    handleChangeMember(event) {
        event.preventDefault();
        event.stopPropagation();
        const member = event.detail.value.member;

        if (!member) return;

        const memberIndex = this.members.findIndex((m) => m.uniqueKey === member.uniqueKey);
        if (memberIndex !== -1) {
            this.members[memberIndex] = { ...this.members[memberIndex], ...member };
            this.members = [...this.members];
        }

        this.dispatchCustomEvent("change", { field: "members", value: this.members });
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
    }

    getMemberWithDefaultFields() {
        const defaultValuesKeys = Object.keys(this.defaultValuesMapping || {});
        const initialMember = defaultValuesKeys.reduce((memberObj, key) => {
            memberObj[key] = this.defaultValuesMapping[key];
            return memberObj;
        }, {});

        return initialMember;
    }

    populateDefaultValues() {}

    processFormData() {
        this.handleManagementChange();
        this.setMembers();
    }

    handleManagementChange() {
        const isManagerManaged = this.formData[MANAGER_MANAGED_FIELD];
        if (isManagerManaged == undefined) return;

        if (isManagerManaged === true) {
            this.switchMembersSection("Member", "Manager");
        } else if (isManagerManaged === false) {
            this.switchMembersSection("Manager", "Member");
        }
    }

    switchMembersSection(roleFrom, roleTo) {
        if (!this.memberRole) return;

        // Show the section and update roles
        if (this.memberRole === roleTo) {
            if (this.showSection === false) {
                this.showSection = true;

                if (!this.formData?.members) return;

                const formData = { ...this.formData };
                let updateRole = false;
                formData.members = formData.members.map((member) => {
                    if (member && member[ROLE_FIELD] === roleFrom) {
                        updateRole = true;
                        return { ...member, [ROLE_FIELD]: roleTo };
                    }
                    return member;
                });

                if (!updateRole) return;

                this.formData = formData;
                this.membersInitiated = false;
                this.setMembers();

                // TODO: during the component initialization, this.formData does not include members with fields set by the setMembers method, so sending this event overwrites all member data. We’ll likely need to find a way to prevent this in the future.
                this.dispatchCustomEvent("formupdate", { formData });
            }
        }
        // Hide the section
        else if (this.memberRole === roleFrom) {
            if (this.showSection === true) {
                this.showSection = false;
            }
        }
    }

    setComponentProperties() {
        super.setComponentProperties();
        if (this.cmpProperties?.reloadMembers) {
            this.membersInitiated = false;
            this.setMembers();
        }
    }

    handleEditSectionClick(event) {
        this.dispatchEvent(
            new CustomEvent("editsection", {
                bubbles: true,
                detail: event.detail
            })
        );
    }
}