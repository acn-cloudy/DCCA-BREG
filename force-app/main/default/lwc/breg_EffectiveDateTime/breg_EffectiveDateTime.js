import BaseFormComponent from "c/breg_BaseFormComponent";

export default class Breg_EffectiveDateTime extends BaseFormComponent {
    defaultTitle = "Effective Date and Time";
    effectiveSelectorValue;

    alwaysRequired = true;

    // Private properties for datetime display/storage separation
    _effectiveDateTimeDisplayValue;
    _effectiveDateTimeFormDataValue;

    /**
     * Getter for effectiveDateTimeValue - prioritizes user-entered display value
     * over the form data value to prevent GMT conversion from affecting display
     */
    get effectiveDateTimeValue() {
        if (this._effectiveDateTimeDisplayValue !== undefined) {
            return this._effectiveDateTimeDisplayValue;
        }
        return this._effectiveDateTimeFormDataValue;
    }

    /**
     * Setter for effectiveDateTimeValue - stores form data value separately
     * without overwriting the user's display value
     */
    set effectiveDateTimeValue(value) {
        this._effectiveDateTimeFormDataValue = value;
    }

    get effectiveSelectorOptions() {
        return [
            { label: `${this.config?.labelOverride2} is effective on the date and time of filing.`, value: "Immediate" },
            { label: `${this.config?.labelOverride2} is effective on a later date and time, not more than 30 days after the filing.`, value: "Specific Date/Time" }
        ];
    }

    get showDateTimeField() {
        return this.effectiveSelectorValue === "Specific Date/Time";
    }

    get sectionDescription() {
        return this.config?.labelOverrideLong || "";
        // return `The ${this.config?.labelOverride2} is effective on the date and time of filing the ${this.formConfig?.formName} or at a later date and time, no more than 30 days after the filing, if so stated.  Check one of the following statements:`;
    }

    get effectiveSelectorLabel() {
        return `The ${this.config?.labelOverride2} is effective on?`;
    }

    get effectiveDateTimeLabel(){
        return `${this.config?.labelOverride2} Effective Date`;
    }
    get effectiveSelectorValueReadOnly() {
        const option = this.effectiveSelectorOptions.find((opt) => opt.value === this.effectiveSelectorValue);
        let label = this.showDateTimeField ? "Effective on later date/time" : option.label;
        return `The ${this.config?.labelOverride2} is: <p>${label.toUpperCase()}</p>`;
    }

    get effectiveDateTimeValueReadOnly() {
        if (!this.effectiveDateTimeValue) {
            return ` <b></b>`;
        }

        const date = new Date(this.effectiveDateTimeValue);
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, "0");
        const day = String(date.getDate()).padStart(2, "0");
        let hours = date.getHours();
        const minutes = String(date.getMinutes()).padStart(2, "0");

        const ampm = hours >= 12 ? "PM" : "AM";
        hours = hours % 12 || 12;
        const hoursFormatted = String(hours).padStart(2, "0");

        const formattedDate = `${year}/${month}/${day} ${hoursFormatted}:${minutes} ${ampm}`;
        return ` <b>${formattedDate}</b>`;
    }

    // Handles the effectiveDateTime blur event with HST to GMT conversion
    handleInputBlur(event) {
        const inputName = event?.target?.name;
        if (inputName === "effectiveDateTime") {
            this.validateEffectiveDateTime(event);
            const dateTimeValue = this.getValueFromEvent(event);
            if (dateTimeValue) {
                // Store the user's input for display (unchanged)
                this._effectiveDateTimeDisplayValue = dateTimeValue;
                // Convert HST to GMT and dispatch the converted value for storage
                const gmtValue = this.convertDateTimeToGmt(dateTimeValue);
                this.dispatchCustomEvent("change", this.getValueChangeData(inputName, gmtValue));
            }
        }
    }

    /**
     * Handles the effectiveDateTime blur event with HST to GMT conversion
     * @param {Event} event - The blur event
     */
    handleEffectiveDateTimeBlur(event) {
        const inputName = event?.target?.name;
        const hstValue = this.getValueFromEvent(event);
        console.log("** handleEffectiveDateTimeBlur hstValue:", hstValue);
        console.log("** handleEffectiveDateTimeBlur inputName:", inputName);
        // Convert HST to GMT for Salesforce storage
        const gmtValue = this.convertHstToGmt(hstValue);
        console.log("** HST value:", hstValue, "-> GMT value:", gmtValue);

        // Dispatch the GMT value to form data
        this.dispatchCustomEvent("change", this.getValueChangeData(inputName, gmtValue));
    }

    /**
     * Converts the datetime value from lightning-input to GMT, treating the user's input as HST.
     * lightning-input returns an ISO string converted from the browser's local timezone to GMT.
     * We need to extract what the user actually entered (local time) and treat it as HST.
     * HST is UTC-10 with no daylight saving time.
     * @param {string} inputValue - ISO string from lightning-input (e.g., "2026-01-21T09:00:00.000Z")
     * @returns {string|null} ISO 8601 string in GMT/UTC representing the HST time, or null if input is empty
     */
    convertDateTimeToGmt(inputValue) {
        if (!inputValue) return null;

        // lightning-input returns a GMT ISO string that was converted from browser's local timezone.
        // We need to get the "face value" (what the user saw/entered) and treat it as HST instead.
        const dateFromInput = new Date(inputValue);

        // Extract local time components (what the user actually saw on the datetime picker)
        const year = dateFromInput.getFullYear();
        const month = String(dateFromInput.getMonth() + 1).padStart(2, "0");
        const day = String(dateFromInput.getDate()).padStart(2, "0");
        const hours = String(dateFromInput.getHours()).padStart(2, "0");
        const minutes = String(dateFromInput.getMinutes()).padStart(2, "0");

        // Reconstruct the datetime as HST (UTC-10) and let JavaScript convert to GMT
        const hstDateTimeString = `${year}-${month}-${day}T${hours}:${minutes}:00-10:00`;
        console.log("** User entered datetime (local time):", `${hours}:${minutes}`);
        console.log("** Treating as HST:", hstDateTimeString);

        const gmtDate = new Date(hstDateTimeString);
        console.log("** Converted to GMT:", gmtDate.toISOString());

        return gmtDate.toISOString();
    }

    /**
     * Validates the effective date/time input against business rules:
     * - Cannot be backdated
     * - Cannot exceed 30 days after filing
     * - Time selection must exclude 12:00 AM / 12:00 PM
     * - Hawaii Standard Time (HST) only
     * @returns {boolean} True if valid, false otherwise
     */
    validateEffectiveDateTime(event) {
        const dateTimeInput = event?.target;
        const dateTimeValue = this.getValueFromEvent(event);
        console.log("** validateEffectiveDateTime dateTimeValue:", dateTimeValue);
        if (!dateTimeValue) {
            return false;
        }

        // Get current time
        const now = new Date();
        console.log("** now:", now);

        // Parse user input (datetime-local format: YYYY-MM-DDTHH:mm)
        // The input is treated as HST since the label indicates "(HST)"
        const selectedDateTime = new Date(dateTimeValue);
        console.log("** selectedDateTime:", selectedDateTime);

        // Rule 1: Cannot be backdated
        if (selectedDateTime < now) {
            dateTimeInput.setCustomValidity("Effective date/time cannot be in the past");
            dateTimeInput.reportValidity();
            return false;
        }

        // Rule 2: Cannot exceed 30 days after filing
        const maxDate = new Date(now);
        console.log("** maxDate:", maxDate);
        maxDate.setDate(maxDate.getDate() + 30);
        if (selectedDateTime > maxDate) {
            dateTimeInput.setCustomValidity("Effective date/time cannot exceed 30 days after filing");
            dateTimeInput.reportValidity();
            return false;
        }

        // Rule 3: Exclude 12:00 AM (00:00) and 12:00 PM (12:00)
        const hours = selectedDateTime.getHours();
        const minutes = selectedDateTime.getMinutes();
        console.log("** hours:", hours);
        console.log("** minutes:", minutes);
        if ((hours === 0 || hours === 12) && minutes === 0) {
            dateTimeInput.setCustomValidity("12:00 AM and 12:00 PM are not allowed. Please select a different time");
            dateTimeInput.reportValidity();
            return false;
        }

        // Clear any previous custom validity
        dateTimeInput.setCustomValidity("");
        dateTimeInput.reportValidity();
        return true;
    }

    /**
     * Override reportValidity to include effective datetime validation
     * @returns {boolean} True if all inputs are valid
     */
    reportValidity() {
        const baseValid = super.reportValidity();
        const dateTimeValid = this.showDateTimeField ? this.validateEffectiveDateTime() : true;
        return baseValid && dateTimeValid;
    }
}