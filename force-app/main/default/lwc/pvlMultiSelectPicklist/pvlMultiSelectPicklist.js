import { LightningElement, api } from 'lwc';

export default class PvlMultiSelectPicklist extends LightningElement {
    @api label = '';

    _options = [];
    _value = [];

    // ── Public API ────────────────────────────────────────────

    @api
    get options() {
        return this._options;
    }
    set options(val) {
        this._options = val || [];
    }

    @api
    get value() {
        return this._value;
    }
    set value(val) {
        this._value = val || [];
    }

    // ── Computed ──────────────────────────────────────────────

    /** Options that have NOT yet been selected (shown in dropdown). */
    get availableOptions() {
        const selectedSet = new Set(this._value);
        return this._options.filter(opt => !selectedSet.has(opt.value));
    }

    get hasPills() {
        return this._value.length > 0;
    }

    /** Build pill data from selected values, preserving selection order. */
    get selectedPills() {
        const optMap = new Map(this._options.map(o => [o.value, o.label]));
        return this._value.map(v => ({
            label: optMap.get(v) || v,
            value: v
        }));
    }

    // ── Event Handlers ────────────────────────────────────────

    handleComboboxChange(event) {
        // Stop the combobox's native change event from leaking to the parent
        event.stopPropagation();

        const picked = event.detail.value;
        if (!picked || this._value.includes(picked)) {
            return;
        }

        const newValues = [...this._value, picked];
        this._value = newValues;
        this.fireChange(newValues);

        // Reset the combobox back to placeholder so user can pick another
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const combo = this.template.querySelector('lightning-combobox');
            if (combo) {
                combo.value = '';
            }
        }, 0);
    }

    handlePillRemove(event) {
        // Stop pill's native remove event from leaking
        event.stopPropagation();

        const removedValue = event.target.name;
        const newValues = this._value.filter(v => v !== removedValue);
        this._value = newValues;
        this.fireChange(newValues);
    }

    // ── Helpers ───────────────────────────────────────────────

    fireChange(newValues) {
        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: { value: newValues }
            })
        );
    }
}