import { LightningElement, api, track } from "lwc";

export default class NameClearenceSearchFilters extends LightningElement {
    @api selectedMatchType = "alphabetical";
    @api selectedDataSources = ["current", "historical", "reservations"];

    @track showDataSourceError = false;

    // Match type options
    get matchTypeOptions() {
        return [
            { label: "Alphabetical", value: "alphabetical" },
            { label: "Exact Match", value: "exact" },
            { label: "Begins With", value: "beginswith" },
            { label: "Contains", value: "contains" }
            //{ label: "Phonetic", value: "phonetic" }
        ];
    }

    // Data source options
    get dataSourceOptions() {
        return [
            { label: "Current/Active Names", value: "current" },
            { label: "Historical Names", value: "historical" },
            { label: "Name Reservations", value: "reservations" }
        ];
    }

    // Computed properties for display
    get matchTypeLabel() {
        const option = this.matchTypeOptions.find((opt) => opt.value === this.selectedMatchType);
        return option ? option.label : this.selectedMatchType;
    }

    get dataSourcesLabel() {
        const selectedLabels = this.dataSourceOptions.filter((opt) => this.selectedDataSources.includes(opt.value)).map((opt) => opt.label);
        return selectedLabels.length > 0 ? selectedLabels.join(", ") : "None";
    }

    get isCaseSensitiveDisabled() {
        // Case sensitive doesn't make sense for phonetic matching
        return this.selectedMatchType === "phonetic";
    }

    // Event handlers
    handleMatchTypeChange(event) {
        this.selectedMatchType = event.detail.value;

        // Reset case sensitive if switching to phonetic
        if (this.selectedMatchType === "phonetic") {
            this.caseSensitive = false;
        }

        this.dispatchFilterChange();
    }

    handleDataSourceChange(event) {
        const newSelection = event.detail.value || [];

        if (newSelection.length === 0) {
            this.showDataSourceError = true;
            return;
        }

        this.showDataSourceError = false;
        this.selectedDataSources = [...newSelection];
        this.dispatchFilterChange();
    }

    handleResetFilters() {
        // Reset to defaults
        this.selectedMatchType = "alphabetical";
        this.selectedDataSources = ["current", "historical", "reservations"];
        this.showDataSourceError = false;

        this.dispatchFilterChange();
    }

    // Helper method to dispatch filter changes
    dispatchFilterChange() {
        const filterData = {
            matchType: this.selectedMatchType,
            dataSources: [...this.selectedDataSources]
        };

        // Dispatch individual filter changes
        this.dispatchEvent(
            new CustomEvent("filterchange", {
                detail: { filterType: "matchType", value: this.selectedMatchType }
            })
        );

        this.dispatchEvent(
            new CustomEvent("filterchange", {
                detail: { filterType: "dataSources", value: this.selectedDataSources }
            })
        );
    }
}