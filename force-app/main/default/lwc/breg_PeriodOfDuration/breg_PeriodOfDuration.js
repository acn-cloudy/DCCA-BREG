import BaseFormComponent from "c/breg_BaseFormComponent";

const EXPIRATION_DATE_VALUE = "For a specified term to expire on";

export default class Breg_PeriodOfDuration extends BaseFormComponent {
    defaultTitle = "Period of Duration";
    periodOfDurationValue;
    expirationDateValue;

    dependentFieldsMapping = {
        periodOfDuration: ["expirationDate"]
    };

    get periodOfDurationOptions() {
        const atWillOption = { label: "At-will", value: "At-will" };
        const expirationDateOption = { label: EXPIRATION_DATE_VALUE, value: EXPIRATION_DATE_VALUE };
        
        const customAttWillOption = this.componentSettings?.atWillOption;
        if (customAttWillOption) {
            atWillOption.label = customAttWillOption;
            atWillOption.value = customAttWillOption;
        } 

        return [atWillOption, expirationDateOption];
    }

    get showDateInput() {
        return this.periodOfDurationValue === EXPIRATION_DATE_VALUE;
    }

    get periodOfDurationValueReadOnly() {
        let label = this.getLabelFromOptions(this.periodOfDurationOptions, this.periodOfDurationValue);
        if (this.periodOfDurationValue === EXPIRATION_DATE_VALUE) {
            label = `Expires on ${this.formattedExpirationDate}`;
        }
        return `<b>Period of Duration:</b><br> ${label.toUpperCase()}`;
    }

    handleInputBlur(event) {
        super.handleInputBlur(event);
        this.validateExpirationDate(event);
    }

    validateExpirationDate(event) {
        const dateTimeInput = event?.target;
        const dateTimeValue = this.getValueFromEvent(event);

        if (this.periodOfDurationValue === EXPIRATION_DATE_VALUE) {
            if (!dateTimeValue) {
                dateTimeInput.setCustomValidity("Expiration date is required.");
                dateTimeInput.reportValidity();
                return false;
            }

            const selectedDate = dateTimeValue.split("T")[0];
            const hawaiiToday = this.getHawaiiToday();

            if (selectedDate <= hawaiiToday) {
                dateTimeInput.setCustomValidity("Expiration date must be greater than today.");
                dateTimeInput.reportValidity();
                return false;
            }
        }

        dateTimeInput.setCustomValidity("");
        dateTimeInput.reportValidity();
        return true;
    }

    reportValidity() {
        const baseValid = super.reportValidity();
        if (this.showDateInput) {
            const expirationDateInput = this.template.querySelector('input[name="expirationDate"]');
            if (expirationDateInput) {
                return this.validateExpirationDate({ target: expirationDateInput }) && baseValid;
            }
        }
        return baseValid;
    }

    getHawaiiToday() {
        return new Intl.DateTimeFormat("en-CA", {
            timeZone: "Pacific/Honolulu",
            year: "numeric",
            month: "2-digit",
            day: "2-digit"
        }).format(new Date());
    }

    get formattedExpirationDate() {
        if (!this.expirationDateValue) {
            return "";
        }

        const dateValue = this.expirationDateValue.split("T")[0];
        const [year, month, day] = dateValue.split("-");

        return `${month}-${day}-${year}`;
    }
}