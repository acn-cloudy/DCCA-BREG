import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_RegisteredAgent extends BaseFormComponent {
    defaultTitle = "Registered Agent";

    agentTypeValue;
    registeredAgentFirstNameValue;
    registeredAgentLastNameValue;
    registeredAgentEntityNameValue;
    registeredAgentEntityLocationValue;
    agentFullName = '';

    agentTypeOptions = [
        { label: "Individual", value: "Individual" },
        { label: "Entity", value: "Entity" }
    ];

    get isIndividual() {
        return this.agentTypeValue === "Individual";
    }
    get isEntity() {
        return this.agentTypeValue === "Entity";
    }

    handleInputChange(event) {
        event.preventDefault();
        event.stopPropagation();
        super.handleInputChange(event);
        const inputTag = event?.target?.tagName?.toLowerCase();
        if (inputTag === "lightning-input" || inputTag === 'lightning-textarea') return;
        const inputName = event?.target?.name;
        const value = this.getValueFromEvent(event);

        if (inputName === "agentType") {
            const isEntity = value === "Entity";
            this.dispatchCustomEvent("change", this.getValueChangeData(inputName, isEntity));
            // if (isEntity) {
            //     this.registeredAgentFirstNameValue = '';
            //     this.registeredAgentLastNameValue = '';
            // } else {
            //     this.registeredAgentEntityNameValue = '';
            // }
        }
    }

    handleInputBlur(event) {
        if (this.readOnly) return;
        event.preventDefault();
        event.stopPropagation();
        super.handleInputBlur(event);
        const inputName = event.target.name;
        const value = this.getValueFromEvent(event);
        if (inputName === "registeredAgentFirstName" || inputName === "registeredAgentLastName") {
            this.agentFullName = `${this.registeredAgentFirstNameValue || ''} ${this.registeredAgentLastNameValue || ''}`;
            this.dispatchCustomEvent("change", { field: "regAgent", value: this.agentFullName });
        } else if (inputName === "registeredAgentEntityName") {
            this.dispatchCustomEvent("change", { field: "regAgent", value });
        }
    }

    processFormData() {
        super.processFormData();
        const agentTypeField = this.targetFieldsMapping?.agentType;
        if (agentTypeField) {
            const agentTypeValue = this.formData[agentTypeField];
            if (agentTypeValue === true) {
                this.agentTypeValue = "Entity";
            } else if (agentTypeValue === false) {
                this.agentTypeValue = "Individual";
            }
        }
    }
}