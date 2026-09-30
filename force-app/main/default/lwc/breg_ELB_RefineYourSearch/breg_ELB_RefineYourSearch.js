import { LightningElement, api } from "lwc";

export default class Breg_ELB_RefineYourSearch extends LightningElement {
    @api searchInput; // Public property to receive input from parent
    selectedStatus = "All";
    entityName = "";
    zipCodes = "";
    startDate = "";
    endDate = "";

    zipError = "";

    connectedCallback() {
        this.entityName = this.searchInput.name;
        this.zipCodes = this.searchInput.zipCodes;
        this.startDate = this.searchInput.startDate;
        this.selectedStatus = "All";
        this.dispatchEvent(
            new CustomEvent("stepdata", {
                detail: {
                    status: "All"
                }
            })
        );
        this.endDate = this.searchInput.endDate;
        console.log("searchInput Refine", this.searchInput);
        console.log("name", this.name);
        this.validate();
    }
    @api
    validate() {
        console.log("Validating RefineYourSearch");
        let isValid = this.customValidation();
        const inputs = this.template.querySelectorAll("lightning-input");
        inputs.forEach((input) => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        if (this.zipCodes != null && this.refs.zipInput !== null > 0) {
            const zips = this.zipCodes
                .split(",")
                .map((zip) => zip.trim())
                .filter((zip) => zip.length > 0);
            console.log("Zips after split and trim:", zips);
            const invalidZips = zips.filter((zip) => !/^\d{5}$/.test(zip));
            if (invalidZips.length > 0) {
                //this.zipError = `Invalid ZIP codes: ${invalidZips.join(', ')}`;
                this.refs.zipInput.setCustomValidity(`Invalid ZIP codes: ${invalidZips.join(", ")}`);
                isValid = false;
                console.error("Invalid ZIP codes:", invalidZips);
            } else {
                this.zipError = "";
                this.refs.zipInput.setCustomValidity("");
            }
        }
        return isValid;
    }

    //At least one field must be filled, except for name
    customValidation() {
        const inputs = this.template.querySelectorAll('lightning-input:not([data-name="name"])');
        const inputsArray = Array.from(inputs);
        const zipInput = inputsArray.find((input) => input.dataset.name === "zipCodes");
        const startDateInput = inputsArray.find((input) => input.dataset.name === "startDate");
        const endDateInput = inputsArray.find((input) => input.dataset.name === "endDate");
        const statusInput = this.template.querySelector("lightning-combobox");
        if (!zipInput || !startDateInput || !endDateInput || !statusInput) {
            return false;
        }
        let isValid = true;
        if (statusInput.value || zipInput.value || (startDateInput.value && endDateInput.value) || endDateInput.value) {
            zipInput.setCustomValidity("");
            startDateInput.setCustomValidity("");
            endDateInput.setCustomValidity("");
            statusInput.setCustomValidity("");
        } else {
            if (startDateInput.value && !endDateInput.value) {
                // Show error message if start date is filled but end date is not
                zipInput.setCustomValidity("");
                startDateInput.setCustomValidity("");
                statusInput.setCustomValidity("");
                endDateInput.setCustomValidity("If Start Date is not blank, then End Date cannot be blank.");
                isValid = false;
            } else {
                // Show error message if no fields are filled
                zipInput.setCustomValidity("Please fill at least one field.");
                startDateInput.setCustomValidity("Please fill at least one field.");
                endDateInput.setCustomValidity("Please fill at least one field.");
                statusInput.setCustomValidity("Please select a status or fill other fields.");
                isValid = false;
            }
        }

        zipInput.reportValidity();
        startDateInput.reportValidity();
        endDateInput.reportValidity();
        statusInput.reportValidity();
        return isValid;
    }

    get statusOptions() {
        return [
            { label: "All", value: "All" },
            { label: "Active", value: "Active" },
            { label: "Not Active", value: "Not Active" }
        ];
    }

    handleInput(event) {
        const fieldName = event.target.name;
        this[fieldName] = event.target.value;
        this.dispatchEvent(
            new CustomEvent("stepdata", {
                detail: {
                    [fieldName]: event.target.value
                }
            })
        );
    }
}