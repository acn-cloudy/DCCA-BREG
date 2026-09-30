import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_MemberType extends BaseFormComponent {
    defaultTitle = "Member Type";
    memberTypeValue;
    entityNameValue;
    entityLocationValue;
    firstNameValue;
    lastNameValue;

    dependentFieldsMapping = {
        memberType: ["entityName", "firstName", "lastName", "entityLocation"]
    };

    memberTypeOptions = [
        { label: "Individual", value: "Individual" },
        { label: "Entity", value: "Entity" }
    ];

    get memberTypeSelectorLabel() {
        return `Is the ${this.config?.labelOverride2} an individual or an entity?`;
    }

    get showMemberTypeSelector() {
        return "memberType" in this.targetFieldsMapping && !this.componentSettings?.hideMemberType;
    }

    get showEntityLocationField() {
        return "entityLocation" in this.targetFieldsMapping;
    }

    get isEntity() {
        return "entityName" in this.targetFieldsMapping && (this.memberTypeValue === "Entity" || (!this.showMemberTypeSelector && !this.memberTypeValue));
    }

    get isIndividual() {
        return (
            "firstName" in this.targetFieldsMapping && (this.memberTypeValue === "Individual" || (!this.showMemberTypeSelector && !this.memberTypeValue))
        );
    }

    get readOnlyMemberType() {
        return this.memberTypeValue ? ` (${this.memberTypeValue.toUpperCase()})` : "";
    }

    get readOnlyName() {
        const name = this.entityNameValue || `${this.firstNameValue} ${this.lastNameValue}`;
        return name ? name.toUpperCase() : "";
    }
}